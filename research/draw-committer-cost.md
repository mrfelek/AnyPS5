# Draw committer: per-draw cost

Sonic Origins Plus (PPSA05325) Sonic 2 menu, Linux desktop (RTX 3080 Ti), upstream `a19e7f6fd`, 2026-10-24. Run: [Sonic S2 menu](../perf-data/runs/2026-10-24-sonic-s2-menu-draw-cache.md).

## The committer's 16.5 us per draw, by phase (medians of 12 windows)

The committer (`DrawPipeline::run` -> `Driver::commitDraw` -> `VulkanDevice::Draw`) spends ~7.1 s per 10 s on ~430k commits. ~410k of ~414k draws are template hits (resource cache hit), and 97% continue an already open render pass.

| Phase | ms / 10 s | us / draw | What runs there |
|---|---|---|---|
| record | 1,671 | 4.1 | recordDraw: render pass key, store-flush checks, **PrepareDrawBindings** (per draw: snapshot or upload every in-place read buffer, fresh descriptor set, vkUpdateDescriptorSets), pass access lists, hazard check, bind + push + draw |
| lookup | 1,449 | 3.5 | resolveDrawResources: ~100-word key + hash, SharedResourceCache().Find, **ShaderResources::Revalidate**, MovedReadOnlyBuffers (the moved ring pointers), CheckBufferAliases; rare 19-24 ms hook waits |
| vertex | 782 | 1.9 | prepareDrawInputs: vertex fetch planning, per-range in-place/copy inputs |
| keep | 765 | 1.9 | keepRecordedDraw: make_shared, recorder Keep/KeepBytes, MarkGpuWrites, MarkSliceDirty, linear-target FlushPending |
| prepare | 490 | 1.2 | setup between target lookup and resources |
| pipeline | 486 | 1.2 | masked state copy, CachedPipeline lookup, AcquireFramebuffer |
| readTarget | 344 | 0.8 | refreshResidentTarget (~38 pages walked per lookup) |
| validate | 218 | 0.5 | input checks, cached fragment outputs |
| setup / resources | 222 | 0.5 | target setup; the ~2.4k real builds |
| outside Draw | ~700 | ~1.6 | GPU mutex, labels, writer notes, submit |

Recipe hits (1.1k per 10 s) cost 31 us, twice a template hit, so the recipe path is not the way to cut cost here.

## Worker and committer are both near their limit

- Worker (queue 0): 18.4 us x 420k = 7.7 s per 10 s, plus 12.1k packet drains (mostly DMA_DATA) = 0.7 s.
- Committer: 7.1 s per 10 s. Queue depth seen by the worker averages 0.88 of 8.
- So cutting only one side moves FPS little; both need to get cheaper.

## Other games

- Diablo II Resurrected (PPSA03912) main menu (RTX 3080 Ti): ~39 us per commit, 143k commits per 10 s, but the menu is GPU-bound.
- Diablo II Resurrected main menu on the AMD mini PC (Radeon 780M): queue worker 0 at 99%, ~70.7k draws per 10 s at ~46 us each.
- Ghost of Yotei (PPSA26344) cinematic (fork build): 11,439 commits per 10 s at 381 us; dominated by readTarget page walks (209 lookups of 1 ms or more = 937 ms, worst draw 219.5 ms) and address-based builds (1,938 at 751 us). A different profile from Sonic.

## Upstream (checked 2026-10-24)

No open PR does a general "cut the committer's per-draw cost" change. Relevant:

| PR / issue | What it does | State | Phase it hits |
|---|---|---|---|
| issue #7895 (SP4C3B4R-8) | parallel draw recording; maintainer wants small off-by-default steps with before/after timings | open | all |
| #8992, #8278 | draw prepare/record split, dispatch complete/record split | merged | groundwork |
| **#9508** (Raghav314) | GPU descriptor heap, `APS5_GPU_HEAP=1`, needs VK_EXT_descriptor_heap: skips the per-draw descriptor set rebuild (Hades II committer 2.6 -> 1.2 ms/frame) | open | record, part of lookup |
| **#9012** (SP4C3B4R-8) | audit a cached template only after the host-import set changed (Astro Bot revalidate 1,542 -> 1,162 ms/10 s) | open | lookup |
| #10103, #9875, #9897 | smaller per-draw copies | open | vertex |
| #6972 (meh7an) | faster resource-cache hash; closed by its author, no gain on current main | closed | lookup |

Candidates for our own change (not written): keep per-pass objects once per pass instead of per draw; skip render pass key / pipeline / framebuffer work when the draw's state equals the previous draw in the same pass; patch the moving ring pointers through dynamic offsets if #9508 cannot be used. Timer patch: [patches/committer-split-timers.diff](patches/committer-split-timers.diff).

## Update 2026-10-25: Radeon 780M, D2R character select

Split timers on AMD: about 46 us per draw, of which descriptor set allocate 0.5 us and update 1.6 us; the draw-and-submit step takes about 48 us per commit. My descriptor set reuse prototype cut descriptor writes by about 30% but left cost per draw, presents and GPU time unchanged, so it is ruled out. The next step is to break down draw-and-submit and name the threads so committer and queue-worker time can be told apart. [run](https://github.com/mrfelek/AnyPS5/blob/main/perf-data/runs/2026-10-25-d2r-character-select-amd-draw-set-reuse.md)

AI-assisted. Tested by me on my own machine.
