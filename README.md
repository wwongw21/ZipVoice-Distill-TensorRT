# ZipVoice Windows Launcher Package

This folder contains the Windows launch and stop controls for the canonical
ZipVoice application in WSL:

`<HOME>/tts/ZipVoice` in `Ubuntu-24.04`

## Portable-dev workflow

Edit the live WSL application or these live launcher scripts, run/debug them
immediately through the public launcher, test, then commit the intended files.
No rebuild or copy-to-portable step is required.

## Commands

- Launch: `Start ZipVoice GUI.cmd`
- Stop: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\Voice Tray.ps1 -StopOnly`
- Tray self-check: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\\Voice Tray.ps1 -SelfCheck`
- WSL tests: `<HOME>/.local/state/zipvoice/host-envs/current/bin/python -B -m unittest discover`

## Data and cleanup

Runtime models, voices, databases, generated audio, caches, and Docker state
are deployment data, not launcher source. They are protected by the cleanup
scope and manifests. The one-time cleanup result is recorded in
`cleanup/DELETION_MANIFEST-ONE-TIME-20260819.json`,
`cleanup/QUARANTINE_MANIFEST-ONE-TIME-20260819.json`, and `CLEANUP_REPORT.md`.
