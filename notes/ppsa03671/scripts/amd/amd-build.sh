#!/bin/bash
# AMD: build main c36ab99c74 + #12575 (a7af0b7a4b) + #12746 (ac71a77a4a), relink PPSA03671 into $GAME_DIR/rt
set -u
G=$GAME_DIR; W=$SRC; B=$W/build
cd $UPSTREAM_CLONE || exit 1
git fetch -q https://github.com/boykopovar/AnyPS5 main refs/pull/12575/head:refs/heads/pr12575 refs/pull/12746/head:refs/heads/pr12746 2>&1 | tail -2
git cat-file -e c36ab99c74^{commit} && git cat-file -e a7af0b7a4b^{commit} && git cat-file -e ac71a77a4a^{commit} || { echo "commits missing"; exit 1; }
[ -e $W ] && { echo "$W exists"; exit 1; }
git worktree add --detach $W c36ab99c74 > /dev/null 2>&1 || exit 1
cd $W && git -c user.name=t -c user.email=t@t merge -q --no-edit a7af0b7a4b && git -c user.name=t -c user.email=t@t merge -q --no-edit ac71a77a4a || { echo MERGE FAILED; exit 1; }
echo "tree $(git rev-parse --short HEAD^{tree})"
git submodule update --init --recursive --reference $UPSTREAM_CLONE > sub.log 2>&1; echo "submodules unfetched: $(git submodule status | grep -c "^-")"
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DANYPS5_RELINKER_CLI=ON -DPython3_EXECUTABLE=/usr/bin/python3 > cfg.log 2>&1; echo "cfg $?"
ninja -C build -j16 > build.log 2>&1; echo "ninja $?"; grep -m3 -E "error:|FAILED" build.log
ninja -C build -t targets all | grep -E "^core/libs/libs/[A-Za-z0-9_-]+\.prx: CUSTOM_COMMAND" | cut -d: -f1 > prx-targets.txt
xargs -a prx-targets.txt ninja -C build -j16 > build3.log 2>&1; echo "prx $?"
R=$G/rt; WK=$G/work
(cd $WK && $B/core/relinker/relinker --registry src/eboot.elf app.elf 2>&1 | tr "\r" "\n" | grep -iE "error|fail|Conversion complete" | tail -3)
for d in $R/app0 $R/app0/sce_module; do [ -L $d ] && { echo "ABORT link $d"; exit 1; }; done
mkdir -p $R/libs $R/shader_cache
for f in $B/core/libs/libs/*.prx; do case $(basename $f) in *.native.prx) ;; *) cp $f $R/libs/;; esac; done
for f in $B/core/libs/libs/unpatched/*.native.prx; do n=$(basename $f .prx); cp $f $R/libs/$n.prx; $B/core/libs/nid_patcher $n --preserve-export-list $B/core/libs/libc.exports $R/libs/$n.prx | grep -v "^OK"; done
cp $WK/app.elf $WK/*.json $R/ && chmod +x $R/app.elf
(cd $WK && find app0 -name "*.guest.prx") | while read f; do [ -L $R/$f ] && { echo "ABORT link $f"; exit 1; }; cp $WK/$f $R/$f; done
echo "$R ready, missing libs $(cd $R && LD_LIBRARY_PATH=libs ldd app.elf | grep -c "not found")"
echo BUILDDONE
