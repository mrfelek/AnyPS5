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

None on this card: the GPU stays the limit. The stall would matter on a machine where the menu is CPU-bound (for example the AMD mini PC, where this menu is bound on queue worker 0).

AI-assisted. Tested by me on my own machine.
