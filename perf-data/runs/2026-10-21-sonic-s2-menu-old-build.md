# Sonic Origins Plus (PPSA05325), Sonic 2 menu page, draw cache on an older build

- **Date / machine:** 2026-10-21, Linux desktop (RTX 3080 Ti).
- **Build:** integration build on upstream `572fe318c` (2026-10-21).
- **Environment:** default profile set + draw cache trace, shader cache warm.
- **Phase measured:** last three steady 10 s windows on the Sonic 2 menu page.

## Result

127-130 presents per 10 s, CPU-bound on the draw path (about 8.1 s per 10 s). The GPU is idle about 32 ms of every frame. Draw cache hits are about 3%: setups are recognised, but per-draw user words and pointers change, so about 563-589k shader stages are captured and recompiled every 10 s. Newer run: [2026-10-24](2026-10-24-sonic-s2-menu-draw-cache.md).

| Metric | Value |
|---|---|
| Presents per 10 s | 127-130 |
| In-flight wait p50 / p90 | about 20.4 / 21.8 ms |
| GPU busy / idle per frame | 45.6-45.8 / 31.7-32.6 ms |
| GPU classes per frame | draw 22.8-23.5, copy 4.6, storage upload 4.2 (1326 MiB per present), fill 2.9 |
| Draw cache | 361-374k lookups, 2.8-3.1% hits, about 350k data-only hits, 291-299k user words/pointers only; the 4096-entry cache is full (12-17k evictions) |
| Stages reused / compiled per 10 s | about 137k / 563-589k |
| Draw cost per packet (us) | capture 4.2-4.4, recompile 6.3-6.6, vectors 1.4, key/lookup/validate 2.6-2.8, lock wait 3.4-3.9; total 21.6-22.4 |

No per-thread CPU, RAM or VRAM data: this run is older than the standard measurement set.

AI-assisted. Tested by me on my own machine.
