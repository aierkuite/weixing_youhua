# Core Quality Guidelines

> Quality for this project means preserving GNSS numerical behavior, public C APIs, build variants, and regression data outputs while making targeted improvements.

---

## Overview

RTKLIB is a mature C/C++ codebase with many compile-time feature switches and platform-specific branches. Optimize conservatively:

* preserve public declarations in `src/rtklib.h`
* preserve binary/file format behavior unless the task explicitly changes it
* keep command-line output and exit status compatible
* test with available makefile targets and representative fixtures
* avoid broad style rewrites that obscure numerical changes

---

## Forbidden Patterns

Do not change public struct layouts, macro values, or exported function signatures without an explicit migration plan. Types such as `obsd_t`, `eph_t`, `nav_t`, `raw_t`, `rtcm_t`, `prcopt_t`, and `solopt_t` are cross-module contracts.

Do not replace fixed-size protocol buffers casually. Many constants in `rtklib.h`, such as `MAXRAWLEN`, `MAXSTRPATH`, `MAXOBS`, and `MAXSAT`, are tied to protocol parsing and array indexing.

Do not introduce dependencies into core `src/*.c` unless the target makefiles are updated and the portability impact is accepted. Existing builds support plain C with optional LAPACK, IERS, MKL, and platform branches.

Do not convert all manual allocation to a new allocator abstraction in a local optimization task. Keep ownership clear and local.

---

## Required Patterns

Follow existing exported function documentation for new public C functions:

```c
/* new matrix ------------------------------------------------------------------
* allocate memory of matrix
* args   : int    n,m       I   number of rows and columns of matrix
* return : matrix pointer (if n<=0 or m<=0, return NULL)
*-----------------------------------------------------------------------------*/
extern double *mat(int n, int m)
```

When modifying an option, constant, or GNSS system capability, search all references first. At minimum check `src/rtklib.h`, core modules in `src/`, command-line apps under `app/consapp/`, GUI option dialogs, and tests.

Keep numerical changes isolated and explain expected output impact. Use trace output or existing tests to validate edge cases such as week rollover, leap seconds, constellation-specific frequencies, ephemeris selection, and ambiguity resolution.

---

## Testing Requirements

For command-line and core library work, use the closest existing makefile test target:

* `app/consapp/rnx2rtkp/gcc/makefile` has `test1` through `test24` and a grouped `test` target
* `test/utest/makefile` builds C unit-style tests such as `t_matrix.c`, `t_time.c`, `t_coord.c`, `t_rinex.c`, `t_lambda.c`, and `t_preceph.c`
* `test/data/` contains receiver raw logs, RINEX fixtures, SP3 files, TLE data, and other regression inputs

On Windows-focused sessions, it is acceptable to document when GCC, make, Qt, C++ Builder, or MATLAB is unavailable locally, but still identify the exact target that should be run in the proper environment.

---

## Code Review Checklist

Before accepting an optimization, check:

* Does it preserve `rtklib.h` public API and compile-time feature switches
* Does every changed allocation path free owned memory on failure and success
* Does it preserve return code semantics for callers
* Does trace output remain level-gated and compatible with `TRACE` off
* Does it avoid changing CLI output, file formats, and `.ini` keys unintentionally
* Are relevant makefile tests or unit tests run or explicitly documented as unavailable
