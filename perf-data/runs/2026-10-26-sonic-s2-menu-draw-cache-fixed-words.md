# Sonic Origins Plus (PPSA05325), Sonic 2 menu page, which fixed words block draw cache reuse

Question: the [pass-over run](2026-10-26-sonic-s2-menu-draw-cache-pass-over.md) showed about 600,000 cached stages per 10 s passed over "for a changed fixed word". Which words are they, and how do they change?

- **Date / machine:** 2026-10-26, Linux desktop (RTX 3080 Ti). See [machines.md](../machines.md).
- **Build:** upstream `e4bb5fc125` + [data-hit-relocation-v5.patch](../../research/patches/data-hit-relocation-v5.patch) (v4 plus a breakdown of the changed fixed words and up to 32 logged samples). Not upstream.
- **Arms:** one unmeasured warm-up boot, then one measured boot with relocation on.
- **Environment:** default profile set + `APS5_TRACE_DRAW_CACHE=1` + committer split timers + frame dumps, headless, audio muted, memory cap. No errors.
- **Phase measured:** Sonic 2 menu page, +120..+240 s. 145 presents per 10 s, frame p50 69.0 ms, GPU 44.0 ms per frame (draw 23.0, copy 4.5, storage upload 4.1, fill 2.9).

## Result

- 531,000-604,000 cached stages per 10 s are passed over for a changed fixed word; 154-159 are relocated.
- **Every one of them is a user word the shader reads as a value and that is forwarded**; none is the base of a stage that cannot relocate.
- Almost all samples are **user word 12** (a few are words 0, 8 and 16). They change in whole ring-block steps, for example 0x4c00040 -> 0x5600040 -> 0x4d00040 -> 0x5880040: the low bits stay, the high part moves. They look like the same buffer offsets moving with a ring buffer.
- One different case: program 0x205d92200, user word 0, 0x2168200 -> 0x2699300, a stage that does have relocatable words (0x10000000).

**Way to go:** these words are ring offsets the shader reads as plain values. Pass them to the shader as data (a uniform or push value) instead of baking them into the compiled stage, so a moved ring block reuses the cached stage. Treating them as moved pointers (relocation) does not cover them, because they are values, not bases.

## The two draw cache lines, verbatim

```
[draw-cache] 10 s: 414052 lookups, 13403 hits (3.2%), 122 stage misses, 400922 without an entry, 399927 data-only hits (stages: 157619 reused, 154 of them relocated, 642235 compiled; 0 verified; cached stages passed over: 604389 for a changed fixed word (604389 read as values, 604389 of them forwarded; 0 bases of stages that cannot relocate), 1950 for a moved layout, 36209 for moved data that differs); no entry: new registers 0, user words/pointers only 312888, evicted 60906, seen but never inserted 27128; stage misses: front differing 88, fragment differing 34, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 32 (1.2 words changed each), other runs 174; 4096 entries, 23653 evicted
[draw-cache] 10 s: 401714 lookups, 42705 hits (10.6%), 179 stage misses, 389597 without an entry, 358176 data-only hits (stages: 152361 reused, 159 of them relocated, 563991 compiled; 0 verified; cached stages passed over: 531506 for a changed fixed word (531506 read as values, 531506 of them forwarded; 0 bases of stages that cannot relocate), 2700 for a moved layout, 30975 for moved data that differs); no entry: new registers 0, user words/pointers only 318597, evicted 48187, seen but never inserted 22813; stage misses: front differing 143, fragment differing 36, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 65 (5.0 words changed each), other runs 256; 4096 entries, 21796 evicted
```

## All 32 logged samples (the cap was reached), verbatim

```
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5180020 -> 0x4c00020, read as value and base, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1d700): user word 12 0x5180060 -> 0x4c00060, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205c07000): user word 12 0x4d80000 -> 0x5580000, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205d92200): user word 0 0x2168200 -> 0x2699300, read as value, forwarded yes, relocatable words 0x10000000
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x4c00000 -> 0x5600000, read as value and base, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5180020 -> 0x5600020, read as value and base, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1d700): user word 12 0x4c00040 -> 0x5600040, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1d700): user word 12 0x5180060 -> 0x5600060, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1de00): user word 12 0x4c00080 -> 0x5600080, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205f0ab00): user word 12 0x4c00090 -> 0x5600090, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205f0e400): user word 8 0x4c000b0 -> 0x56000b0, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205f0fe00): user word 16 0x4c000c0 -> 0x56000c0, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 0 (program 0x205e26b00): user word 0 0x4c000e0 -> 0x56000e0, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205c00d00): user word 12 0x4c00110 -> 0x5600110, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205c07000): user word 12 0x4d80000 -> 0x4f80000, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205d92200): user word 0 0x2168200 -> 0x2699300, read as value, forwarded yes, relocatable words 0x10000000
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x4c00000 -> 0x4d00000, read as value and base, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5180020 -> 0x4d00020, read as value and base, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1d700): user word 12 0x4c00040 -> 0x4d00040, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1d700): user word 12 0x5180060 -> 0x4d00060, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1de00): user word 12 0x4c00080 -> 0x4d00080, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205f0ab00): user word 12 0x4c00090 -> 0x4d00090, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205f0e400): user word 8 0x4c000b0 -> 0x4d000b0, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205f0fe00): user word 16 0x4c000c0 -> 0x4d000c0, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 0 (program 0x205e26b00): user word 0 0x4c000e0 -> 0x4d000e0, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205c00d00): user word 12 0x4c00110 -> 0x4d00110, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205c07000): user word 12 0x4d80000 -> 0x5180000, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205d92200): user word 0 0x2168200 -> 0x2699300, read as value, forwarded yes, relocatable words 0x10000000
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x4c00000 -> 0x5880000, read as value and base, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5180020 -> 0x5880020, read as value and base, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1d700): user word 12 0x4c00040 -> 0x5880040, read as value, forwarded yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1d700): user word 12 0x5180060 -> 0x5880060, read as value, forwarded yes, relocatable words 0x0
```

AI-assisted. Tested by me on my own machine.
