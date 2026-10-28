# ZipVoice-Distill-TensorRT engineering handoff

Review date: **22 October 2026**. All findings remain **OPEN**. This handoff contains proposed repairs and release checks; no source fixes or new runtime acceptance are claimed. This documentation update makes the failed-shutdown acceptance criteria and WSL test prerequisites explicit.

**Reviewed source:** [`main` at `96d641298cfce10ad9af44c4f900c608626868a9`](https://github.com/wwongw21/ZipVoice-Distill-TensorRT/tree/96d641298cfce10ad9af44c4f900c608626868a9).

The full structured handoff is in [report.json](report.json). Historical commands retain their original review-workspace paths; read the prerequisites before running them. Only repository-specific diagnostics listed below are attached.

## Audience and required outcome

### Audience

1. Maintainer of the Windows launcher and tray

2. Implementation agent adding a narrow failure-state correction

3. Windows/WSL release reviewer with access to the actual owned ZipVoice deployment

### Outcome

After a failed shutdown, keep the tray honest about the failure and leave a usable retry action, while preserving managed runtime identity, ownership and shutdown checks.

## Scope and reviewed branches

1. Entire tracked Windows launcher/tray code; README and historical cleanup/archive records

## Architecture

### Components

#### Item 1

##### Name

Windows entry point

##### File

Start ZipVoice GUI.cmd

##### Responsibility

Prepare the WSL host environment; reuse a healthy/already-starting GUI; start Docker Desktop and wait for WSL Docker integration when needed; establish runtime ownership through bootstrap; start hidden WSL GUI and tray; poll /health and open dedicated Edge app window.

##### Sources

###### Item 1

**File**

Start ZipVoice GUI.cmd

**Line**

14

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Start%20ZipVoice%20GUI.cmd#L14>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/Start ZipVoice GUI.cmd

###### Item 2

**File**

Start ZipVoice GUI.cmd

**Line**

23

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Start%20ZipVoice%20GUI.cmd#L23>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/Start ZipVoice GUI.cmd

###### Item 3

**File**

Start ZipVoice GUI.cmd

**Line**

69

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Start%20ZipVoice%20GUI.cmd#L69>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/Start ZipVoice GUI.cmd

###### Item 4

**File**

Start ZipVoice GUI.cmd

**Line**

84

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Start%20ZipVoice%20GUI.cmd#L84>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/Start ZipVoice GUI.cmd

#### Item 2

##### Name

Tray controller and monitor

##### File

Voice Tray.ps1

##### Responsibility

Single-instance Windows Forms tray; health/readiness/background polling; open/activate dedicated Edge window; request managed GUI interrupt; verify shutdown completion across process, HTTP, ports and ownership record.

##### Sources

###### Item 1

**File**

Voice Tray.ps1

**Line**

36

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Voice%20Tray.ps1#L36>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/Voice Tray.ps1

###### Item 2

**File**

Voice Tray.ps1

**Line**

122

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Voice%20Tray.ps1#L122>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/Voice Tray.ps1

###### Item 3

**File**

Voice Tray.ps1

**Line**

204

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Voice%20Tray.ps1#L204>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/Voice Tray.ps1

###### Item 4

**File**

Voice Tray.ps1

**Line**

277

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Voice%20Tray.ps1#L277>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/Voice Tray.ps1

#### Item 3

##### Name

Readiness and ownership contracts

##### Responsibility

GUI liveness at 127.0.0.1:8020/health; readiness at /ready; backend check at 8010/v2/health/ready; exact GUI process pattern; shutdown checks ports 8010/8011/8012/8020 and runtime-ownership.json removal.

##### Sources

###### Item 1

**File**

Voice Tray.ps1

**Line**

7

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Voice%20Tray.ps1#L7>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/Voice Tray.ps1

###### Item 2

**File**

Voice Tray.ps1

**Line**

36

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Voice%20Tray.ps1#L36>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/Voice Tray.ps1

###### Item 3

**File**

Voice Tray.ps1

**Line**

57

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Voice%20Tray.ps1#L57>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/Voice Tray.ps1

###### Item 4

**File**

Voice Tray.ps1

**Line**

82

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Voice%20Tray.ps1#L82>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/Voice Tray.ps1

###### Item 5

**File**

Voice Tray.ps1

**Line**

140

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Voice%20Tray.ps1#L140>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/Voice Tray.ps1

#### Item 4

##### Name

Runtime application outside this tree

##### Responsibility

zipvoice_bootstrap.py prepare/exec/adoption and zipvoice_gui.py in historical WSL location. Actual implementation and current checkout are unavailable in this review.

##### Sources

###### Item 1

**File**

README.md

**Line**

3

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/README.md#L3>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/README.md

###### Item 2

**File**

README.md

**Line**

13

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/README.md#L13>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/README.md

###### Item 3

**File**

Start ZipVoice GUI.cmd

**Line**

15

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Start%20ZipVoice%20GUI.cmd#L15>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/Start ZipVoice GUI.cmd

###### Item 4

**File**

Start ZipVoice GUI.cmd

**Line**

76

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Start%20ZipVoice%20GUI.cmd#L76>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/Start ZipVoice GUI.cmd

#### Item 5

##### Name

Historical cleanup and archive evidence

##### Files

1. CLEANUP_REPORT.md

2. cleanup/*

3. docs/history/ARCHIVE_SUMMARY.md

##### Responsibility

Record prior inventory/deletion/quarantine outcomes. These do not execute cleanup and do not prove present data/runtime state.

##### Sources

###### Item 1

**File**

README.md

**Line**

35

**Sha**

96d641298cfce10ad9af44c4f900c608626868a9

**Url**

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/README.md#L35>

**Local snapshot**

/workspace/repos/ZipVoice-Distill-TensorRT/README.md

### Control flow

1. User launches CMD -> WSL bootstrap prepare -> reuse existing health/process or prepare Docker/WSL -> establish ownership lease if missing -> launch bootstrap exec -> start tray -> poll /health -> open Edge

2. Tray timer -> test GUI health/readiness and backend/process -> derive Starting/Running/Needs attention/Stopping -> update actions

3. End -> set StopRequested -> Stop-Service -> interrupt exact managed GUI -> close managed Edge -> verify process/health/ports/ownership gone. A failed check shows an error; the current timer can still close the tray on its next tick if its health/backend/process Running predicate is false, even when a port or ownership record remains.

### State ownership

#### Item 1

##### State

ShutdownInProgress

##### Owner

Stop-Service

##### Meaning

Reentrancy guard for an actively executing shutdown; reset in finally.

#### Item 2

##### State

StopRequested

##### Owner

End click handler and monitor

##### Meaning

Latched intent used by exit policy and currently passed as if shutdown were still in progress; not reset on failure.

#### Item 3

##### State

SeenRunning

##### Owner

Timer

##### Meaning

Tracks whether monitor has observed a live GUI/backend before deciding to exit.

#### Item 4

##### State

StartupDeadline

##### Owner

Tray initialization

##### Meaning

Seven-minute boundary for a never-started monitor.

### Public commands

#### Item 1

##### Purpose

Launch

##### Command

```
cmd.exe /d /c ".\Start ZipVoice GUI.cmd"
```

#### Item 2

##### Purpose

Tray self-check

##### Command

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Voice Tray.ps1" -SelfCheck
```

#### Item 3

##### Purpose

Managed stop

##### Command

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Voice Tray.ps1" -StopOnly
```

## Deployment ownership

### Known

1. Launcher source pins the WSL distribution name Ubuntu-24.04 and historical path <HOME>/tts/ZipVoice.

2. Launcher calls zipvoice_bootstrap.py to prepare/exec/adopt runtime and expects a GUI health service at port 8020.

3. The actual WSL runtime source/check-out was not supplied in this repository. Its compatibility and ownership contract remain unverified.

4. Use the launcher documentation and readiness checks to identify the actual runtime checkout before integration testing; no compatibility with another implementation is established.

### Unverified

1. Live WSL checkout, remote, commit, local changes and presence/version of bootstrap/GUI

2. Actual container/image and runtime ownership record contents/validation behavior

3. Current model/engine builds, Docker Desktop/WSL integration and installed Windows Edge/PowerShell behavior

### Next read only inventory

#### Item 1

##### Command

```
wsl.exe -d Ubuntu-24.04 -- git -C <HOME>/tts/ZipVoice branch --show-current
```

##### Status

NOT RUN

#### Item 2

##### Command

```
wsl.exe -d Ubuntu-24.04 -- git -C <HOME>/tts/ZipVoice rev-parse HEAD
```

##### Status

NOT RUN

#### Item 3

##### Command

```
wsl.exe -d Ubuntu-24.04 -- git -C <HOME>/tts/ZipVoice status --short
```

##### Status

NOT RUN

#### Item 4

##### Command

```
wsl.exe -d Ubuntu-24.04 -- test -f <HOME>/tts/ZipVoice/zipvoice_bootstrap.py
```

##### Status

NOT RUN

#### Item 5

##### Command

```
wsl.exe -d Ubuntu-24.04 -- test -f <HOME>/tts/ZipVoice/zipvoice_gui.py
```

##### Status

NOT RUN

#### Item 6

##### Command

```
curl.exe --connect-timeout 1 --max-time 1 -fsS http://127.0.0.1:8020/health
```

##### Status

NOT RUN; liveness response alone does not establish application identity/ownership

### Instructions

Read inventory before relating proposed launcher fixes to a deployed backend. Preserve unrelated processes, containers, models, voices, databases and generated audio. Historical cleanup manifests do not authorize new deletion or cleanup.

### WSL application test prerequisites

The launcher and README record a WSL checkout location and Python interpreter, but the application checkout is not included here. Treat those recorded values as candidates only. Before running its tests on the actual WSL host, confirm the checkout root and sanitized remote/project identity, branch, commit and worktree status; confirm the expected bootstrap and GUI files; and confirm the interpreter exists, is executable and belongs to the deployment's active environment. Do not claim a deployment was identified until those checks have been read on that host. Keep local checkout paths and any credential-bearing remote URL out of shared logs.

Then inspect the checkout for its real `unittest` suite and import layout. Set `ZIPVOICE_REPO`, `ZIPVOICE_PYTHON`, `ZIPVOICE_TEST_START` and `ZIPVOICE_TEST_TOP` from that inspection. The two test directories must be absolute paths inside the verified checkout; `ZIPVOICE_TEST_START` must contain the discovered test modules, and `ZIPVOICE_TEST_TOP` must be their import root. Do not assume the shell starts in the application checkout, or guess `.` / `tests/` when the layout is unknown.

Run this template inside the verified WSL distribution after setting those four values. It changes to the verified checkout, passes explicit discovery paths to `unittest`, and exits with an error when discovery finds zero test cases:

```bash
set -euo pipefail
: "${ZIPVOICE_REPO:?Set this to the verified application checkout}"
: "${ZIPVOICE_PYTHON:?Set this to the verified runtime interpreter}"
: "${ZIPVOICE_TEST_START:?Set this from the inspected test layout}"
: "${ZIPVOICE_TEST_TOP:?Set this from the inspected import layout}"
test -x "$ZIPVOICE_PYTHON"
test -d "$ZIPVOICE_TEST_START"
test -d "$ZIPVOICE_TEST_TOP"
test "$(realpath "$ZIPVOICE_REPO")" = "$(git -C "$ZIPVOICE_REPO" rev-parse --show-toplevel)"
git -C "$ZIPVOICE_REPO" remote get-url origin
git -C "$ZIPVOICE_REPO" branch --show-current
git -C "$ZIPVOICE_REPO" rev-parse HEAD
git -C "$ZIPVOICE_REPO" status --short
test -f "$ZIPVOICE_REPO/zipvoice_bootstrap.py"
test -f "$ZIPVOICE_REPO/zipvoice_gui.py"
cd "$ZIPVOICE_REPO"
"$ZIPVOICE_PYTHON" -B - "$ZIPVOICE_REPO" "$ZIPVOICE_TEST_START" "$ZIPVOICE_TEST_TOP" <<'PY'
from pathlib import Path
import sys
import unittest

repo, start, top = (Path(value) for value in sys.argv[1:])
if not all(path.is_absolute() for path in (repo, start, top)):
    raise SystemExit("ERROR: checkout and unittest discovery directories must be absolute")
repo, start, top = (path.resolve() for path in (repo, start, top))

def is_within(parent, child):
    try:
        child.relative_to(parent)
        return True
    except ValueError:
        return False

if not all(path.is_dir() for path in (repo, start, top)):
    raise SystemExit("ERROR: checkout or explicit unittest discovery directory is missing")
if not is_within(repo, start) or not is_within(repo, top) or not is_within(top, start):
    raise SystemExit("ERROR: unittest discovery directories must be inside the checkout, with TEST_TOP above TEST_START")

suite = unittest.defaultTestLoader.discover(
    start_dir=str(start), top_level_dir=str(top)
)

def count_cases(items):
    return sum(count_cases(item) if isinstance(item, unittest.TestSuite) else 1 for item in items)

count = count_cases(suite)
if count == 0:
    raise SystemExit("ERROR: unittest discovery collected zero test cases")
print(f"Collected {count} test cases")
result = unittest.TextTestRunner(verbosity=2).run(suite)
raise SystemExit(0 if result.wasSuccessful() else 1)
PY
```

The bare `python -m unittest discover` command in the README is historical evidence only. An absolute interpreter path does not set the working directory or discovery roots, and default discovery can report success after collecting zero tests. This template remains unrun until the actual checkout, interpreter and suite layout are verified.

## Mitigations

### Item 1

#### Finding

ZVT-1

#### Proposal

If the tray's End action remains disabled after a visible shutdown error, use the documented -StopOnly command only against the verified owned runtime to retry the normal managed shutdown path; inspect its error if it fails. This is an operational option, not an action taken in this review.

#### Status

PROPOSED; NOT RUN

### Item 2

#### Finding

ZVT-1

#### Proposal

Preserve the existing exact process match and ownership checks. Do not work around the UI bug by adding broad pkill patterns or unverified named-container stop/remove calls.

#### Status

PROPOSED

### Item 3

#### Gap

Unavailable WSL application

#### Proposal

Obtain the actual runtime checkout inventory and source before further runtime diagnosis; do not substitute an unrelated implementation without confirming compatibility.

#### Status

PROPOSED

## Prioritized sequence

### Item 1

#### Order

1

#### Work

Identify the actual Windows/WSL deployment and ownership contracts.

#### Dependencies

None recorded.

#### Reason

Runtime GUI/bootstrap source is outside the reviewed trees; avoid patching or testing a presumed backend.

#### Completion

Record launcher SHA plus WSL branch/SHA/status and confirm exact bootstrap/GUI paths.

### Item 2

#### Order

2

#### Work

Add a dependency-light failure-state regression seam in the tray self-check/tests.

#### Dependencies

None recorded.

#### Reason

Current built-in -SelfCheck covers pure state helpers but does not exercise a failed End handler followed by a timer tick.

#### Completion

Mock shutdown failure and running-state observation without stopping actual services; reproduce Stopping/disabled End after the catch.

### Item 3

#### Order

3

#### Work

Implement ZVT-1 by separating failed stop intent from an actively running shutdown.

#### Dependencies

1. Regression seam

#### Reason

The latched StopRequested flag currently suppresses future retry despite ShutdownInProgress being false.

#### Completion

Failed stop shows Needs attention and keeps End enabled through later ticks; successful stop and reentrancy behavior remain correct.

### Item 4

#### Order

4

#### Work

Run Windows self-check and isolated live WSL lifecycle checks.

#### Dependencies

1. Narrow source change

2. Verified test deployment

#### Reason

Source state tracing cannot prove PowerShell/WinForms event behavior or real shutdown/ownership reconciliation.

#### Completion

Record native results and final source SHA; keep any unavailable check explicitly NOT RUN.

## Findings and implementation handoff

### ZVT-1 Medium: Failed shutdown leaves the tray stuck in Stopping with retry disabled

**Status:** OPEN. [Pinned source](https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Voice%20Tray.ps1#L266).

#### Evidence classification

Strongly supported by source state transition; not reproduced on Windows

#### Observed mechanism

The End handler sets script:StopRequested=true. On Stop-Service timeout/error it displays Needs attention but never clears that flag. If the health/backend/process Running predicate remains true, the next 2-second timer tick passes StopRequested=true to Get-TrayState, which returns Stopping; Set-TrayState disables End. If those Running checks are false, Should-ExitMonitor can close the tray because StopRequested is true, even when Stop-Service failed only because an expected port or the ownership record remains. The monitor does not currently use those residual checks in its exit decision.

#### Impact and scope

After a failed shutdown, the tray either returns to Stopping and disables End while the application still appears to run, or closes while residual ports or the ownership record remain. In both cases the normal retry path is lost even though the shutdown checks did not all pass.

#### Repair direction

Track an unresolved shutdown failure separately from StopRequested and ShutdownInProgress. Keep the tray in Needs attention and End enabled when no stop call is active. Do not close the monitor after a failed check until a retry verifies that the exact GUI process, health/readiness endpoints, expected ports and ownership record are all gone.

#### Verification already obtained

Static trace of End catch -> timer tick -> Get-TrayState -> Set-TrayState; Windows PowerShell/WinForms and WSL were unavailable, so no live reproduction or built-in -SelfCheck executed.

#### Repair status

PROPOSED

#### Source refs

##### Item 1

###### File

Voice Tray.ps1

###### Line

266

###### Sha

96d641298cfce10ad9af44c4f900c608626868a9

###### Url

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Voice%20Tray.ps1#L266>

###### Local snapshot

/workspace/repos/ZipVoice-Distill-TensorRT/Voice Tray.ps1

##### Item 2

###### File

Voice Tray.ps1

###### Line

288

###### Sha

96d641298cfce10ad9af44c4f900c608626868a9

###### Url

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Voice%20Tray.ps1#L288>

###### Local snapshot

/workspace/repos/ZipVoice-Distill-TensorRT/Voice Tray.ps1

##### Item 3

###### File

Voice Tray.ps1

###### Line

166

###### Sha

96d641298cfce10ad9af44c4f900c608626868a9

###### Url

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Voice%20Tray.ps1#L166>

###### Local snapshot

/workspace/repos/ZipVoice-Distill-TensorRT/Voice Tray.ps1

##### Item 4

###### File

Voice Tray.ps1

###### Line

229

###### Sha

96d641298cfce10ad9af44c4f900c608626868a9

###### Url

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Voice%20Tray.ps1#L229>

###### Local snapshot

/workspace/repos/ZipVoice-Distill-TensorRT/Voice Tray.ps1

##### Item 5

###### File

Voice Tray.ps1

###### Line

155

###### Sha

96d641298cfce10ad9af44c4f900c608626868a9

###### Url

<https://github.com/wwongw21/ZipVoice-Distill-TensorRT/blob/96d641298cfce10ad9af44c4f900c608626868a9/Voice%20Tray.ps1#L155>

###### Local snapshot

/workspace/repos/ZipVoice-Distill-TensorRT/Voice Tray.ps1

#### Trigger

End is clicked and Stop-Service throws or reaches its failure deadline. Cover both a still-running application on the next timer tick and the residual-only case where the GUI/process and health/backend checks are gone but an expected port or ownership record remains.

#### Detailed handoff evidence

End sets script:StopRequested=true. The catch sets Needs attention without resetting that flag. When the health/backend/process checks still indicate Running, the timer passes StopRequested to Get-TrayState, which returns Stopping and disables End. In the residual-only case, those checks say not running, so Should-ExitMonitor returns true because StopRequested is latched and closes the tray. Stop-Service's port and ownership checks can still have failed; the monitor exit path does not consult them.

#### Source derived transition

##### Item 1

###### Step

Before click

###### Stoprequested

false

###### Shutdowninprogress

false

###### State

Running or Needs attention

###### End enabled

true

##### Item 2

###### Step

End handler begins

###### Stoprequested

true

###### Shutdowninprogress

true while Stop-Service executes

###### State

Stopping

###### End enabled

false

##### Item 3

###### Step

Stop-Service fails; finally/catch finish

###### Stoprequested

true

###### Shutdowninprogress

false

###### State

Needs attention

###### End enabled

true

##### Item 4

###### Step

Next timer tick sees running service

###### Stoprequested

true

###### Shutdowninprogress

false

###### State

Stopping

###### End enabled

false

##### Item 5

###### Step

Failed stop leaves only an expected port open or the ownership record present; health, readiness, backend readiness and exact GUI process checks are false

###### Stoprequested

true

###### Shutdowninprogress

false

###### Current monitor result

Closed on the next timer tick because Running is false and StopRequested is true

###### Required result

Needs attention remains visible; End stays enabled; shutdown is not reported complete

#### Detailed handoff impact

After a failed stop, the error can be replaced by Stopping with End disabled, or the monitor can close if only residual resources remain. Both outcomes hide an unresolved failure and block the normal retry action.

#### Change surface

1. Voice Tray.ps1: End click handler, persistent error/intent state, timer Get-TrayState input and Set-TrayState action policy

2. Voice Tray.ps1 -SelfCheck or a separate Windows test harness for failure->tick->retry; keep tests local and mocked

#### Repair steps

1. Define separate meanings for requested stop, active shutdown, and failed shutdown. Avoid using a permanently latched intent as the active-operation indicator.

2. On failed Stop-Service, reset the active/requested state as needed for retry and retain an error/Needs attention condition until acknowledged/retried or resolved.

3. Make the next timer tick preserve an actionable failure state while the runtime still runs; allow another End action once ShutdownInProgress is false.

4. Keep an unresolved shutdown-failure state separate from StopRequested and ShutdownInProgress. While failure remains unresolved, do not close the monitor just because health/backend/process checks are false; residual ports or ownership records still mean shutdown verification failed.

5. Close the monitor after a retry only when the existing full shutdown checks pass: exact GUI process gone, health/readiness endpoints gone, expected ports closed and ownership record gone. Preserve the existing never-started monitor timeout.

6. Extend state tests to invoke a fake failing shutdown and then the same timer decision path; test both a running service and residual-only failures (port-only and ownership-record-only), then test a successful retry.

7. Validate the narrow change on Windows PowerShell/WinForms, then on an isolated verified owned WSL deployment.

#### Invariants

1. End is disabled only while an actual shutdown is in progress, not indefinitely after an error.

2. A failed stop remains visible/actionable through subsequent timer ticks, including when only expected ports or the ownership record remain.

3. Two concurrent stop operations are not started.

4. A failed stop does not close the monitor while any expected shutdown check remains. A successful shutdown verifies process, health/readiness, ports and ownership lease removal before reporting completion and closing the monitor.

5. Tray controls stop only the managed GUI/application path; do not introduce broad process termination or named-container stops.

6. Closing/reopening the dedicated Edge app does not target unrelated browser profiles.

#### Proposed acceptance (NOT RUN)

1. Mock Stop-Service failure with health/background still running: immediately after catch and after at least two timer ticks, the tray remains visible in Needs attention and End remains enabled.

2. Mock a residual-port-only failure: health, readiness, backend readiness and exact GUI process are false; one expected port (test each expected port in turn) remains open and all other shutdown checks pass. Immediately after the catch and after at least two timer ticks, the tray remains visible in Needs attention, End stays enabled and shutdown is not reported complete.

3. Mock an ownership-record-only failure: health, readiness, backend readiness and exact GUI process are false; all expected ports are closed but the ownership record remains. Immediately after the catch and after at least two timer ticks, the tray remains visible in Needs attention, End stays enabled and shutdown is not reported complete.

4. A second End click invokes Stop-Service again. If all process, endpoint, port and ownership checks pass, the monitor exits; if any residual check still fails, it stays visible and reports the remaining check.

5. While fake Stop-Service is in progress, End remains disabled and duplicate invocation is rejected.

6. The existing never-started startup timeout, health-but-unready state and successful-stop exit behavior still pass.

7. An error balloon/message explains the failure without being contradicted by a permanently spinning Stopping label or a monitor that closes with residual resources.

#### Regression scenarios

1. Shutdown timeout while GUI health stays 200

2. Native WSL command failure before interrupt is delivered

3. GUI process, health, readiness and backend checks gone while one expected port remains open; monitor stays visible and retry remains available

4. GUI process, health, readiness, backend and port checks gone while ownership record remains; monitor stays visible and retry remains available

5. Successful first shutdown

6. Failure followed by a successful retry

7. Failure followed by spontaneous runtime exit

8. User double-clicks End / overlapping UI events

9. Existing startup, ready/unready and monitor exit cases in -SelfCheck

#### Risks

1. StopRequested also participates in Should-ExitMonitor, so changing its lifecycle can affect monitor exit timing; track failure state separately and test both exit paths.

2. A simplistic state reset can replace Needs attention with Running on the next poll despite unresolved shutdown verification; preserve error visibility intentionally.

3. Live stop/retry tests act on a real runtime; use a verified disposable owned instance and avoid unrelated containers or user data.

#### Rollback

Revert only the tray state correction if native lifecycle behavior regresses. Retain normal -StopOnly as the documented managed control where ownership is verified; preserve all user/deployment data.

#### Reproduction

##### Status

SOURCE TRACE ONLY — LIVE REPRODUCTION NOT RUN

##### Prerequisites for source review

1. Pinned Voice Tray.ps1 at 96d641298cfce10ad9af44c4f900c608626868a9

##### Recorded read command

```
nl -ba '/workspace/repos/ZipVoice-Distill-TensorRT/Voice Tray.ps1' | sed -n '155,175p;260,300p'
```

##### Recorded result

The catch leaves StopRequested true; the next running tick calls Get-TrayState with true, obtaining Stopping and disabling End via Set-TrayState.

##### Native reproduction procedure

1. On Windows, run the tray in a local test harness whose shutdown call is mocked to throw and whose health/background predicate remains true.

2. Invoke End and advance the timer handler at least once.

3. Observe the original code's Needs attention -> Stopping transition and disabled End while running checks stay true. In separate mocked cases, make only a port remain and only the ownership record remain after health/readiness/backend/process checks turn false; the original timer closes the tray. No actual WSL processes or containers should be stopped by these fixtures.

##### Proposed native command

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Voice Tray.ps1" -SelfCheck
```

##### Native command caveat

```
Current -SelfCheck does not contain the End-failure/timer fixture; extend it or run an explicit test harness before claiming this regression is tested.
```

##### Live runtime steps

Only after source/state tests pass and deployment identity is established, validate a controlled failed shutdown and successful retry on an isolated owned WSL instance.

##### Limits

Neither powershell.exe/pwsh nor WinForms, cmd.exe, Docker Desktop or the user's WSL runtime were available here.

## Verification

### Recorded

#### Item 1

##### Name

Source inventory

##### Status

RAN BEFORE HANDOFF

##### Result

Reviewed the complete two executable tracked files, Start ZipVoice GUI.cmd and Voice Tray.ps1, at the pinned main commit.

#### Item 2

##### Name

Repository status

##### Command

```
git -C /workspace/repos/ZipVoice-Distill-TensorRT status --short
```

##### Status

RAN BEFORE HANDOFF

##### Result

Empty output; no tracked project edits.

#### Item 3

##### Name

Readme/runtime relationship

##### Status

RAN BEFORE HANDOFF

##### Result

README identifies this repository as a launcher package. The runtime source named by the launcher is not included here; integration compatibility remains unverified.

### Native checks not run

#### Item 1

##### Name

Built-in tray self-check

##### Environment

Windows PowerShell with cmd.exe and Windows Forms available

##### Command

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Voice Tray.ps1" -SelfCheck
```

##### Status

NOT RUN

##### Expected after repair

Existing helper/native-stderr guards plus added shutdown-failure/retry state test pass.

#### Item 2

##### Name

Windows launch smoke

##### Environment

Actual Windows host with verified Ubuntu-24.04 checkout, Docker Desktop integration, Edge and models/runtime prerequisites

##### Command

```
cmd.exe /d /c ".\Start ZipVoice GUI.cmd"
```

##### Status

NOT RUN

##### Expected after repair

One managed GUI process and one tray; health and readiness correctly represented; reuse path does not duplicate instances.

#### Item 3

##### Name

GUI liveness/readiness probes

##### Environment

Actual verified test host

##### Commands

1. ```
   curl.exe --connect-timeout 1 --max-time 1 -fsS http://127.0.0.1:8020/health
   ```

2. ```
   curl.exe --connect-timeout 1 --max-time 1 -fsS http://127.0.0.1:8020/ready
   ```

##### Status

NOT RUN

##### Expected after repair

Statuses match tray state; liveness alone is not treated as readiness/ownership proof.

#### Item 4

##### Name

Managed stop smoke

##### Environment

Verified disposable owned WSL runtime, with work saved and no unrelated services targeted

##### Command

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Voice Tray.ps1" -StopOnly
```

##### Status

NOT RUN

##### Expected after repair

Normal shutdown confirms exact GUI gone, expected endpoints/ports closed and ownership record gone; failure reports remaining checks clearly.

#### Item 5

##### Name

Controlled failed End -> timer ticks -> retry

##### Environment

Windows Forms test harness first; isolated WSL deployment second

##### Command

```
No ready-made command currently exists for the mocked End-failure fixture; implementation must add and document it before execution.
```

##### Status

NOT RUN

##### Expected after repair

Needs attention persists with End enabled after failure; second attempt runs; no broad pkill/container-stop workaround.

#### Item 6

##### Name

WSL application test suite

##### Environment

Only after inspecting the current checkout and its tests

##### Command

```
Use the WSL application test template under "WSL application test prerequisites". Fill ZIPVOICE_REPO, ZIPVOICE_PYTHON, ZIPVOICE_TEST_START and ZIPVOICE_TEST_TOP only after inspecting the actual deployment; the template passes explicit start_dir/top_level_dir values and fails if it collects zero cases.
```

##### Status

NOT RUN

##### Caveat

This is a proposed test command, NOT RUN. The application checkout, interpreter and suite layout have not been verified here. The README's bare discovery command is insufficient by itself: its absolute interpreter path does not choose a checkout working directory or explicit discovery roots, and zero collected tests can still return success. Use the inspection-gated template above with explicit paths. Do not record a suite pass until the verified checkout collects at least one test case and all collected tests pass.

### Completion boundary

Finding remains OPEN. This handoff does not claim a native reproduction, implemented fix, tested deployment or release approval.

## Limitations

1. Linux workspace cannot validate Windows PowerShell/WinForms event scheduling, process matching, Edge activation or WSL/Docker Desktop integration.

2. Actual runtime GUI/bootstrap/ownership implementation was not supplied in this repository; lifecycle compatibility remains unverified.

3. Historical cleanup records were reviewed as records only; no cleanup or deletion was attempted.

4. The source-supported failure-state finding is narrower than a complete release qualification; all native checks remain NOT RUN.

## Delivery and diagnostic files

### Destination repository

wwongw21/ZipVoice-Distill-TensorRT

### Status

All findings remain OPEN; documentation transfer only.

### Portable evidence

This JSON retains the complete repository-specific handoff. Historical /workspace paths are evidence references and prerequisites, not portable hyperlinks. Applicable repository-specific diagnostics are included alongside the report.

### Diagnostics included

None recorded.

### Not included

Original environments, model weights, user data and complete source snapshots are not included. Clone the pinned source and follow the recorded prerequisites. Bug-demonstration scripts intentionally assert pre-fix behavior; they are not a post-fix passing suite.

### Public scope

Only public launcher-repository evidence is included. Separate runtime source details and cross-repository diagnostics are excluded.


## Remaining review limits

1. Linux environment cannot execute cmd, Windows PowerShell, WinForms, Docker Desktop or user's Ubuntu-24.04 WSL deployment

2. Repository intentionally contains launcher/evidence files only; actual WSL application checkout and its ownership/health contracts are not available

3. Historical cleanup reports were treated as records, not evidence of current deployment behavior or permission to delete anything
