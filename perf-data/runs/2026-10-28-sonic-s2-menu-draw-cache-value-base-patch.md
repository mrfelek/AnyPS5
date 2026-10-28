# Sonic Origins Plus (PPSA05325), Sonic 2 menu page, draw cache relocation v8 (value-and-base words)

Question: [v7](2026-10-28-sonic-s2-menu-draw-cache-buffer-base-patch.md) stopped on a binding that comes from no user word. Does v8, which also relocates words that are read both as a value and as a descriptor base, pass the verifier?

- **Date / machine:** 2026-10-28, Linux desktop (RTX 3080 Ti). See [machines.md](../machines.md).
- **Build:** upstream `e4bb5fc125` + [data-hit-relocation-v8.patch](../../research/patches/data-hit-relocation-v8.patch). Not upstream. Clean build, warm-up boot finished normally.
- **Arm:** verifier first (`APS5_VERIFY_DRAW_DATA_HITS=1` and `APS5_TRACE_DRAW_CACHE=1`, checked in the process environment, no switches off). The speed arms (M D M D) were to follow only if it passed.

## Result: the verifier finds a mismatch, so v8 is not safe yet

At about +116 s, about 20 s after reaching the Sonic 2 menu page (the same point as v7), the verifier stopped the game:

```
[videoout] presentation failed: APS5_VERIFY_DRAW_DATA_HITS: stage 0 (program 0x205bb6700) of a data-only hit differs from its full build in its bindings (22 runs / 55 words kept, 22 / 55 fresh; first differing run 22: kept 0x0-0x0 from user word -1, fresh 0x0-0x0; variant 0xd7 / 0xd7; key 0x6a1cd1059a24f12, shape 0x65275f667e3a3894; binding 0 (role 0, slot 0, 16 / 16 dwords) dword 0: kept 0x488134c, fresh 0x4881014)
terminate called after throwing an instance of 'std::runtime_error'
```

- This time the message names the word: binding 0 (role 0, slot 0), dword 0, is 0x488134c in the kept build and 0x4881014 in a fresh one. That is a descriptor base 0x338 bytes off, so a base was patched by the wrong delta, or patched when it should not have been.
- The counters read "0 reused, 0 of them relocated", yet 14,248 and 21,407 of the verified stages are marked "moved", so the verifier does check stages that v8 moved even though the reuse counter shows none.
- The user word 12 samples ("read as value and base") from v7 are gone from the passed-over list, so v8 now takes those stages. The words still passed over are user word 0 of three programs, all "read as value, forwarded, held by a descriptor", relocatable words 0x0.
- The menu looked normal in the screenshot at +98 s. The speed arms did not run, and the draw replay R2 test that builds on this waits.

**Ruled out for now:** v8 as written. **Next:** find which base gets the 0x338 delta (the one binding named above) and fix the delta, then rerun the verifier before any speed test.

## The two draw cache lines before the stop, verbatim

```
[draw-cache] 10 s: 56253 lookups, 4480 hits (8.0%), 524 stage misses, 51360 without an entry, 50815 data-only hits (stages: 0 reused, 0 of them relocated, 101628 compiled; 44091 verified, 14248 of them moved; cached stages passed over: 14583 for a changed fixed word (14583 read as values, 14583 of them forwarded but held by a descriptor; 0 bases of stages that cannot relocate), 3640 for a moved layout, 41264 for moved data that differs); no entry: new registers 326, user words/pointers only 49498, evicted 241, seen but never inserted 1295; stage misses: front differing 413, fragment differing 111, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 621 (2.6 words changed each), other runs 313; 4096 entries, 1536 evicted
[draw-cache] 10 s: 100896 lookups, 6321 hits (6.3%), 272 stage misses, 94620 without an entry, 94036 data-only hits (stages: 0 reused, 0 of them relocated, 188072 compiled; 76636 verified, 21407 of them moved; cached stages passed over: 31539 for a changed fixed word (31539 read as values, 31539 of them forwarded but held by a descriptor; 0 bases of stages that cannot relocate), 8611 for a moved layout, 73838 for moved data that differs); no entry: new registers 257, user words/pointers only 93215, evicted 0, seen but never inserted 1148; stage misses: front differing 153, fragment differing 119, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 136 (1.7 words changed each), other runs 284; 4096 entries, 1320 evicted
```

## The 32 logged passed-over samples, summarized

- 5x program 0x205d92200, stage 1: `user word 0 0x2168200 -> 0x2699300, read as value, forwarded yes, held by a descriptor yes, relocatable words 0x10000000`
- 24x program 0x205f3cb00: `user word 0 0x26a1d00 -> 0x285a800` (22x) and `0x285a800 -> 0x26a1d00` (1x), all "read as value, forwarded yes, held by a descriptor yes, relocatable words 0x0".
- 2x program 0x205f3cb00: `user word 0 0x285a800 -> 0x2862700`, same flags.
- 1x program 0x205c49b00: `user word 0 0x289c300 -> 0x28a9200`, same flags.

AI-assisted. Tested by me on my own machine.
