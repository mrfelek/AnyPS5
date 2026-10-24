# Ghost of Yotei (PPSA26344): why it runs at about 1 FPS

Linux desktop (Ryzen 9 5950X, RTX 3080 Ti 12 GB, NVIDIA 615.71.09), 2026-10-22..24. Builds: upstream main, and hritikutekar's linux-best-u2 fork build (the only one that reaches the opening cinematic for us). Run: [boot/loading and GPU path A/B](../perf-data/runs/2026-10-24-ghost-of-yotei-boot-load-gpu-path-ab.md). Upstream discussion: D#675.

## Upstream main (2026-10-22): never leaves the title-scene load

- **Blend terminate** after ~7.6 min: "blending unclamped normalized color is not implemented" (8_8 UNORM target, BLEND_CLAMP clear, normal alpha blending). Merged #6875 accepts these targets only without blending; #9748 (Celegans12) handles packed 11_11_10 targets through pixel interlock and leaves the unclamped case as a throw. Our approximate fix (let Vulkan blend with its clamp; exact while shader outputs stay in [0,1]) is in [patches/yotei-blend-unclamped-normalized.patch](patches/yotei-blend-unclamped-normalized.patch).
- **Giant compute shaders:** 517 pipelines over 100k SPIR-V words take 25 min in the NVIDIA driver on one thread (largest 1.7M words = 500 s). Wave64 programs run as 2 lanes per invocation on 32-wide subgroups, roughly doubling them.
- **Cached giants rebuilt:** the journal held two variants of each 1.2-1.3M-word giant that differ in exactly 21 SPIR-V instructions (one `OpConstant 1` vs `0`, 20 `OpLogicalAnd` with `true` vs `false` in bounds-check guards). The recompiler folds a guest-data-dependent boolean into the shader as a literal, so each new value is a new shader and a 54-70 s compile. The pipeline journal also hit its 1024 MiB cap, so new variants are never recorded (env fix `APS5_PIPELINE_JOURNAL_MAX_MIB=4096`; code fix: make that value a runtime value or specialization constant).
- **VRAM thrash** once shaders exist: ~110 s per frame; "texture caches released 0 MiB of ~260 MiB asked for" logged 19,692 times; the title scene binds huge image tables (44,508 textures, ~9.9 GB for one draw, measured by hritikutekar). 12 GB is too small.

## Cinematic on linux-best-u2: the wait chain (per ~1,040 ms frame)

- **Queue 0:** ~893 direct dispatches at ~610 us (device call 304 ms, GPU-mutex wait ~100 ms, prologue ~99 ms). **355 ms of pipeline drains**: 62 of 78 drains per frame are forced by dispatches (every DISPATCH_DIRECT that arrives while draws are queued drains the draw pipeline, `Dispatch.cpp`). 32 "fill HLE" dispatches cost 112 ms (~3.5 ms each).
- **Committer:** 43% busy at 381 us per commit, mostly readTarget page walks (121 ms per frame; 6.5M pages per 10 s; worst lookup 219 ms) and address-based builds (94 ms).
- **GPU mutex:** queue 0 holds it in dispatch 276 ms per frame (max single hold 256 ms); other queues wait 89-258 ms each behind it.
- **Hazard waits:** 480 ms per frame across the async queues.
- **GPU:** 333 ms busy per frame; storage upload 1.8 GB, write-back 1.17 GB, staging 0.97 GB per frame: **about 4 GB moves between guest memory and the GPU every frame**.
- **Game threads** spin on rdtsc waiting for our results (main thread 36% of perf samples). The queue-0 worker is only 8.4% of on-CPU samples with a flat profile: its "busy" time is mostly waiting.
- Same bottleneck as hritikutekar (RX 9070 XT) and Celegans12 (RTX 4070 Ti S) report, so it is not our GPU or Linux.

Dispatch cache in the cinematic: ~14k lookups per 10 s, about half with no entry, only 1.4-1.6k equal; the cache sits at its 8,192-entry limit. Misses come almost entirely from a different layout key (1.09M layout misses vs 22k "same key, data changed").

## Ruled out

| Change | Result |
|---|---|
| `APS5_PIPELINE_DISPATCH=1 APS5_PIPELINE_DMA=1` + 65,536-entry dispatch cache | no gain (11.6 vs 11.8 presents per 10 s); per-dispatch cost rose 600 -> 862 us because the bigger cache validates more entries without hitting |
| GPU path chain (#9508 descriptor heap -> #7642 image tables on the GPU heap -> #10193 table columns), `APS5_GPU_HEAP=1 APS5_GPU_PATH=1` | slower: 3 vs 14 presents per 10 s in loading, GPU 283 vs 64 ms per frame, draw cache hits 12% vs 85%; vertex SPIR-V 6-9 MB per program (380 guest words -> 1.16M SPIR-V words of address and bounds arithmetic) |
| Image-table reuse idea | ruled out: u2 uses the bindless texture service, and resolveImageTables has 0% of samples there |
| #7844 (bigger import budget) | not applicable: 0 refused host imports in 13 runs |

GPU path side findings (for #10193): each program is stored twice in the shader disk cache (gpuResolvedImages=1, then the fallback with 0; the "ineligible" memo is in memory only), so the cache grew 23 -> 65 GB in 155 s; mapped cache files are never unmapped (26,741 at the end).

## Memory growth with the shader cache off

With `ANYPS5_NO_SHADER_CACHE=1` memory grows ~9 GB per minute after 90 s until the cap; pipeline and texture counters stay flat. Growth is host-side anonymous memory (the OOM kill showed anon 17.4 GB, shmem 5.1 GB). With the cache on there is no runaway (peak 11.8 GB, settles ~7 GB). Likely the in-memory recompile path (malloc churn in recompiler passes). Closest upstream: #9052 (closed, no root cause).

## Leads, by size

1. Image round trip + hazard waits (~480 ms waits + ~114 ms of GPU copies per frame), same as the [menu round trip](menu-image-round-trip.md).
2. Draw-pipeline drains on dispatch (355 ms). `APS5_PIPELINE_DISPATCH_MISSES=1` (u2 only) turns misses into pipeline items; not tested yet.
3. Committer readTarget page walks (121 ms) and the slow fill HLE (112 ms).

AI-assisted. Tested by me on my own machine.
