# Shader function-table calls (upstream main 21554447d, 2026-10-23)

## What main already does
- The log line "could not be prepared at registration (its s_swappc_b64 ... calls a computed target); preparing it when it is used" is only a DEFERRAL (ShaderRegistry.cpp, UnresolvableSwappcTarget). It is not a failure.
- At first use, COMPUTE shaders get their callees linked (LinkUserDataCallees in ShaderRegistry.cpp):
  - user-data calls: target pair is user data (or an s_mov copy) -> callee read from guest memory and inlined (#3294).
  - table calls: target = two dwords of an s_buffer_load from a V# loaded by s_load_dwordx4 off a user-data or constant pointer -> up to 64 callees read from the table and inlined behind a compare chain (#4706, #7413, #6160).
- GRAPHICS stages (vertex/pixel/etc.) get NO callee linking (LinkUserDataCallees returns early for non-compute; only the fetch-shader call and the user-data tail are handled).
- If linking does not apply, the shader throws at use: "shader 0x.. stage N: computed/data-dependent s_swappc_b64 call target at program counter 0x.. is not statically resolvable" (GraphBuilder.cpp).

## Our evidence
- Astro Bot (PPSA21564) (main cecb540a6): 96 shaders deferred with that reason, but ZERO use-time failures, zero "not statically resolvable", zero table-callee errors, 0 driver errors. So on current main this is NOT what limits Astro Bot (its limit is ~8 FPS).
- Ghost of Yotei (PPSA26344) (main 11f976b27, 2026-10-22): 104 deferred with that reason. Use-time outcome unknown: not checked at that point.
- Hot Wheels Infinite Rush (PPSA22408) (AMD mini PC, main f6075c2, 2026-10-22): 105 deferred. Use-time outcome unknown: not checked at that point.

## Open upstream fixes (all compute-only, none reviewed yet)
- #8070 (thuanquang): link a table call whose V# is a slice of an s_load_dwordx8/x16. Helped Little Nightmares, Severed Steel, Ghostrunner, Persona 3 Reload.
- #9068 (frankea): link big callee sets that exceed s_call_b64 range, fix 64-bit link-pair overwrite, relay branches for a 2nd table call. Helped GT7, Ghostrunner, P3R (with #8070).
- #8140 (tv7/Lexroid): link table callees that read their own program counter (s_getpc_b64). Helped Wolverine (next stop #6191). Conflicts with #9068 in GraphBuilder.cpp LinkCalls.
- #7816 (Capmare): pass the real wave size to the call analysis (wave64 link-pair refusal). Wolverine.
- Related: #9702/#9703 (frankea) structurizer speed for the huge linked shaders; issue #7459 (GetImageResource on a Phi chain) is the next stop for most titles after linking.
- Issue #3274 (Ratchet & Clank): per-lane function table in a waterfall loop, compute. Still open, no PR. No PR at all links callees for graphics shaders.

## Result of the log check (2026-10-23)
Logs read: Ghost of Yotei (PPSA26344) on main 11f976b27 and Hot Wheels Infinite Rush (PPSA22408) on the AMD mini PC, main f6075c2.
- Yotei: 104 deferrals, 0 use-time "not statically resolvable", 0 table/user-data callee errors. Its real shader failures: 3x "GetImageResource dword 0 is not a valid runtime value" (chains ReadConstBuffer->GetBufferResource->GetSrtResource, and ReadFirstLane(Phi(SelectU32...))) = issue #7459 family, plus 10x unsupported MIMG 0xe5 (BVH).
- Hot Wheels: 105 deferrals, 0 use-time call failures, and no other shader failures either. The black scenery has another cause.
- Astro Bot: 96 deferrals, 0 failures (see above).
=> Table calls are not a blocker for any of our three games on current main. The open PRs above help other titles (Wolverine, Ghostrunner, P3R, GT7, Little Nightmares).

AI-assisted. Tested by me on my own machine.
