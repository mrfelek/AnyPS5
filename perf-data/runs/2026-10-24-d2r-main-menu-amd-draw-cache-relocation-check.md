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

AI-assisted. Tested by me on my own machine.
