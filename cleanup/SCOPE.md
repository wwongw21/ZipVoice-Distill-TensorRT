# Cleanup Scope

## Repository Root
- Exact path: `<USERPROFILE>\Documents\ZipVoice-Distill TensorRT`
- Current branch: `master`
- Current commit: `N/A` (repository has no commits yet; only untracked files)

## Allowed Related Paths
| Path | Ownership Evidence | Expected Contents | Deletion Allowed? |
|---|---|---|---|
| `<USERPROFILE>\Documents\ZipVoice-Distill TensorRT` | Active working copy in current task | Application source, launch scripts, runtime/test outputs, temporary artifacts | Yes |

## Explicit Exclusions
- User data: `<none in scope>`
- System data: `<none in scope>`
- Other repositories: `<not in scope>`
- Cloud services: `<not in scope>`
- Shared caches: `<not in scope>`
- Symlinks or mounts: `<inspect before any scoped change>`

## One-Time Full-Deployment Cleanup Expansion (2026-08-19)

This is a single cleanup operation. Deletion eligibility is based on whether
an item is required by the latest verified full deployment, not on its age.

### Allowed Related Paths
| Path | Ownership Evidence | Expected Contents | Deletion Allowed? |
|---|---|---|---|
| `\\wsl.localhost\Ubuntu-24.04\home\william\tts\ZipVoice` | Launcher target and active WSL Git checkout | Canonical application source, tests, locks, runtime configuration, and deployment documentation | Yes, only for exact manifested obsolete artifacts |
| `<HOME>/.local/state/zipvoice` in `Ubuntu-24.04` | Bootstrap and runtime state root used by the launcher | Managed host environment, ownership state, runtime logs, and recovery state | Yes, only for superseded environments/state proven unnecessary |
| `<HOME>/.local/share/zipvoice/outputs/79cb2a1b-df3e-4009-ae2c-8b9392f8f60e` in `Ubuntu-24.04` | Test output created by this cleanup validation | One verified test audio output and checkpoint | Yes, exact test artifact only |
| `<HOME>/.local/share/zipvoice/outputs/716ec736-af57-4843-b8ee-0cc12aa845a4` in `Ubuntu-24.04` | Test output path created by this cleanup validation | Canceled test job output path | Yes, exact test artifact only |
| Docker objects named `zipvoice-trt*` | Runtime lock and launcher ownership | ZipVoice containers and derived images | Yes, only for exact obsolete objects after current deployment validation |

### Explicit Exclusions
- User voice recordings, custom voice manifests, SQLite databases, and generated user media unless individually classified and preserved.
- The shared Hugging Face cache and unrelated Docker images/build cache.
- Other repositories, WSL distributions, system files, and non-ZipVoice containers.
- Current source, current dependency locks, current models/engines, rollback engines, current host environment, and all artifacts required by `runtime/runtime-lock.json`.
