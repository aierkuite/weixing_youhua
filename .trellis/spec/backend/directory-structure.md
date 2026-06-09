# Core Directory Structure

> In this RTKLIB workspace, `backend` means the C library, receiver decoders, command-line tools, utilities, and test data under `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34`.

---

## Overview

RTKLIB is not a web backend. The central boundary is the C library in `src/rtklib.h` plus implementation files in `src/`. Console applications and utilities call that library instead of duplicating positioning, stream, RINEX, RTCM, or receiver-specific logic.

Keep source optimization work inside the smallest existing module that owns the behavior. Do not move public APIs or reclassify GNSS constants unless the task explicitly includes API migration.

---

## Directory Layout

```text
RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/
├── src/                  # shared C library implementation
│   ├── rtklib.h          # public API, constants, structs, compile-time switches
│   ├── rtkcmn.c          # common time, coordinate, matrix, trace, and utility code
│   ├── rtkpos.c          # RTK positioning logic
│   ├── postpos.c         # post-processing orchestration
│   ├── rinex.c           # RINEX read/write logic
│   ├── rtcm*.c           # RTCM common, RTCM2, RTCM3 decode/encode logic
│   ├── stream*.c         # stream and stream server handling
│   └── rcv/              # receiver-specific raw protocol decoders
├── app/consapp/          # command-line applications
│   ├── rnx2rtkp/
│   ├── convbin/
│   ├── rtkrcv/
│   ├── str2str/
│   └── pos2kml/
├── app/winapp/           # Windows VCL GUI applications
├── app/qtapp/            # Qt GUI applications
├── util/                 # standalone development and conversion utilities
├── lib/                  # bundled third-party/static library support such as IERS
├── test/data/            # receiver, RINEX, SP3, TLE, and other regression data
└── test/utest/           # C and MATLAB unit/regression tests
```

---

## Module Organization

Public library declarations belong in `src/rtklib.h`. Implementations normally use `extern` for public functions and `static` for file-local helpers, as seen in `src/rtkcmn.c`.

Receiver protocol work belongs under `src/rcv/` when it is tied to a specific device family, such as `src/rcv/ublox.c`, `src/rcv/novatel.c`, or `src/rcv/septentrio.c`. Shared protocol logic belongs in `src/rcvraw.c`, `src/rtcm.c`, `src/rtcm2.c`, `src/rtcm3.c`, or `src/rtcm3e.c` depending on the format.

Console tools should stay thin. For example, `app/consapp/rnx2rtkp/rnx2rtkp.c` parses CLI arguments, loads options, then delegates processing to `postpos()`. New processing behavior should go into `src/` unless it is purely CLI presentation.

Build files are application-local. `app/consapp/rnx2rtkp/gcc/makefile` compiles the exact `src/*.c` files needed for that executable, with feature macros such as `-DTRACE`, `-DENAGLO`, `-DENAQZS`, `-DENAGAL`, `-DENACMP`, `-DENAIRN`, and `-DNFREQ=5`.

---

## Naming Conventions

Use the existing short lowercase C file names for core modules, such as `rtkcmn.c`, `postpos.c`, and `preceph.c`. Receiver-specific files use lowercase vendor/protocol names under `src/rcv/`.

Public constants in `rtklib.h` are uppercase macros, such as `SYS_GPS`, `MAXSAT`, `VER_RTKLIB`, and `PATCH_LEVEL`. Public structs use the `_t` suffix, such as `prcopt_t`, `solopt_t`, `filopt_t`, and `gtime_t`.

Public C functions generally use compact lowercase names, such as `satno()`, `satsys()`, `mat()`, `zeros()`, `traceopen()`, and `postpos()`. File-local helpers are `static` and may use subsystem prefixes.

Keep the existing banner comment style for exported C functions:

```c
/* satellite system+prn/slot number to satellite number ------------------------
* convert satellite system+prn/slot number to satellite number
* args   : int    sys       I   satellite system (SYS_GPS,SYS_GLO,...)
*          int    prn       I   satellite prn/slot number
* return : satellite number (0:error)
*-----------------------------------------------------------------------------*/
extern int satno(int sys, int prn)
```

---

## Examples

Use these files as structural references before adding or optimizing code:

* `src/rtkcmn.c` for common utilities, exported function comments, matrix helpers, trace functions, and platform wrappers
* `src/ephemeris.c` for GNSS ephemeris calculations and trace-heavy numerical logic
* `src/convrnx.c` for file conversion orchestration, `showmsg()` progress callbacks, and allocation cleanup patterns
* `app/consapp/rnx2rtkp/rnx2rtkp.c` for command-line option parsing and library delegation
* `app/consapp/rnx2rtkp/gcc/makefile` for app-local build dependencies and regression targets
