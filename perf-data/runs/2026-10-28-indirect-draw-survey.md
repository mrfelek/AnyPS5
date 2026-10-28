# Indirect draw survey across games (28 October)

Question: the Diablo II Resurrected menu loses 3.4-3.9 s per 10 s to one indirect draw whose arguments are read on the CPU ([no-read probe](2026-10-24-d2r-main-menu-indirect-no-read-probe.md), [GPU-path fix](2026-10-28-d2r-main-menu-indirect-gpu-path-ab.md)). Do other games have the same stall, and would the same fix help them?

Every run uses the indirect draw trace (`APS5_TRACE_INDIRECT_DRAWS=1`), 10 s summaries, GPU and draw profiling, audio muted.

## Windows laptop (RTX A2000 Laptop, NVIDIA 610.60)

See [machines.md](../machines.md).

### Castlevania Belmont's Curse (PPSA35399), main `cc672fdfc6`

- **No indirect draws or dispatches at all**, measured over the last 150 s of in-game idle after New Game. There are no indirect summary lines, no indirect draw trace lines, and no DRAW_INDIRECT or DISPATCH_INDIRECT hook syncs. The only "indirect" hits are indirect register-set packets and an empty recipe counter.
- Context: 38.2 presents per 10 s, GPU 104.9 ms per frame.
- So the indirect fix cannot help this game.

### Metal Gear Solid Peace Walker (PPSA05268), main `cc672fdfc6`: not measured

- The game stops 8 s after launch with `sceHttp2SetCookieBox not implemented` (0xC0000409). This is another HTTP/2 stub, like the `sceHttp2GetMemoryPoolStats` one that stops Hot Wheels on current main since `db57916260`.
- The relink itself was fine (12 modules).

### Hot Wheels Infinite Rush (PPSA22408), `6d0139cd33` + GameUpdate fix

Current main does not boot this game on Windows (see the [Hot Wheels section of the staging run](2026-10-28-d2r-written-only-staging-revert-ab.md#other-title-hot-wheels-infinite-rush-title-menu-and-garage-windows-laptop)), so the older base is used. It predates the "patched SGPR not folded" reason, so no draw can report it here.

- **Phases:** title idle +151..+250 s, title to menu +250..+425 s, garage 150 s at +579..+730 s. Presents per 10 s 36.2 / 35.6 / 10.1, GPU 113 / 109 / 151 ms per frame.
- **Argument reads (ms per 10 s):** title 9.7, 18.5, 22.6, 23.6, 24.6, then a steady 20-24; menu presses 13.8, 75.3, 126.1, 59.4; garage 15-52, mostly 20-30. That is about 1% of the Diablo II menu's 3.6 s.
- **Hook syncs at indirect arguments:** DRAW_INDIRECT about 70 syncs and 18-22 ms per 10 s at the title and menu, out of about 480 syncs and 7.2-7.8 s in total. Garage: 37-40 syncs and 8-45 ms (94 and 119 ms at the garage load), out of 230-290 syncs and 2.3-4.3 s. DRAW_INDEX_INDIRECT: 0 in every window. The larger waits are elsewhere (WAIT_REG_MEM_64 and the DISPATCH_INDIRECT capture).
- **Indirect draws:** 9,244 on the GPU path and 1,220 on the CPU path; all 1,220 CPU ones give "non-vertex path", for example:

```
[draw] indirect 0x24 args 0x10fd6c0010 stride 16 count 1 locs base=none inst=none idx=none analyzer v=-1 i=-1 shared=0/0 conflict=0/0 indx=0 -> cpu (non-vertex path)
indirect: gpu-side 390 (390 rewritten), cpu-side 46 ( non-vertex path 46), empty skipped before their stages 24006, argument reads 32.3 ms
```

- **Indirect dispatches** all go GPU-side and never read arguments on the CPU:

```
[indirect] (cumulative): gpu-side 52853, cpu-side 0 (thread dimensions 0, fill kernel 0, pending image results 0, pending label or copied write 0, not imported 0, misaligned 0, disabled 0, device memory LDS 0); CPU argument reads took 0.0 s
```

  About 650 of them per 10 s spend about 0.9 s inside the device call (max 81.6 ms), almost all of it binding images ("resources: B images"), with 33 ms of hook waits.

**Result:** Castlevania has no indirect work at all. Hot Wheels has the same kind of CPU-path indirect draws, but they cost only 20-30 ms per 10 s and give a different reason ("non-vertex path"), which the base-vertex fix does not cover. In this sample, the large indirect stall is specific to the Diablo II menu. **Next for Hot Wheels:** the image binding time inside indirect dispatches (about 0.9 s per 10 s) is the larger indirect-related cost.

AI-assisted. Tested by me on my own machine.
