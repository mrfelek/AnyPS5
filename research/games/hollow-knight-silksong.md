# Hollow Knight Silksong (PPSA12544)

Everything I tested on this game, in one place. Upstream discussion: [D#726](https://github.com/boykopovar/AnyPS5/discussions/726). Machines: AMD mini PC (Radeon 780M, RADV, Mesa 26.0.8) and Linux desktop (RTX 3080 Ti). Specs: [machines.md](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/machines.md). Game version 1.0.30021.

## Where it gets to

- **Radeon 780M (RADV):** menu and the first area (tut_01) run. Before the fix below there was a diagonal seam across the whole screen (seen since at least 13 October).
- **RTX 3080 Ti:** title screen at the 60 FPS cap, about 2.4 ms of GPU time per frame.
- **Start Game aborts on current main (RTX 3080 Ti, 2026-10-25):** about 97 s in, while loading the first area, the log shows "storage image ... memory no longer registered; 135 of 144 pending ranges dropped" and then "storing storage image results pending over memory outside the write watch without the guest bytes saved before them is not implemented", and the game terminates. Plain main does the same as main plus my float fix, so the fix is not the cause. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-d2r-main-menu-f32-flush-ab.md) (Run 5)

## The AMD seam: cause and fix

- The seam comes from the final full-screen pass (6 indices, plain vertex + pixel shader). Its pixel shader interpolation was lowered to `PerVertexKHR` + `gl_BaryCoordKHR`, and on RADV the per-vertex order disagrees with the barycentrics on the second triangle (most likely a Mesa bug).
- **Fix: [#10547](https://github.com/boykopovar/AnyPS5/pull/10547)** (mine, prefers host interpolation on RADV). Pixel shaders are first translated with normal host interpolation; only shaders that cannot use it fall back to the native barycentric path. `APS5_NO_HOST_INTERPOLATION_FIRST=1` turns it off. With it the 780M shows no seam in the menu or tut_01, and Diablo II Resurrected and Hot Wheels still run. GPU tests all pass, no new validation errors. Approved, waits merge.
- Ruled out on the way: `APS5_STORE_AT_FLIP`, `APS5_NO_RECT_INDIRECT`, `APS5_NO_GPU_INDIRECT_DRAW`, `APS5_NO_DRAW_INPUTS_IN_PLACE`, validation errors, the rect-list 4th corner, provoking vertex first.
- A broader fix (turning off fragment barycentrics on RADV) also removed the seam but broke Diablo II Resurrected (a pixel shader needs barycentrics without a vertex shader) and Hot Wheels (mesh emulation over 32 KiB), so it is ruled out. The narrower change above (host interpolation first) is the way.

## Other tests

- **Float denormal flush probe** (my fix, not upstream yet), title screen on RTX 3080 Ti, one pair: both at the 60 FPS cap, GPU 2.4 vs 3.5 ms per frame (one pair only, not yet a regression), picture identical apart from moving particles. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-d2r-main-menu-f32-flush-ab.md)

AI-assisted. Tested by me on my own machine.
