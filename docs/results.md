# Tested results

## Production build

- Kernel: Gentoo Linux `6.18.38-gentoo-nouveau-prod2`;
- GPU: GT216M/NVA5, `10de:0a29`;
- 157 installed kernel modules, all matching production vermagic;
- Nouveau built in; module-signature checking disabled on this non-enforcing
  legacy-BIOS build, avoiding the previous unsigned-module taint;
- kernel taint after boot and power tests: `0`;
- Xorg: generic `modesetting`, glamor OpenGL 3.3, DRI3, Present, page flips;
- renderer: direct/accelerated Mesa NVA5 at 1920x1200.

The completed boot, S3 and guarded-S4 gates below used Mesa 25.3.6.  Mesa
26.1.5 was installed afterward to gain upstream fence-race fix `0e79791fa5f6`;
at the time of this snapshot, its final reboot/login/S3 smoke test was still
pending and is not folded into the earlier power claims.

The production boot reached `graphical.target` without the former white-screen
detour or corrupted login frames.  The complete targeted journal scan found
zero PFIFO, PGRAPH, DMA_PUSHER, MMU, trap, timeout, Oops, call-trace or lockup
faults.

## Deep S3

A real lid-close test spent roughly 1 minute 53 seconds asleep by wall clock.
Kernel monotonic time, which excludes time actually asleep, advanced 10.567
seconds from suspend entry through exit.  Results:

```text
success: 1
fail: 0
all failed_* counters: 0
last_failed_errno: 0
```

The same Plasma session remained interactive, Wi-Fi reassociated, the kernel
stayed untainted, and no Nouveau fault appeared before or after resume.

## Direct S4

The first S4 test used 32 GiB of empty swap for 7.7 GiB RAM, a matching resume
UUID in GRUB/initramfs, `HibernateMode=shutdown`, and a one-shot production
restore entry while retaining a `noresume` fallback.

After power-on, the restored system retained the exact pre-hibernation kernel
boot ID and the exact same KWin and plasmashell PIDs.  systemd returned from
the hibernate operation and thawed the same `user.slice`.  Acceleration,
display mode, networking and the desktop were healthy; the Nouveau fault scan
remained empty.

## Negative measurements

- ordinary BAR2 `memcpy_fromio()`: about 1.8 MiB/s on this platform;
- rejected MOVNTDQA/WC helper: about 0.25 MiB/s and a 42.674-second device
  phase;
- accepted four-qword GPR path: about 2.8 MiB/s in the diagnostic benchmark;
- an earlier qword1 build logged a 10.147-second suspend-device phase;
- the prod2 deep-S3 gate advanced 10.567 seconds of kernel monotonic time from
  suspend entry through exit.

These numbers are platform-specific.  Other NVA5/root-complex combinations
must be benchmarked and validated rather than assumed equivalent.
