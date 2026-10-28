# Diablo II Resurrected (PPSA03912), per-use refresh: our prototype and upstream #10894

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
- The verifier result is below.

### Verifier: the per-use partial walk disagrees with the full walk

- **PR on with proof verification (`APS5_VERIFY_PROOFS=1`):** about 8 s after the button press into the menu (+132-133 s), the log prints `[rescache] APS5_VERIFY_PROOFS: the per-use partial walk disagrees with the full walk`, and the process stops. That stop is by design: in the PR source the verifier runs a full walk after each per-use fast proof and aborts on a disagreement. Reproduced on a second run; the lines just before it are resource-key misses for draw and dispatch shader sets ("layout", "no-component-change"). The PR has no switch that names the disagreeing draw.
- **PR on with the partial walk off (`APS5_NO_PER_USE_PARTIAL_WALK=1`):** clean, 180 s in town, no errors, memory normal.

| | PR off | PR on | PR on, partial walk off |
|---|---|---|---|
| menu presents /10 s | 90 | 104 | 100 |
| menu GPU ms/frame | 97.5 | 89.9 | 92.1 |
| town presents /10 s | 80 | 96 | 91 |
| town GPU ms/frame | 90.3 | 67.2 | 83.2 |
| committer us (menu / town) | 37.7 / 28.3 | 24.6 / 21.3 | 29.8 / 23.4 |
| resource cache misses (menu / town) | 52k / 40k | 0 / 0 | 0 / 0 |
| town revalidate (last 10 s) | 161,715 calls, 225 ms | 228,443 calls, 699 ms, 3,928 full | 233,234 calls, 1,349 ms, 48,686 full (46,228 "per-use texture") |

Without the partial walk every per-use reuse falls back to a full walk, so revalidation doubles and about 5 presents per window are lost, but it is still +11% (menu) and +14% (town) over PR off. The partial walk gives the extra gain and is also the part the verifier flags.

**Way to go:** #10894's templates, with the full-walk fallback as the safe default until the partial walk agrees with the full walk on Diablo II; our prototype stays only as a reference.

## Other title: Astro Bot (desktop)

With #10894 off, Astro Bot's hub_crashsite gives only 6,574 draw and 1,260 dispatch refusals of this kind in about 170 s (Diablo II: 912,489), so the PR has nothing to act on there and the PR-on arm was not run. [page](2026-10-28-astro-bot-per-use-texture-templates-10894-scan.md)

## Upstream #10894 on the AMD mini PC (Radeon 780M)

- **Machine:** AMD mini PC, Ryzen 9 PRO 8945HS, Radeon 780M (RADV, Mesa 26.0.8). See [machines.md](../machines.md).
- **Build:** the PR head `0c6bca70d9`, Release. One run per arm covering the menu (+245..+365 s) and then town (last 150 s of 180 s), shader disk cache off, audio muted. A = PR off, B = PR on, V = B with proof verification, W = V with the partial walk off. No validation errors, device loss or terminate in A, B or W.

**Result: town +16% presents (55 -> 64 per 10 s, frame p50 183 -> 158 ms); the menu stays at about 58 because it is GPU-bound on this machine.** Builds drop about 25 times, committer time 30% (menu) and 18% (town); GPU time per frame is unchanged. No regression seen.

| per 10 s (median) | A menu | B menu | A town | B town |
|---|---|---|---|---|
| presents | 58 | 59 | 55 | 64 |
| frame p50 ms | 173.2 | 171.6 | 183.2 | 158.0 |
| GPU busy per present ms | 168.7 | 168.7 | 142.9 | 140.0 |
| committer us per commit | 45.8 | 32.2 | 47.8 | 39.0 |
| recorded draw average us | 42 | 27 | 35 | 25 |
| template hits / builds | 44937 / 34800 | 78866 / 1401 | 112111 / 28922 | 162127 / 1518 |
| resource cache draw misses | 33408 | 0 | 27625 | 0 |
| revalidate ms (per-use partial walks) | 97.6 (0) | 459.9 (31708) | 189.1 (0) | 577.1 (30720) |

- **Verifier (V):** the same "per-use partial walk disagrees with the full walk" line, once, at about +128 s on the "press to begin" screen right after the button press, before the menu; the run then ended. **With the partial walk off (W):** clean through the whole menu and into town (presents 58 / 61, builds about 1,400 per 10 s, resource cache misses 0). Same pattern as on the desktop.
- **Town picture:** every AMD town frame is fully textured (ground around the player, the campfire and between tiles, lit torches), in A and in B.
- The machine went to sleep during W's town phase, so W has only 2 town windows.

Last revalidate window of each, verbatim:

```
A menu: [rescache] revalidate (10 s): 46084 calls 97.6 ms: fast 44458, full 1626, failed 0; fast-fail by reason: pending image 145 memory changed 29; full walks: T1 refreshed 118 (0 storage images, 145 view sources, 0 views served by their own pending source, 0 overlaps left by the refresh accepted), full by reason: memory changed 29 audit 1597, T1 fallback by reason:, proofs verified 0; fast-fail pending image: own 0 (the query excepts the own object), foreign 145, snapshot 0, T1 eligible 145; keys proven: 0 sampled, 0 storage; epoch gate: 35380 registry scans skipped, 46084 import loops skipped; lookup log: 0 builds and full walks kept their records past the bound; per-use partial walks 0
A town: [rescache] revalidate (10 s): 113576 calls 189.1 ms: fast 110997, full 2579, failed 0; fast-fail by reason: pending image 137 memory changed 27; full walks: T1 refreshed 110 (0 storage images, 137 view sources, 0 views served by their own pending source, 0 overlaps left by the refresh accepted), full by reason: memory changed 27 audit 2552, T1 fallback by reason:, proofs verified 0; fast-fail pending image: own 0 (the query excepts the own object), foreign 137, snapshot 0, T1 eligible 137; keys proven: 0 sampled, 0 storage; epoch gate: 97794 registry scans skipped, 113576 import loops skipped; lookup log: 0 builds and full walks kept their records past the bound; per-use partial walks 0
B menu: [rescache] revalidate (10 s): 79518 calls 459.9 ms: fast 76104, full 3414, failed 0; fast-fail by reason: pending image 145 memory changed 29; full walks: T1 refreshed 116 (0 storage images, 145 view sources, 0 views served by their own pending source, 0 overlaps left by the refresh accepted), full by reason: memory changed 29 audit 3385, T1 fallback by reason:, proofs verified 0; fast-fail pending image: own 0 (the query excepts the own object), foreign 145, snapshot 0, T1 eligible 145; keys proven: 0 sampled, 0 storage; epoch gate: 58696 registry scans skipped, 79518 import loops skipped; lookup log: 0 builds and full walks kept their records past the bound; per-use partial walks 31708
B town: [rescache] revalidate (10 s): 163917 calls 577.1 ms: fast 160054, full 3863, failed 0; fast-fail by reason: pending image 158 memory changed 31; full walks: T1 refreshed 132 (0 storage images, 158 view sources, 0 views served by their own pending source, 0 overlaps left by the refresh accepted), full by reason: memory changed 31 audit 3832, T1 fallback by reason:, proofs verified 0; fast-fail pending image: own 0 (the query excepts the own object), foreign 158, snapshot 0, T1 eligible 158; keys proven: 0 sampled, 0 storage; epoch gate: 136535 registry scans skipped, 163917 import loops skipped; lookup log: 0 builds and full walks kept their records past the bound; per-use partial walks 30720
```

AI-assisted. Tested by me on my own machine.
