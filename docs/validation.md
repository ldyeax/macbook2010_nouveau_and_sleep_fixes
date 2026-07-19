# Validation checklist

Run `scripts/validate-boot.sh` as root after every relevant boot.  It reports
the active release/command line, connector state, sleep configuration, driver,
fault counts and PM timing from a selected journal boot.

## Boot and kernel

```bash
uname -r
cat /proc/cmdline
cat /proc/sys/kernel/tainted
lspci -nnk -s 01:00.0
cat /sys/module/nouveau/parameters/ignorelid
cat /sys/power/mem_sleep
cat /sys/power/resume
```

Require the intended unique kernel release, Nouveau bound to `10de:0a29`,
taint zero, `ignorelid=1` (some tools may render a boolean as `Y`), `[deep]`,
and the expected resume device.

## Fault scan

```bash
journalctl -b -k --no-pager | grep -Ei \
  'nouveau|DMA_PUSHER|PGRAPH|PFIFO|MMU|TRAP|timeout|BUG:|WARNING:|Call Trace:'
```

The pass criterion is zero DMA_PUSHER, cache, opcode, trap, trapped-access,
MMU-timeout, Oops and trace faults.  The tested GT216M's probe-time
`failed to create ce channel, -22` is acceptable only when immediately
followed by `MM: using COPY for buffer copies` and no later GPU fault.

## Xorg, Mesa and Plasma

```bash
glxinfo -B
grep -Ei 'modeset\(|glamor|DRI3|Present' /var/log/Xorg.0.log
grep -E '^\[[^]]+\][[:space:]]+\(EE\)' /var/log/Xorg.0.log || true
xrandr --current
```

Require direct rendering, accelerated NVA5, generic modesetting, glamor,
DRI3/Present, the internal panel's native mode, and zero graphics-related Xorg
errors.  Anchoring the grep avoids Xorg's informational `(EE) error` legend,
but every real record still needs classification.

On the tested Mac, Xorg can briefly see unnamed Apple Bluetooth HID-proxy
keyboard/mouse nodes (`05ac:820a`/`05ac:820b`) while they disappear during the
controller's transition to HCI mode (`05ac:8218`).  The resulting
`Invalid path`, `Failed to create a device`, and `PreInit returned 2` sequence
is acceptable only for those vanished unnamed nodes, with the real internal
keyboard and bcm5974 touchpad initialized and working.  Do not waive video,
modeset, glamor, DRI, Present, GPU-hang or persistent input errors.

Check the greeter, Plasma login, lock/unlock, VT switching and a few accelerated
applications.  SDDM's live X arguments should include `-s 0 -dpms`.

## Suspend and hibernation

```bash
cat /sys/kernel/debug/suspend_stats
journalctl -b -u systemd-suspend.service --no-pager
journalctl -b -u systemd-hibernate.service --no-pager
```

Follow the gates in `docs/power-and-hibernation.md`.  Scan the kernel log
again after every resume and verify the desktop remains interactive.

## Build checks

Before installing a newly rebuilt kernel:

- verify all patch hashes and `git apply --check` results;
- run `olddefconfig` and compare the resulting config intentionally;
- verify exact `kernelrelease` and every module's vermagic;
- reject zero-size modules and foreign build/source symlinks;
- inspect `nv50_instobj_memcpy_from` for two fences, scalar GPR loads, no
  SIMD/MOVNT instructions, and a `memcpy_fromio()` fallback;
- generate and parse-check GRUB before arming a one-shot boot.
