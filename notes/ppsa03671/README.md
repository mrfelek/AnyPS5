# PPSA03671 (01.001.005): investigation record

What was tried, what worked, what failed, the numbers, and how to reproduce each step.

This is meant as a reference for whoever picks this title up next. Everything below is measured; failures and wrong guesses are included on purpose, so they don't have to be repeated. Raw log excerpts are in the replies in [discussion #5516](https://github.com/boykopovar/AnyPS5/discussions/5516). No game data is in this branch: no captures, dumps or memory, only code, scripts and notes.

**Hardware and software**
- **NVIDIA:** RTX 3080 Ti 12 GB, driver 615.71.09, Linux 7.3, Ryzen 9 5950X, 32 GB RAM.
- **AMD:** Radeon 780M (Phoenix, 29 GB shared memory), Mesa 26.0.8 RADV, Linux 7.0.
- **Builds:** Release. Base `main` plus the PRs named below, plus a local prototype: this branch, `wip/ppsa03671-record`. Its last commits hold the diagnostics of sections 6–8; section 10 lists what's where.
- **Every run:** started from launch, headless (kwin offscreen on NVIDIA, the box's own display on AMD). Input comes from `APS5_PAD_INPUT_FILE`, which takes a cross written at a set time.

---

## 0. Where it stands

| | NVIDIA 3080 Ti | Radeon 780M |
|---|---|---|
| Logos, forest, Screen Reader dialog | yes | yes |
| Initial Setup menu | **yes, drawn in full since tonight** (it showed only its bottom-right hints before, see section 7) | yes |
| New Game → opening cinematic | black for at least 4.5 min after New Game, at ~0.25 FPS; not reached | **yes**, about 2 min after New Game, but only with the ray-tracing kernel skipped |
| Ray-tracing kernel `0x11d049aa00` | planned, compiled, runs; output unverified | compiles only outside the game, in 34 min with ~66 GB of RAM plus swap, and the game doesn't reuse that result (section 5) |
| Frame time in the forest/menu | ~3.75 s per frame, ~2.8 s of it on the GPU | ~12 FPS with the kernel skipped |

The current blocker is frame time on NVIDIA. The game's own progress (the menu filling in, the load after New Game) advances per frame, so at 4–6 s per frame it takes minutes or doesn't happen within a run.

---

## 1. Settings used, and what each is for

These are the switches the runs that got furthest use. The ones marked "prototype" exist only in the prototype tree.

| Switch | What it does | Why it's here |
|---|---|---|
| `APS5_TEXTURE_DOWNSCALE=1` | drops the top mip of large block-compressed textures | keeps the 780M within memory; `=2` didn't help further |
| `APS5_LAZY_TABLES=1` + `APS5_DIAG_TABLE_USAGE=1` (prototype) | builds only the texture-table entries shaders actually read; the rest borrow a texture of the same shape | the big tables (section 2) |
| `APS5_DIFF_IN_PLACE=1` (prototype) | diffs big writable regions against guest memory instead of keeping a CPU copy | 780M memory (section 2) |
| `APS5_HOST_IMPORT_MIB=12288` | raises the host-import budget | 780M lost stores and GPU hangs (section 2) |
| `APS5_DIAG_IGNORE_STENCIL_EXPORT=1` (prototype) | skips stencil-export replays the emulation can't do safely | NVIDIA stop at `0x11d01d0900` (section 3) |
| `APS5_EXP_ONLY=11d049aa00`, `APS5_EXP_DIRECT_CHASE=1`, `APS5_EXP_FOREIGN_RECORDS=1`, `APS5_EXP_DESCRIPTOR_DATA=1`, `APS5_EXP_NULL_TYPED_LOADS=1` (prototype) | turn on the local planning experiments for the ray-tracing kernel only | section 4 |
| `APS5_SKIP_SHADER=11d049aa00` (upstream) | skips that kernel's dispatches | how the 780M gets past the menu |
| `ANYPS5_NO_SHADER_CACHE=1` | turns off the emulator's own shader cache | needed with lazy tables |
| `__GL_SHADER_DISK_CACHE_SIZE=4000000000` | raises the NVIDIA shader disk cache to 4 GB | the compiled kernel alone takes about 0.5–0.7 GB in it |

---

## 2. Intro and memory

**The texture tables.** The first scene's dispatches and draws bind one bindless texture table each, of 9,000–12,600 slots, with about 7,500–8,000 distinct textures. Built in full, that's about 5 GB of copied textures per dispatch. Shaders read only about 200–270 of the 12,600 slots: `[diag-tableuse] ... 12634 distinct slots bound, 202 read by shaders`.

| | Before | With lazy tables |
|---|---|---|
| 12.4k-entry dispatch on NVIDIA | 595 ms | 9–30 ms |
| VRAM on NVIDIA | 10.7 GB | 5.8 GB |
| Intro logos frame on NVIDIA | 112 ms | 56 ms |
| 8.9k-entry dispatch on the 780M | 4–6 s | 102 ms |
| GTT during the logos on the 780M | 11.9 GB | 8.5 GB |

**780M OOM, first cause.** An `LD_PRELOAD` logger for big allocations found it: `GuestBufferMemory::copyRegion` copies a 2.67 GiB writable region (`0x1210000000+0xab000000`) into a staging buffer, and also into `region.uploaded`, a CPU vector kept for the write-back diff. That happened about 330 times per 12 minutes, about 5.4 GB each time.
- **Fix (prototype `APS5_DIFF_IN_PLACE=1`):** regions of 64 MiB or more that are writable and not sparse skip the CPU copy. The write-back diffs each 64 KiB block against guest memory while it's unchanged since the upload. 656,998 blocks were diffed with only 5 conflicts, and anonymous memory stayed at 5.3 GB instead of 7–8 GB.

**780M GPU hangs (ring timeouts, `vkQueueSubmit -4`).** A shader stores through BDA into `0x1130000000+0x9c600000` (2.4 GiB). Past the host-import budget (2,829 MiB by default there), that range is served by a mirror that is read-only in the BDA table: `BDA access failed ... reason=2`, 266–344 times per run. Lost stores then hang the GPU.
- **Fix:** `APS5_HOST_IMPORT_MIB=12288` gave 0 failures, no hang, and 22.5 GB used with 7.4 GB free. `6144` was not enough.

**Still open on the 780M:** the guest's own shared memory grows from about 8 to about 20 GB as the level loads. That's real game memory, so a 29 GB iGPU box needs the remaining GPU-side copies cut (staging, mirrors, retained pools).

---

## 3. Stencil export, NVIDIA only

- **The shader:** pixel shader `0x11d01d0900` exports its stencil reference, up to 256 values, about 28 draws per 5 minutes.
- **Its state:** `DB_DEPTH_CONTROL=007007e1` (stencil `ALWAYS`, depth off), `DB_STENCIL_CONTROL=00030030` (zpass `REPLACE_TEST`), `DB_SHADER_CONTROL=00000043` (Z and stencil-test-value export, kill), `DB_STENCILREFMASK=01ffff01`.
- **Why only NVIDIA:** NVIDIA has no `VK_EXT_shader_stencil_export`, so the driver replays the draw once per stencil value with a fixed reference. That replay refused this shader.

What I tried:
- **Failed:** a rule accepting its `ReadFirstLane` of a per-pixel `SelectU32` tree. It passes `StencilReplaySafe`, then `MaskReplaySafety` refuses the EXEC/VCC mask branches. It would also depend on same-triangle wave packing, so it's not a PR.
- **Worked (prototype):**
  - stencil replay of triangle strips: winding-free, or culled through a front-face-flipped pipeline for odd triangles;
  - a driver-side skip of the unsafe replays (`APS5_DIAG_IGNORE_STENCIL_EXPORT=1`).
- **Next NVIDIA-only stop, also covered by the strip replay:** `stencil replay supports direct triangle lists without restart, mesh or tessellation`.
- **Diagnostics I used (prototype):**
  - `APS5_DIAG_STENCIL_DRAWS=1`: logs per draw the fragment hash, the export flag, stencil state and counts.
  - `APS5_DIAG_DRAW_REGS_FOR=<hex address>`: prints that program's `DB_*` and `CB_*` registers.
  - Matching prepared programs by SPIR-V hash did **not** work, because the hashes differ per variant. Matching by code address does.

---

## 4. The recompiler gap in the ray-tracing kernel `0x11d049aa00`

**The stop.** On both GPUs: `GetSamplerResource dword 0 is not a valid runtime value; chain: ReadConstBuffer@pc=0xb600 ... ReadFirstLane(SelectU32 ...)`. [#7395](https://github.com/boykopovar/AnyPS5/pull/7395) covers the same shape at `pc=0xbb28`, but not this one. j2m304 reported the same stop on Windows with an RTX 4080 SUPER, around frame 1038.

**What it is.** A BVH walk over linked records. Descriptors are reached through record pointers, and the next pointer is sometimes loaded through the current one.

**The steps that made it plannable, as PRs** (each with focused tests that fail without its change):
- **[#16472](https://github.com/boykopovar/AnyPS5/pull/16472), direct pointer-chase step (on [#9749](https://github.com/boykopovar/AnyPS5/pull/9749)):** the next record pointer is loaded straight through the current one.
- **[#16631](https://github.com/boykopovar/AnyPS5/pull/16631), chase depth 4 → 8 (on [#16472](https://github.com/boykopovar/AnyPS5/pull/16472)):** the chase at `pc=0x2a9a8` has 5 sites and depth 5. blawesom confirmed it on an RX 9070 XT with the validation layer, 32 of 32 tests.
- **[#16812](https://github.com/boykopovar/AnyPS5/pull/16812), plain reads through a re-read V# (on [#9969](https://github.com/boykopovar/AnyPS5/pull/9969)):** it reads words 1 and 2 of a T# as plain values to decode the image size:
  ```
  %27336 = ReadConstBuffer %27335, %27326  [pc=0xee70 off=0x4]
  %27337 = ReadConstBuffer %27335, %27326  [pc=0xee70 off=0x8]
  %27352 = IAdd32 (BitwiseOr32 (%27336 >> 0x1e), (%27337 << 2) & 0xfffc), 1      width
  %27355 = IAdd32 ((%27337 >> 0xe) & 0x3fff), 1                                  height
  ```
- **[#16814](https://github.com/boykopovar/AnyPS5/pull/16814), a re-read V#'s words as the next pointer (on [#16812](https://github.com/boykopovar/AnyPS5/pull/16812)):** the V# at P+0x10 is both a T# array's buffer and, through its words 0 and 1, the next record pointer:
  ```
  %20169..%20172 = LoadAddressU32 %20168  [pc=0xd0cc off=0x10..0x1c]
  %20180 = GetBufferResource %20169, %20170, %20171, %20172
  %21191 = Phi [%13015, ...], [%20614, ...]      the next pointer's high word
  ```
- **Writing the tests:** I assembled the test shaders with `llvm-mc -triple=amdgcn -mcpu=gfx1030`, which reproduces hand-written encodings exactly. A V# that is read again at dispatch needs its records registered as guest allocations in page-aligned memory; otherwise the BDA reads fault with `Unmapped`.

**Still local hacks (not PR-ready):**
- a second record table at `pc=0xef7c`;
- a TYPE 2 V# used for loads, bound as null (`[exp-typed] ... has TYPE 2: bound as a null V#`);
- records from a foreign origin.

**State of the kernel.** Planned, compiled and running on NVIDIA. Its output is **unverified**:
- there's nothing to compare it with yet;
- the log repeats `deferred write-back failed: image table: shader 0x11d049aa00 stage 4 pc 0xba08 selected the descriptor at 0x10a0000070: outside the snapshot`, so some of its lookups get a placeholder;
- lazy tables can hand it a borrowed texture for a frame.

**Skipping it isn't free.** Its output feeds later passes. In a replay with it skipped, a later mesh draw asked for 2,045 × 2,149 workgroups, past the 4,194,304 limit that both GPUs report as `maxMeshWorkGroupTotalCount`. The game itself, skipping it from boot, doesn't crash, but later passes may get wrong inputs.

---

## 5. Compiling the ray-tracing kernel

**Its SPIR-V is 2,573,271 words** (3.44M before optimization), about 78 SPIR-V words per guest code word. Translating guest code to SPIR-V takes only 246 ms (`compute shader 0x11d049aa00 recompile took 246 ms (2573271 SPIR-V words, 360234 captured regions)`). The cost is in the GPU driver's compile of that SPIR-V. The table and pointer-chase lookups are emitted inline at every access, which is where the size comes from.

| Attempt | Result |
|---|---|
| NVIDIA, first compile | about 18 minutes of black screen, two threads in `libnvidia-gpucomp`; the cache grew by about 540 MB |
| NVIDIA, cached | the scene about 2 minutes in |
| NVIDIA, cache miss after a shader change, 25 min run, 25 GB cap | **failed**, the compile didn't finish |
| NVIDIA, same, 27 GB cap plus 24 GB swap | finished in 12 minutes |
| RADV, inside the game | **OOM**, killed at about 15 GB anonymous memory |
| RADV, inside the game, +16 GB swap | **OOM**, the GPU's pinned memory leaves too little |
| RADV, outside the game, 26 GB RAM + 16 GB swap | **OOM after 2 min** at 26 GB + 15.4 GB swap, still growing |
| RADV, outside the game, `RADV_DEBUG=llvm` | **refused:** `captured SPIR-V version exceeds enabled device support` (the capture was made for ACO's device features) |
| RADV, outside the game, 26 GB RAM + 82 GB swap | **worked:** 34 min (`pipeline_create` 2,044,026 ms), peak RSS 27.2 GB plus about 40 GB of swap; a 2.8 MB Mesa cache entry |
| RADV, game run right after that | **cache miss:** the game built byte-identical SPIR-V (1,689,074 words, `recompile took 219 ms`), logged `[dispatch] creating a pipeline for 1689074 SPIR-V words` and compiled again; presents stopped at about 70 s, no OOM in 630 s |
| RADV, inside the game, 29 GB RAM + 82 GB swap | reached the kernel at about 2 min and was compiling at 29 GB RAM + 42 GB swap; **stopped by hand after 8 min**, so not finished |

The other big pipeline, `0x11d0376e00` (1,565,212 words), compiles fine on RADV.

**Why the standalone result isn't reused (not verified):** `agc_compute_pipeline_replay` creates its device with `VulkanDevice::CompileOnly`, which has no window. So it enables no `VK_KHR_swapchain` and no other presentation extensions, while the game's device does. Mesa's cache key may include the device's enabled extensions and features, so the two keys differ. A fix would be to let the tool enable exactly the game's extension and feature list. To check it, compare the Mesa cache entry the game writes with the tool's, or run the tool with the game's extension list.

On the RADV runs here, the kernel is the AMD build (1,689,074 words, `required_subgroup_size` 32); the NVIDIA build is 2,573,271 words.

**How to compile a pipeline outside the game** (any build can capture; the tool needs `-DANYPS5_ENABLE_SPIRV_TOOLS=ON`, so I used a separate build directory to keep the game's build unchanged):

```sh
# 1. capture: an EMPTY directory of its own (not the run's log directory, or the capture stops the title)
APS5_DUMP_COMPUTE_PIPELINES=$HOME/cpdump APS5_DUMP_COMPUTE_MIN_WORDS=1000000 ./app.elf
#    -> cpdump/compute-<identity>/capture.aps5cp, written before the driver compiles

# 2. compile alone, in a memory-capped scope, so a runaway compile can't take the machine down
cmake -S . -B build-tools -G Ninja -DCMAKE_BUILD_TYPE=Release -DANYPS5_ENABLE_SPIRV_TOOLS=ON
ninja -C build-tools agc_compute_pipeline_replay
systemd-run --user --scope -p MemoryMax=26G -p MemorySwapMax=infinity \
  build-tools/core/libs/prx/libSceAgcDriver/agc_compute_pipeline_replay \
  cpdump/compute-<identity>/capture.aps5cp --output result.json
```

The driver's own disk cache keeps the result (Mesa's `~/.cache/mesa_shader_cache`, NVIDIA's `GLCache`). A later game run with byte-identical SPIR-V, layout and flags then loads it instead of compiling. Any change to the recompiler, or to a switch that affects emitted code, invalidates it.

**Conclusion:** the kernel has to get much smaller in SPIR-V, with the lookups emitted once as functions and called from each access. That's the only fix for RADV, and it would also make the NVIDIA compile and cache misses cheap.

---

## 6. The frame recorder and replay for this title

`APS5_FRAME_CAPTURE` records a few frames at the driver boundary, and `agc_frame_replay` replays them with no game running. Once the caches were warm, one replay of these frames took about 40 s instead of a 5–10 minute game run.

**Capturing:**
```sh
APS5_FRAME_CAPTURE=$HOME/cap APS5_FRAME_CAPTURE_TRIGGER=$HOME/cap.trigger APS5_FRAME_CAPTURE_FRAMES=3 ./app.elf
echo 3 > $HOME/cap.trigger     # at the moment of interest; the capture starts at the next frame boundary
```
- **Frame boundaries do work here:** the title flips through submissions with flip packets, counted in `Submit`.
- **The trigger timing matters, and I didn't find out why:** a trigger written at 235 s never started a capture, although boundaries kept coming and the recorder stayed in `Waiting`. A trigger at 180 s worked. Three menu frames came to 2.1 GB on disk, a 3.9 GB snapshot plus 0.8 GB of deltas.
- **Bug, fixed locally:** the snapshot skipped GPU-only allocations, those with CPU protection 0 and a GPU bit. The CPU can't read them, but the driver does, so the replay stopped with `guest memory is not readable at 0xb214c00000 (range 0xb214c00000+0x40000)`. In `FrameRecorder::committedRanges` I changed `if (!allocation->readable) continue;` to `if (!allocation->readable && !allocation->gpu) continue;`. That added 108 ranges and 33 MB.

**Replaying:**
```sh
agc_frame_replay $HOME/cap --frames out/           # writes reference-N.bmp and replay-N.bmp
agc_frame_replay $HOME/cap --repeat 2              # the second pass is warm: compile cost removed
```
- **Run it from a directory where `shader_cache` points to the title's own,** so the title's pipeline cache is used.
- **Use the same switches as the title,** especially `APS5_DIAG_TABLE_USAGE=1` with lazy tables. Without it every table entry gets built, and the replay reached 27 GB before its first submission. That was my mistake.
- **Memory:** with the kernel compiling, the replay peaked at 26 GB of RAM plus 2 GB of swap, about 10 minutes for the first pass. Run it under a memory cap; the desktop sits at 1–2 GB free meanwhile.
- **Don't skip the kernel in a replay** of frames that were captured with it running (the mesh draw in section 4).
- **A replay-only artefact:** in the replay, 128 of 182 draws rebuilt their 12,500-slot table bindings at about 45 ms each. Their revalidation failed on memory the write tracker doesn't watch: `collect refusals: sampled 217, storage 13 (uncommitted pages 11, unwatched 219) over 62 surfaces, 239.4 MiB`. The game itself has none of that: 213 of 213 draws were template hits, with zero refusals. So don't judge CPU cost from the replay.

---

## 7. The NVIDIA menu that showed only its hints, and what it actually was

On NVIDIA the Initial Setup menu showed only "Enable Screen Reader / Select" in the bottom-right over black, while the 780M drew it in full. Each guess, in order:

| Guess | Test | Result |
|---|---|---|
| Stencil export | `APS5_SKIP_SHADER=11d01d0900`; in a replay, the stencil test off for every pipeline | **wrong**, no change |
| The ray-tracing kernel | `APS5_SKIP_SHADER=11d049aa00` in the game | **wrong**, no change |
| The UI composite losing content | `APS5_DUMP_TARGETS` + `APS5_NO_RESIDENT_TARGETS=1` in a replay | the 4K UI layer `0xb1dc100000` itself holds only the hints, so the menu is never drawn into it |
| Wave64 emulation of the UI shader | the whole UI is one pixel shader `0x9dc4300` (vertex `0x9dc7300`) walking element lists with ~50 `Ballot` and ~40 `LaneId`; `APS5_SINGLE_LANE=9dc4300,9dc7300` | **wrong**, no change |
| A hang | presents counted per frame | **wrong**, it kept presenting at ~0.2 FPS |
| **Speed** | see below | **right** |

**The cause.** The prototype's `APS5_DIAG_TABLE_USAGE` instrumentation adds two device-wide atomics to every texture-table read:
- **an `OpAtomicOr`** into a usage bitmap, which lazy tables need;
- **an `OpAtomicIAdd` on one global counter,** which feeds only a log line (`[diag-tableuse] executed counter: 26285 valid reads (x65536) ...`). That's about 1.7 billion increments per 10 s on a single address.

I put the counter behind its own switch, `APS5_DIAG_TABLE_COUNTER` (in `SpirvImageEmitter.cpp`), and kept the bitmap:

| | With the counter | Without |
|---|---|---|
| Frame time, menu frames, game | 6.2 s | 3.75 s |
| GPU time per frame | 5.5 s | 2.8 s |
| Initial Setup menu | hints only | **drawn in full** |

So the menu builds itself over frames, and at 6 s per frame it didn't get there within a run. The lesson for others: atomics on one global address in every table read are a big hit on NVIDIA, so keep diagnostic counters out of hot shader paths.

---

## 8. Where the NVIDIA frame time goes now

Measured in the replay's warm pass with `APS5_PROFILE_GPU=1 APS5_PROFILE_GPU_DRAWS=1 APS5_PROFILE_DRAW=1`:

| | Per 10 s |
|---|---|
| GPU time | 4.5–6.3 s, of it draws 4.3–5.2 s |
| Slowest draws | 100 ms to 1.2 s each |
| Dispatch `0x11d0349300` | ~600 ms per run |
| Dispatch `0x11d0376e00` | ~140 ms |
| Ray-tracing kernel | not among the top costs |

**The slow draws:**
- **They're all mesh draws:** stage 7, the game's primitive shaders run as Vulkan mesh shaders, plus a fragment shader. Only two mesh programs are behind them: `0x11d00cde00` and `0x11d0134500`.
- **Their sizes are small:** 5 to 5,454 vertices, one instance, not indexed, no stencil replay. One 481-vertex draw took about 400 ms.
- **Their target:** a 2560×1440 G-buffer with five color targets (mask `0xfffff`).
- **Not changed by** `APS5_NO_MESH_WINDOW_BUFFER=1` or `APS5_SINGLE_LANE=11d00cde00,11d0134500`.

**Not the cause:** the per-frame `[diag-order] queue 0x28 serial N held 2 s behind queue 0` lines. They're async submissions waiting by design for queue 0's earlier work, not lost time of their own. Likewise the `WAIT_REG_MEM_64 ... timed out after 1000ms`, which happens once per run, not per frame.

**Labeling the slow draws needed a local change:** the `[drawvariant]` lines from `APS5_PROFILE_GPU_DRAWS` are only printed when a draw's stage count equals its program count, which mesh draws don't meet, so the slow draws had no label. I added a `[diag-drawkey]` print at the point where the timing key is set, with stages, stencil replays, index and instance counts, and paired it with `APS5_TRACE_DRAW_PROGRAMS`.

---

## 9. What's left, in order

1. **NVIDIA frame time:** the two mesh programs above, and `0x11d0349300`. This blocks New Game and everything after.
2. **The ray-tracing kernel's SPIR-V size:** for RADV, and for NVIDIA compile times and cache misses. Short of that, make `agc_compute_pipeline_replay` create the game's exact device, so a kernel compiled outside the game is reused by it (section 5).
3. **The ray-tracing kernel's correctness:** first the out-of-snapshot descriptors. Then compare its output between GPUs, with a replay `--dump` of its output buffer, once RADV can compile it.
4. **780M memory:** the GPU-side copies (section 2).

---

## 10. What's on this branch

**Code** (all prototype, not PR-ready; the switches are in section 1 and below):
- the planning experiments of section 4 (`APS5_EXP_*`), lazy tables and their usage bitmap (`APS5_LAZY_TABLES`, `APS5_DIAG_TABLE_USAGE`), and `APS5_DIFF_IN_PLACE`;
- the stencil work of section 3 (strip replay, `APS5_DIAG_IGNORE_STENCIL_EXPORT`, `APS5_DIAG_STENCIL_DRAWS`, `APS5_DIAG_DRAW_REGS_FOR`, `APS5_DIAG_SPIRV_HASH`);
- the last commit: GPU-only memory in frame captures, `APS5_DIAG_CAPTURE_BOUNDARIES`, `[diag-drawkey]` labels for mesh draws, the mesh workgroup-limit error with its grid, `APS5_DIAG_NO_STENCIL_TEST`, and `APS5_DIAG_TABLE_COUNTER` (the counter atomic of section 7, now opt-in).

**Scripts** ([`scripts/`](scripts/README.md)): the run harness on both machines, input and capture triggers, the pipeline capture and standalone compile, and the replay A/B. Paths are variables; see that README.

**How the runs were organised, and what to do better:**
- One game per machine at a time, each run in its own memory-capped systemd scope (`memguard.sh`), stopped by PID.
- Input goes to the running game through `APS5_PAD_INPUT_FILE`, so a run doesn't need a restart to press a button.
- Put every trace you might need into one run. Most lost time here came from runs that each added one more switch.
- A frame capture plus `agc_frame_replay` answers GPU questions in about 40 s instead of a 5–10 minute game run, once the caches are warm.
- The driver caches decide everything about turnaround: a changed switch that alters emitted code costs one long compile of the ray-tracing kernel per GPU.

AI-assisted.
