# ZipVoice Windows Launcher Package

## October 28 integrated main

This separate working copy combines local Windows launcher revision `fd532cf`
with cloud `main` revision `0da1c2a`, and retains the current local icon,
shortcut, documentation and test changes. Both saved revisions remain reachable
in Git history. The reconciled source is committed on local and cloud main;
the reconciliation and pre-finalization preservation branches retain earlier
versions.

The tray keeps the local bounded shutdown probes and managed-process identity,
alongside the cloud event handlers and verified shutdown result. The two
monitor flags for responding endpoints and an active shutdown are separate.
The launcher tests import only top-level production functions so the
self-check's nested mocks cannot replace them.

The 21 isolated Docker launcher checks and tray self-check pass. The separate native runtime was qualified with a real TensorRT build, Fast and Quality speech output, cancellation, retry, copied-profile add/delete and normal shutdown. Its Linux suite passes 106 root and 23 runtime checks. WSL is available on this host. Docker Desktop is absent, so the default Docker launcher reports that requirement clearly. Use the explicit native commands below for the separately qualified copied runtime.

The original Windows folder, including Git metadata and its ignored shortcut,
is retained in the recovery workspace's preparation and finalization snapshots.
These local archives are not included in a GitHub clone. They must be copied
off this computer before a reset. Generate a shortcut for the chosen checkout
with New ZipVoice Shortcut.ps1; shortcuts contain absolute local targets.

This folder contains the Windows launch and stop controls for the ZipVoice
application checkout identified in historical project records as:

`<HOME>/tts/ZipVoice` in `Ubuntu-24.04`

The live WSL checkout was inspected during October 28 finalization. Confirm its
branch, commit and Git status again before relying on a historical source note.

## Source of truth

This Windows repository contains launcher and evidence files. Historical
project records identify the executable Python application at the WSL
location above; current location and Git state require a live check. The
recorded Windows `main` baseline is commit
`d9913202eb29d43f9e7fab0d517d5129b269ff74`. That identifier is a historical
baseline, not proof of the current checkout. Before relying on it, verify the
live state with `git branch --show-current`, `git rev-parse HEAD`, and
`git status --short`.

## Portable-dev workflow

After verifying the WSL checkout, edit that application or these launcher
scripts, run/debug them through the public launcher, test, then commit the
intended files. No rebuild or copy-to-portable step is required.

## Commands

- Launch: `Start ZipVoice GUI.cmd`
- Stop: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\Voice Tray.ps1 -StopOnly`
- Tray self-check: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\Voice Tray.ps1 -SelfCheck`
- Isolated launcher tests: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Launcher.Tests.ps1`
- WSL tests: `<HOME>/.local/state/zipvoice/host-envs/current/bin/python -B -m unittest discover`

## Separate native commands

Use `Start ZipVoice Native.cmd`, `Native Status.cmd` and `Stop ZipVoice Native.cmd` for the explicit experimental native profile on port 8026. The first start creates a private configuration file; the qualified copied runtime and its model files must be retained. See [README-NATIVE.md](README-NATIVE.md) for locations, limits, dependency versions and safe cancellation.

## Application icon and shortcut

The tray uses `assets/zipvoice.ico`: a white Z with cyan sound bars. The icon
contains 16, 20, 24, 32, 40, 48, 64, 128, and 256 pixel sizes for Windows display
scaling. Status messages and tray controls work as before.

Create the matching launch shortcut in this folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\New ZipVoice Shortcut.ps1"
```

Open `ZipVoice.lnk` to run the existing `Start ZipVoice GUI.cmd` launcher. To
place the shortcut elsewhere, pass `-DestinationDirectory` with an existing
folder. Run the command again after moving the checkout. The generated shortcut
uses absolute paths and is excluded from Git. An existing shortcut to another
target is left unchanged.

`assets/zipvoice.svg` and `assets/zipvoice.png` provide the same design in vector
and image formats. To regenerate all three assets, run
`python tools/generate_icons.py` with Pillow installed. Pillow is needed only
for regeneration, not to launch ZipVoice.

The matching ICO and SVG assets are also connected to the browser UI in
`<HOME>/tts/ZipVoice` in `Ubuntu-24.04`. That application's
`zipvoice_gui.py` serves `/favicon.ico` and `/favicon.svg` and declares both in
the page header. This supplies the same identity to browser tabs and the Edge
app window opened by the launcher. Restart or reload an existing app window to
pick up the change. Windows window/taskbar rendering has not been checked live.
This repository has no packaged executable or installer.

## Data and cleanup

Active deployment models, user voices, databases, and user-generated audio
were excluded when identified as active deployment data. The historical
manifests also record removal of specific stale Windows copies, generated
outputs, and Docker objects; eight root-owned cache entries remained
undeleted. Check each itemâ€™s recorded outcome before drawing conclusions about
current files. These records do not authorize new deletions. The one-time
cleanup result is recorded in
`cleanup/DELETION_MANIFEST-ONE-TIME-20260819.json`,
`cleanup/QUARANTINE_MANIFEST-ONE-TIME-20260819.json`, and `CLEANUP_REPORT.md`.
Those files describe completed historical operations. They do not authorize a
new deletion or prove that old quarantine payloads are still recoverable. Any
new cleanup requires a fresh live inventory, exact scope, and validation.

## 2026-10-04 launcher audit and reconciliation

The local launcher changes were audited and reconciled in Windows `main` using
local checks.
Command checks now distinguish success, an absent process or ownership record,
and infrastructure errors, including negative exit codes. Shutdown probes use
the remaining 30-second budget. The four port connections start together and
have a shared wait of up to three seconds; only confirmed connection refusal
counts as a closed port. Unknown results keep shutdown unsuccessful and
available for retry. Edge profile arguments preserve spaces and apostrophes.

Local validation passed the tray self-check, 19 isolated regression checks,
PowerShell and embedded-command syntax, cleanup JSON parsing, and Git
whitespace checks. Tests use simulated command results and temporary local
ports. They do not start WSL, Docker, Edge, or ZipVoice.

**Historical October 4 live-test status: not run.** WSL reported unavailable virtualization during that audit. The October 28 native qualification above supersedes that host observation.
Startup, duplicate launch, audio generation, shutdown, and restart therefore
remain unverified. The Linux application source, model engines, and Docker
deployment were outside this reconciliation. Committing the Windows launchers
and obtaining a clean working tree do not qualify the application for release.

Repository cleanup is limited to the clean older worktree already represented
in `main` and empty `patches`, `runtime`, and `cleanup/quarantine` folders after
fresh checks. Historical cleanup records and Git history are retained. No
GitHub push or remote deletion is part of this operation.
