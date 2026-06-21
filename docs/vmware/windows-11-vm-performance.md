# Fast Windows 11 VMs under VMware — without breaking Docker/WSL2

If you run **Docker Desktop + WSL2 and VMware Workstation on the same Windows host**, the
Windows hypervisor must be on at boot — which forces VMware into nested mode and makes
Windows 11 guests feel painfully slow. Here's how to get acceptable VM speed without giving
up Docker/WSL2. Tested on a 12th-gen Intel laptop, 64 GB RAM, VMs on NVMe, VMware
Workstation 17.x.

## The constraint

Docker Desktop + WSL2 **require** the Windows hypervisor at boot
(`hypervisorlaunchtype = auto`). That forces VMware Workstation into nested **Windows
Hypervisor Platform (WHP)** mode (~20–30% slower than bare-metal). You can't turn the
hypervisor off without breaking Docker/WSL2, so the goal is to optimize *within* hybrid mode.

## Why the Windows 11 VMs were painfully slow (in order of impact)

1. **Guest Memory Integrity / VBS on.** Windows 11 enables Core Isolation by default. VBS
   *inside* a VM that's *already* nested under WHP = double-nested virtualization. Usually
   the single biggest factor.
2. **Host VBS on** (`VirtualizationBasedSecurityStatus = 2`) — a second tax on every VM
   exit, separate from the bare hypervisor WSL2 needs.
3. **Wrong vCPU counts** — too few (2) starves Windows 11; too many (8) causes scheduling
   contention across P/E hybrid cores. Sweet spot: **4**.
4. **Memory + graphics** — an oversized RAM allocation starves the host alongside WSL; 8 GB
   SVGA graphics memory with 3D on is slow under WHP.

## What to change

### Host (one reboot required)
- Memory Integrity (HVCI), VBS, and Credential Guard → **off** (registry). Back up the
  relevant registry keys first.
- Leave `hypervisorlaunchtype` at **auto** on purpose → Docker/WSL2 keep working.

### Per-VM `.vmx` (VM powered off; back up each `.vmx` first)
| Setting | Typical before | After |
|---|---|---|
| `numvcpus` | 2 or 8 | **4** |
| `cpuid.coresPerSocket` | 1 or 2 | **2** |
| `memsize` (oversized VMs) | 24576 | **16384** |
| `mks.enable3d` | TRUE | **FALSE** |
| `svga.graphicsMemoryKB` | 8388608 (8 GB) | **262144 (256 MB)** |
| `mainMem.useNamedFile` | — | **FALSE** |
| `MemTrimRate` | — | **0** |
| `sched.mem.pshare.enable` | — | **FALSE** |

### In-guest (run inside each Windows 11 VM — highest impact, don't skip)
Disable guest Memory Integrity / VBS / Credential Guard + nested hypervisor, SysMain,
WSearch, and hibernation; set the High Performance power plan; set visual effects to
best-performance; clear temp. Reboot the guest afterwards (the VBS change only applies after
reboot). The same levers work on Windows 10 guests.

## Verify

```powershell
# After the host reboot: VBS off AND Docker/WSL2 still work
Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard |
    Select VirtualizationBasedSecurityStatus      # expect 0
wsl -l -v                                          # docker-desktop should still run
```

## Rollback
- **Host:** re-import the registry backups, then reboot.
- **Any VM:** copy its `*.vmx.bak-<timestamp>` back over the `.vmx`.
- **Guest:** re-enable Core Isolation in Windows Security;
  `bcdedit /set hypervisorlaunchtype auto`.
