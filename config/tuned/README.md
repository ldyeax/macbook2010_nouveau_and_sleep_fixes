# KDE power-profile bridge

This MacBook's Westmere CPU uses `acpi-cpufreq`.  It has no ACPI
`platform_profile`, Intel P-State/HWP support or Energy Performance Bias
interface, so `power-profiles-daemon` 0.30 loads only its placeholder backend.
KDE can select its reported `balanced` and `power-saver` profiles, but those
selections do not alter the hardware and no `performance` profile is exposed.
Enabling `CONFIG_X86_INTEL_PSTATE` is not a remedy: Linux's Intel P-State CPU
ID table starts at Sandy Bridge and does not contain Westmere model `0x25`.
No missing kernel module is involved.

Gentoo's `sys-apps/tuned[ppd]` installs `tuned-ppd`, a compatible provider of
the `org.freedesktop.UPower.PowerProfiles` D-Bus API used by PowerDevil.  The
profiles here intentionally tune only the working cpufreq controls:

- `performance`: `performance` governor with boost enabled;
- `balanced`: `schedutil` governor with boost enabled;
- `power-saver`: `powersave` governor with boost disabled.

The custom profiles avoid the unrelated storage, VM, network, audio, video and
sysctl changes in TuneD's general-purpose built-in profiles.  Install them and
the mapping before starting the services:

```bash
repo=/path/to/macbook2010_nouveau_and_sleep_fixes
for profile in bigmac-balanced bigmac-performance bigmac-power-saver; do
    install -D -m 0644 \
        "$repo/config/tuned/profiles/$profile/tuned.conf" \
        "/etc/tuned/profiles/$profile/tuned.conf"
done
install -D -m 0644 "$repo/config/tuned/ppd.conf" /etc/tuned/ppd.conf
systemctl enable --now tuned.service tuned-ppd.service
```

Validate all four cpufreq policies after switching each profile:

```bash
ppd_dest=org.freedesktop.UPower.PowerProfiles
ppd_path=/org/freedesktop/UPower/PowerProfiles
ppd_iface=org.freedesktop.UPower.PowerProfiles
busctl --system get-property "$ppd_dest" "$ppd_path" "$ppd_iface" Profiles
busctl --system set-property "$ppd_dest" "$ppd_path" "$ppd_iface" \
    ActiveProfile s performance
grep . /sys/devices/system/cpu/cpufreq/policy*/scaling_governor
busctl --system set-property "$ppd_dest" "$ppd_path" "$ppd_iface" \
    ActiveProfile s balanced
grep . /sys/devices/system/cpu/cpufreq/policy*/scaling_governor
busctl --system set-property "$ppd_dest" "$ppd_path" "$ppd_iface" \
    ActiveProfile s power-saver
grep . /sys/devices/system/cpu/cpufreq/policy*/scaling_governor
grep . /sys/devices/system/cpu/cpufreq/policy*/boost
busctl --system set-property "$ppd_dest" "$ppd_path" "$ppd_iface" \
    ActiveProfile s balanced
tuned-adm verify
```

`powerprofilesctl` is supplied by `power-profiles-daemon`, so it is removed by
the conflicting TuneD installation on Gentoo.  KDE uses the same D-Bus API
directly.  If PowerDevil was already running while the provider was replaced,
restart only its user unit once so it refreshes the available choices:

```bash
systemctl --user restart plasma-powerdevil.service
```

Do not enable the old `cpupower-frequency-set.service` alongside TuneD.  It is
safe to keep the `cpupower` command for inspection and manual troubleshooting.
