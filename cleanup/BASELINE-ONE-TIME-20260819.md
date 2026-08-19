# One-Time Full-Deployment Cleanup Baseline

## Scope and date

- Date: 2026-08-19 (America/Los_Angeles)
- Windows launcher root: `<USERPROFILE>\Documents\ZipVoice-Distill TensorRT`
- Canonical WSL source: `<HOME>/tts/ZipVoice` in `Ubuntu-24.04`
- Current WSL branch: `codex/zipvoice-reliability-longform`
- Current WSL commit: `cd07c0260a41e4f3a3ac287652920552885eefb9`
- Windows branch: `master` unborn, zero commits

## Git state before cleanup

- Windows repository: 25 non-ignored untracked files; no staged or unstaged tracked changes.
- WSL repository: 12 unstaged tracked files after the protected `.gitignore` update and 20 non-ignored untracked source/test/document files.
- WSL runtime payloads, models, voices, backups, and generated media are ignored or explicitly excluded from the intended commit scope.
- No merge, rebase, sequencer, conflict, or index-lock operation is active.

## Storage baseline

- Windows launcher overlay: 25 files, 420,691 bytes.
- WSL checkout including runtime payloads: approximately 2.9 GiB.
- Managed WSL host environment: 92 MiB.
- Docker: 6 ZipVoice containers; writable layers total 24.74 GB. Images total 50.69 GB with 599.1 MB currently reported reclaimable. Build cache is 50.05 GB with only 36.86 KB reported reclaimable and is not project-owned.
- Windows C: free 379.04 GiB / 39.78%.
- WSL root: 1,009,021,206,528 bytes available / 2% used.

## Public commands

- Launch: `Start ZipVoice GUI.cmd`
- Stop: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Voice Tray.ps1 -StopOnly`
- WSL tests: `<HOME>/.local/state/zipvoice/host-envs/current/bin/python -B -m unittest discover`

## Baseline validation

- WSL managed suite: 94 tests, 0 failures, 9 documented skips, 0.886 seconds.
- GUI and Docker were stopped at baseline capture.
- Health endpoints `127.0.0.1:8020/health` and `127.0.0.1:8010/v2/health/ready` were unavailable while stopped.
- No Windows ZipVoice Edge window or WSL GUI process was present.
- WSL repository inspection passed after runtime payload protection rules were added; no BLOCK or WARN findings remained.

## Protected current deployment

- Container: `zipvoice-trt-pinned-r5`.
- Current image digest: `sha256:05ee9e98fbc868bf1d38e24817ce79fb8d0788b11629455be96f242fe9d73b90`.
- Current/rollback model engines and model files referenced by `runtime/runtime-lock.json`.
- Managed host environment selected by `host-envs/current`.
- Voice recordings, manifests, SQLite databases, prompt audio, model caches, and user-generated media.

## Candidate evidence hashes

- WSL generated output `runtime/nvidia_triton/audiobook_validation.opus`: `a3b8af340009038990b99a5d298a05bd60934289f78dd1e369d279af01b62ea0`.
- WSL `runtime/nvidia_triton/pytriton_server.py.orig`: `caeeddc72b8a9737ac9dd981876c643897bc9f93c3a060c8df9e541d2a391bbe`.
- WSL `runtime/nvidia_triton/pytriton_server.py.pre-model-presets`: `640a8f34ceeeb210589e67b7545a245316ea89aabd756de299da55663b805ab9`.
- WSL `runtime/nvidia_triton/pytriton_server.py.pre-standard-template`: `fa3fd3eb794e6d922328b4b0f8d02ffcdb27ed1f970a5c7adcc0e63717b2a34c`.
- WSL `zipvoice_gui.py.orig`: `97d675c0ceb10925841d20467165e75c95f0672c6df0dd52145e5c1079bc9797`.
- WSL `zipvoice_gui.py.pre-model-presets`: `42efac798a01a212b2c0bb4d9fc214b86203fd1e852924736ac74318929d04bf`.
- Windows stale `tensorrt_export.py`: `D77661A08C4744CB31170A3C1469119CB56B87985507427B31F9DE4829E62E23`, byte-identical to the live package exporter.

## Known warning

- WSL emitted the existing NAT-mode localhost-proxy warning during commands. It did not block the managed test suite or prior validated launcher lifecycle.
