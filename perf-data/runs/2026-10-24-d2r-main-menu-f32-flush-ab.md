# f32 denormal flush probe A/B: Diablo II Resurrected (PPSA03912) main menu, Hot Wheels Infinite Rush (PPSA22408) on Windows

Question: how much GPU time does the emulated 32-bit float denormal flush cost, and is it needed on each GPU?

- **Dates / machines:** 2026-10-24, Linux desktop (RTX 3080 Ti), AMD mini PC (Radeon 780M) and Windows laptop (RTX A2000). See [machines.md](../machines.md).
- **Phase measured:** settled main menu, from 60 s after pressing Cross until the stop (about 3-6 min), no input.
- **Environment:** default profile set, shader disk cache off (`ANYPS5_NO_SHADER_CACHE=1`) so every arm compiles the same shaders, audio muted.

## Result

On the RTX 3080 Ti the emulated flush costs about a quarter of the frame. With a driver probe that decides per GPU whether the hardware already matches (floor/ceil stay emulated), the main menu goes from about 91 to 115 presents per 10 s (+26%) and GPU time from about 104 to 74 ms per frame. All of the saving is in draw passes. On the Radeon 780M the probe already says the hardware matches, so nothing changes there.

## Run 1: test switch, Linux desktop

Build: upstream `a19e7f6fd` + a local test patch that adds two switches (not upstream). A = plain, B = `APS5_TEST_F32_FLUSH_ASSUMED=1` (skip the emulated flush), C = B + `APS5_TEST_NATIVE_FMINMAX=1`. Order A1 B C A2 C2.

| Arm | Presents/10 s | Frame p50 ms | GPU ms/frame | GPU load % | CPU s/10 s | VRAM GB | RAM anon/shmem GB |
|---|---|---|---|---|---|---|---|
| A1 | 87 (86-92) | 115.9 | 107.5 | 98.5 | 19.1 | 7.67 | 1.55 / 6.96 |
| B | 117 (115-119) | 86.1 | 72.9 | 89.5 | 23.2 | 7.45 | 1.50 / 6.91 |
| C | 114 (112-116) | 88.2 | 74.0 | 92.1 | 22.5 | 7.41 | 1.45 / 6.96 |
| A2 | 86 (86-87) | 116.5 | 108.1 | 98.9 | 17.7 | 7.67 | 1.50 / 6.92 |
| C2 | 114 (113-120) | 87.8 | 74.5 | 91.3 | 23.0 | 7.52 | 1.43 / 6.97 |

- In-flight wait p50: about 60 ms in A, 32-34 ms in B and C.
- Non-draw GPU classes are unchanged (fill about 4, storage upload about 3.5 ms/frame): the saving is all inside draw passes.
- Shader compiles are the same in every arm (430 variants, 0 disk cache lines).
- Native fmin/fmax (C) adds nothing on top of B.
- Main menu image is the same in every arm.

But: a first probe found that on this NVIDIA driver 33 of 5472 test cases differ from the emulated flush, so skipping it unconditionally is not exact. All 33 were floor/ceil. That led to run 2.

## Run 2: per-GPU probe, floor/ceil stay emulated, Linux desktop

Build: A = upstream `6d0139cd33`; B3 = A + probe patch (version 2). Every B3 launch logged `f32 denormal flush: hardware (0 of 5472 probe results differ)`. Both float tests pass.

| Arm | Presents/10 s | Frame p50 ms | GPU ms/frame | Top GPU classes ms/frame | GPU load % | VRAM MiB | CPU ms/10 s |
|---|---|---|---|---|---|---|---|
| A (a1) | 92 | 108.7 | 103.2 | draw 91.2, fill 3.4, upload 2.9 | 98.2 | 9318 | 20502 |
| B3 (b1) | 117 | 85.5 | 72.7 | draw 61.0, fill 3.3, upload 2.9 | 89.6 | 9778 | 22886 |
| A (a2) | 93 | 108.3 | 102.9 | draw 90.6, fill 3.4, upload 2.9 | 98.4 | 10284 | 20644 |
| B3 (b2r) | 113 | 88.7 | 75.2 | draw 61.7, fill 4.0, upload 3.3 | 91.7 | 10204 | 26518 |
| A (a3) | 88 | 114.2 | 107.1 | draw 92.9, fill 4.0, upload 3.4 | 98.6 | 10284 | 17881 |

- 0 pipeline creates inside the window, pipeline cache 100% hits in all arms.
- B3 uses more CPU only because it renders more frames.
- Caveat: one of three B3 launches had a shared-memory jump (5.6 to 24.7 GB in 20 s) during boot and was stopped by the memory cap. Two reruns with memory sampling did not repeat it. Most likely a one-off, not ruled out.
- Hollow Knight Silksong (PPSA12544) title screen, one pair: both capped at 60 FPS, GPU 2.4 vs 3.5 ms/frame (one pair at 2-4 ms, not yet a regression), picture identical apart from moving particles.

## Run 3: same probe on AMD Radeon 780M (RADV)

All arms log `f32 denormal flush: hardware (0 of 5472 probe results differ)`, so B behaves like A. Both tests pass.

| Arm | Presents/10 s | Frame p50 | GPU busy/present | Draws/10 s (cost per draw) | CPU total | RSS / VRAM / GTT GiB |
|---|---|---|---|---|---|---|
| A | 51.4 | 193.5 ms | 187.0 ms | 70701 (46 us) | 136% | 8.5 / 1.9 / 11.0 |
| B | 51.2 | 193.0 ms | 186.7 ms | 70116 (46 us) | 139% | 8.6 / 1.8 / 11.7 |

On this machine the D2R menu is CPU-bound on queue worker 0 (99% busy, mostly draw recording at about 46 us per draw).

## Run 4: same probe on Windows laptop (RTX A2000, driver 610.60), Hot Wheels Infinite Rush (PPSA22408)

Build: A = upstream `6d0139cd33` + the GameUpdate "no update" fix; B = A + probe patch v2. All four float tests pass on Windows. B logs `f32 denormal flush: hardware (0 of 5472 probe results differ)`. Order A B A B A B; the table uses the warm pairs 2 and 3 (A-1 aborted at the garage load with the known "still pinned by GPU work" error).

| Phase | Metric | A-2 | B-2 | A-3 | B-3 |
|---|---|---|---|---|---|
| Title idle | Presents/10 s | 36.7 | 37.2 | 36.7 | 36.5 |
| | GPU ms/frame | 112.9 | 107.3 | 111.2 | 112.6 |
| | Draw class ms/10 s | 519 | 468 | 516 | 461 |
| Title to menu | Presents/10 s | 35.4 | 36.4 | 35.5 | 35.5 |
| | GPU ms/frame | 111.1 | 106.8 | 110.4 | 110.6 |
| | Draw class ms/10 s | 621 | 552 | 622 | 545 |
| Menu / garage | Presents/10 s | 8.75 | 9.71 | 9.38 | 9.82 |
| | GPU ms/frame | 156.0 | 150.2 | 155.5 | 151.9 |
| | Draw class ms/10 s | 276 | 228 | 271 | 233 |

- B cuts the draw GPU class by 10-16% in every phase. In Hot Wheels, shadow-publish and storage traffic dominate the frame, so presents move 0-1% on the title and +4-11% in the garage, and GPU ms/frame drops 0-5%.
- Unchanged between arms: other GPU classes (shadow-publish about 1730, storage upload about 890, write-back about 310 ms/10 s), CPU (about 90% of one core on the title), draw cache (about 40 hits of 1950 lookups per 10 s), 0 pipeline cache misses, copies (staging about 1.47 GB in and back, uploads about 12.2 GB, write-backs about 13.6 GB per 10 s, all within 2%), waits (hook syncs about 9.8 s, compute-queue lock about 3.1 s per 10 s), RAM about 7.3 GB, VRAM 3.5-3.7 GB. In-flight wait p50: A 11.7 ms, B 10.1-10.5 ms.
- Castlevania Belmont's Curse (PPSA35399), one pair, inconclusive: A reached gameplay; B stayed on the black loading screen for about 9 minutes after New Game and was stopped. The second B run was stopped before New Game. Plain-main runs on this laptop always reach gameplay, sometimes after a few minutes of loading. Not yet known whether the probe causes the hang; to be rerun.
- No pixel diff yet (screenshots kept).

## Run 5 (2026-10-25): Castlevania loading check and Silksong on plain main, Linux desktop

Builds: A = upstream `6d0139cd33`; B3 = A + probe patch v2. Each runtime relinked from its own build; shader disk cache cold at the start, so b1 and a1 are first boots. Castlevania Belmont's Curse (PPSA35399): boot, New Game, skip the cinematic, then 70 s in the dock scene; medians over 10 s windows from 5 to 70 s after the skip.

| Arm | Flush log line | Presents/10 s | Frame p50 ms | GPU ms/frame | Draw class ms/frame | GPU load % | VRAM MiB | CPU ms/10 s |
|---|---|---|---|---|---|---|---|---|
| b1 B3 (cold) | hardware (0 of 5472) | 76 | 129.6 | 42.7 | 41.7 | 35.6 | 4721 | 25970 |
| b2 B3 | hardware (0 of 5472) | 74 | 134.4 | 33.9 | 32.4 | 36.5 | 4155 | 24863 |
| b3 B3 | hardware (0 of 5472) | 73.5 | 136.1 | 34.0 | 32.6 | 37.1 | 4132 | 24600 |
| a1 A (cold) | none (main never probes) | 71.5 | 139.4 | 36.5 | 34.9 | 37.5 | 4720 | 26890 |
| B3 + `APS5_NO_HW_F32_FLUSH=1` | none (probe skipped) | 72 | 137.9 | 44.7 | 43.7 | 36.0 | 4793 | 24422 |

- **No hang:** all five arms passed the loading screen and reached the same dock scene, with no terminate, Vulkan error or device loss. The single laptop hang (Run 4) did not repeat, so there is no evidence that it comes from the fix.
- This scene is CPU-bound (GPU about 36% busy), so presents barely move. Warm B3 uses 34.0 GPU ms per frame against 36.5 for A (-7%), but A was a cold boot, so that comparison is not clean. With the probe switched off, GPU time is the highest (44.7 ms, one run), which suggests the emulated flush costs GPU time here too.
- **Hollow Knight Silksong (PPSA12544) on plain main A:** Start Game aborts the same way as with the fix, about 97 s in, while loading the first area ("storage image ... memory no longer registered; 135 of 144 pending ranges dropped", then "storing storage image results pending over memory outside the write watch without the guest bytes saved before them is not implemented"). **This is a bug on main, not caused by the fix.**

## Run 6 (2026-10-26): the fix rebased onto a newer main, Linux desktop

Build B4 = upstream `49d1f9b07e` + [nvidia-f32-flush-probe-v2-rebased.patch](../../research/patches/nvidia-f32-flush-probe-v2-rebased.patch). Both commits apply cleanly with `git am`; both tests pass (`agc_float32_flush_control`, `agc_driver_f32_denormal_flush`). Diablo II Resurrected (PPSA03912) main menu, one boot, shader disk cache off, medians over +185..+355 s.

- Probe line: `[float-controls] f32 denormal flush: hardware (0 of 5472 probe results differ from the emulated flush, 42 ms)`.
- Presents 86 per 10 s (85-88), frame p50 116.7 ms, GPU 102.4 ms/frame, GPU load 93.8%, VRAM 10.6 GB, 23.9 s CPU per 10 s, no errors.
- GPU classes per frame: draw 62.4, staging-out 14.8, staging-in 11.3, fill 4.3.
- **The fix still works after the rebase:** the draw class is 62.4 ms/frame, the same as B3 on `6d0139cd33` (61-62 ms; plain main there about 91).
- **New on this main:** staging-out and staging-in classes, together 26 ms/frame and about 20.9 GB each way per 10 s, that were not in any `6d0139cd33` arm. They bring the total back to about 102 ms and 86 presents. This most likely comes from an upstream change between the two mains, not from the patch, but it was not confirmed in this run. Run 7 confirms it.

## Run 7 (2026-10-26): plain main vs the fix on `49d1f9b07e`, Linux desktop

A4 = plain upstream `49d1f9b07e`; B4 = A4 + [the rebased fix](../../research/patches/nvidia-f32-flush-probe-v2-rebased.patch). Order A4 B4 A4 B4. Diablo II Resurrected (PPSA03912) main menu, shader disk cache off, medians over +185..+355 s. No errors, no pipeline creates in the window.

| Arm | Flush log line | Presents/10 s | Frame p50 ms | GPU ms/frame | Top GPU classes ms/frame | GPU load % | VRAM MiB | CPU ms/10 s | Staging in / back per 10 s |
|---|---|---|---|---|---|---|---|---|---|
| a1 A4 | none | 77 | 131.3 | 125.1 | draw 90.0, staging-out 13.7, staging-in 10.1, fill 3.4 | 98.2 | 10607 | 16536 | 18.5 / 18.4 GB (692 regions) |
| b1 B4 | hardware (0 of 5472, 53 ms) | 89 | 113.0 | 99.5 | draw 61.6, staging-out 13.8, staging-in 10.7, fill 4.2 | 93.2 | 10479 | 19946 | 21.6 / 21.6 GB (793 regions) |
| a2 A4 | none | 73 | 138.2 | 131.1 | draw 92.5, staging-out 14.4, staging-in 10.8, fill 4.0 | 99.3 | 10552 | 14784 | 17.5 / 17.5 GB (654 regions) |
| b2 B4 | hardware (0 of 5472, 45 ms) | 86 | 116.1 | 101.8 | draw 61.7, staging-out 14.5, staging-in 11.4, fill 4.4 | 94.3 | 10700 | 20396 | 21.2 / 21.2 GB (766 regions) |

- **The fix still pays on current main:** GPU 125-131 -> 100-102 ms per frame (-21%), presents 73-77 -> 86-89 (+16%). The draw class falls from about 91 to about 62 ms per frame, the same saving as on `6d0139cd33`.
- **The staging traffic comes from upstream, not from the fix:** both arms show it, about 25 ms per frame together. Nearly all staged regions come from reused address-based builds (16,481 of 16,516 in B4), and each region is about 27 MiB, against about 1.2 MiB on `6d0139cd33` (about 819 regions and 1.0 GB per 10 s there).
- **Suspect, not confirmed:** upstream commit `a293f7901b` "perf(agc): stage written-only swept elements on discrete GPUs", which falls between the two mains (it is my own merged PR, [#7618](https://github.com/boykopovar/AnyPS5/pull/7618)) and stages written-only elements into a device-local shadow of up to 256 MiB. A plain-main boot with `APS5_NO_WRITTEN_SHADOW=1` is queued to check it; the first attempt was stopped by the memory cap after a boot-time shared-memory spike (5.7 -> 21.6 GB within 20 s), the same spike seen once before with the fix, so it also happens on plain main (2 of about 13 boots of this menu).

## Which bottleneck moved

On the RTX 3080 Ti the menu was fully GPU-bound (98-99% load) with 4K draw passes dominating. Removing the emulated flush cuts draw-pass time by about a third; the GPU drops to about 90% load and CPU per frame becomes a larger share.

AI-assisted. Tested by me on my own machine.
