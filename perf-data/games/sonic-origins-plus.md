# Sonic Origins Plus (PPSA05325)

Upstream discussion: [D#2021](https://github.com/boykopovar/AnyPS5/discussions/2021).

## Phases and runs

| Phase | Date | Machine | Build | What | Headline | Page |
|---|---|---|---|---|---|---|
| Sonic 2 menu page | 2026-10-25 | Linux desktop | `e4bb5fc125` + local prototypes | descriptor set reuse x draw cache relocation v3 (M R D RD x2) | no FPS change (135-150 presents/10 s); reuse cuts descriptor writes 41%; relocation v3 passes the verifier but fires about 150 times per 10 s | [run](../runs/2026-10-25-sonic-s2-menu-draw-set-reuse-relocation.md) |
| Sonic 2 menu page | 2026-10-26 | Linux desktop | `e4bb5fc125` + relocation v4 counters | why cached stages are passed over | about 600,000 per 10 s for a changed fixed word, few thousand for moved layout/data; 151.5 presents/10 s | [run](../runs/2026-10-26-sonic-s2-menu-draw-cache-pass-over.md) |
| Sonic 2 menu page | 2026-10-26 | Linux desktop | `e4bb5fc125` + relocation v5 counters | which fixed words block reuse | user word 12 (also 0, 8, 16), read as values, moving in ring-block steps; 145 presents/10 s | [run](../runs/2026-10-26-sonic-s2-menu-draw-cache-fixed-words.md) |
| Sonic 2 menu page | 2026-10-28 | Linux desktop | `e4bb5fc125` + relocation v6 | forwarded-value patch (M D x2 + verifier) | no change (136.5-143.5 presents/10 s); verifier passes; the words sit in buffer descriptors, so v6 relocates only 85-146 stages per 10 s | [run](../runs/2026-10-28-sonic-s2-menu-draw-cache-forwarded-patch.md) |
| Sonic 2 menu page | 2026-10-28 | Linux desktop | `e4bb5fc125` + relocation v7 | buffer-descriptor base patch, verifier | verifier finds a binding mismatch at about +118 s; speed arms cancelled | [run](../runs/2026-10-28-sonic-s2-menu-draw-cache-buffer-base-patch.md) |
| Sonic 2 menu page | 2026-10-28 | Linux desktop | `e4bb5fc125` + relocation v8 | value-and-base word patch, verifier | verifier finds a descriptor base 0x338 bytes off at about +116 s; speed arms not run | [run](../runs/2026-10-28-sonic-s2-menu-draw-cache-value-base-patch.md) |
| Sonic 2 menu page | 2026-10-28 | Linux desktop | `e4bb5fc125` + relocation v9 | shared-base refusal, verifier | verifier stops at about +113 s: two moved user words overlap and the range match picks the wrong owner; speed arms not run | [run](../runs/2026-10-28-sonic-s2-menu-draw-cache-overlapping-words.md) |
| Sonic 2 menu page | 2026-10-28 | Linux desktop | `cc672fdfc6` | #7618 written-only staging vs revert (B A B A) | no effect: 160-162 vs 161-165 presents/10 s, staging about 5 MiB/10 s in both, no swept shadows | [run, Sonic section](../runs/2026-10-28-d2r-written-only-staging-revert-ab.md#other-title-sonic-origins-plus-sonic-2-menu-desktop) |
| Sonic 2 menu page | 2026-10-24/25 | Linux desktop | `e4bb5fc125` + #10668 | repeated-fill elision A/B (off/on x2) | GPU -3 to -4.6 ms/frame, presents unchanged (CPU-bound) | [run](../runs/2026-10-25-sonic-s2-menu-fill-elision-10668.md) |
| Sonic 2 menu page | 2026-10-24 | Linux desktop | `a19e7f6fd` | draw cache trace | 142 presents/10 s, CPU-bound on draw thread (18.4 us/draw), draw cache 3.5% hits | [run](../runs/2026-10-24-sonic-s2-menu-draw-cache.md) |
| Sonic 2 menu page | 2026-10-21 | Linux desktop | `572fe318c` | draw cache (older build) | 127-130 presents/10 s, draw path 8.1 s/10 s | [run](../runs/2026-10-21-sonic-s2-menu-old-build.md) |

AI-assisted. Tested by me on my own machine.
