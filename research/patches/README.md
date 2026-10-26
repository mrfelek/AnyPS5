# Test patches and diagnostics

Patches used for the measurements in this folder and in [perf-data](../../perf-data/). None of them is upstream. Most are logging-only or test switches (off by default) made to answer one question; a few are fix prototypes. Each applies to the upstream commit named in the run page that used it; newer main may need a rebase.

| File | Kind | What it does | Used in |
|---|---|---|---|
| `nvidia-f32-flush-probe-v2.patch` | fix prototype (2 commits) | Runs the f32 denormal flush probe on NVIDIA's proprietary driver and keeps the software flush on floor/ceil unless the device declares flush-to-zero | [f32 flush](../f32-denormal-flush.md) |
| `nvidia-f32-flush-probe-v2-rebased.patch` | fix prototype (2 commits) | The same fix rebased onto upstream `49d1f9b07e`; applies cleanly, tests pass, draw time unchanged on the Diablo II Resurrected menu | [f32 flush](../f32-denormal-flush.md) |
| `gpu-float-emulation-ab.diff` | test switches | `APS5_TEST_F32_FLUSH_ASSUMED=1` (skip the emulated flush), `APS5_TEST_NATIVE_FMINMAX=1` | [f32 flush](../f32-denormal-flush.md) |
| `f32-probe-print-diag.diff` | logging | Prints the probe cases that differ from the emulated flush | [f32 flush](../f32-denormal-flush.md) |
| `gpu-pass-timing-diag.diff`, `gpu-variant-names-diag.diff`, `gpu-draw-shader-dump-diag.diff` | logging | Names GPU passes by render target, prints the top-40 GPU passes, dumps fragment shaders of chosen passes | D2R main menu runs |
| `data-hit-relocation-v3.patch` | fix prototype, **not proven yet** | v2 plus a run-order check. 2026-10-25: no verifier failures on D2R, Hot Wheels and Silksong, but those runs did not print the relocated-stage counts (that needs `APS5_TRACE_DRAW_CACHE=1`); relocation does fire on the Hot Wheels title (82-84 stages per 10 s). On the Sonic 2 menu with the trace on, the verifier checked about 130,000 per 10 s with no mismatch, but relocation fired only about 150 times per 10 s, so no speed effect there. Still needs a verifier run with the trace on in a scene where it fires a lot | [run](../../perf-data/runs/2026-10-24-d2r-main-menu-amd-draw-cache-relocation-check.md) |
| `data-hit-relocation-v4.patch` | test-only counters | v3 plus three counters saying why a cached stage was passed over. Sonic 2 menu: about 600,000 per 10 s for a changed fixed word, only a few thousand for moved layout or data | [run](../../perf-data/runs/2026-10-26-sonic-s2-menu-draw-cache-pass-over.md) |
| `data-hit-relocation-v5.patch` | test-only counters | v4 plus a breakdown of the changed fixed words and 32 logged samples. Sonic 2 menu: they are ring offsets in user word 12 read as values | [run](../../perf-data/runs/2026-10-26-sonic-s2-menu-draw-cache-fixed-words.md) |
| `data-hit-relocation-v2.patch` | fix prototype, **superseded** | Reuses a draw cache "data-only hit" when only buffer base pointers moved, relocating them instead of rebuilding. Adds a page-boundary fix over v1, but still fails `APS5_VERIFY_DRAW_DATA_HITS` on the D2R menu (2026-10-25: one stage's contents differ from a fresh build), so not correct yet. **Way forward:** know exactly which words are pointers (recompiler provenance), or pass ring offsets as data | [draw cache](../draw-cache-per-draw-rework.md) |
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
| `nvidia-f32-flush-probe-v1.patch` | fix prototype, **ruled out** | First version: trusted the probe on NVIDIA for all operations. Ruled out because 33 of 5472 probe cases (all floor/ceil) differ from the emulated flush on the RTX 3080 Ti, so it was not exact. **Instead:** v2, which keeps floor/ceil emulated | [f32 flush](../f32-denormal-flush.md) |
| `data-hit-relocation-v1.patch` | fix prototype, **superseded** | First version of the data-only hit relocation. Fails the verifier on the D2R menu (one stage keeps 8 runs where a fresh build has 9); replaced by v2 | [draw cache](../draw-cache-per-draw-rework.md) |
| `draw-set-reuse.diff` | fix prototype, **ruled out** | `APS5_DRAW_SET_REUSE=1` (+ `APS5_DRAW_SET_REUSE_MAX`, default 64): reuses a finished descriptor set per shader build and rewrites only the buffer descriptors that changed. Works (about 30% fewer descriptor writes on the D2R character select, Radeon 780M; 41% fewer per draw on the Sonic 2 menu, RTX 3080 Ti), but cost per draw and FPS do not move on either: descriptor updates are about 1.6 of about 46 us per draw. **Instead:** the larger pieces: the vectors phase (76.8 of 118.5 us per draw packet), reading empty indirect draws before skipping them (about 5.2 ms each, 5.5 s per 10 s), and per-draw buffer snapshots (3.3 us) | [run](../../perf-data/runs/2026-10-25-d2r-character-select-amd-draw-set-reuse.md) |
| `silksong-no-khr-barycentric-on-radv.diff` | fix prototype, **ruled out** | Turns off fragment-shader barycentrics on RADV. Removes the Silksong seam but aborts Diablo II Resurrected (a pixel shader needs barycentrics without a vertex shader) and Hot Wheels (mesh emulation over 32 KiB). **Instead:** host interpolation first, only for shaders that can use it (#10547) | [Silksong](../games/hollow-knight-silksong.md) |
| `silksong-force-provoking-first.diff` | test switch, **ruled out** | Forces the first-vertex provoking mode; the seam stays, so the vertex order is not the cause | [Silksong](../games/hollow-knight-silksong.md) |
| `silksong-host-interpolation-first-early.diff` | fix prototype, **superseded** | First version of "host interpolation first on RADV", on an older base where the seam stayed (a registration-time prepare kept the barycentric path). Rebuilt on main, it fixed the seam and became #10547 | [Silksong](../games/hollow-knight-silksong.md) |
| `silksong-host-interpolation-logged.diff`, `silksong-host-interpolation-dump.diff` | logging | Print which pixel shaders keep the barycentric path, and dump them | [Silksong](../games/hollow-knight-silksong.md) |
| `gameupdate-call-log.diff` | logging | Logs every GameUpdate call (Hot Wheels update check) | [Hot Wheels](../games/hot-wheels-infinite-rush.md) |

Fix prototypes that became upstream PRs are listed in [upstream-prs.md](../upstream-prs.md) instead.

## Approaches ruled out without a published file

Proven not to be the way, with the direction to take instead.

| Approach | Why it is ruled out | Way to go instead |
|---|---|---|
| Committer key and template memos (memoize the draw key and stage template between draws of the same shape) | Saved about 3-4 us per draw and no visible FPS change while the committer and GPU limits stayed | Remove the larger per-draw pieces (vectors phase, empty indirect reads, buffer snapshots); descriptor set reuse is measured and ruled out |
| Inline binding flags (FlagVector) | meh7an's #6970 already did it; tested theirs instead (Sonic menu +8%, Castlevania +20%) | Test existing PRs before writing our own |
| Per-object pointer relocation (treat words that look like nearby pointers as relocatable) | Castlevania +25-30%, but Astro Bot showed 20 wrong cached draws; the safe "+-1 MiB" rule removed the gain | Pointer provenance from the recompiler |
| Image-table reuse for Ghost of Yotei | linux-best-u2 uses the bindless texture service, where that code takes 0% of the time | Profile the build actually used before optimizing |
| Removing per-frame waits in menus one by one | Each removed wait just moved to the next reader of the same GPU result; see [how we worked](../how-we-worked.md) | Keep GPU results on the GPU instead of round-tripping them through guest memory ([structural analysis](../structural-analysis.md)) |

AI-assisted. Tested by me on my own machine.
