# Draw cache: moving buffer pointers make every draw a miss

Runs: [Sonic S2 menu](../perf-data/runs/2026-10-24-sonic-s2-menu-draw-cache.md), [Sonic older build](../perf-data/runs/2026-10-21-sonic-s2-menu-old-build.md), [D2R menu baseline](../perf-data/runs/2026-10-24-d2r-main-menu-baseline.md), [AMD relocation check](../perf-data/runs/2026-10-24-d2r-main-menu-amd-draw-cache-relocation-check.md).

## What the trace shows

| Game / scene | Draw cache hits | What differs between draws |
|---|---|---|
| Sonic Origins Plus (PPSA05325) S2 menu | 3.5% (404k of 420k lookups are data-only hits) | only per-draw buffer pointers: a stage-1 word grows ~0x338 per draw, a stage-5 word drops 48; other words identical (a streaming vertex/constant ring) |
| Diablo II Resurrected (PPSA03912) main menu | 0.3% (120.9k of 121k misses are "user words/pointers only") | 64-bit pointer pairs moving through a ring/double buffer (title-to-menu transition) |
| Castlevania Belmont's Curse (PPSA35399) in-game | ~7% | per-object pointers step 0x110 each frame, per-draw vertex buffer bases |

Data-only hits reuse decode but still re-capture and recompile the stages: Sonic compiles ~650k stages and reuses ~158k per 10 s; D2R compiles 235k and reuses 7k. On Sonic that is ~8.7 us of the worker's 18.4 us per draw (capture 4.1, recompile 4.6). The 4096-entry cache is also full on Sonic (12-17k evictions per 10 s).

## The lever

Keep moving pointers out of the cache key: treat them as data and patch them at bind time, so the compiled stages and resource setup are reused. Earlier attempts:
- Upstream relocation chain #5609 / #6539 (moved pointers): conflicts with current main in ~10 files.
- Our fork prototype (vertex-fetch relocation, on the old chain): ~50% relocated hits on the Sonic menu, 0 verifier mismatches, but no FPS gain, because a relocated hit still cost ~16 us and the committer stayed at ~46 ms per frame. So the hit path itself has to get cheaper too ([committer cost](draw-committer-cost.md)).
- Our data-hit relocation prototype ([patches/data-hit-relocation-v2.patch](patches/data-hit-relocation-v2.patch)), on current main: unit tests and Vulkan validation pass, but `APS5_VERIFY_DRAW_DATA_HITS=1` aborts on the D2R menu on the Radeon 780M (v1: one fragment stage keeps 8 runs where a fresh build has 9, over 174 words; v2 with a page-boundary fix, rerun 2026-10-25: stage 0 of another program, same run count, different contents). With relocation off the same scene is clean. Ruled out as it stands: the way forward is pointer provenance from the recompiler, or ring offsets passed as data.
- Per-object pointer relocation in Castlevania gameplay gave +25-30% in an unsafe local test (no bound on the relocation distance).

Related open upstream work: #9508 (GPU descriptor heap), #9012 (audit templates only after import changes), #8212 (one pipeline when only a table's size differs).

AI-assisted. Tested by me on my own machine.
