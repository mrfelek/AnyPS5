# Sonic Origins Plus (PPSA05325), Sonic 2 menu page, why cached draw cache stages are passed over

Question: on this menu about 400,000 draws per 10 s hit the draw cache on data only, yet about 630,000 shader stages are still compiled per 10 s and relocation fires only about 150 times. Why are the cached stages not reused?

- **Date / machine:** 2026-10-26, Linux desktop (RTX 3080 Ti). See [machines.md](../machines.md).
- **Build:** upstream `e4bb5fc125` + [data-hit-relocation-v4.patch](../../research/patches/data-hit-relocation-v4.patch), which is v3 plus three test-only counters that say why each cached stage was passed over. Not upstream.
- **Arms:** one unmeasured warm-up boot, then one measured boot with relocation on (no switches off).
- **Environment:** default profile set + `APS5_TRACE_DRAW_CACHE=1` + committer split timers + frame dumps, headless, audio muted, memory cap. No errors.
- **Phase measured:** Sonic 2 menu page, +120..+240 s.

## Result

Almost every cached stage that is not reused is passed over because **a fixed word changed**: about 594,000-631,000 per 10 s. Only 2,400-3,500 are passed over for a moved layout and 28,000-35,000 for moved data that differs. That is why relocation (which handles moved data) fires only 127-153 times per 10 s here.

| Window | Lookups | Data-only hits | Stages reused / relocated / compiled | Passed over: changed fixed word / moved layout / moved data differs |
|---|---|---|---|---|
| 1 | 426,330 | 400,544 | 172,041 / 148 / 629,047 | 593,783 / 2,811 / 34,670 |
| 2 | 435,470 | 417,301 | 170,673 / 153 / 663,929 | 630,636 / 3,476 / 30,416 |
| 3 | 438,105 | 416,382 | 174,458 / 127 / 658,306 | 629,329 / 2,355 / 27,743 |

Medians over the same span: 151.5 presents per 10 s, frame p50 66.1 ms, GPU 44.3 ms per frame (draw 23.1, copy 4.6, storage upload 4.1, fill 2.9).

**Way to go:** the fixed-word check decides reuse on this scene, not moved data. Next, find which fixed words change between otherwise matching stages, and whether those words can be passed as data instead of being baked into the stage. Relocating moved data further is ruled out as the main lever here. Follow-up: [which fixed words](2026-10-26-sonic-s2-menu-draw-cache-fixed-words.md) (ring offsets in user word 12, read as values).

## The three draw cache lines, verbatim

```
[draw-cache] 10 s: 426330 lookups, 24812 hits (5.8%), 230 stage misses, 401498 without an entry, 400544 data-only hits (stages: 172041 reused, 148 of them relocated, 629047 compiled; 0 verified; cached stages passed over: 593783 for a changed fixed word, 2811 for a moved layout, 34670 for moved data that differs); no entry: new registers 0, user words/pointers only 294597, evicted 71312, seen but never inserted 35589; stage misses: front differing 194, fragment differing 36, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 59 (4.5 words changed each), other runs 364; 4096 entries, 30421 evicted
[draw-cache] 10 s: 435470 lookups, 17401 hits (4.0%), 162 stage misses, 418090 without an entry, 417301 data-only hits (stages: 170673 reused, 153 of them relocated, 663929 compiled; 0 verified; cached stages passed over: 630636 for a changed fixed word, 3476 for a moved layout, 30416 for moved data that differs); no entry: new registers 0, user words/pointers only 323779, evicted 57557, seen but never inserted 36754; stage misses: front differing 129, fragment differing 33, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 96 (5.9 words changed each), other runs 194; 4096 entries, 27561 evicted
[draw-cache] 10 s: 438105 lookups, 20738 hits (4.7%), 202 stage misses, 417515 without an entry, 416382 data-only hits (stages: 174458 reused, 127 of them relocated, 658306 compiled; 0 verified; cached stages passed over: 629329 for a changed fixed word, 2355 for a moved layout, 27743 for moved data that differs); no entry: new registers 0, user words/pointers only 325236, evicted 56989, seen but never inserted 35290; stage misses: front differing 161, fragment differing 41, other differing 0, layout 0, gate 0, stage count 0; differing captures: same runs 55 (4.2 words changed each), other runs 304; 4096 entries, 31339 evicted
```

AI-assisted. Tested by me on my own machine.
