# Test patches and diagnostics

Patches used for the measurements in this folder and in [perf-data](../../perf-data/). None of them is upstream. Most are logging-only or test switches (off by default) made to answer one question; a few are fix prototypes. Each applies to the upstream commit named in the run page that used it; newer main may need a rebase.

| File | Kind | What it does | Used in |
|---|---|---|---|
| `nvidia-f32-flush-probe-v2.patch` | fix prototype (2 commits) | Runs the f32 denormal flush probe on NVIDIA's proprietary driver and keeps the software flush on floor/ceil unless the device declares flush-to-zero | [f32 flush](f32-denormal-flush.md) |
| `gpu-float-emulation-ab.diff` | test switches | `APS5_TEST_F32_FLUSH_ASSUMED=1` (skip the emulated flush), `APS5_TEST_NATIVE_FMINMAX=1` | [f32 flush](f32-denormal-flush.md) |
| `f32-probe-print-diag.diff` | logging | Prints the probe cases that differ from the emulated flush | [f32 flush](f32-denormal-flush.md) |
| `gpu-pass-timing-diag.diff`, `gpu-variant-names-diag.diff`, `gpu-draw-shader-dump-diag.diff` | logging | Names GPU passes by render target, prints the top-40 GPU passes, dumps fragment shaders of chosen passes | D2R main menu runs |
| `data-hit-relocation-v2.patch` | fix prototype | Reuses a draw cache "data-only hit" when only buffer base pointers moved, relocating them instead of rebuilding. Fails `APS5_VERIFY_DRAW_DATA_HITS` on D2R (one stage builds 8 runs vs 9) | [draw cache](draw-cache-per-draw-rework.md) |
| `datahit-words-trace.diff` | logging | `APS5_TMP_DATAHIT_WORDS=<s>`: prints which user words differ on data-only hits | [draw cache](draw-cache-per-draw-rework.md) |
| `committer-split-timers.diff` | logging | `APS5_TMP_COMMITTER_SPLIT=1`: splits the draw committer's lookup/record/keep/pipeline phases into sub-timers | [committer cost](draw-committer-cost.md) |
| `indirect-no-read-probe.diff` | test switch | `APS5_PROBE_INDIRECT_NO_READ=1`: skips the CPU read of indirect draw arguments (unsafe, upper bound only) | [indirect reads](indirect-draw-reads.md) |
| `trace-hooksync-cpu-upload.diff` | logging | `APS5_TRACE_HOOKSYNC_MS=<ms> APS5_TRACE_CPU_UPLOAD_KIB=<KiB>`: per-wait and per-CPU-upload lines (queue, packet, site, address, writer state) | [menu round trip](menu-image-round-trip.md) |
| `trace-upload-layers.diff` | logging | Adds layer range and format to storage upload trace lines | [menu round trip](menu-image-round-trip.md) |
| `test-skip-big-buffer-flush.diff` | test switch | `APS5_TEST_SKIP_BIG_BUFFER_FLUSH_MIB=<MiB>`: skips flushing pending images for buffer bindings at least that big (unsafe, upper bound only) | [menu round trip](menu-image-round-trip.md) |
| `test-join-crossing.diff` | test switch | `APS5_TEST_JOIN_CROSSING=1`: lets the importer join a buffer that crosses an import run boundary | [menu round trip](menu-image-round-trip.md) |
| `precheck-nothing-trace.diff`, `trace-indirect-groups.diff` | logging | Hot Wheels black scenery: why indirect draws are skipped, which indirect groups are empty | [Hot Wheels](hot-wheels.md) |
| `descriptor-web-fold-lane-index.patch` | fix prototype | Folds descriptor-web paths that hold the lane index (follow-up idea to #8077) | [image descriptors](image-descriptors-7459.md) |
| `yotei-blend-unclamped-normalized.patch` | fix prototype | Blending into unclamped normalized colour targets (Ghost of Yotei) | [Ghost of Yotei](ghost-of-yotei-speed.md) |
| `runtime-buffer-presence.diff` | fix prototype | Early version of the buffer-presence-at-run-time change later opened as #9957 | [Ghost of Yotei](ghost-of-yotei-speed.md) |

AI-assisted. Tested by me on my own machine.
