# How we worked

How the measurements and fixes in this repository were made, which approaches the data ruled out, where our own process slipped, and what I would do the same or differently. Written so others can judge whether the approach was right.

## Who and with what

- **One person, with an AI assistant.** I chose the goals, approved every upstream post, push and new fix, and played the games where a human was needed (touch input, menus at 0.5 FPS). The assistant ran in parallel work streams: one per test game, one per test machine, one per topic (draw cache, committer cost, GPU time, menus, PR watch). Each stream kept notes that the others could read.
- **Three machines** ([specs](../perf-data/machines.md)): a Linux desktop with an RTX 3080 Ti (also my daily machine), an AMD mini PC with a Radeon 780M, and a Windows laptop with an RTX A2000. Numbers are never compared across machines.

## Method

- **One run per machine at a time.** Each machine had one queue; every work stream booked runs through it. Runs on my desktop were muted (they kept interrupting my audio), ran under a memory cap (22-25 GB) after one leak froze the machine, and were shown on a spare monitor or a headless display.
- **Same standard set for every run** ([metrics](../perf-data/README.md)): presents per 10 s, frame p50, GPU time per frame by class, CPU per thread, draw and dispatch cache hits, bytes uploaded and written back, shader compiles, waits, RAM and VRAM. A change is never judged on FPS alone, and runs are compared only within the same game phase (loading, menu, gameplay, cinematic).
- **A/B tests:** base and change built from the same main commit, at least two alternating pairs (ABAB), default settings, screenshots of each measured scene. Before testing a fix, first confirm the bug still reproduces on plain current main on that machine.
- **Correctness of cache changes:** the verify modes (`APS5_VERIFY_DRAW_ENTRIES`, `APS5_VERIFY_DRAW_RECIPE`, `APS5_VERIFY_DRAW_DATA_HITS`) on at least three games. Astro Bot once caught wrong cached draws that Castlevania and Sonic missed.
- **Share runs:** one run per game and scene, with every work stream's trace switches folded into it, instead of each stream re-running the game.
- **Before posting upstream:** look for duplicates in open **and closed** PRs and in contributors' branches; read every comment, review and edit on the thread; describe each PR in words; put the game title next to every game ID; end with one plain AI line.
- **Everything goes to this fork:** each run gets a page that is never renamed (upstream posts link to it), plus the analysis, the approaches ruled out and the patches.

## Approaches ruled out, and the way to go instead

These are not failures: each one is measured proof that a direction is not the way, so nobody has to try it again.

| Approach | What the data showed | Way to go instead |
|---|---|---|
| Removing waits one at a time (Hot Wheels title: importing the crossing buffer, skipping big-buffer flushes) | Each removed wait moved to the next reader of the same GPU result; the skip gives +17% only by dropping needed work | Keep GPU results on the GPU and read them there, instead of a round trip through guest memory |
| Moving work to the GPU path while another limit sits right behind it (D2R indirect draws, #7591; skipping the indirect read) | GPU-path draws 0 -> 3,021 per 10 s, FPS unchanged; removing the 3.6 s wait, FPS unchanged | Find the real limit first with the full metric set; on D2R it is the GPU time of 4K draw passes (float denormal fix: +26%) |
| More draw cache hits through relocation (Sonic, Castlevania, D2R) | Hits rose to about 50% with no FPS gain (a hit still costs about 16 us); guessed pointers gave wrong draws; the relocation prototype fails the verifier | Pointer provenance from the recompiler, ring offsets as data, and a cheaper hit path |
| The GPU path chain on Ghost of Yotei (#9508 -> #7642 -> #10193) | Slower in loading; huge vertex shaders; cache stores everything twice | Fix its cache keys and shader size first; for speed, attack the dispatch-forced drains |
| A bigger dispatch cache (Yotei) | Per-dispatch cost went up | Stable cache keys, not more entries |
| Turning off fragment barycentrics on RADV (Silksong seam) | Fixed the seam, broke two other games | Host interpolation first, only for shaders that can use it (#10547) |

The [structural analysis](structural-analysis.md) ties these together into three design problems and a ranked plan. Every patch behind them is in [patches/](patches/README.md).

## Where our own process slipped

| What happened | Cost | What I changed |
|---|---|---|
| **Over-testing.** The Hot Wheels black scenery got about ten probe runs (D18 to D18m2) that narrowed the cause to one GPU-written value but had no near-term payoff. | Machine time and attention that a playable game would have used better | Stopped it. Findings written up once ([Hot Wheels](games/hot-wheels-infinite-rush.md)). Ask sooner whether a deep dive is worth it. |
| **Waits that only moved.** Removing one wait in the Hot Wheels title (importing the crossing buffer) worked technically, but the next reader blocked on the same GPU writer. Moving D2R's indirect draws to the GPU (#7591) did not raise FPS either. | Several A/B runs with no speed-up | Stopped testing wait removals one by one. The [structural analysis](structural-analysis.md) names the underlying design problems instead. |
| **Experiments that only produced findings.** The first nine days of fork branches gave useful numbers but little FPS. | Time | Kept the lab notes, stopped digging, moved to testing others' PRs and to the bottlenecks that matter. |
| **A machine reported as running when it was not.** After the desktop crashed from Ghost of Yotei's memory growth (about 9 GB per minute with the shader disk cache off), its remote session was disconnected but was still reported as working. | Wrong status for hours | Check the session and its latest real activity before saying a machine is busy. Memory guard on every game launch. |
| **Duplicates.** The buffer-presence PR (#9957) missed a closed PR doing the same thing (#5353, Pipodi). Once a reply was posted on #7618 to questions I had already answered. | Reviewers' time | Duplicate checks now include closed PRs and fork branches; read the whole thread first. A prior-art comment credits #5353. |
| **Posted text longer than approved** (one Ghost of Yotei note). | Had to edit it | Post exactly the approved text. |
| **Disk filled by shader caches** (one test build grew its cache to 65 GB). | Runs stopped for a disk clean-up | Watch free disk during runs; stop at a floor. |
| **Questions about tasks already given.** Asking me about layout or each push for work I had already handed over. | My time | Decide and do it; ask only about posts, new fixes and deletions. |

## What worked

- One queue per machine: no collisions on my daily desktop after the first days.
- The standard metric set: several "wins" turned out to only move the bottleneck, and the set showed it.
- Testing others' PRs on real games and posting the numbers, including "no effect", saved them guesswork.
- Small, focused fixes from real game stops: GameUpdate "no update" (Hot Wheels), RADV host interpolation (Silksong), buffer presence and image tables (Ghost of Yotei), Ngs2 lock (Peace Walker). See [upstream-prs.md](upstream-prs.md).

## Where things stand

The data says the slow games are slow for three design reasons: GPU results make a round trip through guest memory, per-draw work is redone because moving ring pointers break the caches, and everything runs through one serialized line. The fourth, smaller one is the float denormal flush emulation on NVIDIA. See the [structural analysis](structural-analysis.md) for the ranked plan.

AI-assisted. Tested by me on my own machine.
