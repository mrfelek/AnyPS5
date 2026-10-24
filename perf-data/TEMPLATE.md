# <Game title> (<PPSAxxxxx>), <phase>, <what was tested>

- **Date / machine:** YYYY-MM-DD, <machine from machines.md>
- **Build:** upstream commit `<sha>` (+ PR or patch on top, with link and what it does)
- **Environment:** default profile set + <extra env vars>; shader cache warm/cold; audio muted
- **Phase measured:** <loading / menu / gameplay / cinematic>, window <+start..+end s>, <how the game got there>
- **Arms and order:** <A = ..., B = ...; order A B A B>

## Result

One or two sentences: what changed, and by how much.

## Standard set (medians over the measured window)

| Arm | Presents/10 s | Frame p50 | GPU ms/frame | Top GPU classes ms/frame | CPU s/10 s (top threads) | Draw / dispatch cache hits | Uploads / write-backs MiB/10 s | Compiles, disk cache hit/miss | Waits | RAM | VRAM / GPU load |
|---|---|---|---|---|---|---|---|---|---|---|---|

## Which bottleneck moved

Where the time went before, and where it goes now.

## Picture

Same image in every arm? Screenshot or pixel diff note.

## Caveats

Noise, one-off events, anything not ruled out.

AI-assisted. Tested by me on my own machine.
