# Sonic Origins Plus (PPSA05325), Sonic 2 menu page, draw cache relocation v6 (forwarded values)

Question: the [fixed-word run](2026-10-26-sonic-s2-menu-draw-cache-fixed-words.md) showed the blocking words are user words read as values and forwarded. Does patching forwarded values (v6) let those cached stages be reused?

- **Date / machine:** 2026-10-28, Linux desktop (RTX 3080 Ti). See [machines.md](../machines.md).
- **Build:** upstream `e4bb5fc125` + [data-hit-relocation-v6.patch](../../research/patches/data-hit-relocation-v6.patch). Not upstream.
- **Arms:** M = relocation off (`APS5_NO_DATA_HIT_RELOCATION=1 APS5_NO_VERTEX_FETCH_RELOCATION=1 APS5_NO_DATA_HIT_FORWARDED_PATCH=1`); D = all on. Order M D M D, plus one verifier arm (`APS5_VERIFY_DRAW_DATA_HITS=1`, checked in the process environment).
- **Environment:** default profile set + draw cache trace, headless, audio muted, memory cap; medians of 12 windows over +120..+240 s.

## Result

**Verifier passed:** no abort, no errors, about 135,000 verified per 10 s.

**D = M within noise.** v6 relocates only 85-146 stages per 10 s out of about 155,000 reused. The 550,000-580,000 stages passed over per 10 s are "forwarded but held by a descriptor": the forwarded word ends up inside a buffer descriptor, a case v6 deliberately leaves out.

| Arm | Presents/10 s | Frame p50 ms | GPU ms/frame | Committer us/draw | Worker us/draw | Errors |
|---|---|---|---|---|---|---|
| m1 | 143.5 (139-147) | 69.8 | 47.1 | 17.4 | 18.9 | 0 |
| d1 | 138.0 (134-140) | 72.5 | 47.0 | 17.8 | 19.6 | 0 |
| m2 | 136.5 (133-140) | 73.3 | 47.9 | 18.1 | 20.1 | 0 |
| d2 | 141.5 (139-143) | 71.1 | 44.0 | 17.4 | 19.4 | 0 |

Top GPU classes in every arm: draw about 23 ms, copy about 4.8, storage upload 4.1-5.1, fill about 3.

**Ruled out:** patching forwarded values alone. **Instead:** patch the base of the buffer descriptor that holds the forwarded word (v7, next run).

## The draw cache lines, two per arm, verbatim
m1:
```
[draw-cache] 10 s: 406543 lookups, 15333 hits (3.8%), 208 stage misses, 391023 without an entry, 390461 data-only hits (stages: 154924 reused, 0 of them relocated, 625996 compiled; 0 verified; cached stages passed over: 627544 for a changed fixed word (597632 read as values, 597632 of them forwarded but held by a descriptor; 28988 bases of stages that cannot relocate), 0 for a moved layout, 0 for moved data that differs); no entry: new registers 0, user words/pointers only 331616, evicted 25417, seen but never inserted 33990; stage misses: front differing 164, fragment differing 44, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 105 (5.9 words changed each), other runs 264; 4096 entries, 22860 evicted
[draw-cache] 10 s: 402237 lookups, 12847 hits (3.2%), 139 stage misses, 389275 without an entry, 388681 data-only hits (stages: 158103 reused, 0 of them relocated, 619259 compiled; 0 verified; cached stages passed over: 619895 for a changed fixed word (587779 read as values, 587779 of them forwarded but held by a descriptor; 31126 bases of stages that cannot relocate), 0 for a moved layout, 0 for moved data that differs); no entry: new registers 0, user words/pointers only 311727, evicted 50119, seen but never inserted 27429; stage misses: front differing 112, fragment differing 27, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 80 (7.2 words changed each), other runs 168; 4096 entries, 26034 evicted
```
d1:
```
[draw-cache] 10 s: 394936 lookups, 14127 hits (3.6%), 266 stage misses, 380733 without an entry, 379974 data-only hits (stages: 154247 reused, 137 of them relocated, 605701 compiled; 0 verified; cached stages passed over: 566650 for a changed fixed word (566650 read as values, 566650 of them forwarded but held by a descriptor; 0 bases of stages that cannot relocate), 3739 for a moved layout, 37164 for moved data that differs); no entry: new registers 0, user words/pointers only 316108, evicted 32400, seen but never inserted 32225; stage misses: front differing 212, fragment differing 54, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 69 (4.4 words changed each), other runs 402; 4096 entries, 24851 evicted
[draw-cache] 10 s: 398939 lookups, 22018 hits (5.5%), 161 stage misses, 376912 without an entry, 376001 data-only hits (stages: 159424 reused, 146 of them relocated, 592578 compiled; 0 verified; cached stages passed over: 551400 for a changed fixed word (551400 read as values, 551400 of them forwarded but held by a descriptor; 0 bases of stages that cannot relocate), 2352 for a moved layout, 39631 for moved data that differs); no entry: new registers 0, user words/pointers only 282201, evicted 66431, seen but never inserted 28280; stage misses: front differing 126, fragment differing 35, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 32 (1.0 words changed each), other runs 252; 4096 entries, 30002 evicted
```
m2:
```
[draw-cache] 10 s: 389036 lookups, 9994 hits (2.6%), 176 stage misses, 378894 without an entry, 378428 data-only hits (stages: 148160 reused, 0 of them relocated, 608696 compiled; 0 verified; cached stages passed over: 609946 for a changed fixed word (576973 read as values, 576973 of them forwarded but held by a descriptor; 32150 bases of stages that cannot relocate), 0 for a moved layout, 0 for moved data that differs); no entry: new registers 0, user words/pointers only 312665, evicted 45948, seen but never inserted 20281; stage misses: front differing 133, fragment differing 43, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 42 (1.2 words changed each), other runs 264; 4096 entries, 17675 evicted
[draw-cache] 10 s: 397820 lookups, 12232 hits (3.1%), 177 stage misses, 385441 without an entry, 384918 data-only hits (stages: 148619 reused, 0 of them relocated, 621217 compiled; 0 verified; cached stages passed over: 623215 for a changed fixed word (588014 read as values, 588014 of them forwarded but held by a descriptor; 34332 bases of stages that cannot relocate), 0 for a moved layout, 0 for moved data that differs); no entry: new registers 0, user words/pointers only 338220, evicted 17579, seen but never inserted 29642; stage misses: front differing 149, fragment differing 28, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 50 (5.1 words changed each), other runs 274; 4096 entries, 17201 evicted
```
d2:
```
[draw-cache] 10 s: 406060 lookups, 16170 hits (4.0%), 194 stage misses, 389837 without an entry, 389089 data-only hits (stages: 156835 reused, 85 of them relocated, 621343 compiled; 0 verified; cached stages passed over: 583547 for a changed fixed word (583547 read as values, 583547 of them forwarded but held by a descriptor; 0 bases of stages that cannot relocate), 2378 for a moved layout, 36963 for moved data that differs); no entry: new registers 0, user words/pointers only 331325, evicted 21594, seen but never inserted 36918; stage misses: front differing 148, fragment differing 46, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 43 (1.0 words changed each), other runs 296; 4096 entries, 23042 evicted
[draw-cache] 10 s: 406021 lookups, 14451 hits (3.6%), 132 stage misses, 391760 without an entry, 390856 data-only hits (stages: 157764 reused, 125 of them relocated, 623948 compiled; 0 verified; cached stages passed over: 582091 for a changed fixed word (582091 read as values, 582091 of them forwarded but held by a descriptor; 0 bases of stages that cannot relocate), 2694 for a moved layout, 39723 for moved data that differs); no entry: new registers 0, user words/pointers only 323982, evicted 40862, seen but never inserted 26916; stage misses: front differing 94, fragment differing 38, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 35 (1.0 words changed each), other runs 188; 4096 entries, 25203 evicted
```

AI-assisted. Tested by me on my own machine.
