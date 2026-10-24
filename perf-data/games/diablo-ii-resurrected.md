# Diablo II Resurrected (PPSA03912)

Upstream discussion: [D#5146](https://github.com/boykopovar/AnyPS5/discussions/5146).

## Phases and runs

| Phase | Date | Machine | Build | What | Headline | Page |
|---|---|---|---|---|---|---|
| Main menu | 2026-10-24 | Linux desktop | `a19e7f6fd`, `6d0139cd33` | f32 denormal flush A/B | 91 -> 115 presents/10 s, GPU 104 -> 74 ms/frame on RTX 3080 Ti; no change on Radeon 780M | [run](../runs/2026-10-24-d2r-main-menu-f32-flush-ab.md) |

Baseline on the Linux desktop (main menu, current main): about 88 presents per 10 s, GPU-bound (98% load), about 106 ms GPU per frame, draw passes at 4K dominate, draw cache 0.3% hits.

AI-assisted. Tested by me on my own machine.
