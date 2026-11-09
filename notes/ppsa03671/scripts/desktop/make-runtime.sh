#!/bin/bash
# runtime rt-cur from storage-mru build (current main + fix); A' driver = current main without the fix
P=$WORK; D=$P/anyps5-run; W=$P/anyps5-build/storage-mru; B=$W/build; N=rt-cur; K=$D/work-$N
cd $D || exit 1
[ -e $N ] && { echo "$N exists"; exit 1; }
xargs_targets=$(ninja -C $B -t targets all | grep -E "^core/libs/libs/[A-Za-z0-9_-]+\.prx: CUSTOM_COMMAND" | cut -d: -f1)
ninja -C $B -j28 $xargs_targets > $W/build-prx.log 2>&1 || { echo PRX FAILED; exit 1; }
rm -rf $K; mkdir $K && cp -r work-base/src $K/
(cd $K && $B/core/relinker/relinker --registry src/eboot.elf app.elf 2>&1 | tr '\r' '\n' | grep -iE "error|fail|Conversion complete" | tail -3)
chmod +x $K/app.elf
mkdir $N && (cd rt-pin && tar --exclude='./libs' --exclude='./shader_cache' --exclude='./*.log' --exclude='./app.elf' --exclude='./*.json' --exclude='./aps5-*' -cf - .) | (cd $N && tar xf -)
[ -L $N/app0/sce_module ] && { echo "ABORT link"; exit 1; }
mkdir $N/shader_cache $N/libs
for f in $B/core/libs/libs/*.prx; do b=$(basename $f); case $b in *.native.prx) ;; *) cp $f $N/libs/;; esac; done
for f in $B/core/libs/libs/unpatched/*.native.prx; do n=$(basename $f .prx); cp $f $N/libs/$n.prx; $B/core/libs/nid_patcher $n --preserve-export-list $B/core/libs/libc.exports $N/libs/$n.prx | grep -v '^OK'; done
cp $K/app.elf $K/*.json $N/; (cd $K && find app0 -name '*.guest.prx') | while read f; do [ -L $N/$f ] && { echo "ABORT link $f"; exit 1; }; cp $K/$f $N/$f; done
mkdir -p hw-curB/libs hw-curA/libs && cp $N/libs/libSceAgcDriver.prx hw-curB/libs/
cd $W && git switch -q --detach HEAD~1 && ninja -C build -j28 core/libs/libs/libSceAgcDriver.prx > build-curA.log 2>&1 && cp build/core/libs/libs/libSceAgcDriver.prx $D/hw-curA/libs/ ; git switch -q perf/agc-storage-cache-thrash && ninja -C build -j28 core/libs/libs/libSceAgcDriver.prx > /dev/null 2>&1
cmp -s $D/hw-curA/libs/libSceAgcDriver.prx $D/hw-curB/libs/libSceAgcDriver.prx && echo "A==B?!" 
echo "$N ready, missing libs $(cd $D/$N && LD_LIBRARY_PATH=libs ldd app.elf | grep -c 'not found'), branch $(git -C $W rev-parse --abbrev-ref HEAD)"
