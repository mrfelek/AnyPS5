# Run scripts for PPSA03671

These are the scripts the runs in [the notes](../README.md) used, as they ran, with the machine paths replaced by variables. Set these before using them:

| Variable | Meaning |
|---|---|
| `SRC` | the AnyPS5 source tree (with `build/`, and `build-tools/` for the pipeline tool) |
| `WORK` | the directory holding the build trees and `RUN_DIR` |
| `RUN_DIR` | where runtimes (`rt-pin`, `rt-cur`), `hw-pin<SIDE>/libs` driver builds, captures and logs live |
| `GAME_DIR` | the AMD machine's title directory (`rt/` runtime, `work/` relink input) |
| `GAME_SHARE` | the AMD machine's read-only sshfs mount of the title files from the desktop |
| `OUT_DIR` | the AMD machine's run output directory |
| `SCRIPTS` | the directory holding these scripts on the AMD machine |
| `UPSTREAM_CLONE` | a plain clone of the upstream repository on the AMD machine |

## Desktop (NVIDIA)

| Script | What it does |
|---|---|
| `run-ab.sh TAG SECS SIDE...` | starts a headless kwin, runs the title from launch for SECS per side in a memory-capped scope, copies `hw-pin<SIDE>/libs/libSceAgcDriver.prx` in first, takes window shots (`SHOTS=n`), stops by PID; `EXTRA` adds environment, `MEMMAX`/`SWAPMAX` set the cap |
| `memguard.sh CMD...` | runs CMD in its own systemd user scope capped at `MEMMAX` RAM + `SWAPMAX` swap |
| `make-runtime.sh` | builds the prx libraries, relinks the title and assembles a runtime directory without following symlinks into the dump |
| `presser.sh`, `presser2.sh` | write a cross press to the pad input file at 170 s (and 300 s) |
| `trigger180.sh` | starts a 3-frame capture at 180 s through the capture trigger file |
| `mesh-ab.sh` | replays a capture twice per variant (`APS5_NO_MESH_WINDOW_BUFFER`, `APS5_SINGLE_LANE`) and prints frame time and GPU time by program |
| `decode_targets.py SRC OUT` | turns `APS5_DUMP_TARGETS` raw dumps into PNGs (needs numpy and pillow) |
| `last5.py SUMMARY...` | FPS, frame time and GPU time per frame over the last five summary windows |

## AMD machine (Radeon 780M)

| Script | What it does |
|---|---|
| `amd-build.sh` | worktree of a given `main` plus PRs, builds, relinks and assembles the runtime |
| `amd-run.sh TAG SECS` | runs the title on the machine's display with `XENV`, dumps frames every 100 presents, stops by PID |
| `presser.sh` | cross presses from 300 s, every 120 s |
| `amd-memprof.sh` | a run that records the game's largest anonymous mappings and RSS kinds every 60 s |
| `cp-capture.sh` | runs with `APS5_DUMP_COMPUTE_PIPELINES` and the ray-tracing kernel enabled, into an empty directory of its own |
| `cp-compile.sh` | compiles each captured pipeline with `agc_compute_pipeline_replay` in a memory-capped scope, filling the Mesa disk cache |

The swap limit in `cp-compile.sh` (16G) was too small for the ray-tracing kernel; the run that worked used `MemorySwapMax=infinity` with 82 GB of swap.
