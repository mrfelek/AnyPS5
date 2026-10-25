# Diablo II Resurrected (PPSA03912)

Everything I tested on this game, in one place. Upstream discussion: [D#5146](https://github.com/boykopovar/AnyPS5/discussions/5146). Machines: Linux desktop (RTX 3080 Ti, 12 GB), AMD mini PC (Radeon 780M, RADV), Windows laptop (RTX A2000). Specs: [machines.md](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/machines.md).

## Where it gets to on current main

- **Linux (NVIDIA and AMD):** boots, title, main menu, loads a save, and plays in town and in the field. Relink with `relinker --registry src/eboot.elf app.elf` after unwrapping `eboot.bin` and `sce_module/{libc,libSceJobManager,libSceNpCppWebApi}.prx`.
- **Windows:** the relink on current main fails at the relocation check (added by the relocation-check change in #7763), so I have no current Windows numbers.
- **Still breaks sometimes:** some launches start in a slow state and need a relaunch; on the Radeon 780M an intermittent crash after loading a save (2 of 12 starts); heavy memory use (peak RSS about 9.5 GB in the menu).

## Speed on current main

| Phase | Machine | Presents per 10 s | What limits it |
|---|---|---|---|
| Main menu | RTX 3080 Ti | about 88 | GPU (98-99% load, about 106 ms GPU per frame). The heavy passes render at 3840x2160 and four fragment shaders are about 1.3 MB of SPIR-V each. Draw cache hits 0.3%. |
| Main menu | Radeon 780M | about 51 | CPU: queue worker 0 is 99% busy recording draws, about 46 us per draw, about 70k draws per 10 s. |
| Gameplay (town, settled) | RTX 3080 Ti | 55-57 | Staging of written buffers (see #7618 below). |

Run pages: [main menu baseline](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-d2r-main-menu-baseline.md), [all runs for this game](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/games/diablo-ii-resurrected.md).

## Fixes and PRs that touch this game

| Change | What it does | Result on this game |
|---|---|---|
| Float denormal flush probe (my fix, not upstream yet) | Asks the driver per GPU whether 32-bit float denormal handling already matches the PS5, and only emulates it where it does not (floor and ceil stay emulated). | Main menu on RTX 3080 Ti: 91 -> 115 presents per 10 s (+26%), GPU 104 -> 74 ms per frame, same picture. No change on the Radeon 780M, where the hardware already matches. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-d2r-main-menu-f32-flush-ab.md), [notes](https://github.com/mrfelek/AnyPS5/blob/main/research/f32-denormal-flush.md) |
| [#7618](https://github.com/boykopovar/AnyPS5/pull/7618) (mine, stages written-only buffer elements) | Stages only the written elements of buffers the GPU writes, instead of whole buffers. | Gameplay: 55-57 -> 77-85 presents per 10 s (about +40%) for +150-200 MiB VRAM; about 18-21 GB staged in and back per 10 s vs 0.47 GB; 0 refused. Waits on re-review. |
| [#7814](https://github.com/boykopovar/AnyPS5/pull/7814) (VideoOut output resolution) | Lets you pick a 1080p video output. | No change: the game still renders its passes at 4K. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-d2r-main-menu-1080p.md) |

## Ruled out, and what to do instead

These are proven not to be the way for this game. Each says which direction to take instead.

- **Skipping the indirect draw argument read** (probe): one indirect draw per frame stays on the CPU path and waits about 43 ms for the GPU. Removing the wait (3.6 s per 10 s -> 0) does not raise FPS, because the GPU is the limit. **Instead:** cut the GPU time of the 4K draw passes first (the float denormal fix above); only then does the indirect read become worth removing. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-d2r-main-menu-indirect-no-read-probe.md), [notes](https://github.com/mrfelek/AnyPS5/blob/main/research/indirect-draw-reads.md)
- **Draw cache reuse by relocating per-draw pointers** (local experiment): the verifier finds a reused build that differs from a fresh one, in both versions of the patch (v1: 8 runs vs 9 in one fragment stage; v2, rerun 25 October: same run count, different contents), so it is not correct yet. **Instead:** reuse needs to know exactly which words are pointers (provenance from the recompiler), or the moving ring offsets should be passed as data (dynamic offsets) instead of baked into the shader build. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-d2r-main-menu-amd-draw-cache-relocation-check.md)

- **Reusing descriptor sets between draws** (my prototype, Radeon 780M, character select, 25 October): about 30% fewer descriptor writes, but cost per draw (about 46 us), presents (about 53 per 10 s) and GPU time do not change; descriptor updates are about 1.6 us of each draw. **Instead:** the larger pieces: the vectors phase (76.8 of 118.5 us per draw packet) and reading the arguments of empty indirect draws before skipping them (1,067 per 10 s, about 5.2 ms each). [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-25-d2r-character-select-amd-draw-set-reuse.md)

## Known slow spots not fixed yet

- **Loading screens:** one 2D array texture is bound one layer at a time and becomes 90 separate images that copy each other through guest memory, about 35 GB per 10 s each way. [notes](https://github.com/mrfelek/AnyPS5/blob/main/research/menu-image-round-trip.md)
- **Radeon 780M:** the menu is limited by per-draw recording cost on one thread. [notes](https://github.com/mrfelek/AnyPS5/blob/main/research/draw-committer-cost.md)

AI-assisted. Tested by me on my own machine.
