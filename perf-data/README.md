# AnyPS5 performance measurements

Measurements of PS5 games running on [AnyPS5](https://github.com/boykopovar/AnyPS5), taken on my own machines.
They are shared so anyone working on the emulator can compare against them, reuse them, or check a fix without re-running the game.

Everything here is a readable summary. Raw logs (often several GB per run) stay on the machine they came from; ask in an issue if you need a specific log.

## How to find things

- [../research/](../research/): the analysis built on these runs (start with the structural analysis), dead ends and the test patches.

- [games/](games/): one page per game, listing every measured phase and the runs for it.
- [runs/](runs/): one page per run or A/B, named `YYYY-MM-DD-<game>-<phase>-<what>.md`.
- [data/runs.csv](data/runs.csv): one row per run arm with the headline numbers, for spreadsheets and scripts.
- [machines.md](machines.md): hardware, OS and driver of each machine.
- [TEMPLATE.md](TEMPLATE.md): the layout every run page follows.

## Games measured so far

| Game | Phases measured | Page |
|---|---|---|
| Diablo II Resurrected (PPSA03912) | main menu | [diablo-ii-resurrected.md](games/diablo-ii-resurrected.md) |
| Ghost of Yotei (PPSA26344) | boot, loading | [ghost-of-yotei.md](games/ghost-of-yotei.md) |
| Hot Wheels Infinite Rush (PPSA22408) | title screen, boot, race load, race | [hot-wheels-infinite-rush.md](games/hot-wheels-infinite-rush.md) |
| Sonic Origins Plus (PPSA05325) | Sonic 2 menu page | [sonic-origins-plus.md](games/sonic-origins-plus.md) |

## How runs are measured

A change is never judged on FPS alone: fixing one bottleneck can make another one bigger. Every run records the same set, and runs are only compared within the same game phase (loading, menu, gameplay, cinematic).

| Metric | What it means | Source |
|---|---|---|
| Presents per 10 s | frames shown (10 s windows, median over the measured window) | `[present]` log line |
| Frame p50 | median time per presented frame (GPU busy + idle gaps) | `[present]` |
| GPU ms per frame | all GPU time in the window divided by presents, plus the top classes (draw, fill, upload, write-back, shadow-publish, ...) | `APS5_PROFILE_GPU=1`, `[gputime]` |
| CPU per thread | CPU seconds per 10 s for the emulator threads | per-thread sampler |
| Draw cache / dispatch cache | hit rates | `APS5_PROFILE_DRAW=1`, `[draw-cache]` |
| Data copied CPU <-> GPU | storage uploads, write-backs, staging, big-buffer copies in MiB per 10 s | `[buffers]`, `[gputime]` |
| Shader compiles | pipeline creates, disk cache hits/misses, recompile memo | log |
| Waits | in-flight wait, hook syncs, lock waits | `[present]`, `[hooksync]`, `[draw]` |
| Memory | RAM (anon / shmem / file), VRAM, GPU (SM) load | `/proc`, `nvidia-smi dmon` or `amdgpu` |

Default environment for every run: `APS5_PROFILE_GPU=1 APS5_PROFILE_DRAW=1 APS5_TRACE_SUMMARY_EVERY=10`. Game audio is muted. Each run page lists the exact commit, any patch on top, and extra environment variables.

A/B tests use base and change built from the same upstream commit, alternate the arms (A B A B) and report every arm, not only the best one.

## Using this data

Feel free to quote or link anything here. If a number looks wrong, or you want a run on one of these machines, open an issue on this repository.

AI-assisted. Tested by me on my own machine.
