# SDDM greeter policy

`20-no-blank.conf` sets SDDM's X server arguments to
`-nolisten tcp -s 0 -dpms`.  This keeps the unattended login screen visible
instead of exercising the greeter's previously unreliable blank/unblank path.
It does not change a logged-in Plasma session's power-management settings.

Install it as `/etc/sddm.conf.d/20-no-blank.conf`, restart SDDM at a safe time,
and confirm the live greeter Xorg command line contains both arguments.  Keep
any site-specific X server arguments when merging an existing `[X11]` section.
