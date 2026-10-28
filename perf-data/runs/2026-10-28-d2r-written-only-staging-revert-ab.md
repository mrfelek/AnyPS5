# Diablo II Resurrected (PPSA03912), main menu and town, written-only staging on and reverted

Question: does [#7618](https://github.com/boykopovar/AnyPS5/pull/7618) (my merged PR that stages only the written elements of swept buffers, commit `a293f7901b`) cost time on current main? This isolates it with a revert, instead of the switch that turns off every written shadow.

- **Date / machine:** 2026-10-28, Linux desktop (RTX 3080 Ti). See [machines.md](../machines.md).
- **Builds:** A = upstream main `cc672fdfc6` (includes the float fix #11297); B = A + `git revert a293f7901b` (clean, 4 files).
- **Scenes:** main menu (+245..+365 s), then 180 s in town after loading the save (last 150 s measured). Headless, audio muted, memory cap, shader disk cache off, pipeline journal threads 0.
- **Order:** A B A B, no reruns, no errors in any log, no shared-memory spike.

## Result

With the PR, about 20 GB of staging copies go each way per 10 s in both scenes; the revert cuts that to about 0.5-1 GB.

- **Menu: the revert is faster.** Presents 85.5 / 95 -> 109 / 112 per 10 s, GPU 95-104 -> 76-78 ms per frame. The staging classes disappear; the draw class is the same (about 63 ms).
- **Town: the revert is slower.** Presents 73 / 84 -> 59 / 59 per 10 s, GPU 84-94 -> 145-149 ms per frame. In the reverted town most GPU time falls in no named class (b1: named classes 3,606 ms out of 8,324 ms of GPU time per 10 s), while the named ones stay small (draw about 52, fill 3.6, storage upload 2.4 ms per frame).

So the PR is a trade-off, not a plain regression: it costs the menu about 25 GPU ms per frame and saves the town far more. **Not the way:** reverting it. **Next:** trace the reverted town to name the unclassified GPU time, then keep the town gain while stopping the menu from staging about 26 MiB regions every frame.

## Menu (+245..+365 s)

The "hooksync" column is hook syncs per 10 s / time spent in them.

| arm | presents/10 s (range) | frame p50 ms | inflight_wait ms | GPU ms/frame | top classes ms/frame | staging in / back per 10 s | VRAM MiB | SM % | app.elf CPU ms/10 s | hooksync |
|---|---|---|---|---|---|---|---|---|---|---|
| a1 A | 85.5 (84-87) | 117.6 | 37.7 | 103.5 | draw 63.6, staging-out 15.0, staging-in 12.0, fill 4.2 | 21581 MiB in 830 regions (26.00 MiB) / 21581 in 800 (26.96) | 10356 | 94.1 | 22821 | 124 / 3712 ms |
| b1 B | 109.0 (107-111) | 92.3 | 35.3 | 77.9 | draw 63.6, fill 4.5, storage-upload 2.8, fill-clear 1.3 | 960 in 828 (1.16) / 960 in 828 (1.16) | 9694 | 92.3 | 25288 | 109 / 2040 ms |
| a2 A | 95.0 (87-95) | 105.8 | 35.2 | 95.1 | draw 62.1, staging-out 12.8, staging-in 10.0, fill 3.3 | 23610 in 908 (26.00) / 23610 in 908 | 9886 | 92.8 | 20978 | 133 / 3715 ms |
| b2 B | 112.0 (110-112) | 90.0 | 35.5 | 76.3 | draw 63.4, fill 3.9, storage-upload 2.7, fill-clear 1.1 | 986 in 851 (1.16) / 986 in 851 (1.16) | 9483 | 91.7 | 24113 | 112 / 2076 ms |

## Town (last 150 s of 180 s)

| arm | presents/10 s | frame p50 ms | inflight_wait ms | GPU ms/frame | top classes ms/frame | staging in / back per 10 s | VRAM MiB | SM % | app.elf CPU ms/10 s | hooksync |
|---|---|---|---|---|---|---|---|---|---|---|
| a1 A | 73.0 median (1-78, mean 66.8; one window during town load) | 138.0 | 24.7 | 93.9 | draw 52.4, staging-out 14.9, staging-in 11.9, fill 3.8 | 17431 in 2826 (6.17) / 17431 in 1724 (10.11) | 10669 | 74.2 | 23415 | 73.5 / 1000 ms |
| b1 B | 59 (58-65) | 168.8 | 39.0 | 145.4 | draw 51.4, fill 3.6, storage-upload 2.4, fill-clear 1.1 | 522 in 2294 (0.23) / 522 in 1372 (0.38) | 10314 | 88.9 | 22687 | 59 / 2885 ms |
| a2 A | 84.0 (82-85) | 119.7 | 22.7 | 84.4 | draw 49.4, staging-out 12.9, staging-in 10.0, fill 3.2 | 20946 in 3396 (6.17) / 20946 in 2101 (9.97) | 10546 | 73.3 | 26640 | 84 / 928 ms |
| b2 B | 59 (56-60) | 171.7 | 41.3 | 148.6 | draw 52.1, fill 3.6, storage-upload 2.4, fill-clear 1.1 | 509 in 2237 (0.23) / 509 in 1338 (0.38) | 10214 | 91.2 | 21750 | 59 / 3148 ms |

Shared-memory peak: 8,840 / 8,932 / 8,819 / 9,192 MiB (a1 b1 a2 b2).

AI-assisted. Tested by me on my own machine.
