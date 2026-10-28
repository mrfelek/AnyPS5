# Diablo II Resurrected (PPSA03912), character select, draw committer cost and descriptor set reuse A/B (AMD)

Question: on the Radeon 780M the D2R menus are limited by per-draw recording (about 46 us per draw on one thread). Where does that time go, and does reusing descriptor sets between draws cut it?

- **Date / machine:** 2026-10-25, AMD mini PC (Radeon 780M, RADV, Mesa 26.0.8). See [machines.md](../machines.md).
- **Builds:** baseline = upstream `e4bb5fc125` + logging-only committer split timers ([committer-split-timers.diff](../../research/patches/committer-split-timers.diff)) + the test GameUpdate change. A/B = one build of `e4bb5fc125` + split timers + [draw-set-reuse.diff](../../research/patches/draw-set-reuse.diff) (my prototype); A = `APS5_TMP_COMMITTER_SPLIT=1`, B = A + `APS5_DRAW_SET_REUSE=1`. Order A1 B1 A2 B2.
- **Environment:** default profile set + `APS5_PROFILE_DRAW=1`, audio muted.
- **Phase measured:** character select, 30 s settle, then 180 s with no input; numbers from the last 10 s window.

## Result

Reusing descriptor sets works as designed (about 30% fewer descriptor writes), but nothing else moves: cost per draw, presents, GPU time and CPU stay inside run-to-run noise. Updating descriptors is only about 1.6 us of the about 46 us per draw, so it was never the cost. The timer around the whole draw reads about 48 us per commit; inside it, the biggest measured pieces are buffer snapshots for the bindings (about 3.3 us per draw, more than set allocate and update together) and the bindings, record and lookup phases (see the breakdown below). The driver phases per draw packet show where the rest goes: **vectors 76.8 us of 118.5 us per packet**, then capture 14.0, recompile 12.5 and lock wait 9.1. Separately, about 5.5 s per 10 s goes into reading the arguments of 1,067 indirect draws that turn out to be empty (about 5.2 ms each) before they are skipped. The GPU is also busy about 183 of every 187 ms, so on this machine the scene is GPU-bound and CPU-bound at the same time.

## Baseline (split timers)

Pipelined 47.0 us per commit (86,671 commits); 74,057 draws per 10 s recorded at 43 us on average; resources 1,342.8 ms per 10 s (bindings 671.3, upload 95.3, descriptors 197.2); descriptor set allocate 0.56 us, update 1.64 us. 53.4 presents per 10 s, GPU busy 183.1 ms per present. No validation errors.

## A/B: descriptor set reuse

| Metric | A1 | A2 | B1 | B2 |
|---|---|---|---|---|
| Pipelined us per commit | 45.6 | 46.6 | 46.3 | 46.3 |
| Wait for room, us per draw | 7.5 | 8.0 | 7.9 | 7.9 |
| Draws per 10 s | 73.1k | 73.1k | 73.1k | 74.2k |
| Recorded, us per draw (avg) | 43 | 43 | 43 | 43 |
| Resources ms per 10 s | 1357 | 1311 | 1343 | 1367 |
| Descriptors ms per 10 s | 197 | 192 | 194 | 196 |
| Set allocate / update, us | 0.53 / 1.60 | 0.52 / 1.62 | 0.53 / 1.66 | 0.55 / 1.70 |
| Whole draw (commit timer), us | 48.20 | 48.09 | 48.57 | 48.33 |
| Descriptor writes per 10 s | 656,821 | 656,760 | 453,201 | 461,247 |
| Driver phases, us per packet | 118.5 | 117.6 | 117.4 | 116.3 |
| Presents per 10 s | 53.2 | 53.3 | 53.5 | 53.6 |
| Frame p50 ms | 187.8 | 187.7 | 186.7 | 186.7 |
| GPU busy per present ms | 183.9 | 183.3 | 182.7 | 182.6 |

- B reused about 570,000 sets and built about 904,000 fresh per run; about 2.5 million buffer descriptors rewritten and 5.5 million skipped.
- Both arms: queue worker 0 at 99%, a second worker at 31-32%, total CPU 134-135%, RSS 8.3-8.4 GiB, VRAM 1.9-2.0 GiB, GTT 10.9-11.7 GiB. No validation errors, device losses or terminates.
- Per-draw breakdown in A1 (us per draw): buffer snapshots 3.29, key 2.16, record commands 1.86, keep 1.68, set update 1.60, pipeline cached 1.20, revalidate 1.15, find 0.79; phase totals per 10 s: resources 1,357 ms (bindings 678, descriptors 197, upload 92), record 621 ms, lookup 339 ms, vertex 249 ms. Template hits cost 21 us, full builds 71 us (about 41k and 32k per 10 s). B1 is the same within noise.
- Driver phases in A1, us per packet (73,189 packets per 10 s): prologue 0.3, precheck 0.8, decode 2.4, capture 14.0, recompile 12.5, **vectors 76.8**, key/lookup/validate 2.0, lock wait 9.1, epilogue 0.4; total 118.5 (8.7 s per 10 s).
- Draw resource cache in A1: 40,918 hits, 30,899 misses per 10 s; almost all misses have the same key as an existing entry (304,853 cumulative), so the entry is rebuilt rather than reused. Draw recipes: 0 hits (231 with no recipe).
- The "argument reads" (5,515 ms per 10 s in A1) come only from the empty-indirect skip path: 1,067 indirect draws per 10 s whose arguments are read (draw count and records) to find out they draw nothing, about 5.2 ms each. No real indirect draws ran in this scene.
- Caveat: every emulator thread has the same name, so the sampler cannot separate the committer from queue worker 0. Naming the threads would allow that split.

## Why template builds are not kept (2026-10-28)

Follow-up on "resource cache entries rebuilt under the same key". Build: upstream `e4bb5fc125` + [draw-set-reuse-reuse-reasons.diff](../../research/patches/draw-set-reuse-reuse-reasons.diff) (the same split timers plus counters that say why each build could or could not be kept). One run, character select, menu at 36 s, 30 s settle + 180 s counted, audio muted. No validation error, device loss or terminate.

- **Main reason: "texture refreshed per use".** The cumulative counters read 533,656 -> 562,506 builds blocked because a texture is refreshed on every use (about 29,000 per 10 s), against 49,104 -> 50,932 reusable builds. Other reasons are near zero (copied writes 21, no direct regions 37).
- The resource cache still shows almost all misses with the same key as an existing entry (264,693 -> 278,499 cumulative), about 29,000 misses per 10 s against about 38,000 hits.
- **Caveat: this counter build is slower than the earlier baseline in every window**, so it likely adds work of its own: vertex phase 2.1-2.5 s per 10 s (about 0.25 before), recorded draw 75-86 us (43), upload 417-464 ms (about 92), committer 76-79 us per commit (about 46), 50 presents per 10 s (54), frame p50 196 ms. GPU busy per present is unchanged at 183.9 ms. Use it for the reasons, not for speed.

**Way to go:** find out why those textures count as refreshed on every use and whether an unchanged texture can keep its build; that is what blocks reuse in this menu.

Last two 10 s windows, verbatim:

```
Window 1:
[draws] 67994 draws over 10 s (67994 recorded avg 79 us, of them 1188 with completion; 0 recorded then waited avg 0 us; 0 synchronous avg 0 us; render passes 5345 begun, 62649 draws continued one; waited or synchronous because:): validate=48.9ms vertex=2310.4ms setup=38.4ms readTarget=108.8ms (93089 resident lookups, 0 of them >= 1 ms = 0.0; target lookups: full-scissor 93089 / partial 0 / pages walked 2434560 / 102511 us) prepare=86.3ms lookup=354.3ms resources=1572.0ms (bindings 627.7, upload 417.2, descriptors 185.1, other 341.0 of which 0.0 in 0 address-based builds) pipeline=144.5ms record=571.0ms keep=116.0ms; per kind (avg us, count): recipe hit 0 (0) template hit 47 (37447) build 117 (30547) BDA 0 (0); longest draw 110.9 ms, longest phase of any draw: vertex 89.9 lookup 0.5 resources 21.9 record 0.5; hook waits inside draws 0.0 ms (max 0.0; the draws' own syncs, 0.0 ms, not counted); indirect: gpu-side 0 (0 rewritten), cpu-side 0 (), empty skipped before their stages 957, argument reads 3290.5 ms; skipped packets: nothing to draw 0 in 0.0 ms prechecked 0 in 0.0 ms thrown 0 in 0.0 ms; recipe hits 0, misses by reason: not recordable 0 target gone 0 template gone 0 objects gone 0 proof 0
[rescache] draws: 37447 hits, 29359 misses, 259 invalidated, 1188 uncacheable; validation memo 67994 hits / 0 misses (which key words the misses differ in: the miss churn line)
[tmp-reuse] builds (cumulative) by outcome: copied writes 21, lease 0, BDA 0, multisample sources 0, loop guard 0, texture refreshed per use 533656, data over refresh size 0, no direct regions 37, region without serial 0, reusable 49104
[rescache] miss churn (dispatch), first differing word by role: GuestBuffers 25 (V# word 25/0/0/0) GuestImages 14818 (T# word 12733/0/0/184/1901/0/0/0); layout 65, draw target/index 0, same key 23 (not inserted or evicted), first seen 42
[rescache] miss churn (draws), first differing word by role: GuestImages 5 (T# word 1/0/0/4/0/0/0/0); layout 4, draw target/index 160, same key 264693 (not inserted or evicted), first seen 91

Window 2:
[draws] 68082 draws over 10 s (68082 recorded avg 82 us, of them 1188 with completion; 0 recorded then waited avg 0 us; 0 synchronous avg 0 us; render passes 5291 begun, 62791 draws continued one; waited or synchronous because:): validate=48.9ms vertex=2520.2ms setup=39.0ms readTarget=109.4ms (92537 resident lookups, 0 of them >= 1 ms = 0.0; target lookups: full-scissor 92537 / partial 0 / pages walked 2421984 / 103031 us) prepare=87.4ms lookup=352.1ms resources=1599.9ms (bindings 616.6, upload 464.4, descriptors 181.3, other 336.7 of which 0.0 in 0 address-based builds) pipeline=144.9ms record=574.7ms keep=116.4ms; per kind (avg us, count): recipe hit 0 (0) template hit 51 (38090) build 121 (29992) BDA 0 (0); longest draw 119.9 ms, longest phase of any draw: vertex 90.2 resources 45.0 record 0.5; hook waits inside draws 0.0 ms (max 0.0; the draws' own syncs, 0.0 ms, not counted); indirect: gpu-side 0 (0 rewritten), cpu-side 0 (), empty skipped before their stages 1007, argument reads 3036.7 ms; skipped packets: nothing to draw 0 in 0.0 ms prechecked 0 in 0.0 ms thrown 0 in 0.0 ms; recipe hits 0, misses by reason: not recordable 0 target gone 0 template gone 0 objects gone 0 proof 0
[rescache] draws: 38090 hits, 28804 misses, 286 invalidated, 1188 uncacheable; validation memo 68082 hits / 0 misses (which key words the misses differ in: the miss churn line)
[tmp-reuse] builds (cumulative) by outcome: copied writes 21, lease 0, BDA 0, multisample sources 0, loop guard 0, texture refreshed per use 562506, data over refresh size 0, no direct regions 37, region without serial 0, reusable 50932
[rescache] miss churn (dispatch), first differing word by role: GuestBuffers 25 (V# word 25/0/0/0) GuestImages 14916 (T# word 12733/0/0/184/1999/0/0/0); layout 65, draw target/index 0, same key 23 (not inserted or evicted), first seen 42
[rescache] miss churn (draws), first differing word by role: GuestImages 5 (T# word 1/0/0/4/0/0/0/0); layout 4, draw target/index 160, same key 278499 (not inserted or evicted), first seen 91
```

## Ruled out, and what to do instead

Descriptor set reuse is ruled out as a way to cut per-draw cost: descriptor updates are about 3% of it. **Instead:** go after the larger pieces: the vectors phase (76.8 of 118.5 us per draw packet), the 5.5 s per 10 s spent reading empty indirect draws before skipping them (about 5.2 ms each), resource cache entries rebuilt under the same key (mostly blocked by "texture refreshed per use", see above), and the per-draw buffer snapshots (3.3 us). Name the threads so committer time and queue-worker time can be measured separately. On this machine the GPU is close to full as well, so a CPU saving alone would not raise FPS much.

AI-assisted. Tested by me on my own machine.
