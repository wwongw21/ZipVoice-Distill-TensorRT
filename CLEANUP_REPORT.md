# Cleanup Report

> **Historical evidence notice:** This report combines cleanup observations
> recorded on 2026-08-06 and 2026-08-19. Its paths, process state, sizes,
> deletion decisions, and validation results are snapshots, not current
> deletion authority. Before any new cleanup, collect a fresh inventory and
> obtain an exact current scope.
>
> **Current repository note:** At this documentation correction, the Windows
> repository is on `main` at the recorded baseline
> `d9913202eb29d43f9e7fab0d517d5129b269ff74`. Verify the live checkout with
> `git branch --show-current`, `git rev-parse HEAD`, and `git status --short`.
> Older statements below that the repository had no commits or was entirely
> untracked describe the earlier snapshot and are not current facts.
>
> **Recovery evidence gap:** The listed quarantine locations were emptied or
> are absent, and some later manifest commands contain literal placeholders
> such as `<quarantine>` and `<workspace>`. Those commands are retained as
> historical records only. They are not executable recovery instructions, and
> the manifests alone do not prove that deleted payloads can currently be
> restored.

## Executive summary
- The seven candidates in the 2026-08-06 `cleanup/DELETION_MANIFEST.json`
  are recorded as removed from repository paths and marked deleted. The later
  2026-08-19 manifest has separate per-item outcomes, including entries not
  marked deleted.
- At the original snapshot, the repository had no resolved commit context and
  was reported as entirely untracked. This is no longer the current Git state.
- Candidate cleanup set (7 entries) is fully processed (hard delete executed after quarantine) and marked `deleted=true`.

## Completion matrix
| Baseline | Post-cleanup | Reclaim |
|---|---|---|
| `2,944,382` bytes (`cleanup/BASELINE.md`) | `416,812` bytes (measurement used for the reported reclaim calculation) | `2,527,570` bytes reclaimed (`~2.41 MB`) |

| Candidate | Manifest `deleted` | Physical existence now |
|---|---:|---:|
| `__pycache__/` | true | false |
| `benchmark-results/` | true | false |
| `runtime/nvidia_triton/voices/.cache-control/` | true | false |
| `runtime/nvidia_triton/voices/.voice-jobs/` | true | false |
| `runtime/nvidia_triton/voices/.voice-staging/` | true | false |
| ` ; readlink ; done; echo status; grep -E State` | true | false |
| `=1s=%d` | true | false |
- Historical recovery-command text is preserved in
  `cleanup/QUARANTINE_MANIFEST.json`; the referenced payloads are absent, so
  this text is not current rollback proof.

## Scope
- In-scope repository: `<USERPROFILE>\Documents\ZipVoice-Distill TensorRT`
- Governing scope file: `cleanup/SCOPE.md`
- Explicitly allowed path is the repository root.

## Baseline
- Baseline snapshot captured in `cleanup/BASELINE.md`.
- Repository size: `2,944,382` bytes.
- Largest reclaimable-looking categories observed: `benchmark-results`, `__pycache__`.
- A second post-hard-delete size is recorded as `413,046` bytes. The source
  notes do not explain whether its scope differs from the `416,812`-byte
  measurement above, so the exact post-cleanup total is unresolved.

## Canonical architecture in the recorded snapshot
- No dedicated manifest or lockfile observed.
- GUI launch path is `Start ZipVoice GUI.cmd`, which delegates execution into WSL and Docker-backed `zipvoice_bootstrap.py`.
- No explicit dependency manifest (`pyproject.toml`, lockfile, setup files) was found in this snapshot.

## Duplicate analysis
- Exact duplicate scan by content hash was executed across 236 files (`Get-FileHash` on repo files excluding manifest artifacts and temp artifacts).
- Duplicate groups found: 0.
- No obvious name-based duplicate copies found outside generated artifact locations.
- No further irreversible cleanup is proposed from duplicate analysis.

## Obsolete-version analysis
- Runtime/version references are currently pinned by launcher/runtime behavior (for example `zipvoice-trt-pinned-r5`).
- No versioned duplicate artifacts were observed in this snapshot.
- Canonical version checks are limited to the current launcher/runtime path and WSL bootstrap command flow until install/version history is provided.

## Dead-code analysis
- Preliminary static module-reference scan (naive text-match) was run on 11 Python files.
- No removals yet; module-level import graph for definitive dead-code elimination is still pending.
- Scan flagged these unreferenced module-name candidates with no static imports detected from other in-repo files: `benchmark_standard_template.py`, `tensorrt_export.py`, and seven test modules (`test_*` files), consistent with optional utility and test-only files.

## Dependency analysis
- No dependency manifest was found in this working snapshot.
- Active imports and runtime references are in code and scripts (`zipvoice_gui.py`, `pytriton_server.py`, `Start ZipVoice GUI.cmd`, `Voice Tray.ps1`).

## Log/session consolidation
- Benchmark artifacts are present in `benchmark-results/` and include CSV/JSON outputs and generated WAVs.
- No chat/session DB migration has been executed in this stage.

## Proposed file moves
- Generated/runtime-scratch candidates were moved to quarantine and then hard-deleted after manifested stage.
- Recovery-command text remains in `cleanup/QUARANTINE_MANIFEST.json` as
  historical documentation, but the absent payloads make it non-executable.
- `cleanup/quarantine/2026-08-06T07-09-32-0700/` is now emptied and removed after deletion; older quarantine evidence remains tracked in manifest.

## Proposed deletions
- Proposed (manifested) candidates in `cleanup/DELETION_MANIFEST.json` (`deleted=true` for all 7 entries):
  - `__pycache__/` (compiled Python bytecode)
  - `benchmark-results/` (generated benchmark outputs and WAV artifacts)
  - `runtime/nvidia_triton/voices/.cache-control/` (runtime scratch/state cache)
  - `runtime/nvidia_triton/voices/.voice-jobs/` (runtime scratch queue state)
  - `runtime/nvidia_triton/voices/.voice-staging/` (runtime scratch staging state)
  - ` ; readlink ; done; echo status; grep -E State` (empty malformed artifact)
  - `=1s=%d` (empty malformed artifact)
- Current deletion manifest state: all 7 entries are now marked `deleted=true`.

## Quarantine candidates
- 7 candidates are recorded in `cleanup/QUARANTINE_MANIFEST.json` with
  historical recovery-command text.
- Physical quarantine contents were removed after hard-delete. The manifest
  documents intended source and destination paths but does not provide a
  recoverable payload.

## Protected items
- Items recorded as protected in the 2026-08-06 stage:
  - `Start ZipVoice GUI.cmd`
  - `Voice Tray.ps1`
  - `cached_tts_client.py`
  - `benchmark_standard_template.py`
  - `benchmark_texts.txt`
  - `tensorrt_export.py`
  - `pytriton_server.py`
  - `zipvoice_gui.py`
  - `runtime/nvidia_triton/voices/voices.json`
  - `runtime/nvidia_triton/voices/voice-ops.sqlite3`
  - `patches/zipvoice-base-trt-profile-2f7326f.patch`
- The 2026-08-19 manifest later records removal of the stale Windows copies
  of `voices.json` and `voice-ops.sqlite3`; this list describes the earlier
  stage, not the later filesystem state.

## Validation plan
1. Re-check candidate safety with runtime active-state check and static reference traces. ✅
2. Run duplicate hash scan for candidate deletion folders. ✅
3. Generate a deletion dry-run matrix and record expected recovery path for each candidate. ✅
4. If approved, delete manifest entries in one logical group and re-snapshot size and references. ✅
5. Final user-visible validation pass completed via normal launcher/UI flow: ✅ launch, duplicate launch, shutdown, restart.

## End-user validation checks (launcher/UI)
- Primary launch (`Start ZipVoice GUI.cmd`): passed after first successful startup cycle; GUI process count reached 1 and `/health` returned `200`.
- Duplicate launch while running: passed (`duplicate_launch_gui_procs` stayed at 1 after second launcher invocation).
- Shutdown (`Voice Tray.ps1 -StopOnly`): passed; GUI process removed and `/health` returned unavailable; first shutdown attempt after a failed launch timed out on stale ownership file cleanup, then succeeded.
- Restart after shutdown: passed; GUI process count returned to 1 and both `/health` (8020) and `/ready` (8010) returned `200`.
- Observed non-blocking warning: WSL local proxy warning appears in logs (`WSL in NAT mode does not support local proxy`) but does not block runtime.

## End-user validation checks (launcher/UI)
- Primary launch (Start ZipVoice GUI.cmd): GUI health endpoint returned `200` quickly.
- Duplicate/cancellation behavior: second launch while running did not add extra bootstrap runtime processes.
- Shutdown: terminated bootstrap WSL runtime processes and observed health endpoint unavailable.
- Restart: launch after shutdown returned health `200` and recreated runtime bootstrap processes.
- Failure observation: preflight logs included localhost proxy warning (`WSL in NAT mode does not support local proxy`) but did not block launcher from reaching health state.

## Candidate rollback commands (historical, non-executable)

The source paths in the commands below no longer exist. Do not run them as a
rollback procedure. They are preserved only to show the paths recorded during
the 2026-08-06 operation.

- `Move-Item -LiteralPath '<USERPROFILE>\Documents\ZipVoice-Distill TensorRT\cleanup\quarantine\2026-08-06T07-07-00-0700\__pycache__' -Destination '<USERPROFILE>\Documents\ZipVoice-Distill TensorRT\__pycache__' -Force`
- `Move-Item -LiteralPath '<USERPROFILE>\Documents\ZipVoice-Distill TensorRT\cleanup\quarantine\2026-08-06T07-07-00-0700\benchmark-results' -Destination '<USERPROFILE>\Documents\ZipVoice-Distill TensorRT\benchmark-results' -Force`
- `Move-Item -LiteralPath '<USERPROFILE>\Documents\ZipVoice-Distill TensorRT\cleanup\quarantine\2026-08-06T07-07-00-0700\ ; readlink ; done; echo status; grep -E State' -Destination '<USERPROFILE>\Documents\ZipVoice-Distill TensorRT\ ; readlink ; done; echo status; grep -E State' -Force`
- `Move-Item -LiteralPath '<USERPROFILE>\Documents\ZipVoice-Distill TensorRT\cleanup\quarantine\2026-08-06T07-07-00-0700\=1s=%d' -Destination '<USERPROFILE>\Documents\ZipVoice-Distill TensorRT\=1s=%d' -Force`
- `Move-Item -LiteralPath '<USERPROFILE>\Documents\ZipVoice-Distill TensorRT\cleanup\quarantine\2026-08-06T07-09-32-0700\.cache-control' -Destination '<USERPROFILE>\Documents\ZipVoice-Distill TensorRT\runtime\nvidia_triton\voices\.cache-control' -Force`
- `Move-Item -LiteralPath '<USERPROFILE>\Documents\ZipVoice-Distill TensorRT\cleanup\quarantine\2026-08-06T07-09-32-0700\.voice-jobs' -Destination '<USERPROFILE>\Documents\ZipVoice-Distill TensorRT\runtime\nvidia_triton\voices\.voice-jobs' -Force`
- `Move-Item -LiteralPath '<USERPROFILE>\Documents\ZipVoice-Distill TensorRT\cleanup\quarantine\2026-08-06T07-09-32-0700\.voice-staging' -Destination '<USERPROFILE>\Documents\ZipVoice-Distill TensorRT\runtime\nvidia_triton\voices\.voice-staging' -Force`

## Estimated space recovery
- Estimated reclaimable (before deletion):
  - `benchmark-results`: `1,392,251` bytes
  - `__pycache__`: `1,166,663` bytes
  - malformed/empty artifacts: `0` bytes
  - runtime scratch dirs: `0` bytes
  - total candidate estimate: `2,558,914` bytes
- Post-cleanup measured size (including cleanup evidence): `416,812` bytes

## Risks and unresolved questions
- At the original snapshot, no Git commit history was available. The Windows
  repository now has a recorded `main` baseline at
  `d9913202eb29d43f9e7fab0d517d5129b269ff74`; verify the live state before
  relying on it. The preserved manifests do not recreate deleted payloads.
- Hard-coded WSL paths in launch/runtime scripts may affect portability.
- Duplicate/inexact version checks are pending before any source-path pruning.
## Final stage handoff and closeout

### Finalization status
- Stage result: **COMPLETE** for declared scope.
- All candidate cleanup entries in `cleanup/DELETION_MANIFEST.json` are marked `deleted=true`.
- All candidate paths are currently absent in filesystem checks.
- End-user launcher/UI validation was executed for launch, duplicate launch, shutdown, and restart.

### Completion matrix recap
- Baseline snapshot vs post-cleanup is recorded in `Completion matrix` with reclaim measurement.
- Candidate outcomes and the historical intended rollback paths are documented
  in this report. Current rollback capability is not proven.

### Completion conditions check
- Repository functionality: **Passed** (validated via `Start ZipVoice GUI.cmd` and health/ready endpoints).
- Candidate inventory consistency: **Passed** (all manifest states and filesystem presence checks match).
- Recovery evidence: **Historical assessment only**. Command text is preserved,
  but current payload availability and executable rollback are not proven.

## Troubleshooting note: transient startup/shutdown edge case
- **Confirmed finding:** one launch attempt failed with `zipvoice_gui.py` container inspection error (`container ... is not running`) after a prior startup path had stale runtime state.
- **Likely root cause hypothesis:** stale runtime ownership/metadata prevented immediate GUI startup sequencing.

**Recovery runbook:** Treat ownership-record removal as a last-resort state
repair, not a routine startup step.

1. Run `Voice Tray.ps1 -StopOnly`.
2. Confirm GUI health at `http://127.0.0.1:8020/health` and readiness at
   `http://127.0.0.1:8010/v2/health/ready` are both unavailable.
3. Confirm no ZipVoice GUI or bootstrap process remains and the launcher-owned
   ZipVoice container is stopped. If any is active, do not remove the record.
4. Inspect the record at the exact path
   `<HOME>/.local/state/zipvoice/runtime-ownership.json`. Confirm it
   belongs to the stopped ZipVoice instance and is stale. Do not remove an
   unreadable, unexpected, differently located, or actively owned record.
5. Only after those gates pass, remove that exact file inside `Ubuntu-24.04`;
   do not use a wildcard or remove the parent directory.
6. Launch `Start ZipVoice GUI.cmd` and verify exactly one GUI/bootstrap
   instance, GUI health HTTP 200, and runtime readiness HTTP 200.
7. Run `Voice Tray.ps1 -StopOnly` again and verify the instance is gone, both
   endpoints are unavailable, and the ownership record is absent.
8. Restart once more and repeat the single-instance, health, and readiness
   checks. If any check fails, stop and preserve the record and logs for
   diagnosis.

## 2026-08-19 — One-time full-deployment cleanup

### Scope and decision

- Canonical application remained `<HOME>/tts/ZipVoice` in `Ubuntu-24.04`.
- The Windows folder was reduced to the launcher and cleanup/evidence package.
- Deletion eligibility was based on whether an item was required by the latest verified full deployment; age was not used.
- User data, current models, current engines, rollback engines, voices, databases, current host environment, Hugging Face cache, and current `zipvoice-trt-pinned-r5` were retained.

### Verified before deletion

- Managed WSL suite: 94 tests, 0 failures, 9 documented skips.
- Public launcher: health, GUI readiness, and Triton readiness all returned HTTP 200.
- Post-quarantine synthesis: verified Opus output, 28,288 bytes.
- Post-quarantine cancellation: valid 4,560-character request reached terminal `cancelled`.
- Final post-cleanup synthesis: verified short output, 26,632 bytes.
- Final post-cleanup cancellation: valid 3,840-character request reached terminal `cancelled`.
- Shutdown: GUI process 0, ports 8010–8012/8020 closed, ownership record absent.
- Restart: public launcher restored all three readiness endpoints to HTTP 200 and one r5 runtime.

### Removed

- 16 stale Windows application/test/runtime overlay files, sent to the Windows Recycle Bin after exact hash verification.
- WSL historical backup directories, superseded `.orig`/`.pre-*` snapshots, generated audiobook validation output, and the unreferenced runtime-adapter file, sent to WSL trash after quarantine.
- Five superseded stopped ZipVoice containers.
- Three superseded derived Docker images/tags.
- Cleanup/test job outputs created by this run and the root Python bytecode cache, sent to trash.

### Retained or blocked

- Eight nested Python/cache directories remain because they are owned by `root`; normal WSL user deletion and trash operations were denied, and `sudo` requires a password. No privilege escalation was attempted.
- The WSL reliability source/test changes remain unstaged user work. The cleanup-only `.gitignore` protection change was committed on `codex/zipvoice-consolidation` as `78e88535f40f` and verified byte-for-byte.
- Visible Edge/browser interaction was not revalidated in this run because both browser-control surfaces timed out; endpoint, process, output, cancellation, shutdown, and restart checks did run.

### Storage result

- Docker writable layers: 24.74 GB before → approximately 14.8 MB current r5 container layer.
- Windows C: approximately 403.3 GiB free after cleanup.
- WSL root: approximately 1,009,042,395,136 bytes available after cleanup.
