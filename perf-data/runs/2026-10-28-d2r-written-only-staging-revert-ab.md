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

## Follow-up: the PR kept, swept shadow capped at 16 MiB (desktop)

Question: can a smaller cap on the swept shadow keep the town gain while stopping the menu from staging about 26 MiB regions every frame?

- **Date / machine:** 2026-10-28, Linux desktop (RTX 3080 Ti), same scenes and settings as above.
- **Builds:** A = upstream `cc672fdfc6`; C = A with one constant changed in `GuestBufferMemory.cpp`: `DiscreteSweptShadowMax` 256 MiB -> 16 MiB. Not upstream.
- **Order:** a1 c1 a2 c2, no reruns, no errors, no shared-memory spike (peaks 8,872-9,185 MiB). In a2 the town took about 400 s to load (others 25-65 s); its town window was measured normally.

**Result: the cap behaves like the full revert.** The menu is clearly faster (89-93.5 -> 109-111 presents per 10 s, GPU 95-99 -> 77 ms per frame), and the town is clearly slower (82-89 -> 59-67 presents, GPU 84-90 -> 129-151 ms per frame), with most of the extra town GPU time again outside the named classes. **Ruled out:** capping the swept shadow size; below 26 MiB it switches the feature off in both scenes. **Next:** the same as above, trace the town without staging to name that GPU time, then keep staging where it pays (town) by what is written, not by region size.

Menu (+245..+365 s):

| arm | presents/10 s (range) | frame p50 ms | inflight_wait ms | GPU ms/frame | top classes ms/frame | staging in / back per 10 s | VRAM MiB | SM % | app.elf CPU ms/10 s | hooksync |
|---|---|---|---|---|---|---|---|---|---|---|
| a1 A | 89.0 (89-90) | 112.6 | 36.9 | 99.4 | draw 62.9, staging-out 13.8, staging-in 10.6, fill 4.0 | 22492 MiB in 865 (26.00) / 22492 in 865 (26.00) | 9835 | 94.1 | 19699 | 126.5 / 3666 ms |
| c1 C | 111.0 (106-111) | 90.5 | 35.4 | 76.9 | draw 63.6, fill 4.1, storage-upload 2.6, fill-clear 1.2 | 976 in 842 (1.16) / 976 in 842 (1.16) | 9641 | 92.8 | 25724 | 111 / 2150.5 ms |
| a2 A | 93.5 (91-95) | 107.5 | 34.3 | 95.3 | draw 61.9, staging-out 12.8, staging-in 10.1, fill 3.4 | 23528 in 905 (26.00) / 23528 in 873 (26.96) | 9672 | 92.5 | 19912 | 128 / 3544 ms |
| c2 C | 109.0 (108-110) | 92.0 | 36.1 | 76.9 | draw 63.6, fill 4.1, storage-upload 2.6, fill-clear 1.1 | 964 in 832 (1.16) / 964 in 832 (1.16) | 9485 | 90.9 | 25578 | 109 / 2182 ms |

Town (last 150 s of 180 s):

| arm | presents/10 s (range) | frame p50 ms | inflight_wait ms | GPU ms/frame | top classes ms/frame | staging in / back per 10 s | VRAM MiB | SM % | app.elf CPU ms/10 s | hooksync |
|---|---|---|---|---|---|---|---|---|---|---|
| a1 A | 82.0 (78-84) | 122.5 | 26.5 | 89.8 | draw 51.1, staging-out 13.9, staging-in 10.7, fill 3.6 | 20309 in 3292 (6.17) / 20309 in 2037 (9.97) | 10584 | 79.3 | 24816 | 82 / 987 ms |
| c1 C | 59 (55-60) | 171.3 | 41.4 | 150.8 | draw 51.8, fill 3.7, storage-upload 2.4, fill-clear 1.2 | 505 in 2220 (0.23) / 505 in 1328 (0.38) | 10367 | 89.5 | 20476 | 59 / 3229 ms |
| a2 A | 89 (85-91) | 112.4 | 23.9 | 84.1 | draw 49.2, staging-out 12.7, staging-in 10.0, fill 3.1 | 22206 in 3600 (6.17) / 22206 in 2196 (10.11) | 10389 | 77.7 | 26861 | 90 / 923 ms |
| c2 C | 67.0 (61-67) | 152.8 | 35.6 | 128.5 | draw 49.2, fill 3.2, storage-upload 2.2, fill-clear 0.9 | 572 in 2513 (0.23) / 572 in 1503 (0.38) | 10436 | 86.9 | 23601 | 66.5 / 2534 ms |

## Same A/B on the AMD mini PC (Radeon 780M)

- **Date / machine:** 2026-10-28, AMD mini PC (Ryzen 9 PRO 8945HS, Radeon 780M integrated GPU, RADV, Mesa 26.0.8). See [machines.md](../machines.md).
- **Builds and scenes:** the same A (`cc672fdfc6`) and B (A + revert of `a293f7901b`), the same menu window and town window, same settings (headless, audio muted, shader disk cache off). Order A1 B1 A2 B2. No validation errors, no device loss.
- **One arm short:** a1 was stopped by the memory guard while the town was loading (before any in-game frame), so A has two menu windows and one town window. Every complete window stayed at 9.2-9.6 GiB.

**Result: no difference, menu or town.** Staging is about 0.9 GiB each way per 10 s in both arms (the desktop moves about 21 GB with the PR). The PR targets discrete GPUs; the 780M is integrated, so the changed path most likely never runs there. This machine cannot show the desktop trade-off, and the town trace stays on the desktop.

Medians over the 10 s lines in each window:

| | A menu (a1 / a2) | B menu (b1 / b2) | A town (a2) | B town (b1 / b2) |
|---|---|---|---|---|
| presents /10 s | 57 / 57 | 57 / 57 | 58 | 57 / 57 |
| frame p50 ms | 176.4 / 177.3 | 177.1 / 176.9 | 173.2 | 175.8 / 175.8 |
| GPU busy per present ms | 172.4 / 172.9 | 172.8 / 172.5 | 143.0 | 143.1 / 142.9 |
| GPU time ms /10 s | 519 / 518.5 | 515.5 / 516 | 1267 | 1256 / 1241 |
| staging in / back GiB /10 s | 0.9 / 0.9 | 0.9 / 0.9 | 0.9 | 0.9 / 0.9 |
| committer us per commit | 44.6 / 44.8 | 45.3 / 46.3 | 46.4 | 47.4 / 47.0 |
| CPU total % | 142 | 142 / 144 | 218 | 218 / 219 |
| RSS max MiB | 9455 / 9192 | 9272 / 9513 | 9630 | 9380 / 9387 |
| VRAM / GTT MiB | 1979 / 1906, 12646 / 12391 | 1984 / 1977, 12339 / 12303 | 1936, 12909 | 1938 / 1877, 13353 / 13469 |

On this machine the frame is held by draws (about 144 ms per present in the menu, 101 ms in town) and by clears (about 6 ms per present), not by staging (about 2 ms per present in both arms).

## Same A/B on the Windows laptop (RTX A2000 Laptop), partial

- **Date / machine:** 2026-10-28, Windows laptop (RTX A2000 Laptop, NVIDIA 610.60). See [machines.md](../machines.md).
- **Builds and scenes:** the same A (`cc672fdfc6`) and B (A + revert of `a293f7901b`), built with GCC (WinLibs) and Ninja in Release; same menu window, then town; same settings (audio muted, shader disk cache off). Order A1 B1 A2 B2. The D2R relink on Windows works again on this main (no #7763 error).
- **A1 is not comparable:** its menu button press did not register, so its window is probably the title screen. The clean comparison is A2 against B1 and B2.

**Result: the menu staging difference reproduces, but it does not decide speed here, and town could not be measured.**

- With the PR, staging costs about 47-70 ms of GPU time per frame and moves 400-580 MB each way per 10 s; with the revert, about 5 ms per frame and 60-90 MB. Same direction as the desktop.
- But the menu runs at only 0.2-0.4 frames per second on this laptop: storage uploads take about 7-8 s of GPU time per 10 s in every arm, which dwarfs staging, so presents do not separate the arms.
- **Town:** in all four runs, both arms stayed on the "Loading" screen at about 1 present per 10 s for 4-8 minutes after the save opened, until stopped. No crash, and the same in A and B, so it is not an A/B effect. During that loading (B1 against A2, four windows each): staging 2.5 against 29 ms and 32 against 230 MB per 10 s, storage upload 6.6 against 5.9 s.

Menu window, per 10 s:

| | A1 (title?) | B1 | A2 | B2 |
|---|---|---|---|---|
| presents | 1.9 | 3.9 | 2.7 | 2.6 |
| staging in + out GPU ms | 88.5 | 21.7 | 186.2 | 12.0 |
| staging ms per frame | ~47 | ~5.6 | ~70 | ~4.7 |
| staging KiB in (= back) | 403,309 | 89,843 | 576,156 | 59,406 |
| storage-upload GPU ms | 8149 | 6832 | 7591 | 8100 |
| storage-writeback GPU ms | 382 | 600 | 429 | 420 |
| draw GPU ms | 181 | 423 | 295 | 229 |
| shadow-publish GPU ms | 1.9 | 188 | 78 | 1.1 |
| storage uploads direct MiB | 44,525 | 52,139 | 53,751 | 53,965 |
| partial write-backs MiB | 7,441 | 9,488 | 9,321 | 9,066 |
| draws (avg us) | 1718 (19966) | 4238 (1652) | 2754 (3330) | 2063 (30887) |
| draw cache lookups / hits | 1719 / 5 | 4241 / 12 | 2756 / 8 | 2064 / 6 |
| untagged lock wait ms | 642 | 1197 | 813 | 885 |
| CPU total % | 87 | 93 | 88 | 83 |
| RAM peak working set / private MB | 9185 / 20229 | 9383 / 20005 | 9368 / 20131 | 9640 / 20540 |
| VRAM peak MB | 3568 | 3513 | 3646 | 3502 |

**Open on this machine:** the D2R town load crawls on Windows in both arms, so it cannot be a test phase here; and the menu is bound by storage uploads (about 8 s of GPU per 10 s), a bigger problem on this GPU than the staging cost.

AI-assisted. Tested by me on my own machine.
