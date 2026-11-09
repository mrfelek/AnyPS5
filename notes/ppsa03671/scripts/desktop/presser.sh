#!/bin/bash
for i in $(seq 1 120); do pgrep -x app.elf > /dev/null && break; sleep 1; done
t0=$(date +%s)
for at in 170; do
  while [ $(( $(date +%s) - t0 )) -lt $at ]; do sleep 1; done
  pgrep -x app.elf > /dev/null || exit 0
  /usr/bin/python3 -I $SRC/tools/pad_input.py $RUN_DIR/ppsa03671.pad cross && echo "$(date +%T) pressed cross at +$at s"
done
