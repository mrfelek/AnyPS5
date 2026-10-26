# Diablo II Resurrected (PPSA03912)

Upstream discussion: [D#5146](https://github.com/boykopovar/AnyPS5/discussions/5146).

## Phases and runs

| Phase | Date | Machine | Build | What | Headline | Page |
|---|---|---|---|---|---|---|
| Character select | 2026-10-25 | AMD mini PC | `e4bb5fc125` | committer split timers, descriptor set reuse A/B (local patch) | 53 presents/10 s either way; reuse cuts descriptor writes 30%, cost per draw unchanged (about 46 us) | [run](../runs/2026-10-25-d2r-character-select-amd-draw-set-reuse.md) |
| Main menu | 2026-10-24 | Linux desktop | `a19e7f6fd`, `6d0139cd33` | f32 denormal flush A/B | 91 -> 115 presents/10 s, GPU 104 -> 74 ms/frame on RTX 3080 Ti; no change on Radeon 780M | [run](../runs/2026-10-24-d2r-main-menu-f32-flush-ab.md) |
| Main menu | 2026-10-26 | Linux desktop | `49d1f9b07e` | f32 flush fix rebased | Fix still works (draw 62 ms/frame); new staging traffic on this main (26 ms/frame) gives 86 presents/10 s; plain-main arm not run yet | [run 6](../runs/2026-10-24-d2r-main-menu-f32-flush-ab.md) |
| Main menu | 2026-10-26 | Linux desktop | `49d1f9b07e` | f32 flush fix vs plain main (A4 B4 x2) | 73-77 -> 86-89 presents/10 s (+16%), GPU 125-131 -> 100-102 ms/frame; staging traffic (about 25 ms/frame) is on plain main too | [run 7](../runs/2026-10-24-d2r-main-menu-f32-flush-ab.md) |
| Main menu | 2026-10-24 | Linux desktop | `a19e7f6fd` | baseline, draw cache and pass traces | 88 presents/10 s, GPU-bound at 4K, draw cache 0.3% | [run](../runs/2026-10-24-d2r-main-menu-baseline.md) |
| Main menu | 2026-10-24 | Linux desktop | `a19e7f6fd` + #7814 VideoOut | 1080p video output | no change, still renders at 4K | [run](../runs/2026-10-24-d2r-main-menu-1080p.md) |
| Main menu | 2026-10-24 | Linux desktop | `a19e7f6fd` | skip indirect argument reads (probe) | stall 3.6 s -> 0, FPS unchanged (GPU-bound) | [run](../runs/2026-10-24-d2r-main-menu-indirect-no-read-probe.md) |
| Main menu | 2026-10-24 | AMD mini PC | `e4bb5fc125` | draw cache relocation correctness check (local patch, v1 to v3) | v1 and v2 fail the verifier; v3 (2026-10-25) passes, but the runs did not log checked relocated stages, so not proven | [run](../runs/2026-10-24-d2r-main-menu-amd-draw-cache-relocation-check.md) |

Baseline on the Linux desktop (main menu, current main): about 88 presents per 10 s, GPU-bound (98% load), about 106 ms GPU per frame, draw passes at 4K dominate, draw cache 0.3% hits.

AI-assisted. Tested by me on my own machine.
