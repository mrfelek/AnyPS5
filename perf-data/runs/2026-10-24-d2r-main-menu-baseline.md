# Diablo II Resurrected (PPSA03912), main menu, baseline with draw cache and pass traces

- **Date / machine:** 2026-10-24, Linux desktop (RTX 3080 Ti). See [machines.md](../machines.md).
- **Build:** upstream `a19e7f6fd` + logging-only diagnostics (pass names, top-40 GPU passes, draw cache changed words, fragment shader dump; not upstream).
- **Environment:** default profile set + `APS5_TRACE_DRAW_CACHE=1 APS5_TRACE_INDIRECT_DRAWS=1`, shader cache warm, audio muted.
- **Phase measured:** settled main menu (Cross at +125 s, menu at about +170 s, measured +180 s to the stop at +362 s). Three runs on the same day, all agree.

## Result

The main menu runs at about 88 presents per 10 s and is fully GPU-bound: the GPU is 98-99% busy at about 106 ms per frame. The game renders its heavy passes at 4K (3840x2160), and four of them use very large fragment shaders (about 1.3 MB of SPIR-V each). The draw cache almost never hits (0.3%).

## Standard set (medians, main menu)

| Metric | Shared run | Draw cache trace run |
|---|---|---|
| Presents per 10 s | 88 (87-89) | 87 (85-88) |
| Frame p50 | about 113 ms | 114.9 ms |
| GPU per frame | 106 ms; draw 92, fill 4.0, storage upload 3.6, fill-clear 1.1 | 106.2 ms |
| GPU load | 98.6%, 1950 MHz, about 326 W | 98.2% |
| CPU, draw path | 69.6 us per draw packet x 120.8k packets = 8.4 s per 10 s | |
| CPU, committer | about 39 us per commit, 143k commits per 10 s | |
| CPU total (emulator) | | 19.3 s per 10 s |
| Draw cache hits / dispatch cache equal | 0.3% (365 of 121k) / 55.9% | 0.3% / 56.5% |
| Recompile memo | 15% hits | |
| Uploads / write-backs per 10 s | 26675 / 1672 MiB | 26372 / 1653 MiB |
| Waits | in-flight wait p50 about 58 ms; indirect draw argument reads 3.5-3.7 s per 10 s (88 hook syncs); packet drains about 280 ms per 10 s | 87.5 hook syncs, 3.7 s per 10 s |
| RAM | peak about 9.5 GB | anon 1.1, shmem 7.0 GB |
| VRAM | | 7.1 GB |

## Heaviest GPU passes (one 10 s window, 89 presents)

| Pass | Draws | GPU ms per 10 s | Render target | Fragment shader size (SPIR-V) |
|---|---|---|---|---|
| 1 | 178 | 2837 | 3840x2160, format 71 | 1.37 MB |
| 2 | 319 | 1903 | 3840x2160, format 36 | 1.29 MB |
| 3 | 356 | 552 | 1920x1080, format 14 | 337 KB |
| 4 | 89 | 432 | 3840x2160, format 71 | 1.27 MB |
| 5 | 88 | 250 | 3840x2160, format 36 | 457 KB |
| 6 | 121 | 238 | 3840x2160, format 36 | 1.36 MB |

Shader code addresses change between runs, so passes have to be matched by render target, not by address.

## Draw cache

The misses are almost all "user data only" (120,182 of 121k lookups per 10 s): the draw setup is recognised but per-draw user words change. During the title-to-menu transition the changing words come in (low, high) pairs where the high word steps 0x00100002 -> 0x00100003, which looks like 64-bit buffer addresses moving through a ring or double buffer, not constants.

## Which bottleneck it is

GPU time in a few 4K draw passes with huge fragment shaders. Anything that only saves CPU time will not raise FPS on this menu on this card (see the [indirect read probe](2026-10-24-d2r-main-menu-indirect-no-read-probe.md)); see the [f32 flush A/B](2026-10-24-d2r-main-menu-f32-flush-ab.md) for a change that does cut GPU time.

AI-assisted. Tested by me on my own machine.
