# Hot Wheels Infinite Rush (PPSA22408), title screen, importing the read-back buffer (A/B)

Question: the biggest wait on the title is a 632 KiB GPU-written buffer that cannot be imported and is copied back to the CPU about 7 times per second (see [baseline](2026-10-24-hot-wheels-title-baseline.md)). Does letting the importer join it into a host-memory run fix the wait?

- **Date / machine:** 2026-10-24, Linux desktop (RTX 3080 Ti).
- **Build:** upstream `3ca5b17655` + wait trace + a two-line local test switch (not upstream). A = off, B = `APS5_TEST_JOIN_CROSSING=1`. One build for both arms. Order A B A B.
- **Environment:** default profile set + `APS5_TRACE_HOOKSYNC_MS=5 APS5_TRACE_CPU_UPLOAD_KIB=256`, shader cache warm, audio muted.
- **Phase measured:** title screen idle, +60 s to +240 s.

## Result

The import works (B makes 0 CPU copies of that buffer, no import failures), but presents do not change. The next reader blocks on the same GPU writer instead: waits move to a GPU label on the compute queue and to texture reads, and total waiting goes slightly up. The real cause is that the writer's work is still open when the buffer is read.

| Arm | Presents/10 s | Frame p50 ms | GPU ms/frame | GPU load % | Hook syncs / ms per 10 s | CPU copies of the buffer (run) | Graphics held / compute waited ms per 10 s | Uploads / write-backs MiB/10 s | Staging MiB/10 s | CPU ms/10 s |
|---|---|---|---|---|---|---|---|---|---|---|
| A1 | 103 | 98.1 | 55.3 | 62.3 | 1258 / 4404 | 9055 | 6378 / 3188 | 43988 / 38019 | 4124 | 10171 |
| B1 | 99 | 101.2 | 60.6 | 67.8 | 1218 / 4972 | 0 | 6304 / 3772 | 42831 / 37078 | 4063 | 10020 |
| A2 | 96.5 | 103.4 | 60.4 | 65.2 | 1253 / 4374 | 8940 | 6386 / 3180 | 41839 / 36173 | 3912 | 10594 |
| B2 | 107 | 94.0 | 55.1 | 64.0 | about 1240 / 4840 | 0 | 6254 / 3735 | 46414 / 40140 | 4406 | 9844 |

GPU classes per frame are the same in all arms (shadow-publish 10.7-11.6, storage upload 6.2-6.6, draw 3.5, write-back 2.9-3.3 ms). RAM about 5.3 GB, VRAM about 6.3 GB.

## Where the waiting goes (whole run, count / seconds)

| Reason | A arms | B arms |
|---|---|---|
| direct dispatch, buffer upload | about 1800 / 36.5 s | gone |
| indirect dispatch, capture | about 1640 / 15.4 s | about 1700 / 16 s |
| compute queue, wait on GPU label | about 1100 / 12 s | about 3400 / 41 s |
| direct dispatch, texture read | small | about 1900 / 19 s |

## Picture

A vs B differs no more than A vs A (the title is animated): no rendering change.

AI-assisted. Tested by me on my own machine.
