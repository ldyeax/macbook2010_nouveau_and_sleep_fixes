# Gentoo installation

This procedure installs the fixed kernel side-by-side, preserves a known-good
cold-boot fallback, and changes one layer at a time.  Adapt package names and
boot paths when not using Gentoo/GRUB/dracut.

## 1. Record the machine and preserve rollback material

```bash
repo=/path/to/macbook2010_nouveau_and_sleep_fixes
test -f "$repo/patches/linux/series"
dmidecode -s system-product-name
lspci -nnk -s 01:00.0       # tested BDF; locate 10de:0a29 if it differs
findmnt -no SOURCE,FSTYPE,UUID /
swapon --show
blkid
cat /sys/power/mem_sleep

backup_dir=$(mktemp -d /root/grub-backup.XXXXXXXX)
install -d -m 0700 "$backup_dir/etc/default" "$backup_dir/etc" \
    "$backup_dir/boot/grub"
cp -a /etc/default/grub "$backup_dir/etc/default/"
cp -a /etc/grub.d "$backup_dir/etc/"
cp -a /boot/grub/grub.cfg /boot/grub/grubenv "$backup_dir/boot/grub/"
printf 'GRUB backup: %s\n' "$backup_dir"
```

Continue only if the hardware matches the intended scope and `deep` is
available.  Keep the currently booting kernel, its modules and initramfs.

Remove old experimental parameters from the production command line.  The
tested production entry needs `nouveau.ignorelid=1` on this Apple machine, but
does not need `nouveau.config=NvForcePost`, clock/gating experiments,
`nouveau.pstate=1`, or disabled CPU mitigations.

## 2. Obtain and patch Linux 6.18.38

First authenticate the repository inputs:

```bash
cd "$repo"
sha256sum -c patches/linux/SHA256SUMS
```

The strict builder in the next section takes an untouched Gentoo 6.18.38 tree,
copies it, authenticates the complete source inventory and applies the series
inside its new work directory.  Do not run the following manual loop first if
you intend to use that builder.

For a deliberately manual build, apply-or-recognize each whole patch in order:

```bash
cd /usr/src/linux-6.18.38-gentoo
while read -r patch; do
    test -n "$patch" || continue
    case $patch in \#*) continue ;; esac
    patch_file="$repo/patches/linux/$patch"
    if git apply --check "$patch_file"; then
        git apply "$patch_file"
    elif git apply --reverse --check "$patch_file"; then
        printf 'already applied: %s\n' "$patch"
    else
        printf 'divergent or partially applied patch: %s\n' "$patch" >&2
        exit 1
    fi
done < "$repo/patches/linux/series"
```

Patch 0001 is an upstream commit and may already exist in a newer tree.  Use
`git apply --reverse --check` as described in `docs/provenance.md`; never apply
it twice.  Do not apply anything under `patches/linux/rejected/`.

## 3. Configure and build

For an exact MacBookPro6,1 reproduction:

```bash
mkdir -p /var/tmp/linux-6.18.38-prod2-manual
cp "$repo/config/kernel/config-6.18.38-prod2" \
   /var/tmp/linux-6.18.38-prod2-manual/.config
make O=/var/tmp/linux-6.18.38-prod2-manual olddefconfig
make O=/var/tmp/linux-6.18.38-prod2-manual -j4
```

Or use the non-installing strict builder:

```bash
"$repo/scripts/build-kernel.sh" \
    --source /usr/src/linux-6.18.38-gentoo \
    --work-dir /var/tmp/linux-6.18.38-prod2 \
    --jobs 4
```

It leaves the source argument untouched, requires a brand-new work directory,
authenticates the Gentoo source inventory plus patch/config inputs, builds in
`work-dir/out`, stages modules and boot files under `work-dir/stage`, and
verifies the generated qword disassembly.  On different hardware, begin with
a known-booting config and merge only justified settings manually; read
`config/kernel/README.md` before using the production pruning fragment.

Verify the release before installation:

```bash
make -s -C /var/tmp/linux-6.18.38-prod2/src \
    O=/var/tmp/linux-6.18.38-prod2/out kernelrelease
```

It should be unique (the reference is
`6.18.38-gentoo-nouveau-prod2`) so no working kernel or module tree is
overwritten.

## 4. Install kernel, modules and initramfs side-by-side

The commands below use the strict builder's layout.  If you chose the manual
route, set `build_src` and `build_out` to that source and output tree instead.

```bash
build_src=/var/tmp/linux-6.18.38-prod2/src
build_out=/var/tmp/linux-6.18.38-prod2/out
release=$(make -s -C "$build_src" O="$build_out" kernelrelease)

for target in \
    "/lib/modules/$release" \
    "/boot/kernel-$release" \
    "/boot/System.map-$release" \
    "/boot/config-$release" \
    "/boot/initramfs-$release.img"
do
    if test -e "$target" || test -L "$target"; then
        printf 'refusing to overwrite existing target: %s\n' "$target" >&2
        exit 1
    fi
done

make -C "$build_src" O="$build_out" modules_install
install -m 0644 "$build_out/arch/x86/boot/bzImage" \
    "/boot/kernel-$release"
install -m 0644 "$build_out/System.map" \
    "/boot/System.map-$release"
install -m 0644 "$build_out/.config" \
    "/boot/config-$release"
depmod -a "$release"

dracut --force --no-uefi --hostonly --no-hostonly-cmdline \
    --add resume \
    --omit-drivers 'b43 b43legacy brcmfmac wl nvidia nvidia_drm nvidia_modeset nvidia_uvm' \
    --kernel-image "/boot/kernel-$release" \
    "/boot/initramfs-$release.img" "$release"
```

`--no-hostonly-cmdline` prevents a stale root/resume command line from being
embedded; the matching custom GRUB entry supplies it.  If deploying modules
from a build bundle rather than `modules_install`, exclude foreign `build` and
`source` symlinks and verify every module's vermagic.

Check the initramfs contains `resume` and `rootfs-block`, while
`etc/cmdline.d` contains no host command line:

```bash
lsinitrd -m "/boot/initramfs-$release.img"
lsinitrd "/boot/initramfs-$release.img" | grep 'etc/cmdline.d/'
```

## 5. Install the tested userspace policy

```bash
install -D -m 0644 "$repo/config/xorg/20-nouveau-modesetting.conf" \
    /etc/X11/xorg.conf.d/20-nouveau-modesetting.conf
install -D -m 0644 "$repo/config/sddm/20-no-blank.conf" \
    /etc/sddm.conf.d/20-no-blank.conf
install -D -m 0644 "$repo/config/NetworkManager/20-dns.conf" \
    /etc/NetworkManager/conf.d/20-dns.conf
install -D -m 0644 \
    "$repo/config/systemd/60-macbookpro6-1-power.pre-s4.conf" \
    /etc/systemd/sleep.conf.d/60-macbookpro6-1-power.conf
```

Remove/disable any other Xorg Device section that forces the legacy Nouveau
DDX.  The installed staging sleep policy explicitly leaves hibernation
disabled until the new kernel passes S3.

For the exact dated Gentoo snapshot, review and install the files under
`config/portage/` at their matching `/etc/portage/` paths, then emerge exactly
Mesa 26.1.5 containing `0e79791fa5f6`.  The checked-in LLVM/Python settings are
host/profile transition choices, not timeless Nouveau requirements; read
`config/portage/README.md` before copying them.

The patch under `patches/mesa/` is already included in Mesa 26.1.5; do not
apply it again.  It exists for provenance or backporting to an older Mesa.

## 6. Create guarded GRUB entries

Discover identifiers instead of copying another system's values:

```bash
root_uuid=$(findmnt -no UUID /)
mapfile -t resume_devices < <(swapon --show=NAME --noheadings)
if (( ${#resume_devices[@]} != 1 )); then
    echo 'the supplied template requires exactly one active swap partition' >&2
    exit 1
fi
resume_dev=${resume_devices[0]}
if ! test -b "$resume_dev"; then
    echo 'swap files require a custom resume_offset-aware entry' >&2
    exit 1
fi
resume_uuid=$(blkid -s UUID -o value "$resume_dev")
test -n "$root_uuid" && test -n "$resume_uuid"
```

Copy `config/grub/09-nouveau-production.in`, replace all four `@...@`
placeholders, and install it executable under `/etc/grub.d/`.  Adjust the
filesystem GRUB module and microcode initrd list for the local system.  Refuse
to continue if any placeholder remains:

```bash
if grep -Eq '@[A-Z_]+@' /etc/grub.d/09-nouveau-production; then
    echo 'unreplaced GRUB template placeholder' >&2
    exit 1
fi
chmod 0755 /etc/grub.d/09-nouveau-production
```

Merge `config/grub/default-grub.snippet` into `/etc/default/grub`.  The design
is intentional:

- every automatic and rollback entry gets `noresume`;
- only the exact production entry gets `resume=UUID=...`;
- the production and rollback kernels have distinct menu IDs.

Generate a candidate first:

```bash
grub-mkconfig -o /var/tmp/grub.cfg.candidate
grub-script-check /var/tmp/grub.cfg.candidate
grep -c 'resume=UUID=' /var/tmp/grub.cfg.candidate   # must be exactly 1
grep -n 'macbookpro6-1-nouveau' /var/tmp/grub.cfg.candidate
install -m 0600 /var/tmp/grub.cfg.candidate /boot/grub/grub.cfg
```

Require every referenced kernel/initramfs to exist.  Set the persistent
fallback first, then arm production for one boot:

```bash
grub-set-default macbookpro6-1-nouveau-rollback
grub-reboot macbookpro6-1-nouveau-production
grub-editenv /boot/grub/grubenv list
sync
reboot
```

If the one-shot boot cannot complete, the following boot returns to the saved
`noresume` fallback.  Do not promote production or enable S4 until the boot and
S3 gates pass.

## 7. Validate and promote

Follow `docs/validation.md` and `docs/power-and-hibernation.md`.  After the
guarded S4 restore succeeds:

```bash
grub-set-default macbookpro6-1-nouveau-production
grub-editenv /boot/grub/grubenv unset next_entry
```

Retain the known-good rollback entry until the final Mesa/login/power smoke
test is complete.
