#!/bin/bash
# warm run with the prototype; every 60 s record the biggest mappings and RSS kinds of the game
XENV="APS5_LAZY_TABLES=1 APS5_DIAG_TABLE_USAGE=1 APS5_TEXTURE_DOWNSCALE=1 APS5_PROFILE_DRAW=1" $SCRIPTS/amd-run.sh memprof2 660 &
R=$!; O=$OUT_DIR/memprof2-maps.txt; : > $O
while kill -0 $R 2>/dev/null; do
  G=$(pgrep -x app.elf)
  if [ -n "$G" ]; then
    { echo "=== $(date +%T) $(awk "/RssAnon|RssShmem|RssFile/{printf \"%s %s  \", \$1, \$2}" /proc/$G/status) GTT $(cat /sys/class/drm/card*/device/mem_info_gtt_used | head -1)";
      awk "/^[0-9a-f]+-[0-9a-f]+ /{range=\$1; name=\$6} /^Anonymous:/{if(\$2>65536) printf \"%10d kB %s %s\n\", \$2, range, name}" /proc/$G/smaps | sort -rn | head -12; } >> $O
  fi
  sleep 60
done
echo MEMPROFDONE
