# Indirect draw argument reads (Diablo II Resurrected main menu)

Diablo II Resurrected (PPSA03912), Linux desktop (RTX 3080 Ti), upstream `a19e7f6fd`, 2026-10-24. Run: [indirect no-read probe](../perf-data/runs/2026-10-24-d2r-main-menu-indirect-no-read-probe.md).

## What happens

- One DRAW_INDIRECT per frame (count 1, stride 16) stays on the CPU path. Its classification line: `-> cpu (patched SGPR not folded)`. The packet tells the command processor to patch the record's start vertex into s20 and start instance into s21; the recompiler finds no vertex fetch using them (vertexOffsetSgpr / instanceOffsetSgpr = -1, set only by EmbeddedVertexFetch), so `ClassifyIndirectDraw` fails with NotFolded.
- CPU path: `Driver::draw` reads count and arguments up front (`Pm4::ReadDrawCount/ReadDrawArguments`) through `GuestMemory::Read` -> flush hook -> wait for the newest GPU batch writing that range.
- Every 10 s: 86-89 hook syncs (one per frame), 3.2-3.9 s waited, all at DRAW_INDIRECT indirect-args, all "unchanged, in flight unsignaled": the CPU waits ~43 ms for the GPU to finish already submitted work, and the bytes are the same after the wait.

## Upper-bound test

Skipping the read (`APS5_PROBE_INDIRECT_NO_READ=1`, unsafe) removes the stall (3.6 s -> 0) but presents stay at 88 per 10 s: the menu is GPU-bound (96-98% load), so the freed CPU time moves into in-flight wait (57 -> 90-97 ms) and GPU-label waits, and packet drain time doubles.

## Fix shape (not written)

Put the draw on the GPU path: feed s20 from gl_BaseVertex and s21 from gl_BaseInstance (SPIR-V DrawParameters) and use gl_VertexIndex - gl_BaseVertex for the hardware vertex id. Open **#10359** (valenciana-nc) already sources start instance from BaseInstance; the base-vertex half is not covered. #9243 / #9248 (fisherjoey) cache CPU-path indirect draws but keep the read. It only pays once GPU time per frame drops below CPU time.

Related merged work: #7930 (skip empty CPU-path indirect draws), #6931, #5979, #460, #6786, #8066. Closed unmerged: #7894 (non-indexed mesh indirect on GPU).

Hot Wheels Infinite Rush (PPSA22408) also sees all its indirect draws empty-skipped; there `APS5_SYNC_DISPATCH=1` leaves the arguments zero, so it is not a read-too-early race (see [Hot Wheels](hot-wheels.md)).

AI-assisted. Tested by me on my own machine.
