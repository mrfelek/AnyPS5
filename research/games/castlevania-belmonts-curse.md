# Castlevania Belmont's Curse (PPSA35399)

Everything I tested on this game, in one place. Upstream discussion: [D#5832](https://github.com/boykopovar/AnyPS5/discussions/5832). Unity IL2CPP game, content 01.000.000. Machines: Linux desktop (RTX 3080 Ti) and Windows laptop (RTX A2000). Specs: [machines.md](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/machines.md).

## Where it gets to

- **In-game on Linux and Windows.** The menu runs at 60 FPS. The opening cinematic is black: hold Circle to skip it.
- **Windows laptop, plain main:** always reaches gameplay, sometimes after a few minutes on the loading screen.
- **Setup, Linux:** unwrap `Media/Modules` and `Media/Plugins`, then `relinker --registry --module-dir Media/Modules --module-dir Media/Plugins src/eboot.elf app.elf`. **Windows:** add `--windows` to get `app.exe`; put the `.guest.prx` files next to the originals in `app0` (`Media/Modules`, `Media/Plugins`, `sce_module`), not in the `libs` folder. A self-built Windows binary also needs the MinGW `libgcc_s_seh-1`, `libstdc++-6` and `libwinpthread-1` DLLs in the `libs` folder (otherwise error 126).

## Speed

- In-game was about 3.8 FPS on the 15 October build and about 1.9x that on main of 20 October (62-66 presents per 10 s on the Linux desktop).
- **CPU-bound** in the packet worker and the AGC driver. About 93% of draws miss the draw cache because of per-object data: five pointers step by 0x110 per object, and each draw has its own vertex buffer base. Same pattern as Sonic Origins, see [draw cache notes](https://github.com/mrfelek/AnyPS5/blob/main/research/draw-cache-per-draw-rework.md).

## What I tested

| Change | What it does | Result on this game |
|---|---|---|
| jemalloc as the game's allocator (local) | Replaces the guest heap allocator with jemalloc. | +18% (posted earlier in this thread). |
| mimalloc on Linux (local branch, not a PR) | Lets Linux use the `APS5_MIMALLOC` switch that Windows already has (#6067). | +15-22% on two games, but the first run did not shut down cleanly. Needs a re-measure, because the change to when the game's own allocator is used (#7897) came after. |
| `APS5_MIMALLOC` on Windows | Existing switch. | Hangs on loading (2 of 2 starts). |
| Per-object pointer relocation (local) | Relocates the moving per-object pointers so draws hit the cache. | +25-30%, but guessing which words are pointers is not safe (wrong draws on Astro Bot). **Instead:** pointer provenance from the recompiler. |
| [#6539](https://github.com/boykopovar/AnyPS5/pull/6539) (forwards user words), [#5404](https://github.com/boykopovar/AnyPS5/pull/5404) (bypasses the draw cache under 5% hits), `APS5_RELOCATE_VERTEX_FETCH` | Draw cache changes. | Ruled out here: per-draw buffer addresses still change, so draws still miss. **Instead:** pointer provenance from the recompiler, or ring offsets passed as data. |
| Float denormal flush probe (my fix, not upstream yet), Windows laptop | Only emulates float denormal handling where the GPU differs. | Inconclusive: with the fix, one start stayed on the black loading screen for about 9 minutes after New Game and was stopped; the second was stopped before New Game. Needs a rerun. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-d2r-main-menu-f32-flush-ab.md) (Run 4) |

AI-assisted. Tested by me on my own machine.
