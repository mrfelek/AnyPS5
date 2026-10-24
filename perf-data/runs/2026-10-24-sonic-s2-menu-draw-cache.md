# Sonic Origins Plus (PPSA05325), Sonic 2 menu page, draw cache

- **Date / machine:** 2026-10-24, Linux desktop (RTX 3080 Ti). See [machines.md](../machines.md).
- **Build:** upstream `a19e7f6fd` + logging-only diagnostics (draw cache trace, changed-words dump; not upstream).
- **Environment:** default profile set + `APS5_TRACE_DRAW_CACHE=1`, shader cache warm (1302 hits / 2 misses), audio muted.
- **Phase measured:** Sonic 2 menu page, +120..+240 s.

## Result

The menu is CPU-bound on the draw thread: about 42,000 draws per second at 18.4 us each, which is 7.7 s of every 10 s. The draw cache hits only 3.5%, because almost every draw differs from a cached one only in per-draw buffer pointers (a streaming vertex/constant ring offset that grows by a fixed step each draw). Treating those pointers as data instead of part of the cache key is the lever.

## Standard set

| Metric | Value |
|---|---|
| Presents per 10 s | 142 (136-147) |
| Frame p50 | 70.4 ms |
| GPU per frame | 48.3 ms; storage upload 5.2, copy 4.9, fill 3.0, label-run 0.9 |
| In-flight wait p50 | 23.4 ms |
| Draw cache hits / dispatch cache equal | 3.5% / 71.4% |
| Uploads / write-backs per 10 s | 188260 / 27 MiB; staging 4.3 MiB |
| Shader disk cache | 1302 hits / 2 misses |
| Hook syncs per 10 s | 2, 0 ms |
| RAM | anon 1.0, shmem 3.7, file 1.2 GB |
| VRAM / GPU load | 6.9 GB / 75.3% |
| CPU (emulator threads) | 25.6 s per 10 s |

## Draw cost per packet (us)

precheck 0.9, decode 2.1, capture 4.1, recompile 4.6, vectors 1.1, key/lookup/validate 2.5, lock wait 2.2, epilogue 0.4; total 18.4.

## Draw cache, one 10 s window

420,705 lookups, 15,778 hits (3.8%). 404,949 lookups have no entry, of which 404,283 differ only in data; 337,443 of those differ only in user words or pointers. 650,330 shader stages compiled vs 158,236 reused in that window.

Changed words: the same 6-draw cycle repeats; one stage-1 word grows by about 0x338 per repeat and one stage-5 word drops by 48, the rest repeat exactly.

## Older run for comparison

2026-10-21 integration build: 128-130 presents per 10 s, draw cache about 3% hits, GPU 45.7 ms busy + 32 ms idle per frame (CPU-bound).

AI-assisted. Tested by me on my own machine.
