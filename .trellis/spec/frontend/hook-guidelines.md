# GUI Event Guidelines

> This project has no React hooks. The equivalent stateful interaction patterns are VCL event handlers, Qt slots, timers, and worker threads.

---

## Overview

Treat GUI events as thin adapters. They should read or write UI controls, call helper methods such as `UpdateEnable()`, and dispatch work to existing RTKLIB or app helper functions.

---

## Event Handler Patterns

VCL handlers use `void __fastcall ClassName::ControlAction(TObject *Sender)` or framework-specific event signatures. Examples in `app/winapp/rtkplot/skydlg.h` include:

```cpp
void __fastcall FormShow(TObject *Sender);
void __fastcall BtnCloseClick(TObject *Sender);
void __fastcall SkyResChange(TObject *Sender);
```

Qt handlers are declared as slots in headers and connected explicitly:

```cpp
connect(BtnExit,SIGNAL(clicked(bool)),this,SLOT(BtnExitClick()));
connect(MenuStart,SIGNAL(triggered(bool)),this,SLOT(MenuStartClick()));
```

---

## Data Fetching And Background Work

There is no frontend data-fetching framework. File downloads, stream reads, and processing tasks should use the existing app patterns:

* Qt worker threads such as `DownloadThread` in `app/qtapp/rtkget_qt/getmain.cpp`
* Qt timers such as `TimerTimer()`
* RTKLIB stream APIs in `src/stream.c` and `src/streamsvr.c`
* application callback functions such as `showmsg()`, `settspan()`, and `settime()`

Avoid blocking the GUI event loop with long-running processing.

---

## Naming Conventions

Preserve existing handler names that mirror widget names. Use action suffixes such as `Click`, `Change`, `Timer`, `Show`, `Load`, `Save`, `Update`, and `Finished`.

Helper methods that refresh view state commonly use `Update...` names, such as `UpdateType()`, `UpdateEnable()`, `UpdateField()`, and `UpdateSky()`.

---

## Common Mistakes

Do not introduce a new event abstraction for one dialog. Match VCL or Qt conventions already used in that app.

Do not connect the same signal twice during repeated initialization.

Do not call `qApp->processEvents()` casually in new code. If the operation is long-running, prefer the existing worker-thread or timer pattern.
