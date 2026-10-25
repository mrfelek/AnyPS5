# Diablo II Resurrected (PPSA03912), character select, draw committer cost and descriptor set reuse A/B (AMD)

Question: on the Radeon 780M the D2R menus are limited by per-draw recording (about 46 us per draw on one thread). Where does that time go, and does reusing descriptor sets between draws cut it?

- **Date / machine:** 2026-10-25, AMD mini PC (Radeon 780M, RADV, Mesa 26.0.8). See [machines.md](../machines.md).
- **Builds:** baseline = upstream `e4bb5fc125` + logging-only committer split timers ([committer-split-timers.diff](../../research/patches/committer-split-timers.diff)) + the test GameUpdate change. A/B = one build of `e4bb5fc125` + split timers + [draw-set-reuse.diff](../../research/patches/draw-set-reuse.diff) (my prototype); A = `APS5_TMP_COMMITTER_SPLIT=1`, B = A + `APS5_DRAW_SET_REUSE=1`. Order A1 B1 A2 B2.
- **Environment:** default profile set + `APS5_PROFILE_DRAW=1`, audio muted.
- **Phase measured:** character select, 30 s settle, then 180 s with no input; numbers from the last 10 s window.

## Result

Reusing descriptor sets works as designed (about 30% fewer descriptor writes), but nothing else moves: cost per draw, presents, GPU time and CPU stay inside run-to-run noise. Updating descriptors is only about 1.6 us of the about 46 us per draw, so it was never the cost. Most of the time sits in the draw-and-submit step (about 48 us). The GPU is also busy about 183 of every 187 ms, so on this machine the scene is GPU-bound and CPU-bound at the same time.

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
| Draw and submit, us | 48.20 | 48.09 | 48.57 | 48.33 |
| Descriptor writes per 10 s | 656,821 | 656,760 | 453,201 | 461,247 |
| Driver phases, us per packet | 118.5 | 117.6 | 117.4 | 116.3 |
| Presents per 10 s | 53.2 | 53.3 | 53.5 | 53.6 |
| Frame p50 ms | 187.8 | 187.7 | 186.7 | 186.7 |
| GPU busy per present ms | 183.9 | 183.3 | 182.7 | 182.6 |

- B reused about 570,000 sets and built about 904,000 fresh per run; about 2.5 million buffer descriptors rewritten and 5.5 million skipped.
- Both arms: queue worker 0 at 99%, a second worker at 31-32%, total CPU 134-135%, RSS 8.3-8.4 GiB, VRAM 1.9-2.0 GiB, GTT 10.9-11.7 GiB. No validation errors, device losses or terminates.
- Caveat: every emulator thread has the same name, so the sampler cannot separate the committer from queue worker 0. Naming the threads would allow that split.

## Ruled out, and what to do instead

Descriptor set reuse is ruled out as a way to cut per-draw cost: descriptor updates are about 3% of it. **Instead:** break down the draw-and-submit step (about 48 us), and name the threads so committer time and queue-worker time can be measured separately. On this machine the GPU is close to full as well, so a CPU saving alone would not raise FPS much.

AI-assisted. Tested by me on my own machine.
