# Diablo II Resurrected (PPSA03912), main menu, trace evidence for the float flush PR

Question: for [#11297](https://github.com/boykopovar/AnyPS5/pull/11297) (NVIDIA f32 denormal flush), a reviewer asked for trace evidence: where the time goes on main and with the change, and whether the Vulkan validation layer stays clean.

- **Date / machine:** 2026-10-26, Linux desktop (RTX 3080 Ti, NVIDIA 615.71.09, Ryzen 9 5950X). See [machines.md](../machines.md).
- **Builds:** main = upstream `49d1f9b07ec7`; change = `84c51093e3e1`, the same two commits as the PR head `2eacdd2b13` on that main.
- **Setup:** one boot each, main first; shader disk cache off, pipeline journal threads 0, menu reached at +125 s, headless, audio muted, memory cap, trace window `APS5_TRACE_SECONDS=250:10`. 3840x2160.

## Result (window 250-260 s)

| | Presents in 10 s | Frame p50 / p99 ms | GPU busy ms per present |
|---|---|---|---|
| main `49d1f9b07ec7` | 76 | 132.8 / 148.5 | 128.4 |
| change `84c51093e3e1` | 95 | 105.0 / 112.3 | 96.7 |

The interval lines near 250 s from the earlier untraced runs ([run 7](2026-10-24-d2r-main-menu-f32-flush-ab.md)) agree: 76 vs 88 presents, GPU 129.9 vs 105.5 ms.

- GPU draw time per frame: 90.6 -> 60.2 ms. Driver.Draw on queue worker 0x0: 70.1 -> 45.1 ms.
- On main the largest GPU batches are draws of about 23 ms. With the change the five largest are staging-out + staging-in copies of about 21 ms, from upstream's written shadows, present on both builds (see run 7).
- Caveat: both traces report `trace_dropped=true`. Queue worker 0x0 lost events after 6.6 s (main) and 5.6 s (change); its totals are complete, but its per-slice lists miss the end of the window.

Files: [summary line, main](../data/11297-evidence/summary-main-trace.jsonl), [summary line, change](../data/11297-evidence/summary-pr-trace.jsonl), [trace digest, main](../data/11297-evidence/digest-main.txt), [trace digest, change](../data/11297-evidence/digest-pr.txt) (`tools/trace_digest.py` output). The raw traces (about 5.3 MB gzipped each) stay local.

## Validation-layer tests
Command: `ANYPS5_REQUIRE_VULKAN=1 ANYPS5_NO_SHADER_CACHE=1 VK_INSTANCE_LAYERS=VK_LAYER_KHRONOS_validation ctest --test-dir <tree>/build-rel -R 'agc_driver_f32_denormal_flush|agc_f32_denorm_preserve|agc_float32_flush_control' -V`
- The A4 tree was reconfigured with BUILD_TESTING=ON and rebuilt; rt-A4 was not touched.
- main: 3/3 passed (#473 agc_float32_flush_control 0.00 s, #481 agc_f32_denorm_preserve 0.01 s, #782 agc_driver_f32_denormal_flush 0.58 s).
- PR: 3/3 passed (#473 0.00 s, #481 0.02 s, #782 0.41 s).
- "was not found but was requested by env var VK_INSTANCE_LAYERS": 0 hits in both logs. A VK_LOADER_DEBUG=layer rerun of #782 shows "Insert instance layer VK_LAYER_KHRONOS_validation" in both.
- VUID- lines: none in either log. No "Validation Error". vuid-diff is empty.
- Only #782 creates a Vulkan device; #473 and #481 test shader generation only.

AI-assisted. Tested by me on my own machine.
