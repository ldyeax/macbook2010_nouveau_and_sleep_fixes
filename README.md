# MacBookPro6,1 Nouveau and sleep fixes

This repository records a working, rollback-safe configuration for a mid-2010
17-inch MacBook Pro (`MacBookPro6,1`) with an NVIDIA GT216M / GeForce GT 330M
(`10de:0a29`, Nouveau chipset `NVA5`).  It fixes the boot/login GPU-fault burst,
restores reliable lid-triggered deep S3, enables direct S4 hibernation, and
keeps hardware-accelerated Plasma X11.

The validated kernel/power stack is:

- Gentoo Linux 6.18.38 with the three patches in `patches/linux/series`;
- Nouveau built into the kernel, with `nouveau.ignorelid=1` on this Apple
  wiring;
- Xorg's generic `modesetting` driver with glamor, DRI3 and page flipping;
- Mesa 25.3.6 during the recorded S3/S4 gates, followed by a staged update to
  Mesa 26.1.5 containing upstream commit `0e79791fa5f6`;
- ACPI deep S3 and direct S4 through a matching resume-enabled kernel entry.

## Validated result

The production kernel booted with taint `0` and no PFIFO, PGRAPH, MMU,
DMA_PUSHER, trap, timeout, Oops or lockup faults.  A real lid-triggered deep-S3
cycle completed with `success=1`, `fail=0`; kernel monotonic time from suspend
entry through exit advanced about 10.56 seconds.  A guarded S4 test restored
the same kernel boot ID and the exact same KWin and Plasma processes.  The
desktop remained directly rendered by NVA5 after both transitions.  Those
power gates used Mesa 25.3.6; the post-reboot Mesa 26.1.5 smoke result is kept
separate in [tested results](docs/results.md).

## Start here

1. Read [hardware and symptoms](docs/hardware-and-symptoms.md) and
   [root cause](docs/root-cause.md) to confirm that the machine and faults
   match.
2. Follow the side-by-side, known-good-fallback procedure in
   [Gentoo installation](docs/install-gentoo.md).
3. Validate boot and S3 before enabling S4, following
   [power and hibernation](docs/power-and-hibernation.md).
4. Use [validation](docs/validation.md) after every kernel, Mesa or Xorg
   change.

`config/kernel/config-6.18.38-prod2` is the exact tested kernel configuration.
It is useful as a reproducible reference but is deliberately pruned for this
specific MacBook, disk layout and peripherals.  The graphics fixes do not
require copying that pruning blindly to another machine.

## Patch status

The Linux patches are exact, runtime-tested local backports.  Apply them in
the listed order to Linux 6.18.38.  They also pass `git apply --check` on
Gentoo 6.18.18, but production testing was performed on 6.18.38.

They are not yet an upstream-ready submission series.  The two locally
authored patches need a human author to review the changes, certify the Linux
DCO with their own `Signed-off-by`, and address the notes in
[provenance](docs/provenance.md).  Do not treat the AI-generated sign-off in
the preserved qword patch as human DCO certification.

The MOVNTDQA/WC and legacy-GPFIFO experiments under
`patches/linux/rejected/` are retained only as negative evidence.  Never apply
them to a production kernel.

## Repository map

- `patches/linux/`: accepted Linux series and clearly rejected experiments;
- `patches/mesa/`: upstream Mesa race fix for provenance/backporting only;
- `config/`: tested kernel, Xorg, SDDM, systemd, NetworkManager and Portage
  material;
- `scripts/`: portable build and validation helpers;
- `tools/`: the BAR2 read benchmark used during diagnosis;
- `docs/`: diagnosis, installation, rollback, results and provenance;
- `provenance/`: compact build/config/disassembly evidence, not boot binaries.

This work intentionally stays on Nouveau.  The legacy proprietary NVIDIA
driver is not required or recommended here.

## Licensing

The repository's original documentation and helper scripts are covered by
the top-level MIT license.  Copied Linux-derived patches remain subject to the
Linux kernel's GPL-2.0-only terms, and the Mesa patch remains subject to Mesa's
license.  See [licensing](docs/licensing.md) and [NOTICE](NOTICE.md).
