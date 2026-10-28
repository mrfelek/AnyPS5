# Diablo II Resurrected (PPSA03912), character select, per-use refresh fix prototype and upstream #10894 on the RTX 3080 Ti

Question: on the Radeon 780M the [per-use refresh prototype](2026-10-25-d2r-character-select-amd-draw-set-reuse.md#fix-prototype-keep-builds-whose-depth-plane-texture-is-refreshed-per-use-2026-10-28) cut committer time by about 25% but could not raise FPS, because that menu is GPU-bound there. Does it help on the desktop, where this menu is closer to CPU-bound? This run is also the reference for open upstream [#10894](https://github.com/boykopovar/AnyPS5/pull/10894) (WallisSkill), which addresses the same rebuilds and will be measured next the same way.

- **Date / machine:** 2026-10-28, Linux desktop (RTX 3080 Ti), 4K. See [machines.md](../machines.md).
- **Build:** one binary: upstream `04fefebe90` + [per-use-refresh-p1-on-04fefebe90.diff](../../research/patches/per-use-refresh-p1-on-04fefebe90.diff) (the same prototype rebased). A = default, B = `APS5_PER_USE_REFRESH=1` (checked in the process). Not upstream.
- **Scene:** character select, one button press at +125 s and no other input. Shader disk cache off, pipeline journal threads 0, draw and GPU profiling on, headless, audio muted; frames dumped at the same frame numbers in every arm. Medians over +180..+360 s (18 windows). Order A B A B. No aborts and no validation errors.

## Result: committer time -34%, presents +6%, the GPU becomes the limit, same picture

- B removes all draw resource cache misses (about 53,000 -> 0 per 10 s); builds go from about 55,000 (67 us each) to about 2,400 (26-28 us, the uncacheable ones).
- Recorded draw average 39-40 -> 25-26 us, committer 36-37 -> 24 us per commit (-34%). The packet worker barely moves (64-69 -> 60-67 us per packet).
- Presents 96 / 90 -> 102 / 95 per 10 s (+6%). GPU time per frame is unchanged (91-98 ms) and SM load rises to 97-98%, so the GPU is now the limit.
- **Picture:** B differs from A exactly as much as A differs from A (pixels over 24: under 0.1-3.7% on settled frames, about 6.7% from menu animation, about 49% on the transition frame in every pair, including A against A). No visible error.

| arm | presents/10s | p50 ms | inflight ms | GPU ms/frame | top classes | SM % | VRAM MiB | hooksync | CPU ms/10 s | committer us/commit | worker us/packet | recorded avg us | template hits vs builds /10s | resource cache draw hits / misses | refresh on reuse (cumulative) | peak MiB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| a1 A | 96 (92-96) | 104.6 | 32.8 | 91.8 | draw 59.0, staging-out 13.0, staging-in 9.9, fill 3.2 | 91.5 | 9868 | 140 / 3503 ms | app.elf 20471, SDLAudio 75, pipeline thread 13 | 36.2 | 64.0 | 39 | 74237 (18 us) vs 57537 (67 us) | 74237 / 55238 | none | 9570 |
| b1 B | 102 (97-104) | 97.6 | 34.5 | 91.2 | draw 58.6, staging-out 12.7, staging-in 9.9, fill 3.3 | 96.8 | 9973 | 147.5 / 3898 ms | app.elf 23854, driver analysis 563, SDLAudio 77, pipeline thread 14 | 24.1 | 60.4 | 25 | 138698 (25 us) vs 2463 (26 us) | 138698 / 0 | same texture 1282026, other texture 0 | 11310 |
| a2 A | 90 (87-97) | 112.0 | 36.3 | 98.3 | draw 60.5, staging-out 14.3, staging-in 11.0, fill 4.0 | 92.8 | 9856 | 135 / 3638.5 ms | app.elf 21027, driver analysis 562, SDLAudio 86, pipeline thread 15 | 37.0 | 69.3 | 40 | 68938 (18 us) vs 53426 (68 us) | 68938 / 51281 | none | 11202 |
| b2 B | 95 (93-102) | 105.9 | 39.3 | 97.3 | draw 58.9, staging-out 14.9, staging-in 11.1, fill 4.0 | 97.7 | 9695 | 144.5 / 4332.5 ms | app.elf 17127, driver analysis 386, SDLAudio 69, pipeline thread 12 | 24.2 | 66.8 | 26 | 127535 (25 us) vs 2262 (28 us) | 127535 / 0 | same texture 1195798, other texture 0 | 11192 |

**Next:** measure upstream #10894 the same way, then compare the two approaches before proposing anything (done below).

## Upstream #10894 (WallisSkill), menu and town

- **Build:** the PR head `0c6bca70d9` (on `2227f13661`). A = `APS5_NO_PER_USE_TEXTURE_TEMPLATES=1` (the PR's own switch, PR off), B = PR on. One binary.
- **Scene:** the same menu window, then the save is loaded and the town is measured (last 150 s of 180 s). Draw profiling, frame dumps and a town screenshot; headless, audio muted, shader disk cache off.
- **Runs:** one per arm (A1, B1), both without errors; the second pair was skipped because the gap is large and consistent. A first B1 was overwritten by a stray script and was run again.

**Result: a clear gain in both scenes: menu +16% presents (90 -> 104 per 10 s), town +20% (80 -> 96).** The mechanism is the same as the prototype above (resource cache misses to 0, builds to about 2,400, committer about 37 -> 24 us per commit on the menu), and in town the GPU draw class also drops from 50.6 to 33.9 ms per frame.

| | Menu A | Menu B | Town A | Town B |
|---|---|---|---|---|
| presents / 10 s | 90 (86-91) | 104 (103-104) | 80 (78-82) | 96 (93-97) |
| p50 frame ms | 111.7 | 96.8 | 125.4 | 104.9 |
| GPU ms / frame | 97.5 | 89.9 | 90.3 | 67.2 |
| GPU draw class ms | 60.4 | 57.6 | 50.6 | 33.9 |
| staging out / in ms | 14.0 / 10.8 | 12.3 / 9.9 | 14.2 / 11.0 | 12.5 / 10.0 |
| inflight | 36.6 | 34.9 | 25.0 | 10.8 |
| SM busy | 94.3% | 96.5% | 77.7% | 68.1% |
| VRAM MiB | 9781 | 9947 | 10761 | 10213 |
| committer us/commit | 37.7 | 24.6 | 28.3 | 21.3 |
| worker us/packet | 69.0 | 60.4 | 38.2 | 34.4 |
| template hits / builds per 10 s | 69603 / 53955 | 139518 / 2478 | 163129 / 42169 | 224288 / 2269 |
| resource cache draw misses | 51801 | 0 | 40261 | 0 |
| app.elf CPU ms / 10 s | 17805 | 20965 | 24531 | 28862 |
| driver analysis thread ms | 1037 | 468 | - | - |
| staged in MiB / 10 s | 22555 | 25143 | 19777 | 22892 |

- **Cost:** B spends about 474 ms more per 10 s revalidating (161,715 calls / 224.6 ms in A against 228,443 / 698.9 ms in B, with 47,336 per-use partial walks).
- **Picture:** the town screenshots differ in 0.30% of pixels (rain particles only), the menu in 2.24% (animation). No visible error.
- Against the prototype above (menu only, different base): same mechanism and the same cache effect; #10894 gives the larger menu gain here (+16% against +6%) and +20% in town.
- A verifier arm (PR on with proof verification, menu and 60 s of town) is running; its result will be added here.

**Way to go:** #10894 rather than our prototype; the prototype stays only as a reference.

AI-assisted. Tested by me on my own machine.
