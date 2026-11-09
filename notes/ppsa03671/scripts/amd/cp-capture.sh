#!/bin/bash
# usage: cp-capture.sh -- runs PPSA03671 with the RT kernel enabled and compute-pipeline capture on; stops the game by PID once the big capture file is written
C=$OUT_DIR/cpdump; mkdir -p $C; [ -z "$(ls -A $C)" ] || { echo "capture dir not empty"; exit 1; }
pgrep -x app.elf >/dev/null && { echo "a game is running"; exit 1; }
export XENV="APS5_DUMP_COMPUTE_PIPELINES=$C APS5_DUMP_COMPUTE_MIN_WORDS=1000000 APS5_DIAG_TABLE_USAGE=1 APS5_DIFF_IN_PLACE=1 APS5_EXP_DESCRIPTOR_DATA=1 APS5_EXP_DIRECT_CHASE=1 APS5_EXP_FOREIGN_RECORDS=1 APS5_EXP_NULL_TYPED_LOADS=1 APS5_EXP_ONLY=11d049aa00 APS5_EXP_RELEASE_UNWRITTEN=1 APS5_HOST_IMPORT_MIB=12288 APS5_LAZY_TABLES=1 APS5_TEXTURE_DOWNSCALE=1"
$SCRIPTS/amd-run.sh cpcap2 900 > $OUT_DIR/cpcap-run.log 2>&1 &
R=$!
while kill -0 $R 2>/dev/null; do
  f=$(find $C -name capture.aps5cp -size +8M 2>/dev/null | head -1)
  if [ -n "$f" ]; then s1=$(stat -c %s "$f"); sleep 5; s2=$(stat -c %s "$f"); if [ "$s1" = "$s2" ]; then echo "$(date +%T) capture written: $f ($s2 bytes)"; G=$(pgrep -x app.elf); [ -n "$G" ] && kill $G; break; fi; fi
  sleep 2
done
wait $R; tail -2 $OUT_DIR/cpcap-run.log; echo CPCAPDONE
