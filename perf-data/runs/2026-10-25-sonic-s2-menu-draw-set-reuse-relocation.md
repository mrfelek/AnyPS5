# Sonic Origins Plus (PPSA05325), Sonic 2 menu page, descriptor set reuse x draw cache relocation v3

Question: do my two local prototypes, descriptor set reuse and draw cache relocation v3, cut the per-draw cost on this CPU-bound menu, alone or together?

- **Date / machine:** 2026-10-25, Linux desktop (RTX 3080 Ti). See [machines.md](../machines.md).
- **Build:** one build of upstream `e4bb5fc125` + [data-hit-relocation-v3.patch](../../research/patches/data-hit-relocation-v3.patch) + [draw-set-reuse.diff](../../research/patches/draw-set-reuse.diff) with the logging-only committer split timers. Neither is upstream.
- **Arms:** M = both off (`APS5_NO_DATA_HIT_RELOCATION=1 APS5_NO_VERTEX_FETCH_RELOCATION=1`); R = M + `APS5_DRAW_SET_REUSE=1`; D = relocation on; RD = relocation + reuse. Order M R D RD, twice.
- **Environment:** default profile set + `APS5_TMP_COMMITTER_SPLIT=1 APS5_TRACE_DRAW_CACHE=1`, headless, audio muted, memory cap.
- **Phase measured:** Sonic 2 menu page, medians of the last 12 windows (about +120..+240 s).

## Result

Neither prototype moves the frame rate here. Descriptor set reuse cuts descriptor writes per draw by 41% (7.65 -> about 4.5), but the cost per draw stays at 17.8-19.8 us on both the committer and the queue worker, and presents stay at 135-150 per 10 s. Relocation v3 passes the verifier (about 128,000-135,000 checked per 10 s, no mismatch) but triggers only 111-164 times per 10 s against about 600,000 stage compiles, so it has no visible effect on this scene.

| Arm | Presents/10 s | GPU ms/frame | GPU load % | Worker us/draw | Committer us/draw | Commits/10 s | Set alloc / update us | Descriptor writes/10 s (per draw) | Stages compiled / reused / relocated per 10 s |
|---|---|---|---|---|---|---|---|---|---|
| M1 | 148 | 44.1 | 68.3 | 18.2 | 17.8 | 453.0k | 0.38 / 0.66 | 3.47M (7.65) | 636k / 171k / 0 |
| R1 | 146.5 | 44.2 | 68.7 | 18.45 | 18.5 | 449.6k | 0.33 / 0.82 | 2.04M (4.53) | 641k / 160k / 0 |
| D1 | 144 | 44.1 | 66.8 | 18.95 | 18.5 | 440.9k | 0.34 / 0.64 | 3.36M (7.62) | 612k / 164k / 146.5 |
| RD1 | 150 | 44.3 | 70.0 | 18.05 | 18.05 | 457.9k | 0.31 / 0.85 | 2.13M (4.64) | 653k / 166k / 146.5 |
| M2 | 143 | 47.1 | 73.3 | 18.9 | 18.55 | 436.8k | 0.39 / 0.69 | 3.34M (7.66) | 623k / 162k / 0 |
| R2 | 135 | 48.3 | 71.7 | 20.2 | 19.8 | 415.4k | 0.33 / 0.88 | 1.89M (4.54) | 575k / 156k / 0 |
| D2 | 140.5 | 47.4 | 73.3 | 19.3 | 19.0 | 430.9k | 0.39 / 0.69 | 3.30M (7.65) | 593k / 158k / 163.5 |
| RD2 | 144.5 | 44.1 | 65.3 | 18.75 | 18.3 | 442.3k | 0.31 / 0.80 | 2.00M (4.52) | 646k / 153k / 111.5 |

- With reuse on, about 200,000 sets are reused and about 2.6 million buffer descriptor writes skipped per 10 s, but each set update gets slower (0.64-0.69 -> 0.80-0.88 us).
- The committer and queue worker 0 are both saturated at about 9.6-10.2 s of CPU per 10 s in every arm; the next busiest thread uses about 0.6 s.
- Per-draw breakdown, M1, one 10 s window: the draw worker spends 18.3 us per packet (recompile 4.4, capture 3.9, key/lookup/validate 2.6, lock wait 2.4, decode 1.9, vectors 1.2). The committer spends 18.1 us per commit; the largest parts are keep 1.96, revalidate 1.81, record commands 1.58, buffer snapshots 1.30 and pipeline lookup 1.03 us, while set allocate and update together are about 1.0 us. Almost every draw is a template hit (about 420,000 per 10 s at 17 us each). Phase totals per 10 s: record 1,982 ms, lookup 1,604 ms, keep 828 ms, vertex 815 ms.
- Verifier run (RD + `APS5_VERIFY_DRAW_DATA_HITS=1`, full window): no abort or mismatch.
- All 8 arms reached the Sonic 2 menu; no validation errors, terminates or device losses.

## Ruled out, and what to do instead

Both prototypes are ruled out as ways to speed up this menu. Descriptor writes are not what dominates the per-draw cost, and relocation hardly applies here. **Instead:** cut capture and recompile on the draw worker (8.3 of 18.3 us per packet, about 600,000 stage compiles per 10 s, roughly two per data-only hit), and on the committer the keep, revalidate and record steps of each template hit.

AI-assisted. Tested by me on my own machine.
