#!/bin/bash
# usage: run-ab.sh TAG SECS ORDER...  ORDER items A or B. Headless kwin, PPSA03671 from launch, no input, SECS then stop by PID, window shot at the end. EXTRA env via $EXTRA.
P=$WORK; D=$P/anyps5-run; R=$D/${RT:-rt-pin}; TAG=$1; SECS=$2; shift 2
(setsid kwin_wayland --virtual --xwayland --socket wl-$TAG --width 1920 --height 1080 > $D/kwin-$TAG.log 2>&1 < /dev/null & echo $! > $D/kwin-$TAG.pid); sleep 6
XD=$(ls -t /tmp/.X11-unix/ | head -1 | sed 's/^X/:/')
stop() { kill $1 2>/dev/null; for i in $(seq 1 30); do kill -0 $1 2>/dev/null || return; sleep 0.5; done; kill -9 $1; }
n=0
for side in "$@"; do n=$((n+1)); O=$D/$TAG/$n-$side; mkdir -p $O; cd $R || exit 1
  pgrep -x app.elf > /dev/null && { echo "a game is running, stop"; break; }
  [ -d $D/hw-pin$side ] && cp $D/hw-pin$side/libs/libSceAgcDriver.prx libs/
  rm -f aps5-summary.jsonl; t0=$(date +%s)
  setsid env -u WAYLAND_DISPLAY -u XAUTHORITY DISPLAY=$XD SDL_VIDEODRIVER=x11 APS5_TRACE_SUMMARY_EVERY=10 SDL_AUDIODRIVER=pipewire $EXTRA MEMMAX=${MEMMAX:-25G} SWAPMAX=${SWAPMAX:-2G} $D/memguard.sh ./app.elf > $O/game.log 2>&1 < /dev/null &
  for i in $(seq 1 40); do G=$(pgrep -n -x app.elf) && [ "$(readlink /proc/$G/cwd)" = "$R" ] && break; G=; sleep 0.25; done
  ( while kill -0 $G 2>/dev/null; do nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits >> $O/vram.txt 2>/dev/null; sleep 10; done ) &
  ns=${SHOTS:-0}; nexts=$ns
  while kill -0 $G 2>/dev/null && [ $(( $(date +%s) - t0 )) -lt $SECS ]; do
    el=$(( $(date +%s) - t0 ))
    if [ $ns -gt 0 ] && [ $el -ge $nexts ]; then W=$(DISPLAY=$XD xwininfo -root -tree | awk '/"app.elf"/{print $1; exit}'); [ -n "$W" ] && ffmpeg -loglevel error -y -f x11grab -window_id $W -i $XD -frames:v 1 $O/shot-$(printf %04d $el).png; nexts=$((nexts+ns)); fi
    sleep 2; done
  W=$(DISPLAY=$XD xwininfo -root -tree | awk '/"app.elf"/{print $1; exit}'); [ -n "$W" ] && ffmpeg -loglevel error -y -f x11grab -window_id $W -i $XD -frames:v 1 $O/end.png
  if kill -0 $G 2>/dev/null; then stop $G; st=stopped; else st=EXITED; fi
  mv aps5-summary.jsonl $O/ 2>/dev/null
  echo "$(date +%T) $n-$side $st at +$(( $(date +%s) - t0 ))s: $(/usr/bin/python3 -I $RUN_DIR/last5.py $O/aps5-summary.jsonl 2>&1 | tail -1) | $(grep -m1 -E 'terminate|what\(\)|driver failure' $O/game.log | cut -c1-150)"
  for i in $(seq 1 60); do pgrep -x app.elf > /dev/null || break; sleep 1; done; sleep 3; done
kill $(cat $D/kwin-$TAG.pid); echo "$(date +%T) RUNDONE"
