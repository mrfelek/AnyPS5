#!/bin/bash
P=/tmp/ppsa03671.pad; rm -f $P
for i in $(seq 1 120); do pgrep -x app.elf > /dev/null && break; sleep 1; done
t0=$(date +%s)
for at in $(seq 300 120 1500); do
  while [ $(( $(date +%s) - t0 )) -lt $at ]; do sleep 1; done
  pgrep -x app.elf > /dev/null || exit 0
  python3 -I $SRC/tools/pad_input.py $P cross > /dev/null && echo "$(date +%T) pressed cross at +$at s"
done
