# GUI State Management

> GUI state is stored in form fields, RTKLIB option structs, `.ini` settings, and runtime timers/threads.

---

## Overview

There is no global frontend state library. Each desktop application owns its form state and persists user preferences to an app-local `.ini` file.

Core calculation state should stay in RTKLIB structs and library objects. GUI state should be translated into those structs at call boundaries.

---

## State Categories

Form state lives in control values and class members. Examples from `app/qtapp/rtkget_qt/getmain.cpp` include `IniFile`, `UrlFile`, `LogFile`, `TraceLevel`, `TimerCnt`, and `QTimer Timer`.

Persistent user settings are saved with `QSettings` in Qt applications:

```cpp
QSettings setting(IniFile,QSettings::IniFormat);
TraceLevel = setting.value("opt/tracelevel",0).toInt();
setting.setValue("opt/tracelevel",TraceLevel);
```

Processing state belongs in RTKLIB option and data structs such as `prcopt_t`, `solopt_t`, `filopt_t`, `nav_t`, `obs_t`, `raw_t`, `rtcm_t`, and `strsvr_t`.

---

## When To Use Shared State

Use shared app helpers only when multiple dialogs in the same GUI family already depend on them. For example, common Qt dialogs and viewers belong under `app/qtapp/appcmn_qt/`, and common VCL dialogs belong under `app/winapp/appcmn/`.

Do not promote local dialog state to global variables for convenience. If state needs to cross the GUI/core boundary, prefer explicit RTKLIB structs or existing app-level members.

---

## Server State

There is no server state. Remote data sources such as FTP, HTTP, NTRIP, serial, TCP, and UDP are handled by RTKLIB stream/download modules and app-specific controls.

For live streams, keep state transitions consistent with `src/stream.c`, `src/streamsvr.c`, and `app/consapp/str2str/str2str.c`.

---

## Common Mistakes

Do not change existing `.ini` key names unless migration is part of the task. Saved user preferences depend on keys such as `opt/tracelevel`, `opt/localdir`, and `viewer/fontname`.

Do not store numerical processing state only in GUI controls. Convert and validate values before calling RTKLIB APIs.

Do not let UI state bypass `LoadOpt()`, `SaveOpt()`, and `UpdateEnable()` style methods when a dialog already uses them.
