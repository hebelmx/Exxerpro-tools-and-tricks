# PowerToys ZoomIt — the "stuck zoomed desktop" fix

**Symptom:** one monitor suddenly looks permanently zoomed in / unusable, while your
other monitor is fine. Mouse still works; the screen is just magnified.

## Root cause

It's almost never a display/resolution problem. PowerToys **ZoomIt** is sitting in
**Live Zoom** mode — its process title literally reads `ZoomIt Live Zoom`. Live Zoom
magnifies the *live, still-interactive* desktop, so it looks like the screen broke.
It's usually triggered by the default hotkey `Ctrl+4` being hit by accident.

## Fast recovery (any time it happens)

- Press **`Esc`** — exits any ZoomIt zoom mode instantly. ← your panic button
- Or press the Live Zoom toggle again (`Ctrl+4` by default).
- Nuclear option (kills the overlay; fully reversible — PowerToys relaunches it):

  ```powershell
  Stop-Process -Name PowerToys.ZoomIt -Force
  ```

## Rebind the accident-prone hotkey

ZoomIt (the PowerToys build) stores its config in the registry — the same store the
PowerToys Settings GUI writes to:

    HKCU:\Software\Sysinternals\ZoomIt

Hotkeys are encoded as `(modifier << 8) | virtualKey`, where
`Shift=0x01, Ctrl=0x02, Alt=0x04`.

| Mode          | Default hotkey | Encoded value |
|---------------|----------------|---------------|
| Zoom (static) | `Ctrl+1`       | 561           |
| Draw          | `Ctrl+2`       | 562           |
| Break timer   | `Ctrl+3`       | 563           |
| Live Zoom     | `Ctrl+4`       | 564           |

To move Live Zoom off `Ctrl+4` to a deliberate combo like `Ctrl+Alt+Z`
(`Z`=0x5A, Ctrl+Alt=0x06 → `0x06<<8 | 0x5A` = 1626):

```powershell
Set-ItemProperty -Path "HKCU:\Software\Sysinternals\ZoomIt" `
  -Name LiveZoomToggleKey -Value 1626 -Type DWord
# then restart ZoomIt so it reloads: toggle Off->On in PowerToys Settings -> ZoomIt
```

!!! note
    If PowerToys was installed **per-user** (under `%LOCALAPPDATA%`) rather than under
    `Program Files`, launch ZoomIt via the PowerToys runner / Settings — running the
    module exe directly is a no-op.

## Using it (it zooms like a web page)

Once a mode is active, zoom with the **mouse wheel** or **↑/↓**, centered on the cursor —
just like `Ctrl+scroll` on a webpage.

- **Live Zoom (`Ctrl+4`)** — desktop stays live and clickable while magnified.
- **Static Zoom (`Ctrl+1`)** — freezes a snapshot you can then draw on.
- **`Esc`** — exit.
