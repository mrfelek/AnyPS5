# Machines

Numbers from different machines are not comparable with each other. Compare runs only on the same machine.

| Name used in run pages | CPU | GPU | RAM | OS / driver |
|---|---|---|---|---|
| Linux desktop | AMD Ryzen 9 5950X (16 cores) | NVIDIA RTX 3080 Ti, 12 GB | not recorded | Ubuntu 26.10, kernel 7.3, NVIDIA 615.71.09 |
| AMD mini PC | AMD Ryzen 9 PRO 8945HS (16 threads) | AMD Radeon 780M iGPU (RDNA3), RADV | 29 GiB (shared with GPU) | Ubuntu 26.04.1, kernel 7.0, Mesa 26.0.8, Vulkan 1.4.335 |
| Windows laptop | Intel i7-11850H (8 cores) | NVIDIA RTX A2000 laptop | not recorded | Windows 11 25H2, NVIDIA 610.60 |

Notes:
- The Linux desktop has 12 GB of VRAM, which is tight for large games. Runs that needed a lower texture budget say so.
- The Windows laptop throttles when hot, so its wall-clock times (load times) are only comparable within one A/B session.
- Games run on the Linux desktop under a memory cap (22-25 GB) so a leak cannot freeze the machine; a run stopped by the cap is marked as such.

AI-assisted. Tested by me on my own machine.
