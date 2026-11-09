#!/bin/bash
R=$RUN_DIR
BASE="APS5_PROFILE_GPU=1 APS5_PROFILE_GPU_DRAWS=1 APS5_DIAG_TABLE_USAGE=1 APS5_DIFF_IN_PLACE=1 APS5_LAZY_TABLES=1 APS5_TEXTURE_DOWNSCALE=1 APS5_DIAG_IGNORE_STENCIL_EXPORT=1 ANYPS5_NO_SHADER_CACHE=1 APS5_EXP_ONLY=11d049aa00 APS5_EXP_DIRECT_CHASE=1 APS5_EXP_FOREIGN_RECORDS=1 APS5_EXP_DESCRIPTOR_DATA=1 APS5_EXP_NULL_TYPED_LOADS=1 __GL_SHADER_DISK_CACHE_SIZE=4000000000"
for v in "nowin:APS5_NO_MESH_WINDOW_BUFFER=1" "single:APS5_SINGLE_LANE=11d00cde00,11d0134500"; do
  tag=${v%%:*}; ex=${v#*:}
  D=$R/cap-menu-$tag; mkdir -p $D; cd $D; ln -sfn ../rt-cur/shader_cache shader_cache
  env $BASE $ex MEMMAX=26G SWAPMAX=24G $R/memguard.sh timeout 3000 $SRC/build/core/libs/prx/libSceAgcDriver/agc_frame_replay $R/cap-menu --repeat 2 --frames . > replay.log 2>&1 < /dev/null
  echo "== $tag $(grep -o '"passes":\[[^]]*\]' replay.log | grep -oE '"p50":[0-9.]+' | tr '\n' ' ')"
  grep "^\[gputime\]" replay.log | tail -1 | grep -oE "^\[gputime\] [0-9]+ ms|by program: [^;]*" | cut -c1-300
done
echo ALLDONE
