# GUI Quality Guidelines

> GUI quality means preserving existing desktop workflows while keeping heavy GNSS logic in the core library.

---

## Overview

RTKLIB GUI apps are mature VCL and Qt desktop tools. Optimization tasks should avoid broad UI rewrites. Prefer targeted changes that preserve:

* existing dialogs, menu flows, and saved settings
* parity between command-line and GUI behavior where both expose the same RTKLIB option
* build compatibility with Qt project files and C++ Builder project files
* separation between UI orchestration and core processing

---

## Forbidden Patterns

Do not move GNSS algorithms into GUI classes. Core behavior belongs in `src/`.

Do not rename UI controls, slots, event handlers, `.ini` keys, or resources unless the task explicitly includes the migration.

Do not hand-edit generated `.ui` or `.dfm` files for behavior-only changes.

Do not add blocking network, stream, or file processing directly in button handlers when an app already uses worker threads, timers, or RTKLIB stream abstractions.

---

## Required Patterns

For Qt dialogs, update signal-slot connections when adding controls and keep related handler declarations in the matching header.

For VCL dialogs, keep `__fastcall` event signatures consistent with the `.dfm` wiring.

When adding or modifying options, update the full flow: UI control, load/save settings, enable/disable refresh, conversion to RTKLIB option structs, and any command-line parity if applicable.

Use `traceopen()` and `tracelevel()` consistently when GUI trace settings are involved. `app/qtapp/rtkget_qt/getmain.cpp` opens trace output when `TraceLevel>0`.

---

## Testing Requirements

Build the touched GUI target in its native environment when available:

* Qt apps through their `.pro` files under `app/qtapp/`
* Windows VCL apps through their `.cbproj` files under `app/winapp/`

For Qt app targets that link the RTKLIB static library, first build `app/qtapp/RTKLib.pro`, then build the app-local `.pro`. On Windows Qt 5.15.2 + MinGW 8.1.0, the expected sequence is:

```powershell
& 'D:\QT\5.15.2\mingw81_64\bin\qmake.exe' 'RTKLib.pro'
& 'D:\QT\Tools\mingw810_64\bin\mingw32-make.exe'
& 'D:\QT\5.15.2\mingw81_64\bin\qmake.exe' 'rtkpost_qt.pro'
& 'D:\QT\Tools\mingw810_64\bin\mingw32-make.exe'
```

Run the first two commands from `app/qtapp/`, and run the app-local commands from the target directory such as `app/qtapp/rtkpost_qt/`. If qmake generates top-level `app/qtapp` build artifacts, keep them ignored rather than committing generated Makefiles, object scripts, `.qmake.stash`, or static library outputs.

If the local environment cannot build GUI targets, perform a source-level check: verify headers match implementations, signal-slot names match declarations, `.ini` keys are unchanged or migrated, and core library calls still receive valid option structs.

For shared core changes that affect GUI behavior, also run the relevant command-line or unit tests from `app/consapp/` or `test/utest/`.

---

## Code Review Checklist

Before accepting GUI changes, check:

* Are long-running operations kept off the UI thread where existing code already does so
* Are saved settings loaded and saved with stable keys
* Are Qt signals and slots or VCL event handlers wired exactly once
* Are UI changes backed by core tests when they touch GNSS processing
* Are GUI framework types kept out of `src/*.c`
