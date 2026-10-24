# Hot Wheels Infinite Rush (PPSA22408), race load and race, current main and import-hashing A/B

- **Date / machine:** 2026-10-24, Linux desktop (RTX 3080 Ti). See [machines.md](../machines.md).
- **Build:** upstream `3ca5b17655` (includes [#8139](https://github.com/boykopovar/AnyPS5/pull/8139), sparse page permissions), with a test GameUpdate module so the game gets past its update check.
- **Environment:** default profile set + `APS5_TRACE_BIGBUF=1`, shader cache warm (second start), audio muted, memory cap 25 GB.
- **Phase measured:** race load from pressing Cross on the first race. "Slow load" is the 350 s before the race starts; "race" is the first 60-77 s of driving.

## Result

Race load takes about 9 minutes on current main. The game copies its whole 4 GiB heap about 460 times during the load, and that plus hook waits is what the load waits on; the GPU is only about 19% busy. [#10655](https://github.com/boykopovar/AnyPS5/pull/10655) (import page hashing off the draw thread) makes no clear difference on Linux.

## Current main, slow load (+440..+790 s). 2026-10-23 main in brackets

| Metric | Value [2026-10-23] |
|---|---|
| Load time, Cross to race | 531 s [548 s] |
| Presents per 10 s | 3.5, range 2-11 [4] |
| Frame p50 | 3322 ms [2637] |
| GPU per frame | 359.5 ms [376.7] |
| Top GPU classes per frame | shadow-publish 35.9 [64.5], label-run 22.7 [23.2], storage write-back 21.5 [23.1], draw 20.2 [16.1], staging-out 18.1 |
| Full 4 GiB heap copies during load | 460 [447] |
| Storage uploads / write-backs per 10 s | 2309 / 1713 MiB [5368 / 4352] |
| Draw cache hits / dispatch cache equal | 0.0% / 3.3% |
| Pipeline creates (warm), disk cache | 128 creates in 3.6 s; 2425 hits / 11 misses |
| Hook syncs per 10 s | 113 syncs, 2505 ms waiting [99 / 1275] |
| RAM | anon 2.7, shmem 9.2, swap 0.2, file 2.8 GB |
| VRAM / GPU load | 10.0 GB / 18.9% |
| CPU (emulator threads) | 13.5 s per 10 s |

## Current main, race running

| Metric | Value |
|---|---|
| Presents per 10 s | 40.5 (38-41) |
| Frame p50 | 249 ms |
| GPU per frame | 114 ms |
| Storage uploads / write-backs per 10 s | 18974 / 15914 MiB |
| Hook syncs per 10 s | 1112, 2692 ms waiting |
| VRAM / GPU load | 10.3 GB / 47.6% |
| CPU (emulator threads) | 20.3 s per 10 s |

## A/B: #10655 (import page hashing off the draw thread)

A = `3ca5b17655`, B = A + PR head `d3d5e2f262`. Order: B warm-up (not counted), B1, A2, B2; A1 is the run above.

| | A1 | B1 | A2 | B2 |
|---|---|---|---|---|
| Load time (s) | 571 | 511 | 541 | 541 |

| Arm (slow load) | Presents/10 s | Frame p50 ms | GPU ms/frame | Top GPU classes ms/frame | Uploads / write-backs MiB/10 s | Hook syncs / ms per 10 s | GPU load % | CPU ms/10 s |
|---|---|---|---|---|---|---|---|---|
| A1 | 4 | 2899 | 341 | shadow-publish 33.3, label-run 22.1, draw 19.6 | 2431 / 1759 | 115 / 2505 | 20.5 | 14369 |
| B1 | 4 | 2750 | 373 | shadow-publish 38.7, label-run 27.5, draw 25.6 | 2516 / 1868 | 164 / 2177 | 16.4 | 12749 |
| A2 | 4 | 2933 | 328 | shadow-publish 32.6, label-run 21.9, draw 17.1 | 2857 / 1933 | 139 / 2298 | 20.1 | 13764 |
| B2 | 4.5 | 2433 | 304 | shadow-publish 26.9, label-run 19.3, draw 18.8 | 2680 / 1912 | 123 / 2617 | 21.8 | 13294 |

| Arm (race) | Presents/10 s | Frame p50 ms | GPU ms/frame | CPU ms/10 s |
|---|---|---|---|---|
| A1 | 41 | 247.5 | 114.3 | 19374 |
| B1 | 41 | 244.9 | 114.4 | 17093 |
| A2 | 39 | 254.2 | 114.8 | 17520 |
| B2 | 42 | 237.4 | 113.5 | 16831 |

0 pipeline creates in all arms; VRAM 10.0-10.2 GB. B averages about 30 s faster to load, but A2 and B2 both took 541 s: inside run-to-run noise. The PR targets Windows (first touch of each write-watched page), so a Windows run is the real test.

## Which bottleneck moved

Compared with 2026-10-23 main, shadow-publish time per frame halved and uploads/write-backs dropped to about 0.4x, but hook waits doubled and the 4 GiB heap copies are unchanged. The load is bound by the big-buffer copy and waits, not GPU work.

AI-assisted. Tested by me on my own machine.
