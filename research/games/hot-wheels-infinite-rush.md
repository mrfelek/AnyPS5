# Hot Wheels Infinite Rush (PPSA22408)

Everything I tested on this game, in one place. Upstream discussion: [D#6895](https://github.com/boykopovar/AnyPS5/discussions/6895). Machines: Linux desktop (RTX 3080 Ti, 12 GB), AMD mini PC (Radeon 780M, RADV), Windows laptop (RTX A2000). Specs: [machines.md](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/machines.md).

## Where it gets to

- **Current main dies on the logo screen** after about 3.7 minutes: the update check (`sceGameUpdateCreateRequest`) throws. [#10614](https://github.com/boykopovar/AnyPS5/pull/10614) (mine, GameUpdate answers "no update" instead of throwing) fixes it and is approved, waiting for merge. All runs below use that fix.
- **With the fix:** intro, title, menus, garage and races all run on Linux (NVIDIA and AMD) and Windows. The scenery in the garage and in races is black (see below).
- **Setup:** relink the title's `prx/` modules too (`eossdk-ps5-shipping.prx` and the four kitt modules), otherwise it crashes on a null pointer. On NVIDIA I run with `APS5_UNIT_SHADOW_MIB=512 APS5_STAGING_POOL_MIB=768` to avoid `vkAllocateMemory` failures. On first boot: Cross on the PSN error, Down + Cross to cancel the Milestone account prompt, then Options through the five settings pages. At low FPS, hold each button 2.5-4 s.
- **Windows laptop:** one start out of six aborted at the garage load with "still pinned by GPU work".

## Speed

| Phase | Machine | Result | What limits it |
|---|---|---|---|
| Title screen | RTX 3080 Ti | about 95 presents per 10 s (9.5 FPS), GPU 64% busy | Copies: about 41 GB uploaded and 35 GB written back every 10 s. A compute pass binds a written 128 MiB buffer that covers all render targets, so every pending image is flushed and re-uploaded each frame. About 4 s of every 10 s is waiting on the GPU. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-hot-wheels-title-baseline.md) |
| Garage menu | RTX 3080 Ti | about 60 presents per 10 s | Same copy pattern (33 GB up, 28 GB back per 10 s). |
| Race load | RTX 3080 Ti | about 9 minutes warm (14 cold) | The game's 4 GiB sparse heap (only 528 MiB mapped) is copied in full about 460 times. GPU only about 19% busy. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-hot-wheels-race-load.md) |
| Race | RTX 3080 Ti | about 40 presents per 10 s, GPU 114 ms per frame | Copies and hook waits (about 1100 syncs per 10 s). |
| Race load | Radeon 780M | only 25% after 15 minutes | Memory waits on both queue workers, GPU about 3% busy. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-hot-wheels-race-load-amd-import-budget-ab.md) |
| Title / garage | RTX A2000 (Windows) | about 37 / 9-10 presents per 10 s | Shadow-publish and storage copies dominate the frame. |

**Why the heap is copied:** read-only binds of the whole heap are served in place from the joined host-memory import. A dispatch that binds the whole heap writable with atomics skips the import path (it requires that no writer overlaps the range) and falls back to the sparse mirror or a full copy. Without that copy, the load would lose an estimated 275 of its 531 s. [trace](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-hot-wheels-heap-copy-trace.md), [notes](https://github.com/mrfelek/AnyPS5/blob/main/research/hot-wheels.md)

All runs for this game: [game page](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/games/hot-wheels-infinite-rush.md).

## Fixes and PRs tested on this game

| Change | What it does | Result on this game |
|---|---|---|
| [#10614](https://github.com/boykopovar/AnyPS5/pull/10614) (mine) | GameUpdate answers "no update" instead of throwing. | Gets the game past the logo screen. Approved, waits merge. |
| [#8139](https://github.com/boykopovar/AnyPS5/pull/8139) (sparse page permissions, merged) | Tracks permissions per page in sparse ranges. | Heap copies remain (460 vs 447 before). Shadow-publish time halved, hook waits doubled. |
| [#10655](https://github.com/boykopovar/AnyPS5/pull/10655) (import page hashing off the draw thread) | Moves import page hashing off the draw thread. | Linux race load: no clear difference (A 571/541 s, B 511/541 s, inside noise). The PR targets Windows, so a Windows run is the real test. |
| [#7844](https://github.com/boykopovar/AnyPS5/pull/7844) (host heap import budget) | Caps how much host memory the import may reserve. | Radeon 780M: no effect; race load stuck at 25% after 15 min in both arms (the cap never applies with a 5658 MiB host heap). |
| Float denormal flush probe (my fix, not upstream yet) | Only emulates float denormal handling where the GPU differs. | Windows RTX A2000: draw GPU time -10-16% in every phase, presents +0-1% on the title and +4-11% in the garage, because copies dominate. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-d2r-main-menu-f32-flush-ab.md) (Run 4) |

## Ruled out, and what to do instead

Test switches that prove which way is not the way. Each says which direction to take instead.

- **Skipping the big-buffer flush on the title:** +17% presents (109 vs 93 per 10 s), GPU 50 vs 60 ms. Only an upper bound, because it skips work a scene needs when it reads those images. **Instead:** flush only the images the compute pass really reads, or keep them on the GPU so nothing has to be flushed. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-hot-wheels-title-skip-big-flush-ab.md)
- **Importing the crossing buffer instead of copying it:** the import works (0 CPU copies), but presents do not change; the next reader blocks on the same GPU writer. **Instead:** removing waits one at a time only moves them. The GPU result has to stay on the GPU and be read there, instead of going through guest memory ([structural analysis](https://github.com/mrfelek/AnyPS5/blob/main/research/structural-analysis.md), problem 1). [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-hot-wheels-title-join-crossing-ab.md)

## Black scenery (investigation paused)

Same on Radeon 780M (RADV), RTX 3080 Ti (Linux) and NVIDIA on Windows.
- The scenery comes from indirect draws whose arguments the game builds on the GPU after a culling pass. All those arguments come out 0, so the G-buffer stays empty.
- The culling pass sorts objects into 19 buckets; every object lands in buckets 16-18, which no draw reads, because the per-object visibility bitmask (320 bits) is all zero.
- The pass that sets the bitmask runs and its translation matches the guest code. It skips every object because each record has -1 (0xffffffff) in the 4th dword of element 24, which looks like an "unassigned" link written by another GPU pass that runs only occasionally.
- Ruled out: depth pyramid, the draw precheck, dispatch ordering (`APS5_SYNC_DISPATCH=1` changes nothing), CPU writes, aliased mappings, buffer descriptors, atomic addressing, shader function-table calls.
- Same symptom as MXGP 26 ([#9510](https://github.com/boykopovar/AnyPS5/issues/9510)), also a Milestone game.

AI-assisted. Tested by me on my own machine.
