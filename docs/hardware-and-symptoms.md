# Hardware and observed symptoms

## Tested machine

- Apple MacBookPro6,1, mid-2010 17-inch model;
- Intel Arrandale/Westmere Core i5 M 540 and HM55 chipset;
- NVIDIA GT216M / GeForce GT 330M, PCI ID `10de:0a29`;
- Nouveau chipset code `NVA5`, 512 MiB GDDR3;
- internal 1920x1200 panel routed through Apple GMUX;
- Broadcom BCM43224 wireless using `brcmsmac`;
- legacy-BIOS GRUB boot, XFS root and a separate swap partition;
- Plasma X11 with direct NVA5 rendering.

Do not assume the optional pruned kernel configuration is safe merely because
another laptop also contains a GT 330M.  Confirm the model, storage, input,
battery, networking and filesystem paths first.

## Initial graphics failure

The machine could reach an accelerated Plasma desktop, but the first Plasma
splash produced a concentrated Nouveau fault burst.  Representative classes
were:

```text
fifo: DMA_PUSHER ... INVALID_CMD
gr: TRAP_MP_EXEC ... INVALID_OPCODE
gr: TRAP_CCACHE ... FAULT
fb: trapped read ... PAGE_NOT_PRESENT
```

The first PFIFO error was followed by hundreds of secondary graphics-engine
and unmapped-address reports.  Treating only the visible login symptom would
have missed most of the fault chain.

## Login and display symptoms

- Some boots stopped at a white screen with a periodically stuttering cursor.
  Killing the X server returned to a usable greeter.
- An idle SDDM greeter could still move the cursor but no longer accept clicks.
- The legacy Nouveau Xorg DDX/DRI3 path showed transient corrupted frames at
  login and a Qt Quick render thread waiting in the DRI3 Present path.
- VT switching could appear to hang while the bad greeter/server state was
  active.

The generic Xorg `modesetting` driver with glamor, page flipping and DRI3
removed the login corruption on the fixed kernel.  SDDM is configured not to
blank or DPMS-off the greeter; logged-in Plasma retains its own power policy.

## Power symptoms

Closing and reopening the lid could return to a desktop with mouse movement
but no interaction.  Nouveau also spent a long time saving instance-memory
objects through the GPU's BAR2 aperture during suspend.

The final system uses:

- `nouveau.ignorelid=1` for this Apple connector/lid wiring;
- deep ACPI S3, not `s2idle`;
- the scalar-qword NVA5 BAR2 read patch;
- direct S4 only after S3 passes on the same kernel;
- a resume-enabled production GRUB entry and `noresume` on every fallback.

## Expected non-fault messages

This GPU consistently logs `failed to create ce channel, -22`, immediately
followed by `MM: using COPY for buffer copies`.  That is a stable probe-time
fallback on the tested GT216M, not the PFIFO/MMU failure fixed here.

The firmware also emits old ACPI resource warnings, and empty secondary SATA
links can say that they failed to resume before the real disk/optical links
recover.  These should not be confused with Nouveau faults or failed PM
stages.

At Xorg startup, the Apple Bluetooth controller can expose temporary HID proxy
keyboard/mouse nodes (`05ac:820a`/`05ac:820b`) and then replace them with HCI
mode (`05ac:8218`).  Xorg may log an unnamed-device invalid-path/PreInit error
if it races that transition.  It is benign only when those nodes have vanished
and the real internal keyboard and bcm5974 touchpad work normally.
