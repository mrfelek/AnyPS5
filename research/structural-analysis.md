# Why AnyPS5 games are slow: analysis and plan (2026-10-24)

Built from all runs in [perf-data](../perf-data/) and the topic notes in this folder. No new runs were needed. All numbers are from the Linux desktop (RTX 3080 Ti) unless noted; the AMD mini PC and the Windows laptop show the same shapes where measured.

## Short answer

The slowness is structural. Every slow game hits the same three parts of the emulator's design, and the fast ones (Castlevania Belmont's Curse (PPSA35399) menu at 60 FPS, Hollow Knight Silksong (PPSA12544) at 120 FPS) are fast because they avoid them. Fixing one wait or one copy at a time does not help: the wait moves to the next place waiting on the same GPU work.

1. **GPU results go back through guest memory.** When the GPU writes an image or buffer, it is copied back into guest memory and uploaded again for the next user. About 4 GB per second each way on the Hot Wheels Infinite Rush (PPSA22408) title screen, about 4 GB per frame in Ghost of Yotei (PPSA26344).
2. **Work is redone for every draw.** The caches treat a moving buffer pointer as a new draw, so shaders are re-captured and recompiled on almost every draw (Sonic Origins Plus (PPSA05325): about 570,000 stage compiles per 10 s, 3.5% cache hits; Diablo II Resurrected (PPSA03912): 0.3% hits).
3. **Everything waits in one line.** One queue worker, one GPU lock and one draw committer. Other queues wait on it, and dispatches drain the draws first (Yotei: 355 ms of each frame).

A fourth, separate cost is shader translation on NVIDIA (emulated float denormal handling); see [f32-denormal-flush.md](f32-denormal-flush.md).

## The same pattern in every slow game

| Game and phase | Speed | What limits it | Key numbers |
|---|---|---|---|
| Hot Wheels title screen | ~9.6 FPS | 1. round trip | 41 GB uploaded and 35 GB written back per 10 s; our copies ~21 ms of a 55-60 ms GPU frame, the game's draws 3.5 ms; CPU waits on GPU ~4.4 s per 10 s; GPU 64% busy |
| Hot Wheels race load | 8.9 min | 1. round trip | 460 full copies of a 4 GiB heap, ~275 s of the load; GPU 19% busy |
| Hot Wheels race | ~4 FPS | 1. round trip | 19 GB up, 16 GB back per 10 s; GPU 48% busy |
| Ghost of Yotei cinematic | ~1 FPS | 1 + 3 | ~4 GB moved per frame; per ~1,040 ms frame: 480 ms waiting on GPU writes, 355 ms draining draws for dispatches, GPU lock held 276 ms by one queue; GPU 333 ms busy; game threads spin waiting for us |
| Diablo II Resurrected loading screens | 5-11 FPS | 1. round trip | one texture array split into 90 images that copy each other, ~35 GB per 10 s each way |
| Diablo II Resurrected main menu | 8.8 FPS | 4. shader translation, then 2 | GPU-bound at 4K, 106 ms per frame; float fix 73 ms (+34%); then the CPU draw path (~70 us per draw, 0.3% cache hits) |
| Sonic Origins Plus S2 menu | ~14 FPS | 2. redone per draw | draw worker 7.7 s and committer 7.1 s per 10 s; only ring pointers differ between draws |
| Castlevania in-game | ~6 FPS | 2. redone per draw | 2,700 draws per frame, 93% cache misses from pointers stepping per object |
| Castlevania menu, Silksong | 60 / 120 FPS | none | almost no GPU-written images (Silksong 11 MiB per 10 s) |

## Why small fixes stopped paying

| Fix tried | Worked? | Speed change | Where the time went |
|---|---|---|---|
| Float flush skip, D2R menu | yes | +34% | real gain (shader translation) |
| Skip big-buffer flush, Hot Wheels title (test only) | yes | +17% | upper bound of the round-trip fix |
| Join buffer import, Hot Wheels title | yes, CPU copy gone | 0 | wait moved to a queue label and a texture read |
| No indirect-argument read, D2R menu | yes, 3.6 s wait gone | 0 | wait moved to frame-in-flight and label waits |
| #8139 sparse page permissions (merged), Hot Wheels load | partly | 0 | 4 GiB copies unchanged, waits doubled |
| #10655 import page hashing, Hot Wheels load | yes | within noise | - |
| #7844 import budget, AMD Hot Wheels | yes | 0 | - |
| Pipelined dispatch + bigger cache, Yotei | yes | 0 | 90% of dispatches still miss the cache |
| GPU path chain (#9508/#7642/#10193), Yotei | yes | slower (3 vs 14 presents) | shaders 5x heavier |
| 1080p output (#7814), D2R | no | 0 | game ignores it |

The waits are waiting on real GPU work that is itself caused by the round trip and the single line.

## Ranked plan

1. **Stop the 4 GiB heap copy in the Hot Wheels race load.** A dispatch binds the whole heap writable with atomics, which skips the in-place import path. Serve it in place and track the writes. Estimate: about 275 s of the 531 s load.
2. **Finish the NVIDIA float fix.** Measured: D2R menu +26-34%, GPU 104-108 to 73 ms per frame. Nothing on AMD (hardware already matches).
3. **Keep GPU-written data on the GPU.** The GPU copy is the master until the CPU really reads it: write back only on CPU reads, let views of the same memory (array layers, format aliases) share one allocation, flush only what a shader touches. Measured floor +17% on the Hot Wheels title; estimate up to ~2x there, and Yotei's biggest lever (~600 ms of its 1,040 ms frame is copies plus the waits guarding them). Large, in the core memory code: should start as an upstream discussion, then land as small switch-gated steps.
4. **Treat moving pointers as data, not a new draw.** Patch the pointer at bind time; add the GPU descriptor heap so each draw no longer rebuilds its descriptor set. Removes most of Sonic's stage compiles; FPS moves only if both the draw worker (18.4 us/draw) and the committer (16.5 us/draw) get cheaper.
5. **Break up the single line**, last: let dispatches queue behind draws instead of draining them, shorten GPU lock holds, move the per-frame indirect draw to the GPU.

Build order for menus at 60 FPS (16.7 ms CPU and GPU per frame): cheap path for repeated draws (target 10 us per draw on worker and committer) first, then GPU results stay on GPU, then lean GPU translation (float fix, shader bloat: D2R's 4K shaders are ~64x larger than the guest code), then the single line. Estimate after the first three: Sonic ~26, Hot Wheels ~25, D2R ~14 FPS; 60 needs another 2-4x from GPU translation, not yet sized. The one data gap: per-draw GPU cost (a Sonic S2 menu frame capture replayed offline with per-draw timestamps).

## Who upstream already works on each piece

| Step | Upstream work found | State |
|---|---|---|
| 1. Heap copy | none for the writable-atomic case; #8139 merged but did not stop the copies | gap |
| 2. Float fix | none covers NVIDIA | ours, in test |
| 3. GPU data stays on GPU | #4286 (hand image data over without the guest round trip, closed by its author; clear-key half merged), #9400 (storage-refresh wait off the GPU lock), #10159 (keep a DCC target's refresh proof), #7618 (staging written-only buffers), #8104 / #9287 / #9289 (staging copy cost) | pieces only |
| 4. Pointers as data | #5609 / #6539 (moved pointers, conflict with main), #9508 (GPU descriptor heap), #9012 (audit templates only after import change), #8212 (one pipeline when only table size differs) | partial, stalled |
| 5. Single line | issue #7895 (parallel draw recording, maintainer wants small switch-gated steps), #8992 and #8278 (prepare/record splits, merged), #10359 (indirect start instance from BaseInstance) | groundwork merged |

AI-assisted. Tested by me on my own machine.
