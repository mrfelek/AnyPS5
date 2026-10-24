# Slow menus: GPU-written images round-trip through guest memory

Linux desktop (RTX 3080 Ti), 2026-10-24. Runs: [Hot Wheels title baseline](../perf-data/runs/2026-10-24-hot-wheels-title-baseline.md), [skip big flush](../perf-data/runs/2026-10-24-hot-wheels-title-skip-big-flush-ab.md), [import join](../perf-data/runs/2026-10-24-hot-wheels-title-join-crossing-ab.md), [D2R menu baseline](../perf-data/runs/2026-10-24-d2r-main-menu-baseline.md).

## Which menus are slow, and why

| Game / scene | Presents per 10 s | Compute-written image traffic per 10 s (in / back) | Where the frame goes |
|---|---|---|---|
| Hot Wheels Infinite Rush (PPSA22408) intro movie | ~600 | n/a | movie path |
| Hot Wheels title/menu | 86-98 | storage upload 25.9 GB / write-back 36.1 GB, shadow-publish 25.3 GB | queue 0: ~107 compute dispatches per frame at 0.54 ms + indirect 1.8 ms each; GPU 63 ms/frame, ~74% of it our own image/buffer copies, real draws ~4 ms/frame |
| Diablo II Resurrected (PPSA03912) loading screens | 46-109 | 32.7 / 32.6 GB | queue 0: ~3,000 compute dispatches per 10 s at 3.1 ms device call |
| Castlevania Belmont's Curse (PPSA35399) menu | ~600 | ~0 | draws only |
| Hollow Knight Silksong (PPSA12544) | 1,000-1,200 | 11 MiB | many cheap dispatches, tiny images |

Common cause in the slow ones: compute passes that **write** images. After each pass the driver writes the image back to guest memory ("storage refresh": retile into the shadow) and the next pass re-uploads it ("shadow" upload: detile). In code: `StorageTexture::Refresh` in `Graphics/src/Texture.cpp` ("Results of other images pending in this memory must reach it first" -> `FlushPending(..., "storage refresh")`, then upload). Two or more Vulkan images over the same guest surface (different descriptor, format or view) hand the data to each other through guest memory every pass instead of staying on the GPU. Unity games with draw-based menus never hit this path.

## D2R loading screens: one array texture becomes 90 images

`APS5_TRACE_UPLOAD/TRACE_FLUSH`: 2,168 of 2,303 storage-image re-uploads are one guest address under ~200 byte sizes, all "128x128 mips 9", format 62. It is a 2D array texture bound one layer at a time ("layers 162..162", "249..249", ...). `StorageTexture::SameSurfaceShape` only reuses an image when guestBytes, depthOrLastArray and baseArray all match, so each layer range becomes its own Vulkan image over the same memory, and each refresh stores all the others first: 894 shadow re-uploads (35.3 GB) and 1,456 refresh write-backs (35.3 GB) per 10 s.

Fix idea (not written): serve all layer ranges of one array from a single Vulkan image (the widest) through layer views. No upstream PR found for this.

The D2R **main menu** is different: GPU-bound at 4K with cheap image traffic (alias hand-overs 528 per 10 s, ~0.3 s GPU). See [draw cache](draw-cache-per-draw-rework.md) and [f32 flush](f32-denormal-flush.md).

## Hot Wheels title: big buffer bindings flush every render target

Title ~9.5 FPS, menus ~8.3, garage ~6. Every frame about 15 G-buffer/post images (1920x1080, formats 5/13/14/20/29/36/50/56/71, some 2- and 4-layer arrays) are written back and re-uploaded once per present.

- Main trigger: `[flush] image ... for imported buffer region` / `written buffer range` (1,209 + 465 per 10 s). A pair of compute shaders (1440x1x1, ~72 each per 10 s on queue 0) binds a **written** 128 MiB buffer, a 48 MiB one, a written 40 MiB buffer, the whole 4 GiB sparse heap read-only and a 1024x1024 texture. The 128 MiB range covers the memory of all those render targets (Unreal's transient heap), so every pending image in it is stored before the pass (`ShaderResources.cpp` / `GuestBufferMemory.cpp`) and re-uploaded at its next use.
- Smaller: same-address format aliases (120x68, 4-5 objects each), a 4-layer array vs its 2-layer view.
- Upper bound test, skip stores for bindings of 64 MiB or more: +17% presents (109 vs 93), GPU 50 vs 60 ms per frame, shadow-publish halved, write-backs -25%, uploads unchanged, picture same.
- Fix direction: flush only what the shader actually reads, not the whole bound range.

## The biggest wait: a buffer that cannot be imported

`trace-hooksync-cpu-upload.diff`: 1,100-1,150 hook syncs and 3.8-4.2 s waiting per 10 s (~40% of wall time).
- 9,275 of 9,300 CPU uploads are one 632 KiB GPU-written buffer (writable, not host-backed, not addressable) outside the host imports, read back ~7 times per second in bursts of 5. The first read of each burst waits 18-24 ms for the GPU writer.
- Waits by site: direct dispatch buffer upload 35 s, indirect dispatch capture 15 s, compute queue label 13.7 s (whole run).
- At the wait the writer's target was still open (3,829) or in flight (1,482), never already signaled.
- Letting the importer join that buffer (`APS5_TEST_JOIN_CROSSING=1`) removes the CPU copy, but the next reader waits on the same writer: waits move to the compute-queue label (12 -> 41 s) and texture reads, presents unchanged. The real cause is the writer's target still being open when the buffer is read.

## Prior art upstream

- **#4286** (AlxcBTW, "hand aliased storage memory over without the guest round trip"): closed by its author after oneandonlydean asked to (1) choose the path from the DCC keys before the first flush, with no fallback after the fact, and (2) show a gain in a configuration main selects by itself; the gain showed only with write-watched imports. On Linux/NVIDIA main leaves imports watched by default, so Hot Wheels on Linux is that configuration. Its clear-key half landed later (parl0v, "hand pending results over to an image whose DCC keys are a clear code"; `APS5_NO_CLEAR_HAND_OVER=1`): 473 clear-key hand-overs per 10 s on the Hot Wheels title.
- On today's main the uncompressed half looks redundant: main already retiles A's units into the unit shadow on the GPU (26.7 GB per 10 s) and B uploads from the shadow (9.2 GB). Most publishes are "region" publishes from buffer bindings over the transient heap, which #4286's filter would not cover. Expected gain close to zero.
- #9400 (parl0v): storage-refresh writer wait off the GPU mutex (lock time, not bytes). #10159: keep a DCC target's refresh proof. #4448, #6197: storage surfaces vs host imports.

AI-assisted. Tested by me on my own machine.
