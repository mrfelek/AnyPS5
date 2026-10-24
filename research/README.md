# AnyPS5 research notes

Everything I found while testing PS5 games on [AnyPS5](https://github.com/boykopovar/AnyPS5) on my own machines (Linux desktop with an RTX 3080 Ti, an AMD mini PC with a Radeon 780M, a Windows laptop with an RTX A2000), October 2026. The per-run measurements are in [perf-data](../perf-data/); this folder holds the analysis built on them, approaches ruled out with their numbers (and what to do instead), and the test patches used.

Start with the [structural analysis](structural-analysis.md): it explains why the slow games are slow and ranks what to change. The [day log for 24 October](day-log-2026-10-24.md) walks through every run of the main test day in order: why each one ran, the numbers, and what came out of it. For one game at a time, see the [game pages](games/README.md). Every upstream PR I opened, carried or tested is in [upstream-prs.md](upstream-prs.md), and [how-we-worked.md](how-we-worked.md) explains the method, what went wrong and the lessons.

## Topics

| Note | Area | Short result |
|---|---|---|
| [upstream-prs.md](upstream-prs.md) | all | Every upstream PR I opened, that carries my commits, or that I tested, with state and numbers |
| [how-we-worked.md](how-we-worked.md) | all | Machines, method, rules, mistakes, approaches ruled out and the way to go instead |
| [patches/](patches/README.md) | all | Every patch and diagnostic, including the ones ruled out, with the reason and the way to go instead |
| [games/](games/README.md) | each game | One page per game: how far it gets, speed, fixes and PRs tested, approaches ruled out |
| [day-log-2026-10-24.md](day-log-2026-10-24.md) | all | Every step of the 24 October test day, with numbers and decisions |
| [structural-analysis.md](structural-analysis.md) | all | Three design problems (GPU results round-trip through guest memory, per-draw rework, one serialized line) plus NVIDIA float emulation; ranked plan; why single-wait fixes give 0 |
| [menu-image-round-trip.md](menu-image-round-trip.md) | GPU memory model | Slow menus are compute-written images bouncing through guest memory (Hot Wheels title 41 GB up / 35 GB back per 10 s; D2R loading: one array texture split into 90 images) |
| [draw-cache-per-draw-rework.md](draw-cache-per-draw-rework.md) | draw cache | Moving ring pointers make 96-99.7% of draws misses; Sonic recompiles ~650k stages per 10 s |
| [draw-committer-cost.md](draw-committer-cost.md) | draw recording | Committer 16.5 us per draw on the Sonic menu, by phase; worker 18.4 us; both near the limit |
| [indirect-draw-reads.md](indirect-draw-reads.md) | indirect draws | D2R's one CPU-path indirect draw per frame waits ~43 ms; GPU-path fix shape (BaseVertex/BaseInstance) |
| [f32-denormal-flush.md](f32-denormal-flush.md) | shader translation | NVIDIA keeps the software f32 flush; a probe-based fix gives D2R menu +26% (GPU 104 -> 74 ms) |
| [ghost-of-yotei-speed.md](ghost-of-yotei-speed.md) | Ghost of Yotei (PPSA26344) | ~1 FPS from ~4 GB per frame of copies, dispatch drains and GPU-lock holds; GPU path chain is slower; giant shaders and journal cap |
| [hot-wheels.md](hot-wheels.md) | Hot Wheels Infinite Rush (PPSA22408) | Race load copies a 4 GiB heap ~460 times (writable atomic binds skip the import); black scenery traced to an unassigned record link |
| [shader-table-calls.md](shader-table-calls.md) | shader recompiler | Function-table call deferrals are harmless on Yotei, Hot Wheels and Astro Bot; open PRs help other titles |
| [image-descriptors-7459.md](image-descriptors-7459.md) | shader recompiler | Yotei's 3 "GetImageResource not a valid runtime value" shaders, why open PRs don't fix them, two fix directions |

## Who works on each area upstream

From the PRs and discussions read for these notes (authors and reviewers; not complete).

| Area | Upstream PRs / issues | People |
|---|---|---|
| GPU memory model, image hand-over, staging | #4286, #9400, #10159, #7618, #8104, #9287, #9289, #8139 | AlxcBTW, parl0v, Celegans12, oneandonlydean (review) |
| Host imports | #10655, #7844 | thuanquang, Mouhand-Kaddo, MarcZX10 and fogydes (review), adriadam10 |
| Draw cache, pointer relocation | #5609, #6539, #9012, #8212 | SP4C3B4R-8, Ryongen |
| Draw recording, descriptor heap | issue #7895, #8992, #8278, #9508 | SP4C3B4R-8, m335671, Raghav314, oneandonlydean (review) |
| Indirect draws | #10359, #9243, #9248 | valenciana-nc, fisherjoey |
| Image tables, descriptors (Yotei) | #6340, #7642, #10193, #8077, issue #7459 | MarcZX10, EagleBearerYS, Celegans12, 0xcrstn |
| Shader function-table calls | #8070, #9068, #8140, #7816 | thuanquang, frankea, tv7, Capmare |
| Fill elision (Sonic menu) | #10668 | meh7an |
| VideoOut resolution | #7814 | ionut27001 |

## My upstream PRs from this work

- #7618: stage written-only swept buffer elements (Diablo II Resurrected (PPSA03912) in-game: 55-57 -> 77-85 presents per 10 s, +150-200 MiB memory).
- #9957: buffer presence checked at run time.
- #10228: image table for a T# read at a first-lane offset (Ghost of Yotei shaders, see [image-descriptors-7459.md](image-descriptors-7459.md)).
- #10547: host interpolation first on RADV (Hollow Knight Silksong (PPSA12544) diagonal seam on AMD).
- #10614: GameUpdate returns "no update" instead of throwing (Hot Wheels update-check crash).

AI-assisted. Tested by me on my own machine.
