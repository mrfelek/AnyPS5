# Diablo II Resurrected (PPSA03912), main menu and town, written-only staging on and reverted

Question: does [#7618](https://github.com/boykopovar/AnyPS5/pull/7618) (my merged PR that stages only the written elements of swept buffers, commit `a293f7901b`) cost time on current main? This isolates it with a revert, instead of the switch that turns off every written shadow.

- **Date / machine:** 2026-10-28, Linux desktop (RTX 3080 Ti). See [machines.md](../machines.md).
- **Builds:** A = upstream main `cc672fdfc6` (includes the float fix #11297); B = A + `git revert a293f7901b` (clean, 4 files).
- **Scenes:** main menu (+245..+365 s), then 180 s in town after loading the save (last 150 s measured). Headless, audio muted, memory cap, shader disk cache off, pipeline journal threads 0.
- **Order:** A B A B, no reruns, no errors in any log, no shared-memory spike.

## Result

Summary posted upstream on the Diablo II Resurrected discussion: [comment](https://github.com/boykopovar/AnyPS5/discussions/5146#discussioncomment-19245116).

With the PR, about 20 GB of staging copies go each way per 10 s in both scenes; the revert cuts that to about 0.5-1 GB.

- **Menu: the revert is faster.** Presents 85.5 / 95 -> 109 / 112 per 10 s, GPU 95-104 -> 76-78 ms per frame. The staging classes disappear; the draw class is the same (about 63 ms).
- **Town: the revert is slower.** Presents 73 / 84 -> 59 / 59 per 10 s, GPU 84-94 -> 145-149 ms per frame. In the reverted town most GPU time falls in no named class (b1: named classes 3,606 ms out of 8,324 ms of GPU time per 10 s), while the named ones stay small (draw about 52, fill 3.6, storage upload 2.4 ms per frame).

So the PR is a trade-off, not a plain regression: it costs the menu about 25 GPU ms per frame and saves the town far more. **Not the way:** reverting it. **Next:** trace the reverted town to name the unclassified GPU time, then keep the town gain while stopping the menu from staging about 26 MiB regions every frame. (The [staging trace](#what-is-staged-trace-desktop) shows the 26 MiB is only an average: the copies are one 202.5 MiB swept element, re-copied every frame.)

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

**Result: the cap behaves like the full revert.** The menu is clearly faster (89-93.5 -> 109-111 presents per 10 s, GPU 95-99 -> 77 ms per frame), and the town is clearly slower (82-89 -> 59-67 presents, GPU 84-90 -> 129-151 ms per frame), with most of the extra town GPU time again outside the named classes. **Ruled out:** capping the swept shadow size; at 16 MiB it switches the feature off in both scenes (the element that matters is 202.5 MiB, see the trace below). **Next:** the same as above, trace the town without staging to name that GPU time, then keep staging where it pays (town) by what is written, not by region size.

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

## What is staged: trace (desktop)

Question: what exactly does the PR copy about 20 GB of per 10 s?

- **Date / machine:** 2026-10-28, Linux desktop (RTX 3080 Ti), same scenes and settings.
- **Build:** upstream `cc672fdfc6` + [staging-uses-diag.diff](../../research/patches/staging-uses-diag.diff) (test-only logging: each staged guest range with its size and use count per 10 s). One run; the town took about 400 s to load again, and its window was measured after that.
- **Speed in this run:** menu 94 presents per 10 s (93-94), GPU 94.9 ms per frame; town 85 (82-89), GPU 86.6 ms per frame. Same as the A arms above.

**Result: both scenes stage the same 9 guest ranges, each copied in about once per present, and one 202.5 MiB swept range is about 83% of all staging.**

| range | size | swept | copies per 10 s, menu / town | MiB per 10 s, menu / town |
|---|---|---|---|---|
| 0x2a86b47f0+0xca80000 | 202.50 MiB | yes | 94 / 84 | 19035 / 17010 |
| 0x258fb6200+0x1fa4000 | 31.64 MiB | yes | 94 / 84 | 2974 / 2658 |
| 0x2b5138880+0x62b800 | 6.17 MiB | no | 94 / 84 | 580 / 518 |
| 0x2601212e0+0x140000 | 1.25 MiB | yes | 94 / 84 | 118 / 105 |
| 0x235dfab00+0x100000 | 1.00 MiB | no | 94 / 84 | 94 / 84 |
| 0x2b57f97e0+0x10000 | 0.06 MiB | yes | 94 / 84 | 6 / 5 |
| 0x2b57f57d0+0x4000 | 0.02 MiB | yes | 94 / 84 | 1 / 1 |
| 0x2b5764100+0x180 | 0.00 MiB | yes | 94 / 84 | 0 / 0 |
| 0x2b5134800+0x10 | 16 bytes | yes | 94 / 84 | 0 / 0 |

(First 10 s block of each window; totals 22,808 MiB menu, 20,382 MiB town. Every later block has the same 9 ranges at 82-94 copies each.)

- The "26 MiB average region" in the tables above is the total divided by the region count, not a 26 MiB element.
- The last range is the indirect-draw argument block from the [indirect read work](../../research/indirect-draw-reads.md).
- Since the same ranges are copied at the same rate in both scenes, the menu/town difference is not in what is staged but in what the copies save the GPU elsewhere in town. **Next:** stage the 202.5 MiB element only where it is written (or only the written part of it each frame), and trace the town without staging to name the GPU time it saves.

## Other title: Sonic Origins Plus, Sonic 2 menu (desktop)

- **Date / machine:** 2026-10-28, Linux desktop (RTX 3080 Ti). Same A (`cc672fdfc6`) and B (A + revert of `a293f7901b`) builds. Sonic 2 menu page reached by +93 s, measured +120..+240 s, staging trace on. Order b1 a2 b2, then a1 (the first a1 stayed on the title screen because input went in during the cold boot; not counted).

**Result: no effect on Sonic.** Staging is about 5 MiB per 10 s in both builds, there are no swept-shadow regions at all (the trace shows one 31.2 KiB range and one 16-byte atomic element), and 0 shadows are refused.

| arm | presents/10 s (range) | frame p50 ms | inflight_wait ms | GPU ms/frame | top classes ms/frame | staging in / back per 10 s | VRAM MiB | SM % | app.elf CPU ms/10 s |
|---|---|---|---|---|---|---|---|---|---|
| a1 A | 162 (155-168) | 62.1 | 18.2 | 38.2 | draw 18.7, storage-upload 4.0, copy 3.1, fill 3.0 | 5 MiB in 796 / 5 in 320 | 7454 | 63.3 | 23188 |
| b1 B | 161 (149-166) | 62.3 | 18.2 | 38.8 | draw 18.8, storage-upload 4.1, copy 3.1, fill 3.0 | 5 in 798 / 5 in 324 | 7775 | 65.6 | 24008 |
| a2 A | 160 (150-166) | 62.7 | 18.4 | 39.9 | draw 19.0, storage-upload 4.4, copy 3.2, fill 3.2 | 5 in 791 / 5 in 323 | 7686 | 68.9 | 24022 |
| b2 B | 165 (157-169) | 60.6 | 18.3 | 38.4 | draw 18.8, storage-upload 4.0, copy 3.1, fill 3.0 | 5 in 799 / 5 in 323 | 7525 | 67.3 | 23504 |

## Other title: Hot Wheels Infinite Rush, title, menu and garage (Windows laptop)

- **Date / machine:** 2026-10-28, Windows laptop (RTX A2000 Laptop, NVIDIA 610.60). See [machines.md](../machines.md).
- **Why an older base:** Hot Wheels no longer boots on current main on Windows. On `cc672fdfc6`, `e2e27a3ba9` and `3a40945e62` every run stopped about 10 s after launch with `sceHttp2GetMemoryPoolStats not implemented` (0xC0000409). The cause is `db57916260` ("feat(http2): send synchronous HTTP/2 requests over TLS"), after which that call ends in a not-implemented stub for a valid context. So this A/B uses `6d0139cd33`, which predates both that commit and the PR.
- **Builds:** A = `6d0139cd33` + the GameUpdate "no update" fix; B = A + cherry-pick of `a293f7901b` (clean). Audio muted. Order A1 B1 A2 B2; all four reached the garage (no race: race load takes over 5 minutes on this laptop).
- **Phases:** title idle +152..+250 s, title to menu +250..+426 s, garage 150 s at +580..+730 s.

**Result: no measurable effect on Hot Wheels.** Staging volume and region size are the same in both builds (about 1.5 GB each way per 10 s at the title and 0.7 GB in the garage, regions of 250 / 226 KiB), and GPU time per frame differs by 1% or less. The written-only path is either not taken here or changes nothing. B1's title phases are an outlier (shadow publish about 940 against 1,710 ms, presents 41.6 against about 36); B2 on the same build matches A, so that is run-to-run noise.

| phase / metric (per 10 s) | A1 | B1 | A2 | B2 |
|---|---|---|---|---|
| title idle: presents | 35.8 | 41.6 | 37.0 | 36.4 |
| title idle: GPU ms/frame | 116.4 | 112.4 | 111.2 | 112.1 |
| title idle: staging KiB in (= back) | 1,477,284 | 1,712,520 | 1,522,725 | 1,502,430 |
| title idle: regions / average KiB | 5905 / 250.2 | 6843 / 250.3 | 6086 / 250.2 | 6006 / 250.2 |
| title idle: shadow-publish / storage-upload / draw ms | 1704 / 899 / 525 | 944 / 763 / 598 | 1725 / 908 / 517 | 1726 / 908 / 514 |
| title to menu: presents | 35.4 | 39.9 | 35.5 | 35.4 |
| title to menu: GPU ms/frame | 112.4 | 113.1 | 110.5 | 110.9 |
| title to menu: staging KiB in | 1,458,189 | 1,649,600 | 1,474,060 | 1,463,017 |
| garage: presents | 9.73 | 9.79 | 9.57 | 9.36 |
| garage: GPU ms/frame | 155.2 | 155.8 | 154.5 | 154.5 |
| garage: storage-upload / shadow-publish / draw ms | 2516 / 2071 / 298 | 2482 / 2014 / 304 | 2742 / 2166 / 292 | 2765 / 2114 / 283 |
| garage: staging KiB in, regions / average KiB | 704,649, 3113 / 226.4 | 710,523, 3141 / 226.2 | 674,148, 2995 / 225.1 | 659,316, 2928 / 225.2 |
| CPU % of one core (title / menu / garage) | 89 / 93 / 100 | 96 / 97 / 99 | 89 / 90 / 102 | 86 / 89 / 104 |
| RAM peak working set / private MB | 7370 / 12368 | 7405 / 12723 | 7194 / 11763 | 7200 / 11936 |
| VRAM peak MB | 3681 | 3622 | 3693 | 3709 |

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
