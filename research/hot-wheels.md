# Hot Wheels Infinite Rush (PPSA22408): race load and black scenery

Runs: [race load](../perf-data/runs/2026-10-24-hot-wheels-race-load.md), [heap copy trace](../perf-data/runs/2026-10-24-hot-wheels-heap-copy-trace.md), [AMD import budget A/B](../perf-data/runs/2026-10-24-hot-wheels-race-load-amd-import-budget-ab.md), [title screen](../perf-data/runs/2026-10-24-hot-wheels-title-baseline.md). Upstream discussion: D#6895. The game needs a GameUpdate "no update" fix to get past its update check (#10614).

## Race load: the 4 GiB heap copy

- About 9 minutes on the Linux desktop with a warm shader cache (14 min cold). During the slow part there are ~460-541 guest uploads of 4095 MiB (about one per second, 0.5-0.6 s each), from small compute dispatches (12x1x1 to 56x1x1) of two large programs, mostly on queue 0x20 (GPU mutex held up to 573-1288 ms per dispatch). They stop right when the race starts.
- The region is a 4 GiB sparse heap; the guest maps only 528 MiB of it.
- Read-only binds of the whole heap are served in place by the joined sparse-run import. A dispatch that binds the whole heap **writable with atomics** skips the import path (it requires that no writer overlaps the range) and the heap falls back to the sparse mirror or a full copy.
- #8139 (sparse page permissions, merged) did not stop the copies (460 vs 447 the day before); shadow-publish halved, hook waits doubled.
- Cold-cache extra: one 31.8 s compute pipeline (828k SPIR-V words) and a 7.2 s one.
- Estimate if the copy goes: ~275 s of the 531 s load.
- On the Radeon 780M the race load is ~4x slower (25% after 15 min), bound by memory waits on both queue workers with the GPU ~3% busy. #7844 (import budget) does not change it there: the 4 GiB cap never applies with a 5658 MiB host heap.

## Black scenery in the garage and races

Same on Radeon 780M (RADV), RTX 3080 Ti (Linux) and NVIDIA on Windows. Investigation paused.
- The scenery comes from indirect draws whose arguments the game builds on the GPU after a culling pass. All those arguments come out 0, so the G-buffer stays empty.
- The culling pass sorts objects into 19 buckets; every object lands in buckets 16-18, which no draw reads, because the per-object visibility bitmask (320 bits) is all zero.
- The pass that sets the bitmask runs, and its translation matches the guest code (CPU model of the shader over dumped inputs agrees with the all-zero output). It skips every object because each candidate's record has -1 (0xffffffff) in the 4th dword of element 24 (xyz position + this dword), which looks like an "unassigned" link. Those records are written by another GPU pass, written only occasionally.
- Ruled out: depth pyramid, the draw precheck "nothing" path, dispatch ordering (`APS5_SYNC_DISPATCH=1` changes nothing), CPU writes, aliased mappings, the buffer descriptors, the atomic addressing, and shader function-table calls (105 deferred, 0 failures at use).
- Same symptom as MXGP 26 (#9510), also a Milestone game.

AI-assisted. Tested by me on my own machine.
