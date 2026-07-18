# Xorg configuration

`20-nouveau-modesetting.conf` is the tested production choice.  It uses Xorg's
generic KMS `modesetting` driver, glamor acceleration and page flips.  The
resulting stack initializes DRI3/Present and renders directly with Mesa's NVA5
driver; the installed `xf86-video-nouveau` package is not selected.

Install it as `/etc/X11/xorg.conf.d/20-nouveau-modesetting.conf`, or merge its
Device section into an existing `xorg.conf`.  Do not keep another Device
section that forces `Driver "nouveau"` for the same GPU.

The same file enables Ctrl-Alt-Backspace with `DontZap=false` and
`terminate:ctrl_alt_bksp`.  That is an intentional recovery preference from
the investigation, not a requirement of the Nouveau fixes; omit those two
sections if the shortcut is undesirable.

The files under `diagnostic/` are one-variable fallbacks only:

- no-pageflip keeps modesetting/glamor but removes page-flip completion from
  the presentation path;
- nouveau-ddx-dri2 selects the legacy DDX/EXA/DRI2 path.

Use a diagnostic variant only if a presentation wait remains after the kernel
patches, `nouveau.ignorelid=1`, and Mesa's fence-race fix.
