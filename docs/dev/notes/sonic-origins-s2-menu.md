# Sonic Origins Plus: S2 main menu performance notes

Fork notes (mrfelek/AnyPS5, 2026-10-21). They describe what limits Sonic Origins Plus (PPSA05325) on its Sonic 2 main-menu page, what was changed, and what the changes did and did not do. Everything here was measured locally and has not been posted upstream. Anyone is welcome to take the branches below, or any part of them.

## Setup

- **Machine:** Linux (Ubuntu 26.10, kernel 7.3), Ryzen 9 5950X, RTX 3080 Ti 12 GB (NVIDIA 615). Game settings untouched.
- **Display:** headless `kwin_wayland --virtual` (2560x1440) with Xwayland `:19`. The game runs with `DISPLAY=:19 SDL_VIDEODRIVER=x11`, and the monitors stay off.
- **Script:** the save is copied from an earlier boot, so the intro is skipped. The script presses X on the autosave notice, X on the title, then Right twice to the Sonic 2 page. It waits 30 s to settle, then measures for 60 s. Env: `APS5_PROFILE_DRAW=1 APS5_PROFILE_GPU=1 APS5_TRACE_SUMMARY_EVERY=10`.
- **Units:** "presents" means presents per 10 s, one sample per 10 s window. Single runs vary by about ±5.
- **Base:** JJenkx's draw-cache integration branch (572fe318c, on `main` 2185dbf92). The storage fix was also rebuilt on `main` 275e89679.

## Where a frame goes (before any change)

About 130 presents per 10 s, so a frame takes about 73 ms.

| | per frame |
|---|---|
| GPU busy | 48.8 ms: draws 23.5, storage-image alias copies 5.1 (~54 copies, ~24 MB each), copies 4.9, fills 3.2 |
| Draw committer thread | ~46 ms |
| Queue 0 worker | ~45–50 ms |

The CPU threads and the GPU are both close to the frame time. A CPU-only fast path could gain at most about 45% before the GPU limits the frame.

## Finding 1: a surface kept as two storage images, copied whole on every switch

**Branch:** `fix/one-layer-storage-share` (on `main`).

The game uses some render surfaces both as a plain 2D image and as a one-layer 2D array (mostly where it samples them). Formats seen: 71 (960x540 and 3840x2160), 36 (1920x1080 with 10 mips), 56.

- `SurfaceKey` included the dimension, so the storage cache made a second image for the array form.
- `ArrayLayersServeView` did not let a 2D image serve a one-layer array view, so sampling the array form also made that second image.
- Each time the game switched between the two, `StorageTexture::borrowUnits` copied the whole surface from one image to the other: about 7,200 copies (about 170 GB) per 10 s.
- That path also left stale content: the menu's help text showed broken glyphs ("16:S sc.ee.", "Open map") in every run before the fix.

**Change:**
- `ArrayLayersServeView` accepts a one-layer 2D array over a 2D surface.
- `SurfaceKey` files both forms under one key.
- Storage bindings take the view of the shape they declare: the first-layer view is 2D over an array, or a one-layer array over 2D (`StorageViewOtherShape`).
- `APS5_NO_ONE_LAYER_SHARE=1` turns all three off.

On `main` 275e89679, same build, with `APS5_NO_ONE_LAYER_SHARE=1` (which turns the whole fix off) against the default:

| run | presents (6 windows) | alias copies / 10 s | GPU busy / frame | help text |
|---|---|---|---|---|
| fix off | 114–130 | 6,857 (164 GB) | 50.9 ms | broken |
| fix on | 126–132 | 0 | 44.9 ms | clean |

On the integration base (one run each): before the fix 122–138 presents, ~7,200 copies, 48.8 ms of GPU per frame and broken text in all 8 earlier runs; with the fix 136–144, 0 copies, 44–45 ms and clean text in 3 runs.

So the copies and the glitch are gone, and the GPU saves about 4–6 ms per frame. The frame rate gains only about 5%, because the CPU threads still take ~45 ms.

**Other games, same build, fix off vs on:**
- Castlevania (PPSA35399): no alias copies in either run, same presents and the same picture.
- Astro Bot (Sky Garden via `-lvl`): no alias copies in either run. Headless it ran at only 1–2 presents per 10 s with 2+ s of GPU per frame, in both runs, so that problem is unrelated to the fix. It has not been looked into.

**Tests:**
- Two new `ArrayLayersServeView` cases.
- The driver test executables whose names match texture, storage, image, recorder, graphics, layer, alias, sampled or resource: 86 of 87 pass on `main` (84 of 85 on the integration base). `agc_driver_recorder_tests` fails a DCC key-proof check ("(9) a scan under a pending write was kept"), and it fails the same way with the fix off.

## Finding 2: the draw cache misses because vertex-fetch stages are never relocated

**Branch:** `perf/vertex-fetch-relocation` (on the integration base 572fe318c).

The menu's draws mostly differ only in their vertex buffers and per-object constant pointers. Draw relocation (#4943 / #5609 / #6539 in the integration branch) can reuse a cached stage when only base words move. But `cacheDrawStages` leaves out every stage with fetch decode reads, which is every vertex-fetch stage, so none of those draws could hit.

**Change:**
- `DecodeRead` now records which user-data word each fetch read came from (`origin`: the attribute-table word, or the V# words).
- When every decode read of a stage came from a user word, those words become base words of the relocation, and the stage is tagged as relocatable.
- `APS5_NO_VERTEX_FETCH_RELOCATION=1` turns this off.
- `APS5_RELOCATION_NEVER_IDLE=1`, an experiment switch, keeps the relocation trial from going idle when it finds few hits.

**What it did:**
- **Coverage:** 100% of the menu's vertex-fetch stage captures become relocatable. The relocation verifier run found 0 mismatches.
- **Hit rate:** with the trial throttle off (`APS5_RELOCATION_NEVER_IDLE=1`), about half of the menu's draws hit the cache.
- **Cost per draw:** the "capture" and "recompile" figures of the `[draw] driver phases` line drop:

| run | presents | capture | recompile |
|---|---|---|---|
| relocation off | 120–136 | 4.8–4.9 | 6.0–6.9 |
| relocation on | 122–142 | 3.4–3.9 | 3.5–4.3 |
| on + never idle | 128–137 | 2.3 | 2.4 |

- **Frame rate:** no change beyond the noise. A relocated hit still costs about 16 µs of CPU per draw (15.6–16.6 µs):

| part of a relocated hit | µs |
|---|---|
| key build, lookup and validation | ~7 |
| … identity key | 0.26 |
| … relocation lookup | 0.36 |
| … register key | 0.64 |
| … find + relocate | 1.41 |
| … `validateVariant`, per stage | 0.93 (pipeline overlap check 0.51, compare 0.14) |
| waiting on the draw committer | ~5 |

The committer then spends ~46 ms per frame either way. So the next step would be a cheaper hit path in the committer and the worker (skip the key rebuild and the per-stage validation for a draw whose shape and relocation were just proven). After that the GPU, at ~45 ms per frame, is the limit.

## Branches

| branch | base | what |
|---|---|---|
| `fix/one-layer-storage-share` | `main` 275e89679 | Finding 1, with tests and docs |
| `perf/vertex-fetch-relocation` | integration 572fe318c | Finding 2 and these notes |
| `wip/sonic-draw-cache-probes` | integration 572fe318c | every local commit, including the temporary probes; not for merging |

Probe output on the `wip` branch, all printed to stderr:

| tag | what it prints |
|---|---|
| `[tmp-phases]` | per-kind draw phase times (miss, data hit, relocated hit) |
| `[tmp-validate]` | `validateVariant` step timers |
| `[tmp-key]` | key-step timers in `Driver::draw` |
| `[tmp-reloc]` | why stage captures are or are not relocatable |

## Reproduce

- Scripts used (local, not in the repo):
  - `sonic-run.sh RUNTIME TAG`: input sequence and measurement as above; `HEADLESS=1` for the virtual display, `PERF=1` for `perf record`.
  - `sonic-build.sh BUILDDIR NAME`: relinks the game against BUILDDIR's relinker and copies a save past the intro.
- **Input timing:**
  - Fresh runtimes play the intro on first boot, so a save from an earlier boot is copied in.
  - X on the autosave notice at 70 s after start, X on the title 14 s later, Right twice 6 s after that.
- **A/B switches:**
  - `APS5_NO_ONE_LAYER_SHARE=1`
  - `APS5_NO_VERTEX_FETCH_RELOCATION=1`
  - `APS5_RELOCATION_NEVER_IDLE=1`
