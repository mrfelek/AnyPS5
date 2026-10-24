# Ghost of Yotei (PPSA26344)

Everything I tested on this game, in one place. Upstream discussion: [D#675](https://github.com/boykopovar/AnyPS5/discussions/675). Machine: Linux desktop (Ryzen 9 5950X, RTX 3080 Ti 12 GB, 32 GB RAM). Specs: [machines.md](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/machines.md). Dump: v02.002.000.

## Where it gets to

| Build | How far | Notes |
|---|---|---|
| Upstream main, no extra files | Black screen with a loading spinner, never leaves loading | Needs `anyps5-entitlements.ini` next to `app.elf` (for this dump the label `GHOSTYOTEIDUPLEX`), as others in this thread found. |
| Upstream main + entitlements file | Title-scene load, then stops after about 7.6 min | "blending unclamped normalized color is not implemented" (8_8 UNORM target, blending on). The merged unclamped-target change (#6875) accepts these targets only without blending. My approximate fix lets Vulkan blend with its clamp: [patch](https://github.com/mrfelek/AnyPS5/blob/main/research/patches/yotei-blend-unclamped-normalized.patch). With it the game passes that point but stays black at about 1 FPS while it compiles shaders and runs out of VRAM. |
| Celegans12's `yotei/best` | Crashed after 3 min on Linux | Divide by zero in the game's audio setup: the AT9 vibration channel config is not parsed. Fixed on main by the AT9 config change (#6721), which that branch did not have yet. Also needs a Linux build fix (`State` size assert). |
| hritikutekar's `yotei/linux-best-u2` | **Furthest:** "Select an Experience" at 6.5 min, opening cinematic at about 26 min (cold), first "write their names" touchpad scene at about 38 min | 0.1-1 FPS, no errors in 60 min, VRAM 7.9-9.2 GB, RAM about 17.6 GB, shader cache 35-37 GB. Scripted Cross presses get past the menus; the names scene needs moving touch input (passed by hand with a DualSense). |

## Speed

- **Cinematic on linux-best-u2, per frame of about 1,040 ms:** about 4 GB moves between guest memory and the GPU (storage upload 1.8 GB, write-back 1.17 GB, staging about 1 GB). Hazard waits 480 ms. Dispatches force draw-pipeline drains for 355 ms (62 of 78 drains). Queue 0 holds the GPU mutex 276 ms. The committer spends 121 ms walking pages. The GPU is busy only 333 ms. The game threads spin waiting for our results. This matches what hritikutekar (RX 9070 XT) and Celegans12 (RTX 4070 Ti S) see, so it is not this GPU or Linux.
- **Boot and loading, main build:** about 14 presents per 10 s, GPU 64 ms per frame, draw cache hits 85%. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-24-ghost-of-yotei-boot-load-gpu-path-ab.md)
- **Shader compiles (NVIDIA):** 517 pipelines over 100k SPIR-V words take about 25 min cold on one driver thread (largest 1.7M words, about 500 s).
- **VRAM on 12 GB:** the title scene binds huge image tables; with `APS5_RESOURCE_CACHE_ENTRIES=1024` VRAM peak drops from 10.65 to 8.35 GB and the texture cache stops failing to free memory. FPS stays the same.

Full analysis: [ghost-of-yotei-speed.md](https://github.com/mrfelek/AnyPS5/blob/main/research/ghost-of-yotei-speed.md).

## Fixes and PRs from this game

| Change | What it does | State |
|---|---|---|
| [#9957](https://github.com/boykopovar/AnyPS5/pull/9957) (mine, buffer presence at run time) | The recompiler folded whether a buffer is bound into the shader as a constant, so each giant 1.2-1.3M-word compute shader existed in two variants and a new one cost a 54-70 s compile. Reads the presence bit at run time instead. Warm run: giant compile 21.8 s in 15 min vs 1,221 s. Prior art: Pipodi's closed #5353. | Waits on reviewers. |
| [#10228](https://github.com/boykopovar/AnyPS5/pull/10228) (mine, image table at first-lane offset) | Fixes shaders that stop with "GetImageResource ... not a valid runtime value". [notes](https://github.com/mrfelek/AnyPS5/blob/main/research/image-descriptors-7459.md) | Waits on re-review. |
| `APS5_PIPELINE_JOURNAL_MAX_MIB=4096` (setting) | The pipeline journal hits its 1024 MiB default cap, so later giant shaders are never recorded and get compiled again next launch. | Use it for this game. |
| Blend fix (my patch, not a PR) | See the table above. | Patch only. |

## Dead ends

- **GPU path chain** (#9508 descriptor heap -> #7642 image tables on the GPU heap -> #10193 table columns, `APS5_GPU_HEAP=1 APS5_GPU_PATH=1`): slower in loading, 3 vs 14 presents per 10 s, GPU 283 vs 64 ms per frame, draw cache hits 12% vs 85%; vertex SPIR-V reaches 6-9 MB per program. Its shader cache also stores every program twice (reported on #10193).
- **Bigger dispatch cache with pipelined dispatch/DMA** (`APS5_PIPELINE_DISPATCH=1 APS5_PIPELINE_DMA=1`, 65,536 entries): no gain, per-dispatch cost went up (600 -> 862 us).
- **Staging PRs #8104, #9287, #9289** (Celegans12, cheaper staged copies) on the logo phase: no measurable difference.
- **Image-table reuse idea:** dropped; linux-best-u2 uses the bindless texture service, where that code takes 0% of the time.

## Known problems

- **With the shader disk cache off (`ANYPS5_NO_SHADER_CACHE=1`), memory grows about 9 GB per minute** (host-side anonymous memory) until the system runs out. With the cache on it does not.
- 32 GB of RAM is tight: runs swap heavily unless the browser is closed.

AI-assisted. Tested by me on my own machine.
