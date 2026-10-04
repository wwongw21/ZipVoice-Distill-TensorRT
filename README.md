# ZipVoice Windows Launcher Package

This folder contains the Windows launch and stop controls for the ZipVoice
application checkout identified in historical project records as:

`/home/william/tts/ZipVoice` in `Ubuntu-24.04`

The live WSL checkout was not verified in the current review. Confirm its
branch, commit, and Git status before relying on this path as current.

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
- WSL tests: `/home/william/.local/state/zipvoice/host-envs/current/bin/python -B -m unittest discover`

## Data and cleanup

Active deployment models, user voices, databases, and user-generated audio
were excluded when identified as active deployment data. The historical
manifests also record removal of specific stale Windows copies, generated
outputs, and Docker objects; eight root-owned cache entries remained
undeleted. Check each item’s recorded outcome before drawing conclusions about
current files. These records do not authorize new deletions. The one-time
cleanup result is recorded in
`cleanup/DELETION_MANIFEST-ONE-TIME-20260819.json`,
`cleanup/QUARANTINE_MANIFEST-ONE-TIME-20260819.json`, and `CLEANUP_REPORT.md`.
Those files describe completed historical operations. They do not authorize a
new deletion or prove that old quarantine payloads are still recoverable. Any
new cleanup requires a fresh live inventory, exact scope, and validation.
