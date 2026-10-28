# Sonic Origins Plus (PPSA05325), Sonic 2 menu page, draw cache relocation v7 (buffer descriptor base)

Question: the [v6 run](2026-10-28-sonic-s2-menu-draw-cache-forwarded-patch.md) showed the moving words sit inside buffer descriptors. Is it safe to patch the descriptor base so those cached stages can be reused (v7)?

- **Date / machine:** 2026-10-28, Linux desktop (RTX 3080 Ti). See [machines.md](../machines.md).
- **Build:** upstream `e4bb5fc125` + [data-hit-relocation-v7.patch](../../research/patches/data-hit-relocation-v7.patch). Not upstream.
- **Arm:** verifier first (`APS5_VERIFY_DRAW_DATA_HITS=1`, checked in the process environment, no switches off), after a warm-up boot. The speed arms (M D M D) were to follow only if it passed.

## Result: the verifier finds a mismatch, so v7 is not safe yet

About 20 s after reaching the Sonic 2 menu page (about +118 s), before the measurement window, the verifier stopped the game:

```
[videoout] presentation failed: APS5_VERIFY_DRAW_DATA_HITS: stage 0 (program 0x205d6d900) of a data-only hit differs from its full build in its bindings (10 runs / 25 words kept, 10 / 25 fresh; first differing run 10: kept 0x0-0x0 from user word -1, fresh 0x0-0x0; variant 0x205 / 0x205; key 0x63d3c0c609aaa430, shape 0x7c179aefbeeff171)
terminate called after throwing an instance of 'std::runtime_error'
```

- The mismatch is in stage 0 of program 0x205d6d900, binding run 10: the kept build has a binding "from user word -1" where the fresh build has an empty range. It looks like the base patch keeps or rewrites a binding the full build does not have.
- Before the stop, v7 had relocated nothing: the last two draw cache lines show 42,349 and 73,338 verified, and stages passed over for a changed fixed word (17,038 / 38,193), a moved layout (3,242 / 6,603) and moved data that differs (40,501 / 76,048). Every passed-over sample is still "held by a descriptor".
- The menu looked normal in the screenshot at +98 s.
- The speed arms were cancelled, and the draw replay R2 test that builds on v7 waits for a corrected v7.

**Ruled out for now:** v7 as written. **Next:** fix how v7 handles a binding that comes from no user word, then rerun the verifier before any speed test.

## The 32 logged passed-over samples, verbatim

```
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5100020 -> 0x4c00020, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205d92200): user word 0 0x2168200 -> 0x2699300, read as value, forwarded yes, held by a descriptor yes, relocatable words 0x10000000
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x4c00000 -> 0x5400000, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5100020 -> 0x5400020, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205d92200): user word 0 0x2168200 -> 0x2699300, read as value, forwarded yes, held by a descriptor yes, relocatable words 0x10000000
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x4c00000 -> 0x4e80000, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5100020 -> 0x4e80020, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205d92200): user word 0 0x2168200 -> 0x2699300, read as value, forwarded yes, held by a descriptor yes, relocatable words 0x10000000
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x4c00000 -> 0x5480000, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5100020 -> 0x5480020, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205d92200): user word 0 0x2168200 -> 0x2699300, read as value, forwarded yes, held by a descriptor yes, relocatable words 0x10000000
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x4c00000 -> 0x4b80000, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5100020 -> 0x4b80020, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205d92200): user word 0 0x2168200 -> 0x2699300, read as value, forwarded yes, held by a descriptor yes, relocatable words 0x10000000
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x4c00000 -> 0x5200000, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5100020 -> 0x5200020, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5100020 -> 0x4c00020, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x4c00000 -> 0x5100000, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5100000 -> 0x4b00000, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x4c00020 -> 0x4b00020, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5100000 -> 0x5480000, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x4c00020 -> 0x5480020, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5480000 -> 0x5000000, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5480020 -> 0x5000020, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5480000 -> 0x5700000, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5480020 -> 0x5700020, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5480000 -> 0x5880000, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5480020 -> 0x5880020, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5480000 -> 0x5280000, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5480020 -> 0x5280020, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5480000 -> 0x5080000, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
[draw-cache] data-only hit passed over stage 1 (program 0x205e1c600): user word 12 0x5480020 -> 0x5080020, read as value and base, forwarded yes, held by a descriptor yes, relocatable words 0x0
```

AI-assisted. Tested by me on my own machine.
