#!/bin/bash
# usage: cp-compile.sh -- compiles each captured compute pipeline outside the game, one at a time, under a memory cap, filling the Mesa disk cache
T=$SRC/build-tools/core/libs/prx/libSceAgcDriver/agc_compute_pipeline_replay
O=$OUT_DIR/cpcompile; mkdir -p $O
pgrep -x app.elf >/dev/null && { echo "a game is running"; exit 1; }
for d in $OUT_DIR/cpdump/compute-*/; do
  id=$(basename $d)
  echo "$(date +%T) $id start, mesa cache $(du -sh ~/.cache/mesa_shader_cache | cut -f1)"
  systemd-run --user --quiet --scope -p MemoryMax=26G -p MemorySwapMax=16G /usr/bin/time -v $T $d/capture.aps5cp --output $O/$id.json > $O/$id.log 2>&1
  echo "$(date +%T) $id exit $? peak $(grep "Maximum resident" $O/$id.log | awk "{print \$NF}") kB, wall $(grep "Elapsed (wall" $O/$id.log | awk "{print \$NF}")"
done
du -sh ~/.cache/mesa_shader_cache
echo CPCOMPILEDONE
