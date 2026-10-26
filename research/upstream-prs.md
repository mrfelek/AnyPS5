# Upstream PRs: mine, carried, and tested

Every PR in [boykopovar/AnyPS5](https://github.com/boykopovar/AnyPS5) that I opened, that carries my commits, or that I tested on my games. States as of 24 October 2026; the PR page is always the current truth.

## PRs I opened

| PR | What it does | Game behind it | Numbers | State |
|---|---|---|---|---|
| [#10614](https://github.com/boykopovar/AnyPS5/pull/10614) | GameUpdate answers "no update" instead of throwing | Hot Wheels Infinite Rush (PPSA22408) died on the logo screen at about 3.7 min | Gets the game past its update check | Approved, waits merge |
| [#10547](https://github.com/boykopovar/AnyPS5/pull/10547) | Prefers host interpolation on RADV; native barycentrics only where host interpolation cannot be used | Hollow Knight Silksong (PPSA12544) diagonal seam on AMD | Seam gone on Radeon 780M; D2R and Hot Wheels still run; GPU tests pass | Approved, waits merge |
| [#10228](https://github.com/boykopovar/AnyPS5/pull/10228) | Plans an image table for a texture read at a first-lane offset | Ghost of Yotei (PPSA26344) shaders stopping with "GetImageResource ... not a valid runtime value" | Fixes 2 of the 3 failing shaders by offline replay | Waits re-review |
| [#9957](https://github.com/boykopovar/AnyPS5/pull/9957) | Reads a buffer's presence at run time instead of baking it into the shader | Ghost of Yotei giant compute shaders compiled twice | Warm run: giant compiles 21.8 s in 15 min vs 1,221 s | Waits on reviewers (approved earlier, rebased since) |
| [#7618](https://github.com/boykopovar/AnyPS5/pull/7618) | Stages only the written elements of buffers a dispatch writes (discrete GPUs, records wider than one store) | Diablo II Resurrected (PPSA03912) gameplay | 55-57 -> 77-85 presents per 10 s for +150-200 MiB VRAM. On the main menu it costs about 25 GPU ms per frame (73-77 -> 93 presents with it switched off); follow-up being prepared ([run 7](../perf-data/runs/2026-10-24-d2r-main-menu-f32-flush-ab.md)) | Merged 2026-10-25 |
| [#8135](https://github.com/boykopovar/AnyPS5/pull/8135) | Testing guide: memory budgets and sleeping displays | all | docs | Merged |
| [#7591](https://github.com/boykopovar/AnyPS5/pull/7591) | Folds draw offsets the shader reloads after the fetch add, so those indirect draws move to the GPU path | Diablo II Resurrected | GPU indirect draws 0 -> about 3,021 per 10 s; FPS unchanged | Merged |
| [#7428](https://github.com/boykopovar/AnyPS5/pull/7428) | Ngs2 sampler and mixer setup clear the voice callback | Metal Gear Solid: Peace Walker | correctness | Merged |
| [#7200](https://github.com/boykopovar/AnyPS5/pull/7200) | AvPlayer accepts VP9 video and Opus audio | Peace Walker opening movies were black | movies play | Merged |
| [#7072](https://github.com/boykopovar/AnyPS5/pull/7072) | Ngs2 render skips a grain while another thread holds the system lock | Peace Walker froze while loading DLC textures | main froze 2 of 2, fix kept presenting 4 of 4 | Merged |
| [#6627](https://github.com/boykopovar/AnyPS5/pull/6627) | Game testing guide (docs/dev/GAME_TESTING.md) | all | docs | Merged |
| [#5779](https://github.com/boykopovar/AnyPS5/pull/5779), [#5205](https://github.com/boykopovar/AnyPS5/pull/5205), [#5950](https://github.com/boykopovar/AnyPS5/pull/5950) | Depth plane storage views from a later slice, empty indexed draws, sparse dma-buf test skip | general | correctness | Merged |

## PRs by others that carry my commits

| PR | What it does | State |
|---|---|---|
| [#9251](https://github.com/boykopovar/AnyPS5/pull/9251) (SandstromPL) | Decodes MIMG gather opcodes 0xc8 and 0xd8 (my two commits) | Merged |
| [#9183](https://github.com/boykopovar/AnyPS5/pull/9183) (fma-rc) | 3D image gather at level zero; replaces my branch `fix/volume-gather-lz` | Open |
| [#5413](https://github.com/boykopovar/AnyPS5/pull/5413), [#5414](https://github.com/boykopovar/AnyPS5/pull/5414), [#5422](https://github.com/boykopovar/AnyPS5/pull/5422), [#5427](https://github.com/boykopovar/AnyPS5/pull/5427), [#5439](https://github.com/boykopovar/AnyPS5/pull/5439) (mariusyo07) | Five missing system exports for Peace Walker (Json string, Ult mutex/pool destroy, NetCtl V6 callbacks, mspace aligned alloc, AudioOut2 disable chat) | Merged |
| [#1186](https://github.com/boykopovar/AnyPS5/pull/1186) (Michon) | Depth-slice sampling; kept my refusal tests | Merged |
| [#6196](https://github.com/boykopovar/AnyPS5/pull/6196) (SandstromPL) | MSAA draws for Peace Walker; credits my runs | Merged |

## Others' PRs I tested on my games

| PR | What it does | Game | Result |
|---|---|---|---|
| [#7803](https://github.com/boykopovar/AnyPS5/pull/7803), [#8871](https://github.com/boykopovar/AnyPS5/pull/8871) (thuanquang) | 2D MSAA texture reads | Peace Walker; Astro Bot | Peace Walker from blocked to beach tutorial at about 60 FPS; Astro Bot unchanged (does not use that path) |
| [#10655](https://github.com/boykopovar/AnyPS5/pull/10655) (thuanquang) | Import page hashing off the draw thread | Hot Wheels race load, Linux | No clear difference (inside noise); Windows is the real target |
| [#7844](https://github.com/boykopovar/AnyPS5/pull/7844) (Mouhand-Kaddo) | Host heap import budget | Hot Wheels race load, Radeon 780M | No effect (the cap never applies there) |
| [#8139](https://github.com/boykopovar/AnyPS5/pull/8139) (merged) | Sparse page permissions | Hot Wheels race load | Full 4 GiB heap copies remain (460 vs 447) |
| [#7814](https://github.com/boykopovar/AnyPS5/pull/7814) (ionut27001) | VideoOut output resolution | Diablo II Resurrected | 1080p output, but the game still renders at 4K: no change |
| [#9508](https://github.com/boykopovar/AnyPS5/pull/9508) -> [#7642](https://github.com/boykopovar/AnyPS5/pull/7642) -> [#10193](https://github.com/boykopovar/AnyPS5/pull/10193) (Raghav314, EagleBearerYS, Celegans12) | GPU descriptor heap, image tables on the GPU heap, table columns | Ghost of Yotei | Slower in loading (3 vs 14 presents per 10 s); shader cache stores every program twice (reported on #10193) |
| [#8104](https://github.com/boykopovar/AnyPS5/pull/8104), [#9287](https://github.com/boykopovar/AnyPS5/pull/9287), [#9289](https://github.com/boykopovar/AnyPS5/pull/9289) (Celegans12) | Cheaper staged copies | Ghost of Yotei logo phase | No measurable difference |
| [#8912](https://github.com/boykopovar/AnyPS5/pull/8912) (Celegans12) | Pool tiers | Diablo II Resurrected, Radeon 780M | No speed effect over 5 pairs; evictions 0 vs 2,949-4,616 (posted) |
| [#8748](https://github.com/boykopovar/AnyPS5/pull/8748) (LeandroLP23) | Host-placed buffer reuse | D2R and Hot Wheels, Radeon 780M | The new path never fired (posted) |
| [#8932](https://github.com/boykopovar/AnyPS5/pull/8932) (BunnyFl) | Drop pending storage-image results on unmap | Hot Wheels, Castlevania | Not needed on these games: the abort it fixes did not reproduce on current main (0 of 6, 0 of 2) |
| [#6970](https://github.com/boykopovar/AnyPS5/pull/6970) (meh7an) | Inline binding flags | Sonic menu, Castlevania | +8% and +20% (posted) |
| [#6539](https://github.com/boykopovar/AnyPS5/pull/6539), [#5404](https://github.com/boykopovar/AnyPS5/pull/5404), [#4943](https://github.com/boykopovar/AnyPS5/pull/4943), [#5609](https://github.com/boykopovar/AnyPS5/pull/5609) | Draw cache: forwarded user words, bypass under 5% hits, draw relocation | Castlevania, D2R | No measurable gain |
| [#10668](https://github.com/boykopovar/AnyPS5/pull/10668) (meh7an) | Skips repeated fills | Sonic menu | GPU -3 to -4.6 ms per frame, fill class gone; presents unchanged (CPU-bound); [posted on the PR](https://github.com/boykopovar/AnyPS5/pull/10668#issuecomment-6404605718) |

The game pages in [games/](games/README.md) give the full context for each of these.

AI-assisted. Tested by me on my own machine.
