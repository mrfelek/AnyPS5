#!/bin/bash
# usage: amd-run.sh TAG SECS -- PPSA03671 from launch, no input, on the box display; frames dumped every 100 presents; stop by PID
R=$GAME_DIR/rt; TAG=$1; SECS=${2:-300}; O=$OUT_DIR/$TAG; mkdir -p $O
cd $R || exit 1
mount | grep -q " $GAME_SHARE " || { echo "share not mounted"; exit 1; }
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-0 DISPLAY=:0
export XAUTHORITY=$(ls -t /run/user/$(id -u)/xauth_* 2>/dev/null | head -1)
pgrep -x app.elf >/dev/null && { echo "a game is running, not starting"; exit 1; }
rm -f frame_*.bmp aps5-summary.jsonl; kscreen-doctor --dpms on >/dev/null 2>&1
env SDL_AUDIODRIVER=dummy APS5_TRACE_SUMMARY_EVERY=10 APS5_PROFILE_DRAW=1 APS5_DUMP_FRAMES=40 APS5_DUMP_FRAMES_EVERY=100 $XENV ./app.elf > $O/game.log 2>&1 < /dev/null &
G=$!; s0=$(date +%s); echo "$(date +%T) $TAG started pid $G env: $XENV"
(while kill -0 $G 2>/dev/null; do kscreen-doctor --dpms on >/dev/null 2>&1; sleep 60; done) &
while kill -0 $G 2>/dev/null && [ $(( $(date +%s) - s0 )) -lt $SECS ]; do sleep 2; done
if kill -0 $G 2>/dev/null; then kill $G; for i in $(seq 1 30); do kill -0 $G 2>/dev/null || break; sleep 1; done; kill -0 $G 2>/dev/null && kill -9 $G; st=stopped; else st=EXITED; fi
mv aps5-summary.jsonl $O/ 2>/dev/null; mv frame_*.bmp $O/ 2>/dev/null
echo "$(date +%T) $TAG $st at +$(( $(date +%s) - s0 ))s; last error: $(grep -m1 -E "terminate|what\(\)|driver failure" $O/game.log | cut -c1-200)"
echo RUNDONE
