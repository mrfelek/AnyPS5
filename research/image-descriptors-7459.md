# Ghost of Yotei (PPSA26344): the 3 "GetImageResource ... not a valid runtime value" shaders (issue #7459 family)

Date: 2026-10-23. Upstream main aef58d467. Offline replay, no game run.

## How
- Took the 3 failing shaders' full recompile requests from the log of a 2026-10-22 run (main 11f976b27).
- Built `agc_shader_replay` (gcc Release, like upstream CI; the clang build segfaults in Tracker::Run on replay) and replayed them. All 3 fail the same way on today's main, so the problem isn't fixed yet.
- Disassembled the GPU code with `llvm-mc-18 -triple=amdgcn -mcpu=gfx1030` (dumped with `agc_shader_replay --code`).

## Candidate upstream PRs, replayed
| Variant | 0x80001f1100 | 0x8000139c00 | 0x800037fe00 |
|---|---|---|---|
| main aef58d467 | fails | fails | fails |
| + Yunus Shaikh stack (#9790 + #9749, includes #7395/#8939/#9457/#9633) | fails | fails | fails |
| + #8077 (descriptor-web folds, 0xcrstn; merged locally, 3 trivial conflicts) | fails | fails | fails |
| + #6488 (per-lane T# waterfall via image tables; merged locally) | fails | fails | fails |

None of the open PRs fixes any of the 3.

## What the shaders do
All 3 are compute shaders, wave64.

### 0x80001f1100 and 0x8000139c00 (same pattern, pc 0x21f4 / 0x29d0)
```
v_readfirstlane_b32 vcc_lo, v8        ; per-lane index, assumed uniform
v_lshlrev_b32 v8, 5, v8
v_lshl_add_u32 v8, v8, 1, v8          ; v8 = index * 96
v_readfirstlane_b32 vcc_hi, v8
s_buffer_load_dwordx8 s[56:63], s[36:39], vcc_hi   ; T# from a 96-byte record table in an SRT buffer
image_sample_lz v[8:10], v[85:86], s[56:63], s[20:23]
```
The T# is read from a table of records (96-byte stride) in a buffer whose V# comes from the SRT. The record index is a per-lane value that the shader takes from the first active lane (no waterfall loop: the game knows the index is the same for the whole wave).
Main already has image tables for "T# read from a buffer at key*stride", but `TryMakeTableColumn` (ResourceTracker.cpp) only accepts an offset of the form `key<<n`, `key*imm` (+imm) or a masked one. Here the offset is `ReadFirstLane(SelectU32(...))`, a first-lane read of a value merged across divergent branches, which comes out as (x<<6)+(x<<5). So no table is planned and the direct-descriptor check fails.

### 0x800037fe00 (pc 0x9b4)
Per-lane cascade selection: each lane tests its position against up to 4 regions and picks 1 of a few T#s (initial s[20:27], or ones read from the SRT constant buffer at fixed offsets 0x1b8/0x370/0x528). It copies them into VGPRs v[27:34] and then runs a standard readfirstlane + v_cmpx waterfall loop around `image_sample_lz`.
Main's descriptor-web split (SplitDescriptorWeb) does try it: 8 Phis, 2 arms, 3 states. It gives up because one path's "T#" words are per-lane arithmetic (`IAdd32(ISub32(Imm, srt), IAdd32(srt, BitwiseOr32(...)))`), i.e. leftover register contents on a path that reaches the sample only with no active lanes. `Rematerialize` refuses it (ResourceTracker.cpp WebSelector, the "phi == tuple.end()" arm check). #8077 folds such paths only when they hold the program counter, EXEC or a lane mask, not general per-lane arithmetic.

## Fix directions
1. Shaders 1f1100/139c00: let image-table planning accept an offset under ReadFirstLane (key = the first-lane value, stride from its known-zero low bits, as MatchKeyDomain already does for unknown offsets), or recognise `(x<<a)+(x<<b)` as a scale. Small, in ResourceTracker.cpp, with a unit test in tests/ShaderMemory.cpp.
2. Shader 37fe00: treat a descriptor-web path whose words are per-lane (non-uniform) values like #8077's folded paths: select the first descriptor and record a DescriptorFault if a lane ever takes it. Best done on top of #8077, coordinated with its author 0xcrstn.

Outcome: direction 1 was opened upstream as #10228 (image table for a T# read at a first-lane offset). A draft of direction 2 is in [patches/descriptor-web-fold-lane-index.patch](patches/descriptor-web-fold-lane-index.patch), meant as a follow-up to #8077.

AI-assisted. Tested by me on my own machine.
