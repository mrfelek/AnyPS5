# Death Stranding 2: On the Beach

What I did on this game, in one place. Upstream discussion: [D#5424](https://github.com/boykopovar/AnyPS5/discussions/5424). I don't use it for speed tests: it has too many other problems, so its numbers are too noisy.

## Where it gets to

The last blocker I saw is the fragment/colour output: the game runs but shows no image.

## Fixes that carry my work

| Change | What it does |
|---|---|
| [#9251](https://github.com/boykopovar/AnyPS5/pull/9251) (SandstromPL, carries my commits) | Decodes the MIMG gather opcodes 0xc8 and 0xd8. Labelled "unblocks title". |
| [#9183](https://github.com/boykopovar/AnyPS5/pull/9183) (fma-rc) | 3D image gather; replaces my earlier branch `fix/volume-gather-lz`. |

Note for anyone testing: the game's `localcacheps5` folder can be a symlink into the dump. Check symlinks before copying or moving files, or you can move `fullgame.prx` out of the dump.

AI-assisted. Tested by me on my own machine.
