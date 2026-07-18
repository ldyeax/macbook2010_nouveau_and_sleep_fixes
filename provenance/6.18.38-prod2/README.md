# Linux 6.18.38 prod2 evidence

This directory deliberately contains only compact evidence that can be
checked without the original build host.  Kernel objects, modules, boot
images, the multi-gigabyte source tree, raw journals and host-specific build
scripts are omitted.

`qword-disassembly.txt` is the exact optimized `nv50_instobj_memcpy_from()`
function from the validated build.  Its SHA-256 is:

```text
85aadefccdb9fe54a4f5faaaed20cc6ff9c46665bdf55ec1de31aa8890d9228f
```

The build used GCC 15.2.1 and binutils 2.46, as recorded in the exact kernel
config.  `../../scripts/build-kernel.sh` replaces the original host-bound build
script: it authenticates the complete pristine source inventory, accepted
patch order and bytes, and base/fragment/final config relationship.  It builds
only in a new isolated workspace and rejects generated code that loses the
exact four-qword scalar function, NVA5 gate, two read barriers or
`memcpy_fromio()` fallback.

The validated kernel image hashes to
`ad4f1ed5a2a8dc2d0ba8ef8130b0508265eaf4776fad4c049d2e0a8d0c9087bd`;
its `System.map` hashes to
`f5600bdee71fb0ea1cbaf92373bdf8326a30a2be9baa101d205a1a99c94bb870`.
These authenticate the historical installed artifacts.  The portable builder
does not replay host labels or the historical timestamp, so it does not claim
to recreate those binary hashes.

The exact config retains the original build-time default hostname (`bigmac`)
as part of its byte-for-byte provenance.  That value is not required by any
fix and may be changed when adapting the config manually; doing so is no
longer an exact reproduction and therefore intentionally fails the strict
builder's config comparison.
