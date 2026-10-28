# Ghost of Yotei (PPSA26344), #7618 written-only staging vs revert: not testable on current builds

Question: does [#7618](https://github.com/boykopovar/AnyPS5/pull/7618) (stage only the written elements of buffers the GPU writes) change speed in Ghost of Yotei, as it does in Diablo II Resurrected ([D2R A/B](2026-10-28-d2r-written-only-staging-revert-ab.md))?

- **Date / machine:** 2026-10-28, Linux desktop (RTX 3080 Ti 12 GB, 32 GB RAM). See [machines.md](../machines.md).
- **Builds:** A = upstream `cc672fdfc6` (PR in); B = `2604726ada`, the same main with #7618 reverted (the build used for the D2R revert pair).
- **Setup:** headless, audio muted, all traces on, memory guard (4 GB free floor, 20 GB game cap).

## Result: no data, Yotei does not reach a playable state on these builds

| Attempt | What happened | A vs B |
|---|---|---|
| Default settings, shader disk cache off (2 starts per arm) | All 4 starts stopped by the memory guard: the game holds 8-10 GB, then jumps to 17-19 GB (anonymous + shared memory) at +126..+383 s | same |
| Default, shader cache on, cold (1 per arm, 600 s) | No guard trip (max about 10 GB), but a black screen after the logo the whole time while shaders compile (cache grew to 18 GB, 1-26 presents per 10 s) | same |
| Default, shader cache on, warm (1 per arm, 600 s) | Still black. 82-92 presents per 10 s at boot, then 12-17. World streaming audio loads. GPU queue 0x50 is stuck in `WAIT_REG_MEM` (227 s logged in one 10 s window) | same |
| The env list of my earlier world runs, warm caches (1 per arm, 600 s) | Both arms all black (screenshots and the game's own frame dump, mean 0.03/255); 35-80 presents per 10 s at boot, then 2-25 | same |

Env list of the last attempt (both arms): `APS5_SPANNED_WAVE=1 APS5_BINDLESS_IMAGES=1 APS5_BINDLESS_LAZY=1 APS5_NO_RESULT_MEMO=1 APS5_STAGING_DIFF=1 APS5_PIPELINE_INDIRECT=1 APS5_NO_ADDRESS_DRAW_REUSE=1 APS5_ASYNC_LANE=51 APS5_DEFER_REFRESH_FLUSH=1 APS5_BDA_CONTINUE=800029c200 APS5_NO_PRECISE_SMALL_OVERLAP=1 APS5_RESOURCE_CACHE_ENTRIES=1024 APS5_STAGING_POOL_MIB=512`.

**Verdict:** this A/B cannot be done on Yotei with `cc672fdfc6` / `2604726ada`. Both arms behave the same in every attempt, so the black screen and the GPU wait are not caused by #7618. My earlier world runs used an older local integration build that these switches no longer reproduce. **Way to go:** measure #7618 on titles that reach gameplay on current main (Diablo II, Sonic, Hot Wheels are on the [D2R page](2026-10-28-d2r-written-only-staging-revert-ab.md)); come back to Yotei when current main shows the world again. No more runs booked.

AI-assisted. Tested by me on my own machine.
