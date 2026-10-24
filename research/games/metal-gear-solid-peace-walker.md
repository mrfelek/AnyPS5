# Metal Gear Solid: Peace Walker (Master Collection version)

Everything I tested on this game, in one place. Upstream discussion: [D#5268](https://github.com/boykopovar/AnyPS5/discussions/5268). Machines: Linux desktop (RTX 3080 Ti) and Windows laptop (RTX A2000). Specs: [machines.md](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/machines.md).

## Where it gets to

| Build | Machine | Result |
|---|---|---|
| main of 21 October (`cecb540a6`) alone | RTX 3080 Ti, Linux | Stops at the 2D MSAA texture read refusal. |
| `cecb540a6` + [#7803](https://github.com/boykopovar/AnyPS5/pull/7803) (thuanquang, reads 2D MSAA textures as sample 0) + [#8871](https://github.com/boykopovar/AnyPS5/pull/8871) (thuanquang, more 2D MSAA handling, merged) | RTX 3080 Ti, Linux | Reached the beach tutorial at about 60 FPS, no driver errors. |
| main of 22 October with the same MSAA changes, cold shader cache | RTX A2000, Windows | No logo strips, DLC textures (48 files) load in about 2.1 s with no stall, about 10 minutes of play with no crash and 0 Vulkan errors. FPS rose from 13 (tutorial) to 20 (level 2) to 33 (end). |

## Setup

Unwrap `eboot.bin`, `mgspw/mgspw.elf`, `sce_module`, `Media/Modules` and `Media/Plugins`. The launcher and the game are relinked together:
`relinker --registry --module-dir Media/Modules --module-dir Media/Plugins --executable mgspw/mgspw.elf src/eboot.elf app.elf`
This also writes `mgspw.mgspw.elf.elf` and its registry in the runtime root. Put a symlink to each original `.prx` next to its `.guest.prx`. Run with `APS5_HOST_IMPORT_MIB=16384`.

## Fixes that came out of this game

| Change | What it does |
|---|---|
| [#7072](https://github.com/boykopovar/AnyPS5/pull/7072) (mine, merged) | Fixes the Ngs2 system lock deadlock behind the freeze while loading DLC textures. |
| [#5443](https://github.com/boykopovar/AnyPS5/pull/5443) (SandstromPL, merged) | `relinker --executable`, so the launcher and the game binary can be relinked together. |
| [#5915](https://github.com/boykopovar/AnyPS5/pull/5915), [#6014](https://github.com/boykopovar/AnyPS5/pull/6014), [#6196](https://github.com/boykopovar/AnyPS5/pull/6196) (SandstromPL, merged) | MSAA draw support needed by this game. |
| [#7803](https://github.com/boykopovar/AnyPS5/pull/7803) and [#8871](https://github.com/boykopovar/AnyPS5/pull/8871) (thuanquang) | 2D MSAA texture reads; together they take the game in-game (results above). |

Still open on my side: a run on plain main once all MSAA changes are on main, which would make the game count as reaching gameplay on main.

AI-assisted. Tested by me on my own machine.
