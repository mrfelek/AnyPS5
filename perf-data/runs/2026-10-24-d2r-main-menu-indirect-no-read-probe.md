# Diablo II Resurrected (PPSA03912), main menu, indirect draw argument read probe

Question: the CPU waits 3.6 s per 10 s reading indirect draw arguments back from the GPU. What happens if that read is skipped?

- **Date / machine:** 2026-10-24, Linux desktop (RTX 3080 Ti).
- **Build:** upstream `a19e7f6fd` + a local test probe (not upstream): `APS5_PROBE_INDIRECT_NO_READ=1` skips the CPU read of indirect draw arguments.
- **Environment:** default profile set, shader cache warm, audio muted.
- **Phase measured:** settled main menu, +180 s to the stop. Order: P1 (probe), B2 (base), P2 (probe).

## Result

The probe removes the argument-read stall completely (3.6 s -> 0 per 10 s), but FPS does not move. The menu is GPU-bound at 4K, so the time the CPU saves just turns into a longer in-flight wait (57 -> 90-97 ms) and into other GPU-label waits. Packet drain time more than doubles with the probe. Picture unchanged.

| Metric | P1 (probe) | B2 (base) | P2 (probe) |
|---|---|---|---|
| Presents per 10 s | 88 (88-89) | 88 (87-93) | 84.5 (82-86) |
| Frame p50 | 113.7 ms | 113.9 ms | 119.2 ms |
| GPU per frame | 104.1 ms | 105.8 ms | 107.1 ms |
| GPU busy / idle per frame | 107.8 / 5.7-6.0 ms | 111.5 / 2.3-2.7 ms | 113.5-114.8 / 5.9-6.4 ms |
| Small GPU classes per frame | fill 3.4, upload 2.9, fill-clear 0.9 | fill 3.9, upload 3.5, fill-clear 1.1 | fill 4.1, upload 3.7, fill-clear 1.1 |
| GPU load | 96.0% | 98.2% | 96.4% |
| In-flight wait p50 (p90) | 90.3 (108) ms | 57.3 (60) ms | 96.7 (110-114) ms |
| Hook syncs per 10 s | 31-35, 2.6-3.0 s, all on GPU labels | 88, 3.6 s, all on indirect arguments | 36-39, 3.3-3.6 s, all on GPU labels |
| Indirect argument reads | 0 ms | 3585 / 3663 / 3583 ms | 0 ms |
| Committed draws, drains | 142-144k at 42-44 us; drains 602-704 ms | 143k at 39 us; drains 252-263 ms | 134-135k at 40-41 us; drains 394-542 ms |
| Draw cache hits / dispatch cache equal | 0.3% / 56.3% | 0.3% / 56.5% | 0.3% / 55.5% |
| CPU, top threads (ms per 10 s) | 6197 / 5798 / main 1172 | 6060 / 5859 / main 1167 | 5895 / 5560 / main 1085 |
| RAM | anon about 1.05, shmem 6.9-7.0 GB (all) | | |
| VRAM | 7.4-7.6 GB (all) | | |

## Which bottleneck moved

On the 24 October build, none on this card: the GPU stays the limit (Run 2 below shows that changes once the float fix is in). The stall would matter on a machine where the menu is CPU-bound (for example the AMD mini PC, where this menu is bound on queue worker 0).


## Run 2 (2026-10-28): same probe on a newer main with the float fix

On the 24 October build the GPU was the limit, so removing the stall did nothing. Since then the float flush fix (#11297) is in main and cuts about 27 ms of draw time per frame, so the probe was repeated.

- **Build:** upstream main `cc672fdfc6` (contains the float fix) + [indirect-no-read-probe-v2.diff](../../research/patches/indirect-no-read-probe-v2.diff) (the same probe rebased). B = probe off; P = `APS5_PROBE_INDIRECT_NO_READ=1`. Order B P B P, medians over +180..+360 s, no errors.
- **The stall is gone with the probe:** argument reads and the indirect-draw hook-sync waits drop from 3.4-3.7 s per 10 s to 0.
- **Now it pays:** presents 88 / 90.5 -> 93.5 / 101 per 10 s (+6-11%), frame p50 114 / 111 -> 107 / 100 ms. GPU time per frame barely moves (about 97-100 vs 95-100 ms) while GPU load rises to about 99%, so the GPU is the limit again (in-flight wait doubles to about 73 ms).
- **Only one indirect draw is involved:** program 0x2b5167e00, arguments at 0x2b5164800, count 1, about once per frame. That single read waits on GPU writes still in flight and costs about 3.7 s per 10 s.
- **Side effects with the probe:** pipelined packet drains take longer (525-595 vs 215-225 ms per 10 s), and the remaining hook-sync waits (about 2 s per 10 s) move to other sites.
- **Picture:** main-menu pixels differing by more than 24: B1/P1 2.32%, B2/P2 1.03%, B1/B2 2.02%, so the difference is within the run-to-run noise of the animated menu.

| run | presents/10 s (range) | frame p50 ms | inflight p50 / p90 ms | GPU ms/frame | top classes ms/frame | SM % | hooksync syncs / ms (DRAW_INDIRECT ms) | argument reads ms | packet drains (ms) | CPU ms/10 s app.elf / [vkrt]_Analysis / SDLAudio | peak MiB | VRAM MiB | probe lines |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| B1 | 88.0 (87-89) | 113.8 | 38.1 / 39.5 | 100.4 | draw 63.0, staging-out 14.1, staging-in 11.0, fill 4.0 | 94.2 | 134 / 3729 (3727) | 3739.9 | 1855 (215) | 17962 / 704 / 73 | 11374 | 9746 | 0 |
| P1 | 93.5 (91-95) | 107.2 | 72.5 / 105.3 | 100.0 | draw 62.5, staging-out 14.4, staging-in 10.9, fill 4.2 | 99.5 | 25 / 2144 (0) | 0.0 | 2091 (595.2) | 20223 / 502 / 79 | 11223 | 9952 | 6 |
| B2 | 90.5 (84-95) | 110.8 | 35.1 / 43.3 | 96.8 | draw 62.5, staging-out 12.8, staging-in 10.3, fill 3.9 | 92.6 | 135 / 3472.5 (3440) | 3427.4 | 1977 (225.0) | 18511 / 384 / 78 | 11165 | 10933 | 0 |
| P2 | 101.0 (99-101) | 99.8 | 72.6 / 98.1 | 95.0 | draw 62.5, staging-out 12.7, staging-in 10.0, fill 3.3 | 99.0 | 25 / 1952.5 (0) | 0.0 | 2178.5 (524.7) | 20834 / 944 / 70 | 11192 | 9582 | 6 |

The probe log, verbatim:

```
[probe] indirect no-read skip 1: program 0x2b5167e00 args 0x2b5164800 count 1
[probe] indirect no-read skip 2: program 0x2b5167e00 args 0x2b5164800 count 1
[probe] indirect no-read skip 3: program 0x2b5167e00 args 0x2b5164800 count 1
[probe] indirect no-read skip 4: program 0x2b5167e00 args 0x2b5164800 count 1
[probe] indirect no-read skip 1000: program 0x2b5167e00 args 0x2b5164800 count 1
[probe] indirect no-read skip 2000: program 0x2b5167e00 args 0x2b5164800 count 1
```

**This is a probe, not a fix:** skipping the read is only safe if the CPU never needs the arguments. **Way to go:** defer or avoid that one read (for example run this draw on the GPU path or read the arguments after the GPU has written them) without dropping the draw. Together with the float fix it is worth about +6-11% on this menu.

AI-assisted. Tested by me on my own machine.
