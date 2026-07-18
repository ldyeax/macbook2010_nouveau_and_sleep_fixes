# Build and patch provenance

## Canonical production input

The production build started from Gentoo's `gentoo-sources-6.18.38` tree and
applied `patches/linux/series` in order.  The same series passes
`git apply --check` on untouched Gentoo 6.18.18 and 6.18.38 source trees.

The selected Gentoo package came from repository revision
`e59b24d790ccd38de1c7861717b0bd9931df9dd6` with ebuild SHA-256
`af44897f8d0a8985ba78465fdf5dcdd85423c3e9fc367a3714fd436498ac9e70`
and the `symlink` USE flag.  Its source inputs were:

| Source input | SHA-256 |
|---|---|
| `linux-6.18.tar.xz` | `9106a4605da9e31ff17659d958782b815f9591ab308d03b0ee21aad6c7dced4b` |
| genpatches 6.18-45 base | `8179e5e35288672d966c37789a09e52ab5cee14950a97e018a9618da7a33d05d` |
| genpatches 6.18-45 extras | `f3488c88f3aa12936d4e8f138bb6cb301c892f3c5d5ca160d8428ed7ce0f7e88` |

The pristine installed tree contained 91,107 hashed files and 85 symlinks,
with no other filesystem object types.  Hashing every file except Gentoo's
non-Kbuild `patches.txt` into a sorted `sha256sum` manifest produced manifest
SHA-256 `2509f40cfa992ae8aebeb9f8de355b80a6548f5828c6810ef2fbb5c06794401c`;
the sorted `path -> target` symlink list hashed to
`6633ea31dbf46be2fda9aa2d644ed4a36dfa1e42ac85bf060e9015547d747d47`.
`patches.txt` concatenation order can differ between otherwise byte-identical
Gentoo installations and is not consumed by Kbuild.

If a future source already contains upstream commit `34e27b90552a`, do not
apply patch 0001 twice.  Check with:

```bash
git apply --reverse --check patches/linux/0001-instmem-iomapping.patch
```

Reference hashes:

| Item | SHA-256 |
|---|---|
| 6.18.18 qword baseline config | `e87ab1f11254bc8b027c3410eace474f7c31fa564411be8a046df7d192c51674` |
| production pruning fragment | `d9ae6a211ef010de0e815748c712392363e4e74fceb35b2714a010a0710da12d` |
| exact 6.18.38 prod2 config | `95b92db99f953e3845290700561ea8b067103134eaf1f5e08d23e044f952075f` |
| accepted series order file | `0cc92479944014e728d551700490ab8f6adf9643f5ff2cdef1974e270df0d001` |
| qword function disassembly | `85aadefccdb9fe54a4f5faaaed20cc6ff9c46665bdf55ec1de31aa8890d9228f` |
| upstream Mesa patch | `9184817106b2702a0b714f6af6382fe453b4856e377d89a5e95e9f257e2af734` |
| validated kernel image | `ad4f1ed5a2a8dc2d0ba8ef8130b0508265eaf4776fad4c049d2e0a8d0c9087bd` |
| validated System.map | `f5600bdee71fb0ea1cbaf92373bdf8326a30a2be9baa101d205a1a99c94bb870` |

Linux patch hashes are in `patches/linux/SHA256SUMS`.  The compact files in
`provenance/6.18.38-prod2/` preserve the exact generated function
disassembly and explain the reproducible build gates; multi-gigabyte
source/object trees and boot binaries are intentionally not in Git.

## Build gates used

The validated artifact was built with GCC 15.2.1
(`15.2.1_p20260214 p5`), binutils 2.46.0, GNU Make 4.4.1 and kmod 34.2.
The portable builder authenticates the source, ordered patches and config,
but it does not replay the historical build-host labels/timestamp; therefore
it promises the tested inputs and generated-code gates, not a bit-identical
kernel image.

The reproducible build required all of the following:

- exact source-tree and symlink inventory before compilation;
- exact config reconstruction from base + fragment + `olddefconfig`;
- patch hash and applicability checks;
- exact `6.18.38-gentoo-nouveau-prod2` kernel release;
- no zero-sized modules and one matching vermagic across all 157 modules;
- qword function disassembly containing four scalar GPR loads and two fences,
  with no XMM/YMM/ZMM or MOVNT instructions and a `memcpy_fromio()` fallback;
- SHA-256 verification after return from the build host and again after local
  installation;
- side-by-side boot/install with foreign `build`/`source` module symlinks
  excluded.

`scripts/build-kernel.sh --verify-only` exercises the repository/source/config
authentication without compiling.  A full run copies the pristine source to
a brand-new workspace, applies the exact series, builds and stages artifacts
without touching `/boot` or `/lib/modules`, checks the exact function
disassembly, validates 157 nonzero modules and emits a staged SHA-256 manifest.

## Upstream-submission status

The exact tested backports are an installation archive, not yet a polished
mailing-list series.

- The PFIFO patch needs a human Linux DCO sign-off.
- The qword patch's preserved AI `Signed-off-by` is not human DCO
  certification; a human must review, author and sign a newly generated commit.
- An upstream series should include a base commit/prerequisite note, cover
  letter, quantitative results, and an `Assisted-by` trailer appropriate to
  the human submitter's policy.
- Run `scripts/checkpatch.pl --strict` and `scripts/get_maintainer.pl` from a
  real upstream Linux Git checkout before sending.

The PFIFO `Fixes:` tag was verified against full upstream commit
`ebb945a94bba2ce8dff7b0942ff2b3f2a52a0a69`, titled
`drm/nouveau: port all engines to new engine module format`.
