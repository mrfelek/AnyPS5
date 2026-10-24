# Ghost of Yotei (PPSA26344), boot and loading, memory growth and GPU path A/B

- **Date / machine:** 2026-10-24, Linux desktop (RTX 3080 Ti).
- **Build:** a local integration build of upstream main with the GPU path switches (`APS5_GPU_HEAP=1 APS5_GPU_PATH=1 APS5_KEEP_UNEXPECTED_DEVICE_IMAGES=1` for "ON").
- **Environment:** default profile set, Cross pressed every 6 s, memory cap 22 GB, audio muted.
- **Phase measured:** boot through the menu into the long loading screen before the opening cinematic. No run reached the cinematic.

## Result

1. **With the shader disk cache off, memory runs away**: about 8.6-9.7 GB per minute after the first 90 s, until the cap stops the game at about 3 minutes. The log goes almost silent while it grows, and pipeline, texture and buffer pool counters stay flat, so the growth is in something that does not log (guest memory, host imports or file/stream buffers). With the cache on this does not happen.
2. **GPU path ON is slower than OFF** in loading: 30-40% more GPU time per frame and no more presents. Shadow-publish time goes up about 2.5x and the draw cache hit rate collapses.

## Memory with the shader cache off (RSS + swap, MiB)

| Arm | 0 s | 30 s | 60 s | 90 s | 120 s | 150 s | 180 s |
|---|---|---|---|---|---|---|---|
| GPU path OFF | 2214 | 4364 | 8530 | 8946 | 13278 | 17777 | 21768 |
| GPU path ON | 2400 | 5168 | 9179 | 9881 | 13525 | 19618 | 24363 |

## GPU path A/B, shader cache on, minutes 3-8 of loading

| Metric | OFF | ON |
|---|---|---|
| Presents per 10 s | 14 (2-26) | 3 (1-9) |
| Frame p50 | 941 ms | 11557 ms |
| GPU per frame | 63.7 ms; shadow-publish 17.9, draw 11.3, write-back 7.0, upload 5.5 | 283 ms; shadow-publish 45.1, write-back 18.9, draw 6.8, upload 5.9 |
| Draw cache / dispatch cache hits | 84.6% / 59.5% | 12.3% / 32.3% |
| Uploads / write-backs per 10 s | 6943 / 8162 MiB | 709 / 1109 MiB |
| Pipeline creates, disk cache | 35; 0 hits / 4891 misses | 32; 0 / 712 |
| Hook syncs per 10 s | 98, 220 ms | 8.5, 49 ms |
| Direct dispatch cost | 1678 us | 2802 us |
| Image builds | 1887 us each | 1033 us each |
| RAM | RSS 4.9 + swap 1.2 GB | anon 2.4 to 5.4, shmem 2.5, swap 1.8, file 1.0 GB |

With GPU path ON and a warm cache, a burst of shader cache hits maps about 9,000 cache files within 6 s (file RSS jumps to 12-17 GB). These pages are clean and get reclaimed within 2 minutes, so this is not a leak, but a watcher that counts all RSS will stop the game.

## Longer 12-minute arms, shader cache on

| Arm | Length | Presents per 10 s (last minute) | GPU ms per frame | Peak RAM counted / RSS | VRAM | End |
|---|---|---|---|---|---|---|
| OFF | 729 s | 7 | about 181 | 12.4 / 15.9 GB | 8.2 GB | time limit |
| ON | 730 s | 6 | about 238 | 10.9 / 19.7 GB | 7.5 GB | time limit |
| OFF | 670 s | 9 | about 168 | 17.6 / 21.9 GB | 10.4 GB | memory cap at +638 s |

All arms run at about 75 presents per 10 s in the intro and menu, then drop to single digits on the loading screen. In loading the GPU is busy about 105 ms and idle about 514 ms per frame: the loading screen is bound by syncs and CPU work, not the GPU.

AI-assisted. Tested by me on my own machine.
