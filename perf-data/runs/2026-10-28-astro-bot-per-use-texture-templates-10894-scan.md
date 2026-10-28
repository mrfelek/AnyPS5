# Astro Bot (PPSA21564), does upstream #10894 (per-use texture templates) have anything to act on?

Question: [#10894](https://github.com/boykopovar/AnyPS5/pull/10894) (WallisSkill) keeps resource templates whose textures are remade every use, and gives Diablo II Resurrected +16-20% presents ([D2R run](2026-10-28-d2r-character-select-per-use-refresh-desktop.md#upstream-10894-wallisskill-menu-and-town)). Does Astro Bot hit the same case?

- **Date / machine:** 2026-10-28, Linux desktop (RTX 3080 Ti, NVIDIA 615.71.09). See [machines.md](../machines.md).
- **Build:** the #10894 build (`0c6bca70d9`), run with the PR switched off (`APS5_NO_PER_USE_TEXTURE_TEMPLATES=1`) to count what it would act on.
- **Scene:** level hub_crashsite (usual save), on screen, audio muted, all traces on.
- **Rule agreed before the run:** run the PR-on arm only if the PR-off arm shows per-use refusals worth fixing. It did not, so only the PR-off arm was run.

## Result: almost nothing to act on

| Counter | Astro Bot, PR off (about 170 s in the level) | Diablo II, PR off | Diablo II, PR on |
|---|---|---|---|
| per-use refusals ("same key, not inserted or evicted") | 6,574 draws + 1,260 dispatches | 912,489 | 67 |

- Resource cache hits are 75-135k per 10 s; misses are 0.7-1.8k per 10 s and come from layout changes, not per-use textures.
- **Conclusion:** #10894 has nothing to act on in Astro Bot; its gain is specific to Diablo II's textures that are remade every use. No harm expected either, but the PR-on arm was not run.
- **Run note:** the memory guard stopped the run about 170 s into the level (game 16.7 GB, free memory under the 4 GB floor). The refusal count is not affected.

AI-assisted. Tested by me on my own machine.
