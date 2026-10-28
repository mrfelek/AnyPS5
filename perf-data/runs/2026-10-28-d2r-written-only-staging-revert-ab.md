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

## Follow-up: swept shadow capped at 64 MiB (desktop)

Same setup as the 16 MiB cap: A = upstream `cc672fdfc6`; D = A with `DiscreteSweptShadowMax` 256 MiB -> 64 MiB. Order a1 d1 a2 d2, no reruns, no errors, normal town load times (25-65 s), shared-memory peaks 8,871-8,989 MiB.

**Result: the 64 MiB cap behaves like the 16 MiB cap and the full revert.** The menu is faster (88.5-94 -> 113-113.5 presents per 10 s, GPU 95-101 -> 76 ms per frame) and the town clearly slower (79-83 -> 60-61, GPU 84-93 -> 130-133 ms). D still stages the smaller swept elements (about 4.7 GB per 10 s on the menu, 2.5 GB in town), but the 202.5 MiB element from the [trace](#what-is-staged-trace-desktop) is over the cap and no longer staged. **So the PR's town gain comes from staging that one 202.5 MiB swept element; any cap below about 203 MiB loses it.** Ruled out: a size cap at any useful size. **Instead:** keep staging that element where it pays, and make the menu stop needing it (stage only its written part, or skip frames where it is not written).

Menu (+245..+365 s):

| arm | presents/10 s (range) | frame p50 ms | inflight_wait ms | GPU ms/frame | top classes ms/frame | staging in / back per 10 s | VRAM MiB | SM % | app.elf CPU ms/10 s | hooksync |
|---|---|---|---|---|---|---|---|---|---|---|
| a1 A | 94.0 (92-94) | 107.0 | 34.7 | 95.4 | draw 62.4, staging-out 13.1, staging-in 9.9, fill 3.3 | 23547 MiB in 906 (26.00) / 23547 in 906 (26.00) | 10004 | 92.6 | 18204 | 141 / 3586 ms |
| d1 D | 113.0 (106-114) | 89.2 | 34.7 | 76.2 | draw 63.0, fill 3.3, storage-upload 2.2, staging-in 1.7, staging-out 1.7 | 4603 in 955 (4.82) / 4603 in 955 (4.82) | 9857 | 90.5 | 23852 | 113 / 2059 ms |
| a2 A | 88.5 (88-95) | 113.7 | 38.0 | 100.7 | draw 63.3, staging-out 13.8, staging-in 11.0, fill 4.1 | 22848 in 879 (26.00) / 22848 in 879 (26.00) | 9529 | 94.8 | 19332 | 132.5 / 3738 ms |
| d2 D | 113.5 (108-114) | 88.4 | 34.3 | 75.5 | draw 62.5, fill 3.2, storage-upload 2.2, staging-in 1.6, staging-out 1.6 | 4716 in 980 (4.81) / 4716 in 980 (4.81) | 9486 | 89.9 | 22068 | 113.5 / 2060 ms |

Town (last 150 s of 180 s):

| arm | presents/10 s (range) | frame p50 ms | inflight_wait ms | GPU ms/frame | top classes ms/frame | staging in / back per 10 s | VRAM MiB | SM % | app.elf CPU ms/10 s | hooksync |
|---|---|---|---|---|---|---|---|---|---|---|
| a1 A | 79 (76-81) | 127.3 | 27.6 | 92.8 | draw 52.0, staging-out 15.1, staging-in 11.1, fill 3.9 | 19727 in 3198 (6.17) / 19727 in 1978 (9.97) | 10765 | 79.0 | 26300 | 79 / 1024 ms |
| d1 D | 61 (59-69) | 163.5 | 26.1 | 129.7 | draw 52.4, fill 3.7, storage-upload 2.4, staging-out 1.9 | 2574 in 2460 (1.05) / 2574 in 1497 (1.72) | 10112 | 83.2 | 21671 | 61 / 2883 ms |
| a2 A | 83 (79-84) | 121.5 | 22.0 | 84.2 | draw 49.5, staging-out 12.5, staging-in 9.9, fill 3.2 | 20477 in 3319 (6.17) / 20477 in 2053 (9.97) | 10702 | 72.7 | 24945 | 83 / 861 ms |
| d2 D | 60 (58-61) | 168.1 | 25.9 | 133.1 | draw 51.9, fill 3.6, storage-upload 2.4, staging-out 1.9 | 2458 in 2347 (1.05) / 2458 in 1429 (1.72) | 10484 | 83.4 | 19357 | 60 / 3125 ms |

## Follow-up: adaptive staging, measure and pick per element (desktop)

Question: since staging the 202.5 MiB element pays in town but costs the menu, can the emulator measure both ways and pick per element?

- **Build:** A = upstream `cc672fdfc6`; B = A + [adaptive-staging.diff](../../research/patches/adaptive-staging.diff) (my prototype, not upstream): for each large swept element it times a few frames staged and a few frames in place, keeps the faster one, and re-checks later. Same scenes and settings as above, staging counters on. One run per arm, both without errors.

| per 10 s | A1 | B1 |
|---|---|---|
| menu presents | 93.0 | 112.5 |
| menu staging in / out | 23.5 GB | 5.7 GB |
| menu staging GPU ms/frame (in + out) | 10.3 + 12.5 | 2.5 + 2.1 |
| town presents | 86 | 81 |
| town staging | 21.4 GB | 19.0 GB |
| town staging GPU ms/frame (in + out) | 10.1 + 12.4 | 10.9 + 13.8 |
| committer us per commit (menu / town) | 37.3 / 28.6 | 38.0 / 29.8 |

**Result: the menu gets the revert's speed (93 -> 112.5 presents), but town is 6% slower than plain main (86 -> 81) instead of keeping it.** The decisions themselves are right: 32 decisions, 31 of them for the 202.5 MiB element; on the menu in place wins (78 against 97 ms per frame) and in town staging wins (87-96 against 118-139 ms), for example:

```
[staging] adaptive: 0x2a86e47f0+0xca80000 GPU 95.8 ms/frame staged, 138.1 in place (12/7 frames) -> staged
```

The likely cost (not yet tested) is the re-checking: each decision runs 6-8 frames in place again, about 40 ms extra each in town. **Next:** back off the re-check (double the interval each time the answer repeats), then rerun the same pair. Update: [v2 below](#follow-up-adaptive-staging-v2-re-checks-backed-off-desktop) does that; town GPU time is back to the PR-in level, town presents still about 3% short.

## Follow-up: adaptive staging v2, re-checks backed off (desktop)

- **Build:** B = `cc672fdfc6` + [adaptive-staging-v2.diff](../../research/patches/adaptive-staging-v2.diff) (replaces v1: the re-check interval doubles while the answer repeats). A = plain `cc672fdfc6`. Same environment as the v1 pair (draw and GPU profiling, staging counts, indirect trace), headless, muted, shader disk cache off. One run per arm, menu and town in the same run; a second A run was added because town was within 5%. No errors.

| | A1 (PR in, from the v1 pair) | A2 | v1 | v2 |
|---|---|---|---|---|
| Menu presents per 10 s | 93.0 | 93.5 | 112.5 | 113.0 |
| Menu GPU ms per frame | 95.8 | 95.2 | 75.8 | 75.7 |
| Menu staging per 10 s | 23.5 GB | - | 5.7 GB | 5.0 GB |
| Menu staging ms per frame (in + out) | 10.3 + 12.5 | - | 2.5 + 2.1 | 1.6 + 1.6 |
| Town presents per 10 s | 86 | 85 | 81 | 82.5 |
| Town GPU ms per frame | 84.3 | 83.9 | 91.8 | 84.1 |
| Town staging GB per 10 s | 21.4 | 21.1 | 19.0 | 19.4 |
| Town staging ms per frame (in + out) | 10.1 + 12.4 | - | 10.9 + 13.8 | 9.9 + 12.1 |
| Committer us per commit (menu / town) | 37.3 / 28.6 | 37.6 / 27.6 | 38.0 / 29.8 | 37.7 / 27.4 |

**Result: the menu keeps +21% (93 -> 113 presents per 10 s), and town GPU time is back to the PR-in level (84.1 ms, v1 had 91.8).** Town presents are still about 3% below PR-in (82.5 vs 85-86) with GPU time, staging and committer time equal, so the remaining cost is the probe frames (town still re-checks about every 40 s) or CPU-side bookkeeping.

- **Back-off:** in the menu the interval reached 80 s and held. In town every answer is "staged", but the interval goes 20 -> 40, holds at 40, reaches 80 once, then drops back to 40. The lines that hold or reset are mostly short samples (8/3 frames), so a short sample probably resets or holds the back-off instead of counting as a repeat (read from the log, not from the code).
- **Next:** count a short sample with the same answer as a repeat, and let the interval keep growing (160-320 s) while the answer stays the same. Update: [v3 below](#follow-up-adaptive-staging-v3-menu-win-kept-and-town-back-to-pr-level-desktop) does that; town is back to the PR level.

Decision lines, verbatim (15):

```
[staging] adaptive: 0x2601512e0+0x140000 GPU 92.0 ms/frame staged, 121.5 in place (7/7 frames) -> staged (not measured), next probe in 20 s
[staging] adaptive: 0x2a86e47f0+0xca80000 GPU 104.1 ms/frame staged, 84.1 in place (14/7 frames) -> in place, next probe in 20 s
[staging] adaptive: 0x2a86e47f0+0xca80000 GPU 104.0 ms/frame staged, 84.3 in place (13/7 frames) -> in place, next probe in 40 s
[staging] adaptive: 0x2a86e47f0+0xca80000 GPU 106.8 ms/frame staged, 85.1 in place (15/6 frames) -> in place, next probe in 80 s
[staging] adaptive: 0x2a86e47f0+0xca80000 GPU 97.4 ms/frame staged, 78.7 in place (13/8 frames) -> in place, next probe in 80 s
[staging] adaptive: 0x2a86e47f0+0xca80000 GPU 97.1 ms/frame staged, 79.0 in place (8/3 frames) -> in place, next probe in 80 s
[staging] adaptive: 0x2a86e47f0+0xca80000 GPU 84.0 ms/frame staged, 95.7 in place (13/8 frames) -> staged, next probe in 20 s
[staging] adaptive: 0x2a86e47f0+0xca80000 GPU 86.7 ms/frame staged, 116.1 in place (8/3 frames) -> staged, next probe in 40 s
[staging] adaptive: 0x2a86e47f0+0xca80000 GPU 87.2 ms/frame staged, 116.7 in place (8/3 frames) -> staged, next probe in 40 s
[staging] adaptive: 0x2a86e47f0+0xca80000 GPU 87.0 ms/frame staged, 116.9 in place (8/3 frames) -> staged, next probe in 40 s
[staging] adaptive: 0x2a86e47f0+0xca80000 GPU 87.1 ms/frame staged, 117.4 in place (8/3 frames) -> staged, next probe in 40 s
[staging] adaptive: 0x2a86e47f0+0xca80000 GPU 86.8 ms/frame staged, 117.4 in place (13/7 frames) -> staged, next probe in 40 s
[staging] adaptive: 0x2a86e47f0+0xca80000 GPU 87.0 ms/frame staged, 117.4 in place (8/3 frames) -> staged, next probe in 80 s
[staging] adaptive: 0x2a86e47f0+0xca80000 GPU 87.3 ms/frame staged, 117.2 in place (14/7 frames) -> staged, next probe in 40 s
[staging] adaptive: 0x2a86e47f0+0xca80000 GPU 87.2 ms/frame staged, 117.3 in place (13/8 frames) -> staged, next probe in 40 s
```

## Follow-up: adaptive staging v3, menu win kept and town back to PR level (desktop)

- **Build:** B = `cc672fdfc6` + [adaptive-staging-v3.diff](../../research/patches/adaptive-staging-v3.diff) (replaces v2: a short sample with the same answer counts as a repeat, the interval grows up to 160 s, and a jump in frame GPU time triggers a new check at once). A = plain `cc672fdfc6`, the two runs from the v1 and v2 pairs (same day). Same environment, headless, muted, shader disk cache off. One B run, menu and town in the same run, no errors.

| | A1 / A2 (PR in) | v1 | v2 | v3 |
|---|---|---|---|---|
| Menu presents per 10 s | 93.0 / 93.5 | 112.5 | 113.0 | 112.5 |
| Menu GPU ms per frame | 95.8 / 95.2 | 75.8 | 75.7 | 75.9 |
| Menu staging ms per frame (in + out) | 10.3 + 12.5 | 2.5 + 2.1 | 1.6 + 1.6 | 2.2 + 1.7 |
| Town presents per 10 s | 86 / 85 | 81 | 82.5 | 85 |
| Town GPU ms per frame | 84.3 / 83.9 | 91.8 | 84.1 | 84.6 |
| Town staging GB per 10 s | 21.4 / 21.1 | 19.0 | 19.4 | 21.1 |
| Committer us per commit (menu / town) | 37.3 / 28.6 | 38.0 / 29.8 | 37.7 / 27.4 | 38.0 / 28.8 |

**Result: the goal is met. The menu keeps +21% (93 -> 112.5 presents per 10 s, GPU 95.8 -> 75.9 ms per frame), and the town is back to the level with the PR (85 vs 85-86 presents, GPU 84.6 vs 84 ms).** So #7618 does not need to be reverted or capped: deciding per element, by measured GPU time, keeps the gains of both sides.

- **Back-off:** 20 -> 40 -> 80 -> 160 s, then it holds at 160 s. At the change from menu to town it sees the frame GPU time jump (79.4 -> 202.6 ms) and checks again at once, then switches the 202.5 MiB element to staged.
- Loading the save into town took longer in this run (+768 s; A2 +556 s, earlier about +390 s). It happens before the measured windows and does not affect them.
- **Next:** one more pair to confirm (A B on the same day), then decide with Andrzej whether it goes upstream as a follow-up to #7618.

Decision lines, verbatim (12):

```
[staging] adaptive: 0x2601212e0+0x140000 GPU 90.7 ms/frame staged, 113.4 in place (6/7 frames) -> staged (not measured), next probe in 20 s
[staging] adaptive: 0x2a86b47f0+0xca80000 GPU 107.1 ms/frame staged, 85.4 in place (15/7 frames) -> in place, next probe in 20 s
[staging] adaptive: 0x2a86b47f0+0xca80000 GPU 105.3 ms/frame staged, 85.0 in place (8/3 frames) -> in place, next probe in 40 s
[staging] adaptive: 0x2a86b47f0+0xca80000 GPU 107.7 ms/frame staged, 85.1 in place (8/3 frames) -> in place, next probe in 80 s
[staging] adaptive: 0x2a86b47f0+0xca80000 GPU 98.4 ms/frame staged, 79.4 in place (8/3 frames) -> in place, next probe in 160 s
[staging] adaptive: frame GPU 79.4 -> 202.6 ms, probing again
[staging] adaptive: 0x2a86b47f0+0xca80000 GPU 84.1 ms/frame staged, 93.9 in place (16/7 frames) -> staged, next probe in 20 s
[staging] adaptive: 0x2a86b47f0+0xca80000 GPU 87.9 ms/frame staged, 119.9 in place (15/8 frames) -> staged, next probe in 40 s
[staging] adaptive: 0x2a86b47f0+0xca80000 GPU 88.0 ms/frame staged, 122.4 in place (8/3 frames) -> staged, next probe in 80 s
[staging] adaptive: 0x2a86b47f0+0xca80000 GPU 91.8 ms/frame staged, 129.1 in place (8/3 frames) -> staged, next probe in 160 s
[staging] adaptive: 0x2a86b47f0+0xca80000 GPU 87.8 ms/frame staged, 121.1 in place (8/3 frames) -> staged, next probe in 160 s
[staging] adaptive: 0x2a86b47f0+0xca80000 GPU 88.1 ms/frame staged, 120.8 in place (8/3 frames) -> staged, next probe in 160 s
```

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

## Other title: Ghost of Yotei (desktop), not testable

Tried in four setups (shader cache off, cold, warm, and the env list of my earlier world runs); in all of them both arms stay on a black screen or are stopped by the memory guard, the same in A and B. No data for #7618 on Yotei. [page](2026-10-28-ghost-of-yotei-written-only-staging-revert-not-testable.md)

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
