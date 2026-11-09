#!/bin/bash
for i in $(seq 1 120); do pgrep -x app.elf > /dev/null && break; sleep 1; done
t0=$(date +%s)
while [ $(( $(date +%s) - t0 )) -lt 180 ]; do sleep 1; done
pgrep -x app.elf > /dev/null && echo 3 > $RUN_DIR/cap-menu.trigger && echo "$(date +%T) trigger written"
