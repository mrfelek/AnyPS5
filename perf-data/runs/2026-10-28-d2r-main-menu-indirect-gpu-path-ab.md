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

- In B each such draw logs both a GPU line and a CPU line. Argument reads are 0, so the CPU line is probably a second classification that does not read, but this needs checking in the code; the new analysis CPU cost may be linked to it.
- Correctness verifier runs with B (D2R menu, Castlevania, Silksong) are running; results will be added here before anything goes upstream.

AI-assisted. Tested by me on my own machine.
