# GUI Directory Structure

> In this RTKLIB workspace, `frontend` means the desktop GUI applications under `app/winapp/` and `app/qtapp/`. There is no web frontend.

---

## Overview

RTKLIB has two GUI families:

* Windows VCL applications in `app/winapp/`, built with C++ Builder project files
* Qt applications in `app/qtapp/`, built with `.pro`, `.pri`, `.ui`, and `.qrc` files

GUI code should remain a presentation and orchestration layer over the core C library. Shared GNSS processing belongs in `src/`, not in form classes.

---

## Directory Layout

```text
app/
├── winapp/
│   ├── appcmn/            # shared VCL dialogs and helpers
│   ├── rtkpost/
│   ├── rtknavi/
│   ├── rtkplot/
│   ├── rtkconv/
│   ├── rtkget/
│   ├── strsvr/
│   └── rtklaunch/
└── qtapp/
    ├── appcmn_qt/         # shared Qt dialogs, viewers, graph helpers
    ├── rtkpost_qt/
    ├── rtknavi_qt/
    ├── rtkplot_qt/
    ├── rtkconv_qt/
    ├── rtkget_qt/
    ├── strsvr_qt/
    ├── srctblbrows_qt/
    ├── RTKLib.pri
    └── RTKLib.pro
```

---

## Module Organization

Keep shared GUI functionality in `app/winapp/appcmn/` or `app/qtapp/appcmn_qt/`. App-specific windows and dialogs stay inside their app folder.

For Qt, form layout belongs in `.ui` files, resources in `.qrc` files, declarations in `.h`, and behavior in `.cpp`. For VCL, layout resources are `.dfm`, declarations are `.h`, and event handlers are in `.cpp`.

Application launch and project configuration belong in the existing `.cbproj`, `.pro`, `.pri`, and app-local install scripts. Do not centralize build files unless the task is explicitly a build-system migration.

### Qt Build Path Contracts

Qt app project files under `app/qtapp/<app>_qt/` are one directory below `app/qtapp/`, so references to the RTKLIB core source tree must resolve from the app-local `.pro` file, not from the Qt root. Prefer a single derived variable:

```qmake
RTKLIB_SRC = $$clean_path($$_PRO_FILE_PWD_/../../../src)
INCLUDEPATH += $$RTKLIB_SRC
```

Use `$$RTKLIB_SRC/release/libRTKLib.a` or `$$RTKLIB_SRC/debug/libRTKLib.a` for app-local links. The `app/qtapp/RTKLib.pro` project itself is rooted at `app/qtapp/`, so its core source path is `../../src`; do not copy that relative path into app-local `.pro` files.

Some Qt resources still reuse the legacy VCL icon assets from `app/winapp/icon/`. When fixing `.qrc` resources in an app-local Qt directory, verify every `<file>` path against the filesystem. From `app/qtapp/rtkpost_qt/`, legacy icon paths should point at `../../winapp/icon/...`, not `../icon/...`.

---

## Naming Conventions

VCL classes use `T...` names and event handler suffixes such as `Click`, `Show`, `Change`, and `Timer`. Example: `TAboutDialog::FormShow()` and `TAboutDialog::BtnOkClick()` in `app/winapp/appcmn/aboutdlg.cpp`.

Qt classes use descriptive class names such as `MainForm`, `TextViewer`, and `TimeDialog`. Slots commonly match widget names and actions, such as `BtnDownloadClick()`, `DataTypeChange()`, `TimerTimer()`, `LoadOpt()`, and `SaveOpt()`.

Retain app-specific naming already used by the UI files. Renaming widgets causes noisy `.ui` or `.dfm` churn and can break event wiring.

---

## Examples

Use these files as references:

* `app/winapp/appcmn/aboutdlg.cpp` for VCL form construction and event handler style
* `app/winapp/rtkplot/skydlg.cpp` and `skydlg.h` for VCL dialog state update patterns
* `app/qtapp/rtkget_qt/getmain.cpp` and `getmain.h` for Qt signal-slot wiring, `QSettings`, timers, and command-line options
* `app/qtapp/rtkplot_qt/vmapdlg.cpp` for Qt dialog slot wiring
* `app/qtapp/RTKLib.pri` and app-local `.pro` files for Qt build inclusion patterns
