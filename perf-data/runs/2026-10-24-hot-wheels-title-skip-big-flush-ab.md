# Hot Wheels Infinite Rush (PPSA22408), title screen, skip flushing big buffer bindings (upper-bound test)

- **Date / machine:** 2026-10-24, Linux desktop (RTX 3080 Ti).
- **Build:** `895f47f4e` + a local test edit (not upstream, not safe in general): `APS5_TEST_SKIP_BIG_BUFFER_FLUSH_MIB=64` skips the pending-image flush for buffer bindings of 64 MiB or more. A = the [baseline run 1](2026-10-24-hot-wheels-title-baseline.md).
- **Environment:** default profile set + `APS5_TRACE_FLUSH=1`, shader cache warm, audio muted.
- **Phase measured:** title screen idle, +60 s to the end (18 windows each).

## Result

+17% presents (109 vs 93 per 10 s), GPU 50 vs 60 ms per frame: shadow-publish halves and write-backs drop 25%. The title looks the same. This is an upper bound only: the test skips work that is needed when a scene reads those images.

| Metric | B (skip) | A (baseline) |
|---|---|---|
| Presents per 10 s | 109 (103-110) | 93 (87-96) |
| Frame p50 | 92.3 ms | 107.6 ms |
| GPU per frame | 50.2 ms | 60.0 ms |
| GPU classes per frame | storage upload 7.0, shadow-publish 5.7, draw 3.5, write-back 2.2 | storage upload 7.0, shadow-publish 11.4, draw 3.5, write-back 3.2 |
| GPU load | 64.6% | 64.5% |
| Uploads / write-backs per 10 s | 48208 / 26067 MiB | 41060 / 34776 MiB |
| Staging per 10 s | 3606 MiB | 3074 MiB |
| Draw cache hits / dispatch cache equal | 2.2% / 9.0% | 2.0% / 8.2% |
| Disk cache | 94 / 0 | 94 / 0 |
| In-flight wait p50 | 2.6 ms | 2.5 ms |
| Guest memory tracker waits | 734 per 10 s | 553 per 10 s |
| CPU | 10.8 s per 10 s | 10.6 s per 10 s |
| RAM anon / shmem / file | 1.26 / 4.12 / 1.54 GB | 1.21 / 4.12 / 1.57 GB |
| VRAM | 5.28 GB | 5.42 GB |

About 71,700 flushes were skipped, mostly for the 4095 MiB heap and 96/128 MiB buffers.

AI-assisted. Tested by me on my own machine.
