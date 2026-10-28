# Indirect draw argument reads (Diablo II Resurrected main menu)

Diablo II Resurrected (PPSA03912), Linux desktop (RTX 3080 Ti), upstream `a19e7f6fd`, 2026-10-24. Run: [indirect no-read probe](../perf-data/runs/2026-10-24-d2r-main-menu-indirect-no-read-probe.md).

## What happens

- One DRAW_INDIRECT per frame (count 1, stride 16) stays on the CPU path. Its classification line: `-> cpu (patched SGPR not folded)`. The packet tells the command processor to patch the record's start vertex into s20 and start instance into s21; the recompiler finds no vertex fetch using them (vertexOffsetSgpr / instanceOffsetSgpr = -1, set only by EmbeddedVertexFetch), so `ClassifyIndirectDraw` fails with NotFolded.
- CPU path: `Driver::draw` reads count and arguments up front (`Pm4::ReadDrawCount/ReadDrawArguments`) through `GuestMemory::Read` -> flush hook -> wait for the newest GPU batch writing that range.
- Every 10 s: 86-89 hook syncs (one per frame), 3.2-3.9 s waited, all at DRAW_INDIRECT indirect-args, all "unchanged, in flight unsignaled": the CPU waits ~43 ms for the GPU to finish already submitted work, and the bytes are the same after the wait.

## Upper-bound test

Skipping the read (`APS5_PROBE_INDIRECT_NO_READ=1`, unsafe) removes the stall (3.6 s -> 0) but presents stay at 88 per 10 s: the menu is GPU-bound (96-98% load), so the freed CPU time moves into in-flight wait (57 -> 90-97 ms) and GPU-label waits, and packet drain time doubles.

## Fix shape

Put the draw on the GPU path: feed s20 from gl_BaseVertex and s21 from gl_BaseInstance (SPIR-V DrawParameters) and use gl_VertexIndex - gl_BaseVertex for the hardware vertex id. Open **#10359** (valenciana-nc) already sources start instance from BaseInstance; the base-vertex half is not covered. #9243 / #9248 (fisherjoey) cache CPU-path indirect draws but keep the read. It only pays once GPU time per frame drops below CPU time.

Update 2026-10-28 (fix written): #10359 plus my base-vertex half, on main `cc672fdfc6`: the stall goes to 0 with the read kept correct, presents 87-95 -> 100-101 per 10 s, the GPU is the limit after it (SM 99%), picture unchanged; costs 2.3-6 s per 10 s of shader-analysis CPU, and verifier runs are still pending ([run](../perf-data/runs/2026-10-28-d2r-main-menu-indirect-gpu-path-ab.md), [diff](patches/indirect-gpu-path-10359-plus-basevertex-v2.diff)).

Update 2026-10-28: on main `cc672fdfc6` with the float fix, the no-read probe removes the stall (3.4-3.7 s per 10 s, one indirect draw per frame, program 0x2b5167e00) and gives +6-11% presents on the D2R menu; the GPU is the limit again afterwards. A real fix has to defer or avoid that read without dropping the draw ([run](../perf-data/runs/2026-10-24-d2r-main-menu-indirect-no-read-probe.md), Run 2).

Survey 2026-10-28 (Windows laptop): Castlevania Belmont's Curse (PPSA35399) has no indirect draws or dispatches at all; Hot Wheels Infinite Rush (PPSA22408) has CPU-path indirect draws for another reason ("non-vertex path") costing only 20-30 ms per 10 s; Metal Gear Solid Peace Walker (PPSA05268) does not boot on current main on Windows. So far the large stall is specific to the Diablo II menu ([survey](../perf-data/runs/2026-10-28-indirect-draw-survey.md)).

Related merged work: #7930 (skip empty CPU-path indirect draws), #6931, #5979, #460, #6786, #8066. Closed unmerged: #7894 (non-indexed mesh indirect on GPU).

Hot Wheels Infinite Rush (PPSA22408) also sees all its indirect draws empty-skipped; there `APS5_SYNC_DISPATCH=1` leaves the arguments zero, so it is not a read-too-early race (see [Hot Wheels](hot-wheels.md)).

AI-assisted. Tested by me on my own machine.
