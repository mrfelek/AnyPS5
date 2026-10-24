# Hot Wheels Infinite Rush (PPSA22408), race load, host heap out of the import budget (A/B, AMD)

- **Date / machine:** 2026-10-24, AMD mini PC (Radeon 780M, RADV). See [machines.md](../machines.md).
- **Build:** A = upstream main `137a8fab89`; B = A + the source change of [#7844](https://github.com/boykopovar/AnyPS5/pull/7844) (keep the host heap out of the import budget; PR head `1faccc35be`, applied by hand because the PR is 400 commits behind main). Both arms carry a test GameUpdate change to pass the update check.
- **Environment:** default profile set, audio muted.
- **Phase measured:** race load, 15 minutes from pressing Cross. Order A1 B1 A2 B2.

## Result

No effect on this machine. All four starts are at 25% loaded after 15 minutes, and import failures and budget cuts happen in both arms. The reason: this box reports a 5658 MiB host heap, so the PR's reserve (max(2 GiB, min(host heap / 2, 4 GiB)) = 2829 MiB) equals the default and its 4 GiB cap never applies. The failures follow the driver's memory budget (about 5.2-5.7 GiB).

| Start | Import failures | Budget lowered (events, final) | Load at 15 min | Presents/s | GPU busy/present | Memory wait/frame | CPU total | RSS max | VRAM | GTT max |
|---|---|---|---|---|---|---|---|---|---|---|
| A1 | 67 | 36, 225 -> 2 MiB | 25% | 0.26 | 330 ms | 3.77 s | 107% | 12.0 GiB | 2.0 GiB | 9.9 GiB |
| B1 | 61 | 33, 227 -> 2 MiB | 25% | 0.26 | 327 ms | 3.79 s | 107% | 12.0 GiB | 2.0 GiB | 9.9 GiB |
| A2 | 58 | 34, 229 -> 2 MiB | 25% | 0.26 | 327 ms | 3.71 s | 106% | 12.2 GiB | 2.0 GiB | 9.9 GiB |
| B2 | 248 | 78, 2556 -> 28 MiB | 25% | 0.26 | 325 ms | 3.81 s | 106% | 12.1 GiB | 2.0 GiB | 10.8 GiB |

B2 is an outlier: it started with 1.9 GiB of imports already live, its copies moved to the GPU (59,808 regions, 10.5 GiB, against 37-118 regions in the other starts) and CPU guest reads fell from about 675 s to 476 s. Load and FPS stayed the same, so this looks like start-to-start variance.

## Which bottleneck it is

Same in all four starts: both queue workers at 100%, per frame 3.7-3.8 s of memory wait and 3.4-3.6 s of dispatch resource building, GPU about 3% busy. Nothing moved between the arms. On this machine the race load is about 4x slower than on the [Linux desktop](2026-10-24-hot-wheels-race-load.md).

AI-assisted. Tested by me on my own machine.
