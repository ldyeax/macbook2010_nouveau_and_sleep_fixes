# Licensing and provenance

The MIT `LICENSE` covers original documentation, templates and helper scripts
created for this repository.  It does not relicense copied project code.

- The `*.patch` files in `patches/linux/` are derived from Linux kernel sources
  and remain under the kernel's GPL-2.0-only licensing terms.  Patch 0001 is
  an accepted upstream DRM commit by its named authors.  The README, series
  and checksum manifest in that directory are repository metadata.
- `patches/mesa/0001-nouveau-fence-ref-race.patch` is an upstream Mesa commit
  by its named authors and remains under Mesa's licensing terms.
- Full/reference kernel configuration files contain no program code but are
  retained with their build provenance.

The two locally authored Linux patches are preserved byte-for-byte as tested.
Their mail headers are not proof of a human Linux DCO certification.  A human
must review, author and sign off a separately generated submission series
before upstreaming.

The top-level MIT license applies only to original repository documentation,
templates, metadata, helper scripts and diagnostic source.  It does not
relicense the copied patches or the kernel-function disassembly.  See the
top-level `NOTICE.md` for the file-level scope.
