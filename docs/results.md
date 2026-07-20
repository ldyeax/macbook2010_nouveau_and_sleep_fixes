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

The initial boot, S3 and guarded-S4 gates below used Mesa 25.3.6.  Mesa 26.1.5
was installed afterward to gain upstream fence-race fix `0e79791fa5f6`, then
validated separately as described below rather than retroactively folding it
into the earlier S4 claim.

The production boot reached `graphical.target` without the former white-screen
detour or corrupted login frames.  The complete targeted journal scan found
zero PFIFO, PGRAPH, DMA_PUSHER, MMU, trap, timeout, Oops, call-trace or lockup
faults.

## KDE power profiles

On 2026-07-20, `power-profiles-daemon` 0.30 was confirmed to expose only its
placeholder driver on this Westmere/`acpi-cpufreq` system: `balanced` and
`power-saver` were listed but did not control the CPU, and `performance` was
absent.  The production kernel already contained every usable cpufreq governor
and the working `acpi-cpufreq` driver.  Westmere model `0x25` is absent from
Linux's Intel P-State CPU table, so this was not a missing-kernel-option issue.

Gentoo `sys-apps/tuned-2.27.0-r2[ppd]` replaced the placeholder daemon.  Three
custom CPU-only profiles were exercised through the live Plasma 6.6.6
PowerDevil D-Bus action, not merely through TuneD's administrative CLI:

```text
KDE performance -> performance governor on policy0..3, policy boost 1
KDE balanced    -> schedutil governor on policy0..3, policy boost 1
KDE power-saver -> powersave governor on policy0..3, policy boost 0
```

PowerDevil reported all three choices with no degraded or inhibited reason.
`tuned-adm verify` passed after each mode, both TuneD services were enabled and
active, and the final state was restored to `balanced`.  Sentinel values for
VM writeback/swappiness, networking, disk readahead, SATA link power, audio
power saving and NMI watchdog were unchanged across the test, confirming that
the custom mappings did not inherit TuneD's broad built-in profile changes.

## Mesa 26.1.5 reboot and S3 smoke

After the Mesa update, the machine cold-booted the same prod2 kernel and kept
SDDM/Xorg running for roughly 56 minutes before a successful Plasma login.
The new session had no stale installed-library mappings and reported:

```text
direct rendering: Yes
Device: NVA5 (0xa29)
Version: 26.1.5
Accelerated: yes
OpenGL core profile: 3.3, Mesa 26.1.5
KWin compositor active: true
```

A subsequent lid-triggered deep-S3 cycle spent about 33 seconds asleep by wall
clock.  Kernel monotonic time advanced 10.553 seconds from suspend entry
through exit.  The same boot ID and exact KWin/plasmashell processes survived;
the desktop accepted input, direct rendering and compositing remained active,
and NetworkManager restored the `lan` search domain.  Suspend stats were again
`success=1`, `fail=0`, every failed-stage counter was zero, kernel taint stayed
zero, and the post-resume Nouveau fault scan remained empty.

Xorg logged no graphics errors.  It did record a transient libinput failure
for unnamed event nodes belonging to Apple Bluetooth HID proxy IDs
`05ac:820a`/`05ac:820b`; those nodes disappear when the controller transitions
to HCI mode (`05ac:8218`).  The real internal keyboard and bcm5974 touchpad
initialized and remained functional.  This is an input-device enumeration
race, not a Nouveau/Mesa failure.

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
