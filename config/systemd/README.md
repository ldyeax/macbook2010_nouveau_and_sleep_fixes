# systemd sleep policy

`60-macbookpro6-1-power.pre-s4.conf` selects deep ACPI S3 but explicitly
disables hibernation.  Install that staging policy first.  After S3 and all
resume prerequisites pass, replace it at the same destination with
`60-macbookpro6-1-power.conf`, which enables direct S4 while keeping hybrid
and suspend-then-hibernate disabled.

Follow the [guarded power-state procedure](../../docs/power-and-hibernation.md)
and verify adequate swap, resume tooling and a matching resume-enabled
production GRUB entry.  `HibernateDelaySec` and `HibernateOnACPower` are
inactive while suspend-then-hibernate is disabled; they are retained only as
future policy and do not govern direct `systemctl hibernate`.
