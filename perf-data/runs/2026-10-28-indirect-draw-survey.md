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

## AMD mini PC (Radeon 780M, RADV, Mesa 26.0.8)

### Hollow Knight: Silksong (PPSA12544), main `cc672fdfc6`

- Fresh runtime, first gameplay area, 180 s counted. No validation errors, device loss or terminate.
- **No indirect draws at all**, over the whole log: no indirect draw trace lines, no CPU-path lines, no indirect summaries, no hook syncs, no argument-read section in any draw line, and "indirect-args 0" in all 44 barrier lines. 600 presents per 10 s.
- For contrast, on the same machine the Diablo II menu skips about 1,000-1,100 empty indirect draws per 10 s and spends 5.2-6.0 s per 10 s reading their arguments ([character select page](2026-10-25-d2r-character-select-amd-draw-set-reuse.md)).

One counted window, verbatim:

```
[draws] 95022 draws over 10 s (95022 recorded avg 27 us, of them 0 with completion; 0 recorded then waited avg 0 us; 0 synchronous avg 0 us; render passes 15903 begun (new batch 2708, command 5015, key 1177, image 7003), 79119 draws continued one; waited or synchronous because:): validate=62.2ms vertex=335.3ms setup=51.6ms readTarget=343.2ms (93822 resident lookups, 0 of them >= 1 ms = 0.0; target lookups: full-scissor 93822 / partial 0 / pages walked 6009360 / 333011 us) prepare=249.4ms lookup=546.0ms resources=2.2ms (bindings 0.0, upload 0.0, descriptors 0.0, other 0.0 of which 0.0 in 0 address-based builds) pipeline=205.3ms record=657.6ms keep=89.2ms; per kind (avg us, count): recipe hit 65 (207) template hit 27 (94815) build 0 (0) BDA 0 (0); longest draw 1.0 ms, longest phase of any draw: validate 0.5 vertex 1.0 setup 0.7 readTarget 0.9 prepare 0.8 lookup 0.7 pipeline 0.8 record 0.6 keep 0.8; hook waits inside draws 0.0 ms (max 0.0; the draws' own syncs, 0.0 ms, not counted); skipped packets: nothing to draw 0 in 0.0 ms prechecked 0 in 0.0 ms thrown 0 in 0.0 ms; recipe hits 207, misses by reason: not recordable 0 target gone 0 template gone 0 objects gone 0 proof 0
```

**Result:** Castlevania and Silksong have no indirect work at all. Hot Wheels has the same kind of CPU-path indirect draws, but they cost only 20-30 ms per 10 s and give a different reason ("non-vertex path"), which the base-vertex fix does not cover. In this sample, the large indirect stall is specific to the Diablo II menu. **Next for Hot Wheels:** the image binding time inside indirect dispatches (about 0.9 s per 10 s) is the larger indirect-related cost.

AI-assisted. Tested by me on my own machine.
