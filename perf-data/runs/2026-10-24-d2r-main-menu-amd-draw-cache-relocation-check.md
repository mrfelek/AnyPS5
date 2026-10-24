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

AI-assisted. Tested by me on my own machine.
