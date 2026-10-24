# Marvel's Wolverine

What I found on this game, in one place. Upstream discussion: [D#5516](https://github.com/boykopovar/AnyPS5/discussions/5516). **Not re-tested on current main**: everything below is from main `3b1ea78` (mid-October) plus a reading of what has landed since.

## Blockers on `3b1ea78`

242 shader failures:
- 105 `GetSamplerResource`: sampler read from a constant buffer at a runtime offset;
- 13 bindless storage image tables;
- 4 bindless table capacity;
- 2 vertex shaders with `s_barrier`.

Also: `libSceNpCppWebApi.prx` missing from the dump (stubbed), and an unknown `libScePad` import `zBsgF0q8DIM`. The image-table fix (#5188) helped. The earlier change #5089 had no effect and has since been reverted.

## What has landed on main since, and may fix them (not verified)

| Blocker | Change on main |
|---|---|
| 105 sampler failures | Celegans12's runtime-offset image and sampler tables (`d9e47d1e9`) |
| 2 vertex shaders with `s_barrier` | a vertex `s_barrier` before memory access now emits nothing (`7092dde6e`) |
| `libScePad` `zBsgF0q8DIM` | implemented (`acd1e0ef8`) |
| `libSceNpCppWebApi` | restored (`8cd400aa4`, #8843) |
| 4 table capacity failures | maybe the table update-after-bind limits (`070a3f12c`) |
| 13 bindless storage image tables | nothing found |

[#8206](https://github.com/boykopovar/AnyPS5/pull/8206) (Celegans12, merged) adds `APS5_SKIP_REFUSED_DRAWS`, which skips refused draws (not dispatches) and replaces the local drop-on-failure patch I used.

## Setup (Linux)

Unwrap `eboot.bin`, `libcohtml.Prospero.prx` and `libRenoirCore.PS5.prx`; `relinker --registry src/eboot.elf app.elf` with the modules in `sce_module/`; copy the built `libs/*.prx` into `libs/`; `app0/` holds symlinks to the dump plus the `*.guest.prx` files in its root. Windows: `relinker --windows --module-dir mods eboot.elf wolverine.exe`.

Next: a clean run on current main with a fresh shader cache, recounting failures by type. For comparison, ImHoppy reported 2-3.5 FPS on Windows with an RTX 5070 Ti.

AI-assisted. Tested by me on my own machine.
