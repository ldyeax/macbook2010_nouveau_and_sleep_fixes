# Rejected experiments — do not apply

These patches are negative evidence, not part of `../series`.

`0001-instmem-wc-copy.patch` replaces `memcpy_fromio()` with DRM's
MOVNTDQA-based WC helper.  On this GT216M/Westmere machine it reduced BAR2
read throughput to roughly 0.25 MiB/s and made the suspend device phase
42.674 seconds.  SHA-256:
`ea755dff6bf858e06892332ece3e60e7facf56d835cad57ad76a3615aac8d723`.

`0002-pre-fermi-gpfifo-revert.patch` attempted to restore an older GPFIFO path.
It did not address the missing PFIFO channel-VMM TLB invalidation and is not
part of the resolved design.

Keeping these files prevents the failed approaches from being rediscovered
and mistaken for the tested fix.  Production uses the scalar-qword patch in
`../0003-nva5-qword-bar2-read.patch`.
