# Separate ZipVoice Native entrypoint

This package provides a separate experimental native path for the qualified copied runtime. It uses its own Windows commands, private profile and saved engine. The existing Docker launcher and original data keep their separate versions.

Keep these launcher files, control helper, example configuration and assets together in this Windows package.

- Start ZipVoice Native.cmd starts or reuses the native profile, verifies the exact managed process and public Linux/Windows readiness, then opens Edge with a dedicated profile.
- Stop ZipVoice Native.cmd cancels startup or stops that profile through its recorded PID, boot ID, start token, exact AppRoot command and executable. It does not stop Docker or unrelated processes.
- Native Status.cmd reports the profile status.
- New ZipVoice Native Shortcut.ps1 optionally creates the separately named native shortcut. It refuses to replace a shortcut targeting another program.
- Start ZipVoice Native.ps1 -NoBrowser runs the same lifecycle without opening Edge for operator checks.

The first start copies NativeConfig.example.json to the private %LOCALAPPDATA%\ZipVoiceNative\config.json if it does not exist. Review those fields for the intended WSL distribution and copied runtime. The default AppRoot is the persistent, separately copied qualification runtime under ~/.local/state/zipvoice/finalization-validation-20261028/app. Keep that runtime; the launcher does not claim the original profiles or original Docker checkout are native-ready.

The selected copied AppRoot must contain the current isolated ZIPVOICE_JOB_ROOT contract and normal source runtime/plan checks. The profile uses port 8026, separate state, scratch, job-state and output folders. StateRoot is kept short for Unix socket limits. Completed-job pruning defaults to off. Models and voice profiles remain in the copied AppRoot, separate from the original data.

The helper validates the existing GUI host environment against the selected AppRoot's host lock, copies it into the new profile's fingerprinted host cache when needed, validates the copy, then runs the public bootstrap prepare command. The public bootstrap activates current atomically. It does not change the original host environment or use the WSL network for a valid copied cache. Actual service launch also goes through the public bootstrap exec command.

Default time budgets are explicit: engine build 7200 seconds, profile validation 120 seconds, smoke validation 300 seconds, and startup margin 180 seconds, giving a 7800-second Windows startup budget. Startup requires at least build plus 480 seconds. Progress remains starting until the actual public health, admission, source/backend identity and owned listening socket pass. Use the explicit Stop command to cancel a cold build. Closing the launcher console alone is not a stop command.

Stop waits for the GUI, observed owned children, native sockets and actual Linux listening port to close. It does not interpret a WSL VirtioProxy optimistic TCP connection as a live backend or kill an unrelated process. Uncertain identity or outstanding resources produce an error and preserve the ownership record for inspection. Close the dedicated Edge window after stopping; closing Edge alone leaves the backend available.

NativeRuntime.dependencies.txt records the 92-package validation environment, including Torch 2.8/cu128, NumPy 1.26.4, TensorRT 10.7 and Vocos 0.1. The original Docker Torch 2.5.1 pins remain unchanged. Optional k2 is absent, so Swoosh uses its documented Torch fallback. The full verified wheelhouse is retained separately for offline recovery. No faster-performance or new-release claim is made.

Controller tests use real owned CPU child processes and temporary HTTP endpoints. They check lifecycle ownership, signal/timeouts, source identity, stale or mismatched records and argument boundaries. NativeRuntime.PROVENANCE.json records the separate real runtime qualification and Windows entrypoint checks.
