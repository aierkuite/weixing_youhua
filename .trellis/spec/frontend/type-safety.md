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
