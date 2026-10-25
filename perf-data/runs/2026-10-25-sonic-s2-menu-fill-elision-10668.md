# Sonic Origins Plus (PPSA05325), Sonic 2 menu page, repeated-fill elision A/B (#10668)

Question: does [#10668](https://github.com/boykopovar/AnyPS5/pull/10668) (meh7an, skips refilling a memory range that still holds its fill pattern) speed up this menu? Its author reports the menu zero-fills about 68 MiB per frame.

- **Dates / machine:** 2026-10-24 (off 1) and 2026-10-25 (on 1, off 2, on 2), Linux desktop (RTX 3080 Ti). See [machines.md](../machines.md).
- **Build:** upstream `e4bb5fc125` + #10668 (PR head at build time) + logging-only committer split timers + the local draw cache relocation v2 prototype (not upstream; its verifier was not enabled here). One build for all arms; the PR's own off switch `APS5_NO_FILL_ELISION=1` makes the off arms.
- **Environment:** default profile set + `APS5_TMP_COMMITTER_SPLIT=1 APS5_TRACE_DRAW_CACHE=1`, frame dumps, memory cap, audio muted, headless.
- **Phase measured:** Sonic 2 menu page, +120..+240 s, medians. Order off, on, off, on.

## Result

The elision works: about 25,000 repeated fills are skipped per run, and the fill GPU class (2.9-3.1 ms per frame) disappears. GPU time per frame drops by 3-4.6 ms. Presents do not change, because this menu is limited by CPU and draw committer cost (about 25 s of emulator CPU per 10 s), not by the GPU. A real GPU saving that will show once the per-draw CPU cost is cut.

| Arm | Elision | Presents/10 s | Frame p50 ms | GPU ms/frame | Top GPU classes ms/frame | CPU ms/10 s | Fills skipped (run) |
|---|---|---|---|---|---|---|---|
| off 1 | off | 144 | 69.5 | 48.2 | draw 23.6, storage upload 5.2, copy 4.9, fill 3.1 | 26015 | 0 |
| on 1 | on | 141 | 70.9 | 43.6 | draw 23.2, copy 4.8, storage upload 4.8, label-run 0.6 | 25031 | 25288 |
| off 2 | off | 146.5 | 68.4 | 44.2 | draw 23.1, copy 4.6, storage upload 4.1, fill 2.9 | 25448 | 0 |
| on 2 | on | 147.5 | 67.8 | 41.2 | draw 23.0, copy 4.6, storage upload 4.1, label-run 0.3 | 25409 | 25888 |

- Memory about 4.6 GB in every arm; hook syncs 1.5-3 per 10 s, about 0 ms. No terminate, Vulkan error or device loss.

## Which bottleneck moved

The fill work on the GPU is gone, so GPU time falls, but the frame was already set by the CPU (draw worker and committer), so the frame time stays where it was.

AI-assisted. Tested by me on my own machine.
