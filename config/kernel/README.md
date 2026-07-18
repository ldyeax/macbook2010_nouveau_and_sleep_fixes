# Kernel configuration

`config-6.18.38-prod2` is the exact configuration used by the validated
production kernel.  `config-6.18.18-qword1.base` is its known-good predecessor,
and `macbookpro6-1-production.fragment` documents the evidence-based pruning
applied before the final build.

The exact file includes the original build-time `CONFIG_DEFAULT_HOSTNAME` for
byte-for-byte provenance.  That hostname has no functional relationship to
Nouveau, suspend or resume; change it when adapting the config rather than
copying it as a policy choice.

The full production config is a reproducibility reference, not a generic
recommendation.  The pruning assumes all of the following:

- MacBookPro6,1 with Arrandale/HM55 and GT216M/NVA5;
- USB Apple keyboard/trackpad, no PS/2 controller;
- Apple GMUX backlight and ACPI SBS battery;
- directly attached ATA disk, XFS v5 root with no quotas or realtime section;
- MBR boot disk, no TPM, no Intel IOMMU/DMAR, no serial port;
- the retained Broadcom, USB recovery-network, FireWire and external-storage
  device policy described in the fragment comments.

Changing storage, root filesystem, partitioning, input, battery, network or
external-device requirements can make the pruned config unsafe.  The two
Nouveau correctness/performance patches work with a broader kernel config;
start from your known-booting config when hardware differs.

This config also records machine policy choices that are not graphics fixes,
including disabled module-signature enforcement, the security/LSM framework
and strict `/dev/mem`.  Do not inherit those settings as recommendations.
Start from a current Gentoo/distribution security policy unless reproducing
this exact machine, and merge only the Nouveau, device and PM requirements you
have independently justified.

Required power/graphics capabilities include `DRM_NOUVEAU`, ACPI S3,
hibernation, swap resume, the actual root filesystem and disk driver, Apple
GMUX/SBS/input support, and enough PM diagnostics to audit failures.
