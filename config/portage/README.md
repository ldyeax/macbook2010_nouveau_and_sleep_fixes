# Nouveau Portage configuration

These files are the narrow Portage snapshot used on 2026-07-18 for the
GT216M/NVA5 graphics stack.  Install them verbatim only when the active Gentoo
profile and installed consumers match; otherwise re-evaluate the LLVM slot,
Python targets and accepted Mesa version first.

- `package.use/00video_cards` replaces the previous broad `nouveau intel i965`
  list.  PCI enumeration exposes only the NVIDIA GT216M, and current Mesa no
  longer accepts `i965` as a `VIDEO_CARDS` value.
- `package.use/mesa-nouveau` removes OpenCL and Vulkan because neither was used
  or validated on this machine.  NV50 OpenGL/VA-API and the LLVM software
  fallback remain enabled, with Mesa pinned to the then-installed LLVM 21
  slot instead of pulling LLVM 22 during the focused update.
- `package.use/mesa-python-transition` dual-targets only PyYAML and MarkupSafe
  for Python 3.13 and the profile-default 3.14.  That preserves the installed
  LIRC/Jinja2 consumers while Portage builds Mesa 26.1.5.
- `package.use/power-management` enables TuneD's PPD-compatible D-Bus bridge
  and temporarily keeps its new Python dependencies on 3.13.  This lets KDE
  drive real `acpi-cpufreq` profiles without pulling the system's wider 3.14
  transition into the power-management change.
- `package.accept_keywords/mesa-nouveau` accepts only Mesa 26.1.5 from
  `~amd64`; it does not opt the system into Gentoo testing globally.

Both Python transition settings are temporary aids, not permanent Mesa or
TuneD requirements.  Remove them when no installed consumer needs Python
3.13, then rebuild the affected packages for the selected Python target.

The standalone upstream patch is retained under `../../patches/mesa/` for
audit and a single-change backport if an older Mesa must be retained.  Mesa
26.1.5 already contains it and must not be patched a second time.
