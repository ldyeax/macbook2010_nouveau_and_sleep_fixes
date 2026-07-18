# Root-cause analysis

## 1. PFIFO used stale channel-VMM translations

PFIFO fetches GPFIFO entries and indirect push buffers through a channel's
VMM.  During Nouveau's older engine-module conversion, channel construction
stopped accounting PFIFO as a VMM engine user.  `nv50_vmm_flush()` therefore
did not issue Tesla engine `0x05` invalidation when those mappings changed.

The missing flush can leave PFIFO reading commands through a stale
translation.  The first observable result is a DMA pusher command failure;
once the command stream is poisoned, graphics traps, invalid opcodes,
constant-cache faults and unmapped reads follow.

`0002-nv50-pfifo-tlb-invalidate.patch` fixes both sides of the lifetime:

- increment/decrement `vmm->engref[NVKM_ENGINE_FIFO]` with the channel VMM;
- map `NVKM_ENGINE_FIFO` to the NV50/Tesla `0x05` TLB invalidate.

The common channel bookkeeping is logically broader than this one laptop,
but runtime proof in this repository is limited to NVA5 (`10de:0a29`).

## 2. BAR2 instance-memory save was slow on this root complex

Nouveau preserves instance-memory objects before suspending the GPU.  On NVA5
they are read through a prefetchable, write-combined BAR2 mapping.  Westmere's
ordinary `memcpy_fromio()`/REP MOVSL path measured roughly 1.8 MiB/s here.

DRM's MOVNTDQA WC helper was worse on this exact aperture: roughly 0.25 MiB/s
and a 42.674-second device phase.  That experiment is rejected.

`0003-nva5-qword-bar2-read.patch` adds a narrowly scoped callback which is used
only when all of these are true:

- x86-64;
- chipset code `0xa5`;
- source, destination and length are eight-byte aligned.

It issues four independent scalar 64-bit MMIO reads before storing them,
allowing multiple PCIe completions in flight without SIMD/FPU state.  Every
other chipset, architecture or unaligned request retains `memcpy_fromio()`.
An earlier qword1 build logged a 10.147-second suspend-device phase, while the
prod2 S3 gate advanced 10.567 seconds of kernel monotonic time from suspend
entry through exit.  The latency is accepted; correctness is the primary gate.

The first patch in the series is accepted upstream DRM commit `34e27b90552a`,
which changes NV50 instance memory to the `io_mapping` API.  It is a tested
prerequisite/backport in this build, not the PFIFO correctness fix.

## 3. Separate userspace hazards

The kernel fault fix did not make every greeter path automatically safe.

- Xorg's legacy `xf86-video-nouveau` DDX with a forced DRI3 path could leave a
  Qt Quick render thread waiting for a Present event after greeter blanking.
  The production configuration uses Xorg `modesetting` + glamor instead.
- Mesa commit `f2af3a9cae2` introduced a fence-reference race.  Upstream fixed
  it in `0e79791fa5f6`; Mesa 26.1.5 contains the fix.  The official patch is
  retained under `patches/mesa/` for provenance or older-version backports.
- SDDM's X server is launched with `-s 0 -dpms` so an unattended greeter stays
  visible.  This does not override the logged-in user's Plasma display policy.

These changes complement one another but should be tested separately.  A
clean kernel fault log is what distinguishes PFIFO/MMU correctness from an
Xorg/Qt presentation wait.
