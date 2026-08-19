# Cleanup Baseline Snapshot

## General
- Snapshot timestamp: `2026-08-06T06:58:12.3825234-07:00` (America/Los_Angeles)
- Repository path: `C:\Users\William\Documents\ZipVoice-Distill TensorRT`
- Branch: `master`
- Commit: `N/A` (no commit yet in this checkout; `git rev-parse HEAD` is not resolvable)
- Git status baseline: uncommitted workspace with only untracked content

## Existing Repository State
- Baseline `git status --short` output:
  - `?? " ; readlink ; done; echo status; grep -E State"`
  - `?? .gitignore`
  - `?? =1s=%d`
  - `?? "Start ZipVoice GUI.cmd"`
  - `?? "Voice Tray.ps1"`
  - `?? benchmark-results/`
  - `?? benchmark_standard_template.py`
  - `?? benchmark_texts.txt`
  - `?? cached_tts_client.py`
  - `?? finalize_audio.sh`
  - `?? patches/`
  - `?? pytriton_server.py`
  - `?? runtime/`
  - `?? tensorrt_export.py`
  - `?? test_codec_integration.py`
  - `?? test_codec_mastering.py`
  - `?? test_pytriton_cache_control.py`
  - `?? test_voice_cache_protocol.py`
  - `?? test_zipvoice_gui.py`
  - `?? voice_cache_protocol.py`
  - `?? zipvoice_gui.py`

## Repository Size
- Total size: `2,944,382` bytes (`~2.81` MB)

## Related Path Sizes
- `C:\Users\William\Documents\ZipVoice-Distill TensorRT\benchmark-results`: `1,392,251` bytes
- `C:\Users\William\Documents\ZipVoice-Distill TensorRT\__pycache__`: `1,166,663` bytes
- `C:\Users\William\Documents\ZipVoice-Distill TensorRT\runtime`: `20,776` bytes

## Disk Space
- Free disk space on `C:`: `25,609,908,224` bytes (`~23.85` GiB)

## Largest Files (Top files captured)
- `benchmark-results\standard-template-smoke\audio\stage=steps-steps=4-prompt_seconds=2.5-concurrency=1-chunk_seconds=20\short\b1-r1-0.wav` — `462,892` bytes
- `benchmark-results\standard-template-smoke\audio\stage=steps-steps=4-prompt_seconds=2.5-concurrency=1-chunk_seconds=20\short\b2-r1-0.wav` — `462,892` bytes
- `benchmark-results\standard-template-smoke\.warmup\0.wav` — `462,892` bytes
- `__pycache__\zipvoice_gui.cpython-314.pyc` — `273,312` bytes
- `__pycache__\zipvoice_gui.cpython-312.pyc` — `260,116` bytes
- `zipvoice_gui.py` — `205,039` bytes
- `Voice Tray.ps1` — `10,502` bytes
- `Start ZipVoice GUI.cmd` — `4,075` bytes
- `test_zipvoice_gui.py` — `42,485` bytes
- `__pycache__\test_zipvoice_gui.cpython-314.pyc` — `89,721` bytes
- `__pycache__\test_zipvoice_gui.cpython-312.pyc` — `84,179` bytes

## Largest Directories
- `benchmark-results\standard-template-smoke`: `1,392,251` bytes
- `benchmark-results`: `1,392,251` bytes
- `__pycache__`: `1,166,663` bytes
- `runtime\nvidia_triton`: `20,776` bytes
- `runtime\nvidia_triton\voices`: `20,776` bytes
- `benchmark-results\standard-template-smoke\audio`: `925,784` bytes

## Workflow Evidence
- Current install command: not discoverable in tracked metadata
- Current launch command: double-click or run `Start ZipVoice GUI.cmd` (WSL + Docker + `zipvoice_bootstrap.py exec`)
- Current test command: not discoverable in tracked metadata
- Current known-good workflow: `Start ZipVoice GUI.cmd` with Bootstrap/health-check path to `http://127.0.0.1:8020`
- Active runtime/deployment markers:
  - WSL distro: `Ubuntu-24.04`
  - Bootstrap runtime token: `/home/william/tts/ZipVoice/zipvoice_bootstrap.py`
  - Adopted runtime token: `zipvoice-trt-pinned-r5`

## Candidate Hash Tracking
- Deletion candidates not yet finalized; hashes not yet assigned.

## Access Limits
- No external inaccessible locations reported during baseline scan.
