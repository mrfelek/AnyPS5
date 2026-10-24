# Astro Bot (PPSA21564)

Everything I tested on this game, in one place. Upstream discussion: [D#357](https://github.com/boykopovar/AnyPS5/discussions/357). Machine: Linux desktop (RTX 3080 Ti 12 GB, NVIDIA 615.71.09), window 1465x852. Specs: [machines.md](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/machines.md). I use it mostly as a correctness check for draw cache changes, because it once caught a cache bug that Castlevania and Sonic missed.

## Where it gets to

Started straight into the crash-site hub with `-lvl hub_crashsite` and `APS5_HOST_IMPORT_MIB=16384 APS5_PIPELINE_JOURNAL_MAX_MIB=4096`. Runs 180 s with no input and 0 driver errors. It does not hit the update-check throw that stops Hot Wheels on current main.

## Speed (hub, main of 22 October, presents per 10 s over the last four windows)

| Setup | Presents per 10 s | Notes |
|---|---|---|
| Default, cold shader cache | 94, 61, 66, 68 | shader compiles; VRAM 10.8 GB; texture cache over its ~3.0 GB auto budget |
| Default, warm | 80, 79, 80, 83 (about 8 FPS) | VRAM 10.5 GB |
| `APS5_TEXTURE_CACHE_MIB=3584`, warm | 68, 80, 79, 73 | no help |
| Draw cache verify (entries + recipes) | 76, 77, 80, 80 | 0 mismatches over 63,119 entry re-captures and 2.6M recipe decodes |

## What I tested

| Change | Result |
|---|---|
| jemalloc as the game's allocator (local) | +15% (posted earlier in this thread). |
| MSAA changes that take Peace Walker in-game ([#7803](https://github.com/boykopovar/AnyPS5/pull/7803) + [#8871](https://github.com/boykopovar/AnyPS5/pull/8871), thuanquang, 2D MSAA texture reads) | No difference: 82-85 vs 80-85 presents per 10 s, 0 MSAA refusals in both, VRAM about 10.1 GB. This game does not use that path. |

Open: what limits it to about 8 FPS. Profile logs exist for both runs but are not analysed yet.

AI-assisted. Tested by me on my own machine.
