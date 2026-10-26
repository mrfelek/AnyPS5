# Sonic Origins Plus (PPSA05325)

Everything I tested on this game, in one place. Upstream discussion: [D#2021](https://github.com/boykopovar/AnyPS5/discussions/2021). Machine: Linux desktop (RTX 3080 Ti, 12 GB). Specs: [machines.md](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/machines.md). The scene I measure is the Sonic 2 page of the main menu.

## Where it gets to on current main

Boots to the menus and plays. A cold first boot sometimes does not reach the Sonic 2 page; the second (warm) start does.

## Speed: Sonic 2 menu page

| Build | Presents per 10 s | What limits it |
|---|---|---|
| Current main (2026-10-24) | about 142 (14 FPS) | CPU: the draw worker spends 18.4 us per draw at about 42,000 draws per second (7.7 s of every 10 s); the committer adds 16.5 us per draw. The GPU is about 75% busy at 48 ms per frame. |
| 2026-10-21 build | 127-130 | Same shape; GPU idle about 32 ms per frame. |

Draw cost per packet: precheck 0.9, decode 2.1, capture 4.1, recompile 4.6, vectors 1.1, key/lookup/validate 2.5, lock wait 2.2 us.

**Why the draw cache misses:** hits are only 3.5%. Almost every draw differs from a cached one only in per-draw buffer pointers: a streaming vertex/constant ring offset that grows by a fixed step (about 0x338) each draw, in a 6-draw cycle that otherwise repeats exactly. So about 650,000 shader stages are compiled every 10 s. Treating those pointers as data instead of part of the cache key, and making the hit path cheaper, is the lever. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-sonic-s2-menu-draw-cache.md), [older run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-21-sonic-s2-menu-old-build.md), [notes](https://github.com/mrfelek/AnyPS5/blob/main/research/draw-cache-per-draw-rework.md), [committer cost](https://github.com/mrfelek/AnyPS5/blob/main/research/draw-committer-cost.md)

## Fixes tried on this game

| Change | What it does | Result |
|---|---|---|
| One image for a 2D surface and its one-layer array (my fork branch `fix/one-layer-storage-share`) | Shares one image instead of keeping an alias copy. Same idea as NahuelGenchi's `perf/agc-share-one-slice-image` (closed, not in main). | Removes about 7,000 alias copies per 10 s and the broken help glyphs, GPU -4-6 ms, about +5% FPS. Not upstreamed. |
| Vertex fetch relocation (my fork branch `perf/vertex-fetch-relocation`) | Relocates vertex fetch pointers so draws hit the cache. | About 50% cache hits, 0 mismatches, but no FPS gain: a hit still costs about 16 us. Ruled out as the main lever. **Instead:** make the hit path in the committer and draw worker cheaper. |
| Open PRs aimed at the same per-draw cost (not yet measured here) | [#9508](https://github.com/boykopovar/AnyPS5/pull/9508) (Raghav314, GPU descriptor heap: skips the per-draw descriptor set rebuild) and [#9012](https://github.com/boykopovar/AnyPS5/pull/9012) (SP4C3B4R-8, audits a cached template only after the host-import set changed). | Each covers part of the 16.5 us per draw in the committer; neither touches the draw cache misses. [notes](https://github.com/mrfelek/AnyPS5/blob/main/research/draw-committer-cost.md) |

**[#10668](https://github.com/boykopovar/AnyPS5/pull/10668) (meh7an, skips refilling a range that still holds its fill pattern), off/on x2, 24-25 October:** about 25,000 repeated fills skipped per run, the fill GPU class (about 3 ms per frame) disappears, GPU time drops 3-4.6 ms per frame (48.2 -> 43.6 and 44.2 -> 41.2). Presents stay at 141-147.5 per 10 s, because the menu is CPU-bound. A real GPU saving that will show once the per-draw CPU cost is cut. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-25-sonic-s2-menu-fill-elision-10668.md), also posted [on the PR](https://github.com/boykopovar/AnyPS5/pull/10668#issuecomment-6404605718)

**Descriptor set reuse and draw cache relocation v3 (my prototypes), 25 October, M R D RD x2:** ruled out for this menu. Reuse cuts descriptor writes per draw by 41%, but per-draw cost stays at 17.8-19.8 us and presents at 135-150 per 10 s. Relocation v3 passes the verifier but fires only about 150 times per 10 s against about 600,000 stage compiles. **Instead:** cut capture and recompile on the draw worker (8.3 of 18.3 us per packet, about 600,000 stage compiles per 10 s) and the keep, revalidate and record steps of each template hit on the committer. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-25-sonic-s2-menu-draw-set-reuse-relocation.md)

**Why cached stages are passed over (relocation v4 counters, my test build), 26 October:** about 600,000 cached stages per 10 s are passed over because a fixed word changed; only 2,400-3,500 for a moved layout and 28,000-35,000 for moved data. So relocating moved data is ruled out as the main lever on this menu. **Instead:** find which fixed words change between otherwise matching stages and pass them as data. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-26-sonic-s2-menu-draw-cache-pass-over.md)

**Which fixed words (relocation v5 counters), 26 October:** every one is a user word the shader reads as a value, mostly user word 12, changing in whole ring-block steps (for example 0x4c00040 -> 0x5600040 -> 0x4d00040), so they look like ring-buffer offsets. **Instead:** pass those words to the shader as data rather than baking them into the stage. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-26-sonic-s2-menu-draw-cache-fixed-words.md)

AI-assisted. Tested by me on my own machine.
