# Diagnostic BAR2 benchmark

`bar2-read-bench.c` is the measurement tool used to compare read strategies on
the tested NVA5 BAR2 aperture.  It is retained as diagnostic provenance, not
as an installation requirement.  The production kernel uses only the
four-qword scalar approach in patch 0003; it does not use the benchmark's SIMD
experiments.

The program is intentionally hard-coded to PCI function `0000:01:00.0` and
reads one MiB from `resource3_wc`.  It requires root and direct PCI-resource
access.  Do not run it on different hardware, over an active workload, or
without a recoverable console and cold-boot fallback: experimental MMIO access
can hang a GPU or the machine.

To compile for an already-confirmed matching test system:

```bash
cc -O2 -Wall -Wextra -o bar2-read-bench tools/bar2-read-bench.c
```

The platform-specific measurements and the rejected MOVNTDQA result are in
`docs/results.md`.
