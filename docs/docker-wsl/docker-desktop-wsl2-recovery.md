# Docker Desktop / WSL2 recovery — engine won't start after a crash

**Symptom:** the `docker` CLI works, but every command returns
`500 Internal Server Error ... dockerDesktopLinuxEngine`, and Docker Desktop sits on
"starting the Docker engine" forever. Common after a hard crash or unclean shutdown.
Tested on Windows 11 Pro, WSL2, Docker Desktop 4.77.0 (engine 29.5.3).

## Root cause (often two faults, stacked)

1. **Corrupted WSL2 kernel/runtime.** A crash can damage the WSL kernel so that *any* WSL
   VM boots, mounts its module share, hangs ~60s, then gets force-terminated by the Host
   Compute Service (HCS). Even a plain `wsl -d Ubuntu-24.04` fails with
   `Wsl/Service/CreateInstance/CreateVm/HCS_E_CONNECTION_TIMEOUT`. A Docker "repair" that
   doesn't update the kernel will never fix this.
2. **Corrupted `docker-desktop` engine distro.** Even after WSL itself is healthy, the
   Docker *engine* distro can have its own corrupted disk and hang on boot while normal
   distros work.

Rule out the usual suspects first — these are typically fine: `vmcompute`, `hns`, `HvHost`,
`WSLService` running; `hypervisorlaunchtype = Auto`; VirtualMachinePlatform + WSL features
enabled; no `.wslconfig` overrides.

## The key fact that makes repair safe

Docker Desktop stores data in **two separate disks**:

| File | Size | Contents | Disposable? |
|------|------|----------|-------------|
| `…\AppData\Local\Docker\wsl\main\ext4.vhdx` | ~0.1 GB | engine OS (bootstrap) | **Yes** — Docker rebuilds it |
| `…\AppData\Local\Docker\wsl\disk\docker_data.vhdx` | tens of GB | **your images / volumes / containers** | **No** — never touch |

Because user data lives in `docker_data.vhdx`, the tiny `docker-desktop` engine distro can
be unregistered and rebuilt **without losing anything**.

## The fix (in order)

1. **Clean stop + bounce HCS:** quit Docker Desktop, stop `com.docker.service`,
   `wsl --shutdown`, then `Restart-Service vmcompute`.
2. **`wsl --update`** — re-deploys the WSL runtime and kernel. This is usually the core
   fix; afterwards normal distros boot cleanly.
3. **Rebuild the engine distro** — back up first, confirm `docker_data.vhdx` is untouched,
   then `wsl --unregister docker-desktop`. Docker Desktop recreates it on next launch.
4. **REBOOT** — the step people miss. After a major `wsl --update`, registering a *new* WSL
   VM keeps failing with `Wsl/Service/RegisterDistro/CreateVm/0x800705b4`
   ("timeout period expired"). Existing distros run fine; a new VM registration hangs until
   Windows is rebooted to finalize the updated Hyper-V/HCS components.
5. **Post-reboot** — launch Docker Desktop; it rebuilds `docker-desktop`, reattaches the
   data disk, and the engine comes up healthy. Your images survive.

## Error-code cheat sheet

| Code / string | Meaning | What it tells you |
|---|---|---|
| `HCS_E_CONNECTION_TIMEOUT` | guest didn't answer HCS over vsock | WSL VM boots then hangs → corrupted kernel/distro |
| `0xC0370103` (Terminate compute system) | VM force-terminated after the hang | confirms the ~60s boot-then-die pattern |
| `RegisterDistro/CreateVm/0x800705b4` | `ERROR_TIMEOUT` creating a *new* VM | WSL was updated; **reboot to finalize**, then it works |
| `500 ... dockerDesktopLinuxEngine` | CLI fine, engine not up | engine distro not running (look one layer down) |

## Fast path if it happens again

1. Confirm the engine is down and which layer is broken (CLI vs engine vs WSL runtime).
2. `wsl --update`, rebuild the engine distro, reboot if told to.
3. Your images/volumes live in `docker_data.vhdx` — they survive all of this.

> The root cause of *repeated* corruption is usually unclean shutdowns. If this keeps
> happening, see
> [Modern Standby freezes → WSL corruption](modern-standby-freezes-wsl-corruption.md).
