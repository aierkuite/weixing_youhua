# Finish RTK Diagnostic CSV Cleanup

## Goal

Finish the remaining RTK diagnostic CSV cleanup so single-point positioning reports meaningful satellite participation in `sat_diag.csv`, CSV field semantics are documented by positioning mode, and the existing console/Qt diagnostic flows are rechecked without committing generated data.

## Requirements

* In single-point diagnostic output, write `sat_diag.csv` `vsat` from the field that `pntpos()` updates (`ssat->vs`) instead of leaving participating satellites indistinguishable from unused satellites.
* Preserve RTK/double-difference `vsat` behavior by continuing to use the frequency-indexed `ssat->vsat[j]` where that is the active semantic.
* Document which diagnostic CSV fields are meaningful in single-point mode versus RTK/carrier-phase tracking modes.
* Re-run console diagnostic CSV output on the available sample data and verify both CSVs are generated.
* Fix the Qt `showmsg()` callback return value so `postpos()` does not treat normal progress messages as an abort request before observations are read.
* Verify generated diagnostics have stable headers, bounded `quality_score`, valid `decision`, and non-empty single-point `vsat` participation where expected.
* Check that generated output, temporary build products, and external extracted directories are not included in the intended commit scope.

## Acceptance Criteria

* [x] Single-point `sat_diag.csv` no longer reports all `vsat` values as `0` for satellites participating in the solution.
* [x] RTK/double-difference `vsat[j]` behavior is not changed for carrier-phase modes.
* [x] Documentation explains that single-point mode mainly uses `stat`, `ns`, `gdop`, `snr`, `resp`, `quality_score`, `decision`, and `reason`.
* [x] Documentation explains that `ratio`, `resc`, `slip`, `lock`, `outc`, and `rejc` may be normal zero placeholders in single-point mode.
* [x] Console `rnx2rtkp --diag <dir>` can generate `epoch_diag.csv` and `sat_diag.csv` from the available fixture data.
* [x] Qt `rtkpost_qt` no longer leaves diagnostic CSV files with only headers due to inverted progress callback return semantics.
* [x] `git diff --check` passes.
* [x] Available build checks are run, or unavailable toolchains are explicitly reported.

## Definition of Done

* Tests or command-line verification are run where the local Windows environment supports them.
* Changed files are limited to the diagnostic CSV code/documentation and Trellis task record.
* Generated data and temporary build artifacts are left untracked or ignored.
* Commit plan is prepared separately from unrecognized dirty files.

## Technical Approach

Make the smallest core change in `src/rtkpos.c`: route the emitted `vsat` value through a local helper/branch that uses `ssat->vs` for single-point mode and keeps `ssat->vsat[j]` for RTK/double-difference semantics. Update the field contract documentation in Trellis backend specs so future users do not misread normal single-point zeros as failures.

## Decision (ADR-lite)

**Context**: `pntpos()` updates `ssat->vs`, while the current satellite diagnostic CSV writer emits `ssat->vsat[j]`. In single-point mode this produces misleading `vsat=0` rows even when the observation contributed to the solution.

**Decision**: Treat single-point diagnostic `vsat` as satellite-level participation (`ssat->vs`) and retain frequency-level `vsat[j]` for RTK/double-difference modes.

**Consequences**: The CSV column keeps the same name and header, preserving file compatibility. Consumers must interpret the field according to positioning mode, so the mode-specific field semantics are documented.

## Out of Scope

* Changing the diagnostic scoring formula.
* Changing CSV header order or adding new CSV columns.
* Reworking Qt UI behavior beyond verifying existing diagnostic output wiring.
* Committing generated RINEX fixtures, diagnostic outputs, external extracted directories, or build products.

## Technical Notes

* Continuation checklist: `plan_continue.md`.
* Prior archived task: `.trellis/tasks/archive/2026-06/06-10-rtkpost-qt-diag-csv/`.
* Core diagnostic implementation: `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/src/rtkpos.c`.
* Diagnostic API declaration: `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/src/rtklib.h`.
* Console entry point: `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/app/consapp/rnx2rtkp/rnx2rtkp.c`.
* Relevant spec files: `.trellis/spec/backend/index.md`, `.trellis/spec/backend/database-guidelines.md`, `.trellis/spec/backend/quality-guidelines.md`, `.trellis/spec/backend/error-handling.md`.

## Verification Notes

* Console build: `mingw32-make CC=gcc "CFLAGS=... -DWIN32 ..." "LDLIBS=-lws2_32 -lwinmm" rnx2rtkp` passed. The default Unix-oriented makefile failed first because `cc` was not present and MinGW needed `WIN32`.
* Console diagnostic run: `rnx2rtkp.exe --diag diag_verify -p 0 -o diag_verify\single.pos ...\07590920.05o ...\30400920.05n` produced `epoch_diag.csv` and `sat_diag.csv`.
* CSV parse check: 120 epoch rows, 725 satellite rows, `vsat=1` for all single-point satellite rows, `quality_score` in 0..100, and all `decision` values in the allowed set.
* No-diagnostic run: `rnx2rtkp.exe -p 0 -o diag_verify_off\single.pos ...` produced the `.pos` file and did not create `epoch_diag.csv` or `sat_diag.csv`.
* Qt build: `qmake RTKLib.pro -spec win32-g++ "CONFIG+=release"` plus `mingw32-make release` passed; `rtkpost_qt` qmake plus release build also passed. Existing warnings remained around unused RTKLIB parameters, initializer warnings, and deprecated Qt `QProcess::startDetached`.
* Whitespace check: `git diff --check` passed.
* Qt regression root cause: `postpos.c` treats non-zero `showmsg()` return values as abort requests via `checkbrk()`. The Qt `rtkpost_qt` implementation returned `!AbortFlag`, so normal processing returned `1` and stopped in `readobsnav()` before any diagnostic rows were written. `showmsg()` now returns `AbortFlag`, execution resets `AbortFlag` before starting a new worker run, matching the VCL and console semantics, and `ProcessingFinished()` clears stale `reading...` or `processing...` status based on the final return value.
