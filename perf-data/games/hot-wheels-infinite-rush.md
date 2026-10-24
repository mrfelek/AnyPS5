# Hot Wheels Infinite Rush (PPSA22408)

Upstream discussion: [D#6895](https://github.com/boykopovar/AnyPS5/discussions/6895).

## Phases and runs

| Phase | Date | Machine | Build | What | Headline | Page |
|---|---|---|---|---|---|---|
| Race load + race | 2026-10-24 | Linux desktop | `3ca5b17655` | current main; import-hashing A/B | load about 9 min, 460 full 4 GiB heap copies, GPU 19% busy; A/B within noise | [run](../runs/2026-10-24-hot-wheels-race-load.md) |
| Title screen | 2026-10-24 | Linux desktop | `895f47f4e`, `3ca5b17655` | baseline and wait trace | 93 presents/10 s, GPU 64% busy, 41 GB up / 35 GB back per 10 s, 4 s waits per 10 s | [run](../runs/2026-10-24-hot-wheels-title-baseline.md) |
| Title screen | 2026-10-24 | Linux desktop | `895f47f4e` | skip flushing big buffer bindings (upper bound) | +17% presents | [run](../runs/2026-10-24-hot-wheels-title-skip-big-flush-ab.md) |
| Title screen | 2026-10-24 | Linux desktop | `3ca5b17655` | import the read-back buffer | copy gone, wait moves, presents unchanged | [run](../runs/2026-10-24-hot-wheels-title-join-crossing-ab.md) |
| Boot + race load | 2026-10-24 | Linux desktop | `3ca5b17655` | heap copy trace | writable atomic whole-heap binds skip the import and copy the heap | [run](../runs/2026-10-24-hot-wheels-heap-copy-trace.md) |

AI-assisted. Tested by me on my own machine.
