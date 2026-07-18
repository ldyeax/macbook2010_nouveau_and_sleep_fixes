# License scope and third-party material

The top-level MIT `LICENSE` covers original repository documentation,
configuration templates, metadata, helper scripts and diagnostic source.

It does not relicense third-party or derived material:

- `patches/linux/**/*.patch` and
  `provenance/6.18.38-prod2/qword-disassembly.txt` derive from Linux kernel
  code and remain under the applicable Linux kernel terms, principally
  GPL-2.0-only for the files changed here.
- `patches/mesa/0001-nouveau-fence-ref-race.patch` is a preserved upstream
  Mesa change and remains under the applicable Mesa source licenses.

Authorship and review trailers inside preserved patch files identify their
upstream or historical provenance.  The locally tested Linux patches are not
human-DCO-certified for upstream submission; see `docs/provenance.md`.
