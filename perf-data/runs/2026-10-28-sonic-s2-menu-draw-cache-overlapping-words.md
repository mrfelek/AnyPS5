# Sonic Origins Plus (PPSA05325), Sonic 2 menu page, draw cache relocation v9 (overlapping moved words)

Question: [v8](2026-10-28-sonic-s2-menu-draw-cache-value-base-patch.md) stopped on one descriptor base patched by the wrong delta. Does v9, which also refuses bases shared with memory or with another word, pass the verifier?

- **Date / machine:** 2026-10-28, Linux desktop (RTX 3080 Ti). See [machines.md](../machines.md).
- **Build:** upstream `e4bb5fc125` + [data-hit-relocation-v9.patch](../../research/patches/data-hit-relocation-v9.patch). Not upstream. Clean build, warm-up boot finished normally.
- **Arm:** verifier first (`APS5_VERIFY_DRAW_DATA_HITS=1` and `APS5_TRACE_DRAW_CACHE=1`, checked in the process environment, no switches off). The speed arms (M D M D) were to follow only if it passed.

## Result: the verifier finds a mismatch, and now it shows why

At about +113 s, about 20 s into the Sonic 2 menu page (the same point as v7 and v8), the verifier stopped the game:

```
[gpu] driver failure: APS5_VERIFY_DRAW_DATA_HITS: stage 0 (program 0x205d6d900) of a data-only hit differs from its full build in its bindings (10 runs / 25 words kept, 10 / 25 fresh; first differing run 10: kept 0x0-0x0 from user word -1, fresh 0x0-0x0; variant 0x205 / 0x205; key 0x576e3e7132bd7246, shape 0xe497dea22b7273bd; binding 0 (role 0, slot 0, 12 / 12 dwords) dword 0: kept 0x4589284, fresh 0x45890e8; moved user word 4 0x4588f4c -> 0x45890e8, user word 8 0x45890e8 -> 0x4589284, user word 12 0x596fab8 -> 0x54f29fc, user word 14 0x596fcb8 -> 0x54f2bfc)
```

- The kept value 0x4589284 is user word 8's new value. The fresh value 0x45890e8 is user word 4's new value, and also user word 8's old value.
- So binding 0, dword 0, was rebuilt from user word 8 when it should have come from user word 4. Two moved words overlap (one word's new value is another word's old value), and matching a base to "the moved word it lies within 64 KiB above" picked the wrong owner.
- It is the same program (0x205d6d900) that stopped v7.
- The counters still read "0 reused, 0 of them relocated", with 10,920 and 13,918 verified stages marked "moved".
- The new v9 reason, "base shared with memory or another word", now holds back 20 of the first 32 passed-over samples (program 0x205f3b900, user word 0).

**Ruled out:** matching descriptor bases to moved words by address range alone. **Instead:** track which user word each base was built from when the stage is first compiled (provenance), and relocate by that owner, or refuse the stage when two moved words overlap. Then rerun the verifier before any speed test.

## The two draw cache lines before the stop, verbatim

```
[draw-cache] 10 s: 59890 lookups, 4630 hits (7.7%), 498 stage misses, 55009 without an entry, 54319 data-only hits (stages: 0 reused, 0 of them relocated, 108638 compiled; 42930 verified, 10920 of them moved; cached stages passed over: 23784 for a changed fixed word (23784 read as values, 23784 of them forwarded but held by a descriptor; 0 bases of stages that cannot relocate), 3182 for a moved layout, 39675 for moved data that differs); no entry: new registers 334, user words/pointers only 52919, evicted 292, seen but never inserted 1464; stage misses: front differing 399, fragment differing 99, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 638 (2.4 words changed each), other runs 257; 4096 entries, 1549 evicted
[draw-cache] 10 s: 110023 lookups, 7312 hits (6.6%), 283 stage misses, 103007 without an entry, 102141 data-only hits (stages: 0 reused, 0 of them relocated, 204282 compiled; 74004 verified, 13918 of them moved; cached stages passed over: 71482 for a changed fixed word (71481 read as values, 71481 of them forwarded but held by a descriptor; 1 bases of stages that cannot relocate), 8919 for a moved layout, 54431 for moved data that differs); no entry: new registers 276, user words/pointers only 101430, evicted 0, seen but never inserted 1301; stage misses: front differing 171, fragment differing 112, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 121 (1.3 words changed each), other runs 332; 4096 entries, 1503 evicted
```

## The 32 logged passed-over samples, summarized

- 20x stage 0, program 0x205f3b900: user word 0, read as value, forwarded yes, held by a descriptor yes, base shared with memory or another word (new in v9), relocatable words 0x50.
- 6x stage 1, program 0x205f3cb00: user word 0, read as value, forwarded yes, held by a descriptor yes, relocatable words 0x0.
- 6x stage 1, program 0x205d92200: user word 0 0x2168200 -> 0x2699300, read as value, forwarded yes, held by a descriptor yes, relocatable words 0x10000000.

AI-assisted. Tested by me on my own machine.
