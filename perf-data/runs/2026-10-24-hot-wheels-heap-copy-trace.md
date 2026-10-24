# Hot Wheels Infinite Rush (PPSA22408), boot and race load, why the 4 GiB heap gets copied

- **Date / machine:** 2026-10-24, Linux desktop (RTX 3080 Ti).
- **Build:** upstream `3ca5b17655` + a logging-only heap trace (`APS5_HW_TRACE_HEAP=8fc0000000`, not upstream).
- **Phase measured:** boot to 3 minutes into the race load.

## Result

When a dispatch binds the game's whole 4095 MiB sparse heap read-only, it is served in place from the joined host-memory import (the 528 MiB committed part). When a dispatch binds the whole heap writable with atomics, the import path is skipped (it requires that no writer overlaps the range), and the heap falls back to the sparse mirror or a full copy. That is the path behind the about 460 full heap copies per [race load](2026-10-24-hot-wheels-race-load.md).

The trace's 200-line cap filled during boot, so the exact copy reasons during the race load are not captured yet.

## Standard set, 3 traced race-load minutes

| Metric | Value |
|---|---|
| Presents per 10 s | 36 (4-86) |
| Frame p50 | 338 ms |
| GPU per frame | 79.4 ms; shadow-publish 13.0, storage upload 6.9, staging-out 5.4, write-back 4.8, draw 4.6 |
| Uploads / write-backs per 10 s | 11267 / 10654 MiB |
| Hook syncs per 10 s | 196, 2.0 s |
| Disk cache | 412 hits / 4 misses |
| RAM | anon 2.5, shmem 6.3, file 1.9 GB |
| VRAM / GPU load | 9.4 GB / 30.9% |
| CPU | 13.4 s per 10 s |

AI-assisted. Tested by me on my own machine.
