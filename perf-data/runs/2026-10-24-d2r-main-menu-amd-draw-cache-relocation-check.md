# Diablo II Resurrected (PPSA03912), main menu, draw cache data-hit relocation correctness check (AMD)

Question: a local experiment (not upstream) lets the draw cache reuse a cached shader build when a draw differs only in per-draw buffer pointers, by relocating those pointers instead of rebuilding. Is the reused build identical to a fresh one?

- **Date / machine:** 2026-10-24, AMD mini PC (Radeon 780M, RADV). See [machines.md](../machines.md).
- **Build:** upstream main `e4bb5fc125` + the local relocation patch + a test GameUpdate change. A = relocation off, B = relocation on. Both with `APS5_VERIFY_DRAW_DATA_HITS=1`, which rebuilds every data-only hit in full and aborts if the two differ.
- **Environment:** default profile set, audio muted.
- **Phase measured:** main menu, 30 s settle + 180 s, no input.

## Result

The relocation is not correct yet. With it on, the verifier aborts about 5 frames after the menu appears: for one fragment stage the reused build has 8 runs where a full build has 9, over the same 174 words and the same variant. With relocation off, the same build and scene run 210 s with no verifier failure. The patch's unit tests (17/17) and Vulkan validation pass, so the tests do not cover this case.

| Arm | Menu reached | Verifier | Presents per 10 s |
|---|---|---|---|
| A (relocation off) | 36 s | 0 failures in 210 s | 54 (last four windows) |
| B (relocation on) | 38 s | abort after about 5 frames | n/a |

No speed numbers for B; the A/B on speed waits until the relocation passes this check.

## Run 2 (2026-10-25): v2 of the relocation patch

- **Build:** the same upstream main `e4bb5fc125` + [data-hit-relocation-v2.patch](../../research/patches/data-hit-relocation-v2.patch) (adds a page-boundary fix) + the test GameUpdate change. Same machine, same scene, relocation on, `APS5_VERIFY_DRAW_DATA_HITS=1`, audio muted.
- **Result:** the menu appears at 42 s; about 30 s later, while the menu settles, the verifier aborts again: stage 0 of program `0x32b36d500` in a data-only hit differs from its full build (8 runs / 20 words kept, 8 / 20 fresh, same variant). The run count now matches, so it is the contents of a run that differ, not the layout.
- **Compared with run 1:** same class of error in a different place (run 1: stage 1 of `0x32ced1f00`, 174 words, 8 runs vs 9). The page-boundary fix removed one wrong case but not all of them.
- After the abort the process stayed alive for about a minute while its memory grew from 14.7 to 23 GiB, until it was stopped. The Hot Wheels and Silksong verify runs and the speed A/B were not run, because the plan was to stop at the first abort.

**Ruled out, and the way forward:** guessing which user words are relocatable pointers is still not exact after two versions. The way forward is to know exactly which words are pointers (provenance from the recompiler), or to pass the moving ring offsets as data (dynamic offsets) instead of baking them into the shader build.

## Run 3 (2026-10-25): v3 of the relocation patch

- **Build:** upstream `e4bb5fc125` + [data-hit-relocation-v3.patch](../../research/patches/data-hit-relocation-v3.patch) (adds a run-order check) + the test GameUpdate change. Same machine, audio muted, `APS5_VERIFY_DRAW_DATA_HITS=1`, 180 s counted per game.
- **Verifier: no failures in three games.** D2R main menu (menu at 34 s, 54 presents per 10 s, committer 45.7 us per commit), Hot Wheels Infinite Rush (PPSA22408) title (6 presents per 10 s), Hollow Knight Silksong (PPSA12544) first area (600 presents per 10 s, committer 20.9 us per commit). No terminate, validation error or device loss.
- **Caveat, so this is not yet proof:** the line that counts relocated and verified stages is printed only with `APS5_TRACE_DRAW_CACHE=1`, which the verifier runs did not set, so they cannot show how many relocated stages were checked. The speed-counter runs (with the trace on) show that relocation does fire on the Hot Wheels title: 82-84 relocated stages per 10 s with relocation on, 0 with it off.
- **Speed counters, Hot Wheels title (relocation off vs on):** off: 296 lookups, 0 hits, committer 1,193.8 us per commit, 6 presents per 10 s; on: 635 lookups, 6 hits, committer 381.6 us per commit, 13 presents per 10 s. The on window was clearly in a different phase of the title (twice the lookups and presents), so this shows scene timing, not the effect of the relocation.
- **D2R speed counters: invalid.** The off arm crashed about 70 s after launch, before the menu. The on arm loaded a character and then crashed when the machine's disk filled up.

**Way forward:** repeat the verifier runs with `APS5_VERIFY_DRAW_DATA_HITS=1` and `APS5_TRACE_DRAW_CACHE=1` together, so the log shows relocated stages being checked; then repeat the speed A/B in a fixed scene with enough free disk.


## Run 4 (2026-10-28): v3 verifier with the trace on

- **Build:** same as run 3. `APS5_VERIFY_DRAW_DATA_HITS=1` and `APS5_TRACE_DRAW_CACHE=1` together, audio muted, 180 s counted per game.
- **Verifier: no failures.** No abort, terminate, segfault, validation error or device loss. Stages verified with no mismatch: D2R main menu 180,665, Hot Wheels Infinite Rush (PPSA22408) title 1,036, Hollow Knight Silksong (PPSA12544) gameplay area 81,609.
- **This counts as a pass for v3.** Every window reads "0 reused, 0 of them relocated", which first looked like the verifier never saw a relocated stage. It does: the lookup builds the moved (relocated) variant of each candidate whether or not the verifier is on, and the verifier compares that moved candidate with a fresh build. "Reused" and "relocated" count only stages that are actually served, and verify mode serves none, so both read 0 while "verified" includes the moved candidates.
- **Next:** the next revision adds an "N of them moved" count to the verified figure, so the log shows directly how many relocated stages were checked.

Two windows per game, verbatim:

```
D2R menu (menu after 36 s, 0 character loads):
window 9 of 18:
[draw-cache] 10 s: 70934 lookups, 4337 hits (6.1%), 130 stage misses, 70720 without an entry, 66395 data-only hits (stages: 0 reused, 0 of them relocated, 132790 compiled; 10070 verified); no entry: new registers 0, user words/pointers only 70676, evicted 15, seen but never inserted 29; stage misses: front differing 95, fragment differing 35, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 190 (2.0 words changed each), other runs 21; 4096 entries, 1703 evicted
window 18 of 18:
[draw-cache] 10 s: 71129 lookups, 4443 hits (6.2%), 115 stage misses, 70917 without an entry, 66512 data-only hits (stages: 0 reused, 0 of them relocated, 133024 compiled; 9828 verified); no entry: new registers 0, user words/pointers only 70891, evicted 13, seen but never inserted 13; stage misses: front differing 86, fragment differing 29, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 172 (2.0 words changed each), other runs 19; 4096 entries, 1642 evicted
All 18 windows: 0 relocated, 180665 verified.

HW title (title at frame_081):
window 9 of 18:
[draw-cache] 10 s: 255 lookups, 0 hits (0.0%), 0 stage misses, 255 without an entry, 195 data-only hits (stages: 0 reused, 0 of them relocated, 390 compiled; 55 verified); no entry: new registers 0, user words/pointers only 251, evicted 0, seen but never inserted 4; stage misses: front differing 0, fragment differing 0, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 0 (0.0 words changed each), other runs 0; 451 entries, 0 evicted
window 18 of 18:
[draw-cache] 10 s: 261 lookups, 2 hits (0.8%), 4 stage misses, 257 without an entry, 189 data-only hits (stages: 0 reused, 0 of them relocated, 378 compiled; 50 verified); no entry: new registers 0, user words/pointers only 246, evicted 0, seen but never inserted 11; stage misses: front differing 0, fragment differing 4, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 4 (2.5 words changed each), other runs 0; 577 entries, 0 evicted
All 18 windows: 0 relocated, 1036 verified.

Silksong gameplay area:
window 9 of 18:
[draw-cache] 10 s: 94970 lookups, 81783 hits (86.1%), 3205 stage misses, 9982 without an entry, 9981 data-only hits (stages: 0 reused, 0 of them relocated, 19962 compiled; 4508 verified); no entry: new registers 0, user words/pointers only 124, evicted 9710, seen but never inserted 148; stage misses: front differing 3205, fragment differing 0, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 6410 (2.2 words changed each), other runs 0; 4096 entries, 8857 evicted
window 18 of 18:
[draw-cache] 10 s: 94989 lookups, 79105 hits (83.3%), 2502 stage misses, 13382 without an entry, 13378 data-only hits (stages: 0 reused, 0 of them relocated, 26756 compiled; 6253 verified); no entry: new registers 0, user words/pointers only 4, evicted 13356, seen but never inserted 22; stage misses: front differing 2502, fragment differing 0, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 5004 (2.1 words changed each), other runs 0; 4096 entries, 11621 evicted
All 18 windows: 0 relocated, 81609 verified.
```

AI-assisted. Tested by me on my own machine.
