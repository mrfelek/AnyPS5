# Diablo II Resurrected (PPSA03912)

Upstream discussion: [D#5146](https://github.com/boykopovar/AnyPS5/discussions/5146).

## Phases and runs

| Phase | Date | Machine | Build | What | Headline | Page |
|---|---|---|---|---|---|---|
| Character select | 2026-10-25 | AMD mini PC | `e4bb5fc125` | committer split timers, descriptor set reuse A/B (local patch) | 53 presents/10 s either way; reuse cuts descriptor writes 30%, cost per draw unchanged (about 46 us) | [run](../runs/2026-10-25-d2r-character-select-amd-draw-set-reuse.md) |
| Main menu | 2026-10-24 | Linux desktop | `a19e7f6fd`, `6d0139cd33` | f32 denormal flush A/B | 91 -> 115 presents/10 s, GPU 104 -> 74 ms/frame on RTX 3080 Ti; no change on Radeon 780M | [run](../runs/2026-10-24-d2r-main-menu-f32-flush-ab.md) |
| Main menu | 2026-10-26 | Linux desktop | `49d1f9b07e` | f32 flush fix rebased | Fix still works (draw 62 ms/frame); new staging traffic on this main (26 ms/frame) gives 86 presents/10 s; plain-main arm not run yet | [run 6](../runs/2026-10-24-d2r-main-menu-f32-flush-ab.md) |
| Main menu | 2026-10-26 | Linux desktop | `49d1f9b07e` | f32 flush fix vs plain main (A4 B4 x2) | 73-77 -> 86-89 presents/10 s (+16%), GPU 125-131 -> 100-102 ms/frame; staging traffic (about 25 ms/frame) goes away with all written shadows off (93 presents; 110 with the fix too, +43% over plain main); #7618, isolated by a revert on 28 October | [run 7](../runs/2026-10-24-d2r-main-menu-f32-flush-ab.md) |
| Main menu | 2026-10-26 | Linux desktop | `49d1f9b07ec7` | float flush PR #11297, trace evidence (one boot each) | 76 -> 95 presents, GPU busy 128.4 -> 96.7 ms per present, GPU draw 90.6 -> 60.2 ms; validation layer clean | [run](../runs/2026-10-26-d2r-main-menu-11297-trace-evidence.md) |
| Main menu + town | 2026-10-28 | Linux desktop | `cc672fdfc6` | #7618 written-only staging vs revert (A B A B) | menu: revert faster (85.5-95 -> 109-112 presents/10 s); town: revert slower (73-84 -> 59), unnamed GPU time takes over | [run](../runs/2026-10-28-d2r-written-only-staging-revert-ab.md) |
| Main menu + town | 2026-10-28 | Linux desktop | `cc672fdfc6` | #7618 kept, swept shadow capped at 16 MiB (A C A C) | same as the revert: menu 89-93.5 -> 109-111 presents/10 s, town 82-89 -> 59-67; size cap ruled out | [run, cap section](../runs/2026-10-28-d2r-written-only-staging-revert-ab.md#follow-up-the-pr-kept-swept-shadow-capped-at-16-mib-desktop) |
| Main menu + town | 2026-10-28 | AMD mini PC (780M) | `cc672fdfc6` | #7618 written-only staging vs revert (A B A B) | no difference: 57 presents/10 s both arms, staging 0.9 GiB/10 s both; the change targets discrete GPUs | [run, AMD section](../runs/2026-10-28-d2r-written-only-staging-revert-ab.md#same-ab-on-the-amd-mini-pc-radeon-780m) |
| Main menu (+ town load) | 2026-10-28 | Windows laptop | `cc672fdfc6` | #7618 written-only staging vs revert (A B A B) | menu staging 47-70 -> about 5 ms/frame with the revert, but the menu is storage-upload bound (0.2-0.4 FPS, 7-8 s GPU per 10 s) so presents do not separate; town load stalls on Loading in both arms | [run, laptop section](../runs/2026-10-28-d2r-written-only-staging-revert-ab.md#same-ab-on-the-windows-laptop-rtx-a2000-laptop-partial) |
| Main menu | 2026-10-28 | Linux desktop | `cc672fdfc6` | indirect argument no-read probe (B P B P) | 88-90.5 -> 93.5-101 presents/10 s (+6-11%); the 3.4-3.7 s per 10 s stall is gone; GPU-bound again | [run 2](../runs/2026-10-24-d2r-main-menu-indirect-no-read-probe.md) |
| Main menu | 2026-10-24 | Linux desktop | `a19e7f6fd` | baseline, draw cache and pass traces | 88 presents/10 s, GPU-bound at 4K, draw cache 0.3% | [run](../runs/2026-10-24-d2r-main-menu-baseline.md) |
| Main menu | 2026-10-24 | Linux desktop | `a19e7f6fd` + #7814 VideoOut | 1080p video output | no change, still renders at 4K | [run](../runs/2026-10-24-d2r-main-menu-1080p.md) |
| Main menu | 2026-10-24 | Linux desktop | `a19e7f6fd` | skip indirect argument reads (probe) | stall 3.6 s -> 0, FPS unchanged (GPU-bound) | [run](../runs/2026-10-24-d2r-main-menu-indirect-no-read-probe.md) |
| Main menu | 2026-10-24 | AMD mini PC | `e4bb5fc125` | draw cache relocation correctness check (local patch, v1 to v3) | v1 and v2 fail the verifier; v3 (2026-10-25) passes, but the runs did not log checked relocated stages, so not proven | [run](../runs/2026-10-24-d2r-main-menu-amd-draw-cache-relocation-check.md) |

Baseline on the Linux desktop (main menu, current main): about 88 presents per 10 s, GPU-bound (98% load), about 106 ms GPU per frame, draw passes at 4K dominate, draw cache 0.3% hits.

AI-assisted. Tested by me on my own machine.
