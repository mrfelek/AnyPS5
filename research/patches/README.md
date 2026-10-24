# Test patches and diagnostics

Patches used for the measurements in this folder and in [perf-data](../../perf-data/). None of them is upstream. Most are logging-only or test switches (off by default) made to answer one question; a few are fix prototypes. Each applies to the upstream commit named in the run page that used it; newer main may need a rebase.

| File | Kind | What it does | Used in |
|---|---|---|---|
| `nvidia-f32-flush-probe-v2.patch` | fix prototype (2 commits) | Runs the f32 denormal flush probe on NVIDIA's proprietary driver and keeps the software flush on floor/ceil unless the device declares flush-to-zero | [f32 flush](../f32-denormal-flush.md) |
| `gpu-float-emulation-ab.diff` | test switches | `APS5_TEST_F32_FLUSH_ASSUMED=1` (skip the emulated flush), `APS5_TEST_NATIVE_FMINMAX=1` | [f32 flush](../f32-denormal-flush.md) |
| `f32-probe-print-diag.diff` | logging | Prints the probe cases that differ from the emulated flush | [f32 flush](../f32-denormal-flush.md) |
| `gpu-pass-timing-diag.diff`, `gpu-variant-names-diag.diff`, `gpu-draw-shader-dump-diag.diff` | logging | Names GPU passes by render target, prints the top-40 GPU passes, dumps fragment shaders of chosen passes | D2R main menu runs |
| `data-hit-relocation-v2.patch` | fix prototype | Reuses a draw cache "data-only hit" when only buffer base pointers moved, relocating them instead of rebuilding. Fails `APS5_VERIFY_DRAW_DATA_HITS` on D2R (one stage builds 8 runs vs 9) | [draw cache](../draw-cache-per-draw-rework.md) |
| `datahit-words-trace.diff` | logging | `APS5_TMP_DATAHIT_WORDS=<s>`: prints which user words differ on data-only hits | [draw cache](../draw-cache-per-draw-rework.md) |
| `committer-split-timers.diff` | logging | `APS5_TMP_COMMITTER_SPLIT=1`: splits the draw committer's lookup/record/keep/pipeline phases into sub-timers | [committer cost](../draw-committer-cost.md) |
| `indirect-no-read-probe.diff` | test switch | `APS5_PROBE_INDIRECT_NO_READ=1`: skips the CPU read of indirect draw arguments (unsafe, upper bound only) | [indirect reads](../indirect-draw-reads.md) |
| `trace-hooksync-cpu-upload.diff` | logging | `APS5_TRACE_HOOKSYNC_MS=<ms> APS5_TRACE_CPU_UPLOAD_KIB=<KiB>`: per-wait and per-CPU-upload lines (queue, packet, site, address, writer state) | [menu round trip](../menu-image-round-trip.md) |
| `trace-upload-layers.diff` | logging | Adds layer range and format to storage upload trace lines | [menu round trip](../menu-image-round-trip.md) |
| `test-skip-big-buffer-flush.diff` | test switch | `APS5_TEST_SKIP_BIG_BUFFER_FLUSH_MIB=<MiB>`: skips flushing pending images for buffer bindings at least that big (unsafe, upper bound only) | [menu round trip](../menu-image-round-trip.md) |
| `test-join-crossing.diff` | test switch | `APS5_TEST_JOIN_CROSSING=1`: lets the importer join a buffer that crosses an import run boundary | [menu round trip](../menu-image-round-trip.md) |
| `precheck-nothing-trace.diff`, `trace-indirect-groups.diff` | logging | Hot Wheels black scenery: why indirect draws are skipped, which indirect groups are empty | [Hot Wheels](../hot-wheels.md) |
| `descriptor-web-fold-lane-index.patch` | fix prototype | Folds descriptor-web paths that hold the lane index (follow-up idea to #8077) | [image descriptors](../image-descriptors-7459.md) |
| `yotei-blend-unclamped-normalized.patch` | fix prototype | Blending into unclamped normalized colour targets (Ghost of Yotei) | [Ghost of Yotei](../ghost-of-yotei-speed.md) |
| `runtime-buffer-presence.diff` | fix prototype | Early version of the buffer-presence-at-run-time change later opened as #9957 | [Ghost of Yotei](../ghost-of-yotei-speed.md) |
| `nvidia-f32-flush-probe-v1.patch` | fix prototype, **dropped** | First version: trusted the probe on NVIDIA for all operations. Dropped because 33 of 5472 probe cases (all floor/ceil) differ from the emulated flush on the RTX 3080 Ti, so it was not exact. v2 keeps floor/ceil emulated | [f32 flush](../f32-denormal-flush.md) |
| `data-hit-relocation-v1.patch` | fix prototype, **superseded** | First version of the data-only hit relocation; replaced by v2 | [draw cache](../draw-cache-per-draw-rework.md) |
| `draw-set-reuse.diff` | fix prototype, **not measured yet** | `APS5_DRAW_SET_REUSE=1` (+ `APS5_DRAW_SET_REUSE_MAX`, default 64): reuses a finished descriptor set per shader build and rewrites only the buffer descriptors that changed, instead of a new set per draw. Portable (works where VK_EXT_descriptor_heap is missing, such as RADV). Unit tests pass on and off; the Sonic menu A/B is on hold because all game runs were stopped | [committer cost](../draw-committer-cost.md) |
| `silksong-no-khr-barycentric-on-radv.diff` | fix prototype, **dropped** | Turns off fragment-shader barycentrics on RADV. Removes the Silksong seam but aborts Diablo II Resurrected (a pixel shader needs barycentrics without a vertex shader) and Hot Wheels (mesh emulation over 32 KiB) | [Silksong](../games/hollow-knight-silksong.md) |
| `silksong-force-provoking-first.diff` | test switch, **no effect** | Forces the first-vertex provoking mode; the seam stays | [Silksong](../games/hollow-knight-silksong.md) |
| `silksong-host-interpolation-first-early.diff` | fix prototype, **superseded** | First version of "host interpolation first on RADV", on an older base where the seam stayed (a registration-time prepare kept the barycentric path). Rebuilt on main, it fixed the seam and became #10547 | [Silksong](../games/hollow-knight-silksong.md) |
| `silksong-host-interpolation-logged.diff`, `silksong-host-interpolation-dump.diff` | logging | Print which pixel shaders keep the barycentric path, and dump them | [Silksong](../games/hollow-knight-silksong.md) |
| `gameupdate-call-log.diff` | logging | Logs every GameUpdate call (Hot Wheels update check) | [Hot Wheels](../games/hot-wheels-infinite-rush.md) |

Fix prototypes that became upstream PRs are listed in [upstream-prs.md](../upstream-prs.md) instead.

## Ideas dropped without a published file

| Idea | Why it was dropped |
|---|---|
| Committer key and template memos (memoize the draw key and stage template between draws of the same shape) | Saved about 3-4 us per draw and no visible FPS change while the committer and GPU limits stayed |
| Inline binding flags (FlagVector) | meh7an's #6970 already did it; tested theirs instead (Sonic menu +8%, Castlevania +20%) |
| Per-object pointer relocation (treat words that look like nearby pointers as relocatable) | Castlevania +25-30%, but Astro Bot showed 20 wrong cached draws; the safe "+-1 MiB" rule removed the gain. Needs real pointer provenance |
| Image-table reuse for Ghost of Yotei | linux-best-u2 uses the bindless texture service, where that code takes 0% of the time |
| Removing per-frame waits in menus one by one | Each removed wait just moved to the next reader of the same GPU result; see [how we worked](../how-we-worked.md) |

AI-assisted. Tested by me on my own machine.
