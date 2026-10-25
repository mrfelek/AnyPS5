# f32 denormal flush on NVIDIA

Runs: [f32 flush probe A/B](../perf-data/runs/2026-10-24-d2r-main-menu-f32-flush-ab.md) (Linux desktop RTX 3080 Ti, AMD mini PC Radeon 780M, Windows laptop RTX A2000). Patch: [patches/nvidia-f32-flush-probe-v2.patch](patches/nvidia-f32-flush-probe-v2.patch).

## Problem

NVIDIA's proprietary driver does not report `shaderDenormFlushToZeroFloat32`, so `Float32FlushControlFor` never runs the startup probe there, and every `v_add_f32`, `v_mul_f32` and fused multiply-add keeps the software flush (about 20 integer ops each). In 4K pixel shaders that is most of the GPU time on NVIDIA.

## Prototype

Run the same probe as on MoltenVK: with no execution mode declared, compare the driver's default f32 handling with the emulated flush.
- On the RTX 3080 Ti (Linux 615.71.09) the probe first failed in 33 of 5472 results, all `v_floor_f32` and `v_ceil_f32` of denormal inputs: the driver flushes add, multiply and fma by default but not the inputs of floor and ceil.
- Version 2 keeps the software flush on floor and ceil unless the device declares DenormFlushToZero 32. The probe then matches (0 of 5472) on both NVIDIA GPUs tested; RADV, which declares the mode, is unchanged.

## Results

| Machine / scene | Before | After | Notes |
|---|---|---|---|
| RTX 3080 Ti, Diablo II Resurrected (PPSA03912) main menu, 4K, cache off | 92 / 93 / 88 presents per 10 s, GPU ~104 ms/frame | 117 / 113, GPU ~74 ms/frame | +26%, all in the draw class (91 -> 61 ms); screenshots identical |
| RTX A2000 laptop, Hot Wheels Infinite Rush (PPSA22408) | draw class 519-622 ms/10 s | 461-552 | draw -10-16% in every phase; presents +0-1% title, +4-11% garage (frame dominated by copies) |
| Radeon 780M (RADV), D2R menu and Hot Wheels garage | 51.4 presents | 51.2 | probe already "hardware" on main; no change |
| RTX 3080 Ti, Castlevania Belmont's Curse (PPSA35399) dock scene, 2026-10-25 | 36.5 GPU ms/frame (cold boot) | 33.9-34.0 warm | CPU-bound, presents 71.5 vs 73.5-74; probe switched off: 44.7 ms; no hang in 5 arms |
| RTX 3080 Ti, Hollow Knight Silksong (PPSA12544) title | 60 FPS cap, GPU 2.4 ms | 60 FPS, GPU 3.5 ms | one pair, not yet a regression; picture identical apart from particles |

Open before an upstream PR:
- Castlevania Belmont's Curse (PPSA35399): one laptop run with the fix stayed on the loading screen after New Game. Not repeated: on the desktop (2026-10-25) all five arms, three of them with the fix, passed loading.
- Silksong's Start Game abort ("storing storage image results pending over memory outside the write watch ... is not implemented") also happens on plain main (2026-10-25), so it is a main bug, not the fix.
- One desktop boot with the fix had a shared-memory spike (5.6 -> 24.7 GB in 20 s), not repeated in two logged boots.

- 2026-10-26: the fix rebased onto upstream `49d1f9b07e` ([patch](patches/nvidia-f32-flush-probe-v2-rebased.patch)) applies cleanly and keeps the Diablo II Resurrected menu draw class at 62 ms/frame. That main adds about 26 ms/frame of staging traffic, so presents read 86; a plain-main boot on `49d1f9b07e` is still needed to confirm the staging comes from upstream ([run 6](../perf-data/runs/2026-10-24-d2r-main-menu-f32-flush-ab.md)).

The earlier test switch (`APS5_TEST_F32_FLUSH_ASSUMED=1`, [patches/gpu-float-emulation-ab.diff](patches/gpu-float-emulation-ab.diff)) gave +34% but is not exact on NVIDIA because of the floor/ceil cases.

AI-assisted. Tested by me on my own machine.
