# GUI Type Safety

> Type safety here means C/C++ boundary discipline between Qt/VCL types, fixed-size C buffers, and RTKLIB public structs.

---

## Overview

The GUI layer uses C++ framework types, while the RTKLIB core API uses C structs, arrays, `char *`, and primitive numeric types. Keep conversions explicit and localized.

---

## Type Organization

Public C types are declared in `src/rtklib.h`. Do not duplicate these definitions in GUI headers.

Qt-specific declarations belong in Qt app headers such as `app/qtapp/rtkget_qt/getmain.h`, where framework types like `QSettings`, `QTimer`, `QString`, `QComboBox`, and `QSystemTrayIcon` are expected.

VCL-specific declarations belong in VCL app headers under `app/winapp/`.

---

## Validation

Validate GUI input before converting it into RTKLIB structs or fixed arrays. The existing code commonly uses framework conversion helpers such as `toInt()`, `toDouble()`, `toString()`, and legacy C functions such as `atoi()`, `atof()`, `sscanf()`, and `strcpy()`.

When optimizing or touching unsafe string handling, preserve behavior but prefer bounded operations where the surrounding code and compiler allow it. Any change from `strcpy()` to bounded copying must keep null termination and existing field length assumptions.

For Qt file inputs, normalize file URLs before passing paths to RTKLIB C APIs or helpers such as `postpos()`, `reppath()`, `rtk_uncompress()`, or `QFileInfo`-derived output generation. Drag/drop MIME data and some external callers can produce `file:///D:/data.obs` or malformed persisted variants such as `...\file:\D:\data.pos`; convert these at the GUI boundary with `QUrl(...).toLocalFile()` or an app-local helper, then apply `QDir::toNativeSeparators()`.

Wrong:

```cpp
QString file=event->mimeData()->text();
thread->addInput(file);
reppath(qPrintable(file),path,ts,rov,base);
```

Correct:

```cpp
QString file=LocalFilePath(event->mimeData()->urls().first().toLocalFile());
thread->addInput(file);
reppath(qPrintable(LocalFilePath(file)),path,ts,rov,base);
```

Validation cases:

| Input | Expected boundary value |
|-------|--------------------------|
| `file:///D:/GEOP156N(1).26o` | `D:\GEOP156N(1).26o` |
| `D:\GEOP156N(1).26o` | `D:\GEOP156N(1).26o` |
| `...\release\file:\D:\GEOP156N(1).pos` | `D:\GEOP156N(1).pos` |

---

## Common Patterns

Use RTKLIB constants for array sizes and valid ranges. Examples include `MAXFILE`, `MAXSTRPATH`, `MAXRCVCMD`, `MAXSAT`, and `MAXOBS`.

Keep constellation and signal masks as bitmasks matching `rtklib.h` definitions such as `SYS_GPS`, `SYS_GLO`, `SYS_GAL`, `SYS_QZS`, `SYS_CMP`, and `SYS_IRN`.

When converting between degrees and radians, use existing constants such as `D2R` and `R2D`.

---

## Forbidden Patterns

Do not pass `QString` or VCL `AnsiString` into core C functions without an explicit stable C-string conversion whose lifetime covers the call.

Do not add C++ STL containers to `src/*.c`; those files are C, not C++.

Do not widen or narrow GNSS numeric values casually. Time, frequency, coordinate, and variance calculations often depend on `double` precision.

Do not change public struct field types without auditing every caller, file format, and binary decoder.
