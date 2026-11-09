#!/bin/bash
# usage: memguard.sh CMD ARGS... -- run a game command inside its own systemd user scope capped at $MEMMAX (default 22G) RAM + $SWAPMAX (default 2G) swap,
# so a leak gets the game OOM-killed inside its scope and not the desktop. The command keeps this PID (systemd-run --scope execs it).
exec systemd-run --user --quiet --scope --unit=aps5-game-$$ -p MemoryMax=${MEMMAX:-22G} -p MemorySwapMax=${SWAPMAX:-2G} "$@"
