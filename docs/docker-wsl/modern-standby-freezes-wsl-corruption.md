# Modern Standby freezes — the real cause of repeated Docker/WSL corruption

If you keep having to repair Docker/WSL after crashes, the culprit may not be Docker or WSL
at all — it can be a **hardware power-state hang** that forces unclean shutdowns.

## Symptom

Total freeze: screen goes black / loses video signal, **fans keep spinning** (machine still
powered), unresponsive to keyboard/mouse; only a forced hard reset recovers it. **No blue
screen, no minidump.** Often seen on hybrid-GPU laptops (integrated + discrete GPU) that run
mostly docked.

## Root cause: Modern Standby (S0) power-transition hang

Check `powercfg /a`. If the firmware offers **only "S0 Low Power Idle" (Modern Standby)**
and S1/S2/S3 are "not available", the machine has no classic sleep states. On some
hybrid-GPU laptops the Modern Standby transition intermittently hangs at the hardware level
(GPU/PCIe power state), producing the black-screen freeze. Because it's a hardware hang,
Windows never runs a bugcheck — so there's no dump, only a `Kernel-Power 41` with
`BugCheck = 0` on the next boot.

### Evidence to look for
- `Kernel-Power 42 (sleep)` immediately followed by `107 (resume)` seconds later — a
  failed-sleep / instant-wake bounce.
- `WHEA-Logger` **corrected hardware errors** clustered around the freeze.
- **No Display/TDR events (4101/141)** → the GPU didn't soft-recover; it was a full lock.
- Crashes cluster overnight, when the idle machine attempts Modern Standby.

## The corruption chain

```
Modern Standby transition hang
  -> black-screen freeze (fans on, no video)
    -> forced hard reset (unclean shutdown)
      -> WSL2 ext4.vhdx journal left inconsistent
        -> docker-desktop engine distro won't boot -> Docker "500" engine error
```

## Fix: don't transition power state while docked

If the machine runs mostly docked as a desktop, set the policy to "never sleep / Modern
Standby while on AC":

| | On AC (docked) | On battery |
|---|---|---|
| Auto-sleep (Modern Standby) | **never** | never |
| Hibernate on idle | **never** | after 30 min |
| Lid close | do nothing | hibernate |
| Power button | hibernate | hibernate |

Net effect: docked, it never enters Modern Standby, so the freeze cannot occur. Avoid Start
menu → *Sleep* on such a machine; use *Hibernate* or *Shut down*.

## Also recommended
- **BIOS + GPU + Thunderbolt firmware updates** — Modern Standby / PCIe power fixes ship
  there.
- **Vendor hardware diagnostics** once, to clear any WHEA corrected errors as a concern.
- **Retire any flaky USB enclosure/reader** (controller errors add I/O instability); use a
  powered USB hub for always-connected drives.

## Hardening WSL against the *next* unclean shutdown

You can't make ext4-in-a-vhdx immune to a host crash — no WSL version changes that. So:

1. **Prevent unclean shutdowns** — the power fix above (biggest win).
2. **Keep restorable backups** — export distros to `.vhdx` on another drive; corruption
   becomes a restore, not a rebuild.
3. **`.wslconfig`** — `autoMemoryReclaim` + `sparseVhd` reduce host pressure and disk bloat.
4. **Clean-shutdown habit** — `wsl --shutdown` before anything risky; never hard-reset
   unless truly hung.

> If you also store important data on this machine (especially on external USB drives), make
> sure you have real backups / redundancy — a failing enclosure mid-write can corrupt a
> drive independent of this fix.
