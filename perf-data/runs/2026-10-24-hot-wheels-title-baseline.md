# Hot Wheels Infinite Rush (PPSA22408), title screen, baseline and wait trace

- **Date / machine:** 2026-10-24, Linux desktop (RTX 3080 Ti). See [machines.md](../machines.md).
- **Builds:** run 1 on `895f47f4e` with `APS5_TRACE_FLUSH=1 APS5_TRACE_DISPATCH_IO=1`; run 2 on upstream `3ca5b17655` + a logging-only wait trace (`APS5_TRACE_HOOKSYNC_MS=5 APS5_TRACE_CPU_UPLOAD_KIB=256`, not upstream). Both with a test GameUpdate module to pass the update check.
- **Environment:** default profile set, shader cache warm, audio muted.
- **Phase measured:** title screen ("PRESS ANY BUTTON"), no input, +60 s to +240 s.

## Result

The title screen runs at about 95 presents per 10 s (about 9.5 FPS; the intro before it runs at 60 FPS). It is not GPU-bound: the GPU is about 64% busy, doing 60 ms of work per 108 ms frame. The time goes into data copies (about 41 GB uploaded and 35 GB written back every 10 s) and into waits: about 4 s of every 10 s is spent waiting for the GPU before the CPU may touch a buffer.

## Standard set (run 1, medians)

| Metric | Value |
|---|---|
| Presents per 10 s | 93 (87-96) |
| Frame p50 | 107.6 ms |
| In-flight wait p50 | 2.5 ms |
| GPU per frame | 60.0 ms; shadow-publish 11.4, storage upload 7.0, draw 3.5, storage write-back 3.2 |
| GPU load | 64.5% |
| Draw cache hits / dispatch cache equal | 2.0% / 8.2% |
| Uploads / write-backs per 10 s | 41060 / 34776 MiB |
| Staging in / back per 10 s | 3074 / 3075 MiB |
| Pipeline creates, disk cache | 0; 94 hits / 0 misses |
| Guest memory tracker waits | 553 per 10 s |
| RAM | anon 1.2, shmem 4.1, file 1.6 GB, no swap |
| VRAM | 5.4 GB |
| CPU | about 10.6 s per 10 s (about one core) |

## Where the waits go (run 2)

1100-1150 hook syncs and 3.8-4.2 s waiting per 10 s, about 40% of wall time. Waits of 5 ms or more, whole run:

| Queue / packet / reason | Count | Total ms | Max ms |
|---|---|---|---|
| graphics queue, direct dispatch, buffer upload | 1860 | 34960 | 25.0 |
| graphics queue, indirect dispatch, capture | 1683 | 15035 | 11.1 |
| compute queue, wait on GPU label | 1475 | 13748 | 608.3 |
| graphics queue, indirect dispatch, dispatch cache | 223 | 1990 | |
| graphics queue, direct dispatch, texture read | 69 | 592 | |

At the wait, 3829 writers still had their target open and 1482 were in flight; none were already done.

The biggest single wait is one small (632 KiB) GPU-written buffer that cannot be imported as host memory and is read back to the CPU about 7 times per second, in bursts of 5. The first read of each burst waits 18-24 ms for the GPU writer; the other 4 take about 40 us.

## The compute pass behind the copies

A pair of compute shaders (1440x1x1, about 72 of each per 10 s) binds a 128 MiB and a 48 MiB written buffer, a 40 MiB written buffer, a 1024x1024 texture, and the game's whole 4095 MiB sparse heap read-only. The same heap is what gets copied in full about 460 times during the [race load](2026-10-24-hot-wheels-race-load.md).

## Related A/Bs

- [Skip flushing big buffer bindings](2026-10-24-hot-wheels-title-skip-big-flush-ab.md): +17% presents (upper bound, unsafe in general).
- [Import the read-back buffer](2026-10-24-hot-wheels-title-join-crossing-ab.md): the copy goes away but the wait moves.

AI-assisted. Tested by me on my own machine.
