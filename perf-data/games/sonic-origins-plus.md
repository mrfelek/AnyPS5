# Sonic Origins Plus (PPSA05325)

Upstream discussion: [D#2021](https://github.com/boykopovar/AnyPS5/discussions/2021).

## Phases and runs

| Phase | Date | Machine | Build | What | Headline | Page |
|---|---|---|---|---|---|---|
| Sonic 2 menu page | 2026-10-25 | Linux desktop | `e4bb5fc125` + local prototypes | descriptor set reuse x draw cache relocation v3 (M R D RD x2) | no FPS change (135-150 presents/10 s); reuse cuts descriptor writes 41%; relocation v3 passes the verifier but fires about 150 times per 10 s | [run](../runs/2026-10-25-sonic-s2-menu-draw-set-reuse-relocation.md) |
| Sonic 2 menu page | 2026-10-26 | Linux desktop | `e4bb5fc125` + relocation v4 counters | why cached stages are passed over | about 600,000 per 10 s for a changed fixed word, few thousand for moved layout/data; 151.5 presents/10 s | [run](../runs/2026-10-26-sonic-s2-menu-draw-cache-pass-over.md) |
| Sonic 2 menu page | 2026-10-24/25 | Linux desktop | `e4bb5fc125` + #10668 | repeated-fill elision A/B (off/on x2) | GPU -3 to -4.6 ms/frame, presents unchanged (CPU-bound) | [run](../runs/2026-10-25-sonic-s2-menu-fill-elision-10668.md) |
| Sonic 2 menu page | 2026-10-24 | Linux desktop | `a19e7f6fd` | draw cache trace | 142 presents/10 s, CPU-bound on draw thread (18.4 us/draw), draw cache 3.5% hits | [run](../runs/2026-10-24-sonic-s2-menu-draw-cache.md) |
| Sonic 2 menu page | 2026-10-21 | Linux desktop | `572fe318c` | draw cache (older build) | 127-130 presents/10 s, draw path 8.1 s/10 s | [run](../runs/2026-10-21-sonic-s2-menu-old-build.md) |

AI-assisted. Tested by me on my own machine.
