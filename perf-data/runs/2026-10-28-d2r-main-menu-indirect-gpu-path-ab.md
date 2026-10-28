# Diablo II Resurrected (PPSA03912), main menu, indirect draw on the GPU path (#10359 + base vertex)

Question: the [no-read probe](2026-10-24-d2r-main-menu-indirect-no-read-probe.md) showed that one indirect draw per frame stalls the CPU 3.4-3.9 s per 10 s while it reads its arguments. Does a real fix, which feeds the start vertex and start instance to the shader on the GPU instead of reading them, remove that stall safely?

- **Date / machine:** 2026-10-28, Linux desktop (RTX 3080 Ti), 4K. See [machines.md](../machines.md).
- **Build:** one binary: upstream `cc672fdfc6` + [indirect-gpu-path-10359-plus-basevertex-v2.diff](../../research/patches/indirect-gpu-path-10359-plus-basevertex-v2.diff), which is open [#10359](https://github.com/boykopovar/AnyPS5/pull/10359) (start instance from the GPU's base instance) plus my base-vertex half (start vertex from the GPU's base vertex). Not upstream yet.
- **Arms:** A = `APS5_NO_INDIRECT_INPUT_ROUTES=1` (routes off, the CPU read path as on plain main); B = routes on. Indirect draw trace on in all four runs; each run's environment checked in the process.
- **Scene:** main menu, shader disk cache off, pipeline journal threads 0, headless, audio muted; medians over +180..+360 s (18 windows). Order A B A B. No errors.
- **Unit tests on B:** 13 of 13 pass (indirect instance input and vertex input, each with 4 variants, shader memory, indirect instance semantics, request serializer).
- **One rerun:** the first B2 hit the known D2R boot shared-memory spike (5.6 -> 24.7 GB at +86 s), which happens without the patch too; it was stopped by the memory guard and B2 was run again.

## Result: the stall is gone, +6-16% presents, picture unchanged

- Argument reads and the DRAW_INDIRECT wait go from 3.9 / 3.6 s per 10 s to 0, as with the probe, but now without skipping the read unsafely.
- Presents go from 87 / 95 to 101 / 100 per 10 s (+6-16%), and frame p50 from 115.8 / 105.3 to 99.6 / 100.1 ms.
- GPU time per frame stays about the same, but SM load rises to 99%, so the GPU is now the limit (in-flight wait 39 / 35 -> 61 / 79 ms).
- **Cost:** a shader-analysis CPU thread now uses 2.3-6.0 s per 10 s (4 ms in A).
- **Picture:** the pixel difference (threshold 24) between B and A is 2.08% / 1.98%, the same as between A1 and A2 (2.16%, the menu is animated); no visible error.

| arm | presents/10 s (range) | frame p50 ms | inflight_wait p50 / p90 ms | GPU ms/frame | top classes ms/frame | SM % | hook syncs / time | argument reads ms | DRAW_INDIRECT wait ms | packet drains (ms) | CPU ms/10 s | peak / VRAM MiB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| A1 off | 87.0 (86-90) | 115.8 | 39.3 / 41.5 | 101.7 | draw 63.2, staging-out 14.4, staging-in 11.1, fill 4.2 | 93.3 | 135 / 3899.5 ms | 3915.1 | 3896.5 | 1807 (198.4) | app.elf 19422, analysis 4 | 11086 / 9774 |
| B1 on | 101.0 (100-101) | 99.6 | 61.4 / 97.6 | 94.7 | draw 61.7, staging-out 12.8, staging-in 10.0, fill 3.3 | 99.0 | 27 / 2071.5 ms | 0.0 | 0 | 2250.5 (476.3) | app.elf 23059, analysis 5984 | 11439 / 9422 |
| A2 off | 95.0 (95-96) | 105.3 | 34.6 / 35.0 | 93.7 | draw 61.6, staging-out 12.3, staging-in 9.9, fill 3.3 | 92.8 | 126.5 / 3564.5 ms | 3559.9 | 3563.0 | 2059.5 (226.5) | app.elf 19001, analysis 4 | 11403 / 9985 |
| B2 on | 100.0 (100-101) | 100.1 | 79.0 / 98.3 | 95.1 | draw 61.6, staging-out 13.5, staging-in 10.0, fill 3.3 | 99.0 | 24 / 1859.5 ms | 0.0 | 0 | 2261 (628.8) | app.elf 21906, analysis 2277 | 11175 / 9692 |

## Correctness (routes on)

Draw entry and draw recipe verifiers on (`APS5_VERIFY_DRAW_ENTRIES=1 APS5_VERIFY_DRAW_RECIPE=1`, checked in the process), indirect trace on, headless, audio muted. No exceptions, no driver failures and no "unsupported" lines in any game.

- **Diablo II Resurrected menu** (about 3 minutes): every window shows 0 differences (for example "72645 decodes compared, 0 differed"), about 426 cache hits per 10 s.
- **Castlevania Belmont's Curse** (in game, about 70 s): "78973 decodes compared, 0 differed", 7,238 hits per 10 s; the screenshot shows normal in-game dialogue.
- **Hollow Knight: Silksong** (first area): "92073 decodes compared, 0 differed", 82,549 hits per 10 s; the screenshot shows Hornet in the first area, normal.
- **Caveat:** the recipe verifier had nothing to check (0 recipe hits in all three games, because draw recipes are not on by default in this build).

## Diagnostic pair: where the extra CPU in B comes from

Same binary, A3 = routes off, B3 = routes on, draw profiling and indirect trace on, D2R menu, windows +130..+250 s.

- **We do not rebuild the vertex stage on the route path.** The per-packet result memo is the same in both (about 0.17 misses and 1.46 patched per draw packet); pipeline creates in the window: 2 and 2, pipeline cache 100% hits in both, compute pipelines 24 in both, all at boot.
- **The extra thread is the NVIDIA driver's own** shader-analysis thread: 5,550 ms of CPU per 10 s in B3 and absent in A3. Since we create no new pipelines or shaders, it looks like the driver analysing something B submits each frame (the in-place indirect input path or its buffer use).
- **Our own driver time per draw packet drops** from 65.1 to 41.5 us; the "vectors" phase goes from 29 to 1.5 us, which is the argument-read wait disappearing.
- Medians: A3 95.0 presents per 10 s, frame p50 106.3 ms, in-flight wait 34.9 ms, GPU 94.1 ms per frame, SM 92.5%, app.elf CPU 21,298 ms per 10 s. B3 100.0 presents, 100.8 ms, 77.7 ms, 95.7 ms, SM 99.1%, app.elf 24,090 ms plus 5,550 ms in the driver thread.

Per 10 s: presents / memo hits / patched / misses / argument read ms / driver us per packet (vectors, total):

```
A3 (routes off)
130: 20 / 11467 / 5422 / 13340 / 195.0 / 19.1, 311.8
140: 95 / 34007 / 176910 / 20767 / 3520.1 / 28.7, 65.1
150: 93 / 36596 / 188392 / 21572 / 3554.0 / 29.5, 66.6
160: 95 / 37598 / 193183 / 22131 / 3580.5 / 29.1, 65.1
170: 95 / 37911 / 192102 / 21844 / 3450.7 / 28.0, 64.9
180: 95 / 37853 / 194035 / 22020 / 3619.5 / 29.1, 64.7
190: 93 / 36696 / 187797 / 21357 / 3529.2 / 29.4, 66.7
200: 95 / 37485 / 192807 / 21756 / 3530.4 / 28.7, 65.0
210: 94 / 37566 / 190561 / 22251 / 3609.9 / 29.4, 65.5
220: 94 / 37250 / 189792 / 22066 / 3586.5 / 29.4, 65.7
230: 95 / 37465 / 191359 / 22190 / 3528.9 / 28.7, 65.0
240: 95 / 38280 / 191963 / 22369 / 3587.1 / 29.1, 65.1
B3 (routes on)
130: 156 / 11943 / 7351 / 13709 / 0.0 / 1.6, 106.7
140: 100 / 36383 / 189195 / 22723 / 0.0 / 1.5, 45.8
150: 97 / 37899 / 194715 / 22792 / 0.0 / 1.6, 42.2
160: 101 / 40022 / 204094 / 24030 / 0.0 / 1.5, 41.3
170: 96 / 38331 / 195716 / 22926 / 0.0 / 1.6, 43.6
180: 100 / 39428 / 200751 / 23345 / 0.0 / 1.6, 41.9
190: 100 / 39527 / 201527 / 23550 / 0.0 / 1.6, 42.2
200: 100 / 39608 / 201340 / 23796 / 0.0 / 1.5, 41.4
210: 99 / 39793 / 201900 / 23974 / 0.0 / 1.6, 42.4
220: 100 / 39478 / 201600 / 23527 / 0.0 / 1.6, 43.6
230: 100 / 39568 / 200449 / 23685 / 0.0 / 1.5, 41.4
240: 100 / 39936 / 203828 / 24028 / 0.0 / 1.5, 41.5
```

**Next:** find out what the NVIDIA driver analyses each frame on the route path (a buffer usage or descriptor change per draw is the likely cause), then propose the base-vertex half to #10359.

## Indirect draw trace lines, verbatim

A1 and A2, one line each:

```
[draw] indirect 0x24 args 0x2b5134800 stride 16 count 1 locs base=0x98(s20) inst=0x99(s21) idx=none analyzer v=-1 i=-1 shared=0/0 conflict=0/0 indx=0 -> cpu (patched SGPR not folded)
```

B1, three distinct lines, 2,244 times each (B2 the same, about 2,248 each):

```
[draw] indirect draw-parameter routes: instance s21 vertex s20 (user words read by resources 0xfff, vertex resources 0)
[draw] indirect 0x24 args 0x2b5164800 stride 16 count 1 locs base=0x98(s20) inst=0x99(s21) idx=none analyzer v=-1 i=-1 shared=0/0 conflict=0/0 indx=0 -> gpu vertex=in-place instance=in-place
[draw] indirect 0x24 args 0x2b5164800 stride 16 count 1 locs base=0x98(s20) inst=0x99(s21) idx=none analyzer v=-1 i=-1 shared=0/0 conflict=0/0 indx=0 -> cpu (patched SGPR not folded)
```

## Open

- In B each such draw logs both a GPU line and a CPU line. Argument reads are 0, so the CPU line is probably a second classification that does not read; this still needs checking in the code.
- The extra CPU thread in B belongs to the NVIDIA driver (see the diagnostic pair below); what it analyses each frame is not known yet.

AI-assisted. Tested by me on my own machine.
