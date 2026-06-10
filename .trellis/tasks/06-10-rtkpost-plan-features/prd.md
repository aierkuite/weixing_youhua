# rtkpost frontend plan feature surface

## Goal

Update the RTKPOST Windows VCL frontend so the remaining `plan.md` functionality is visible and usable from the GUI. The task is frontend integration: expose the already implemented diagnostic CSV feature in RTKPOST, keep it aligned with the existing `rnx2rtkp --diag` behavior, and avoid changing the core diagnostic algorithm unless a tiny API/build plumbing fix is required.

## What I Already Know

* `plan.md` defines explainable observation quality scoring, adaptive robust diagnostics, slip-risk classification, and two CSV outputs: `epoch_diag.csv` and `sat_diag.csv`.
* The RTKLIB 2.4.3 b34 core already contains diagnostic output functions in `src/rtkpos.c`: `rtkopendiag()` and `rtkclosediag()`.
* `app/consapp/rnx2rtkp/rnx2rtkp.c` already exposes the feature with `--diag dir`.
* `app/winapp/rtkpost/` currently has no diagnostic UI surface found by searching for `diag`, `epoch_diag`, or `sat_diag`.
* User clarified this task is specifically to update the frontend and complete the remaining `plan.md` exposure work.

## Requirements

* Add RTKPOST WinApp frontend controls for enabling observation quality diagnostics.
* Let the user choose or edit the diagnostic output directory from the RTKPOST UI.
* When diagnostics are enabled, open diagnostic output before the existing post-processing run and close it after processing completes.
* Preserve existing RTKPOST behavior when diagnostics are disabled.
* Persist the diagnostic UI state in the RTKPOST settings file with the rest of the form state.
* Keep the GUI as orchestration over RTKLIB core functions; do not duplicate scoring, slip classification, or CSV generation logic in the WinApp layer.
* Complete only the frontend-facing remainder of `plan.md`; algorithmic changes are not part of this task.

## Acceptance Criteria

* [ ] RTKPOST has a visible diagnostic output control surface in the Windows app.
* [ ] Enabling diagnostics from RTKPOST writes `epoch_diag.csv` and `sat_diag.csv` to the selected directory.
* [ ] Disabling diagnostics leaves current RTKPOST processing unchanged.
* [ ] Diagnostic output open failures are surfaced through the existing RTKPOST message flow and do not continue silently.
* [ ] Settings save/load round-trips the diagnostic enable flag and output directory.
* [ ] Existing `rnx2rtkp --diag` behavior remains unchanged.

## Definition Of Done

* Code changes are limited to the RTKPOST WinApp frontend plumbing unless a small core declaration/build fix is required.
* Relevant Trellis frontend/backend specs have been consulted before implementation.
* Static verification or build verification is run where feasible for this Windows VCL project.
* Dirty files not created by this task are not modified or committed.

## Out Of Scope

* Changing the diagnostic scoring algorithm in `src/rtkpos.c`.
* Adding new CSV columns beyond the current `plan.md` fields.
* Porting the UI change to Qt apps.
* Migrating demo5 algorithms or changing ambiguity resolution behavior.

## Technical Approach

Use the same core API as `rnx2rtkp`: call `rtkopendiag(<dir>)` before the existing `postpos()` call when the RTKPOST GUI option is enabled, and call `rtkclosediag()` after processing. Add persistent VCL form state for the enable flag and directory, with a directory browse action if existing helper patterns support it.

## Decision (ADR-lite)

**Context**: The diagnostic logic already lives in the core and is already exposed in the console app. RTKPOST needs a GUI surface, not a second implementation.

**Decision**: Add a small RTKPOST GUI orchestration layer that controls `rtkopendiag()`/`rtkclosediag()` and persists user choices.

**Consequences**: The WinApp stays aligned with the console app, but final validation depends on VCL project build availability in the local environment.

## Technical Notes

* Relevant source paths:
  * `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/src/rtkpos.c`
  * `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/src/rtklib.h`
  * `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/app/consapp/rnx2rtkp/rnx2rtkp.c`
  * `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/app/winapp/rtkpost/`
* Relevant specs:
  * `.trellis/spec/frontend/index.md`
  * `.trellis/spec/backend/index.md`
  * `.trellis/spec/guides/cross-layer-thinking-guide.md`
