# Deep S3 and guarded S4

Power-state testing is staged so a bad kernel cannot consume another kernel's
hibernation image.

## Deep S3 gate

Confirm the kernel and policy:

```bash
uname -r
cat /proc/cmdline
cat /sys/power/mem_sleep          # must show [deep]
cat /sys/kernel/debug/suspend_stats
cat /proc/sys/kernel/tainted
```

Start with the shipped `60-macbookpro6-1-power.pre-s4.conf`, which sets
`AllowHibernation=no`.  Close the lid long enough for a real sleep, then wake
using the machine's working wake control (the tested Mac wakes via the power
button or lid event).  Require:

- `PM: suspend entry (deep)` and a successful S3 wake;
- suspend success increases by one and failure stays unchanged;
- all `failed_*` fields and `last_failed_errno` remain zero;
- the same desktop is interactive;
- no new PFIFO/PGRAPH/MMU/DMA_PUSHER/timeout/Oops entries.

The prod2 gate advanced 10.567 seconds of kernel monotonic time from suspend
entry through exit.  An earlier qword1 build separately logged a 10.147-second
suspend-device phase.  Kernel monotonic time excludes time actually asleep,
so do not mistake the short active interval for an immediate wake.

## S4 prerequisites

Only after S3 passes, verify:

```bash
free -b
swapon --show
cat /sys/power/state              # must include disk
cat /sys/power/disk               # shutdown must be supported if configured
cat /sys/power/resume
cat /sys/power/resume_offset
lsinitrd -m /boot/initramfs-$(uname -r).img | grep -E 'resume|rootfs-block'
```

Swap must comfortably exceed the expected image.  The supplied GRUB template
is intentionally scoped to the tested machine's one active swap partition,
which uses offset zero.  A swap file requires a correctly derived
`resume_offset` and a customized GRUB entry; do not use this template for one
unchanged.  The resume UUID must resolve to the device shown by
`/sys/power/resume`.

Only now replace the staging file with
`config/systemd/60-macbookpro6-1-power.conf` and verify logind reports
hibernation available.  Keep AC connected for the first test.

```bash
repo=/path/to/macbook2010_nouveau_and_sleep_fixes
install -D -m 0644 \
    "$repo/config/systemd/60-macbookpro6-1-power.conf" \
    /etc/systemd/sleep.conf.d/60-macbookpro6-1-power.conf
systemctl hibernate --dry-run
```

## Guarded first hibernation

Keep the rollback as the saved default, but arm production for the single boot
which will restore the production image:

```bash
grub-set-default macbookpro6-1-nouveau-rollback
grub-reboot macbookpro6-1-nouveau-production
grub-editenv /boot/grub/grubenv list
cat /proc/sys/kernel/random/boot_id
pgrep -xo kwin_x11
pgrep -xo plasmashell
sync
loginctl lock-sessions
systemctl hibernate
```

Wait for complete poweroff, then press the power button.  GRUB consumes the
one-shot production entry and its initramfs restores the image.  If restore
fails, that boot can continue cold on production; a later reboot returns to
the `noresume` rollback.

Record the three identifiers before invoking hibernation.  A definitive
restore retains the boot ID and process IDs.  systemd should log return from
the hibernate operation and thaw the same user slice.

GRUB may have consumed `next_entry` on disk while the restored kernel still
has an old page-cache view from before hibernation.  After a successful test,
rewrite the desired state explicitly:

```bash
grub-set-default macbookpro6-1-nouveau-production
grub-editenv /boot/grub/grubenv unset next_entry
sync
```

Direct hibernation can then remain enabled.  Hybrid sleep and
suspend-then-hibernate remain disabled unless independently tested.
