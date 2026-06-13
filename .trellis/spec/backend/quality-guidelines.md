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

### Convention: zero-regression baseline compare

**What**: behavior-preserving changes (new switches defaulting to off, diagnostics, refactors) are verified by running the fixture datasets with the pre-change binary once (archived under `baseline/`, not committed) and comparing post-change output with `cmp` byte-for-byte — headers included.

**Why**: RTKLIB `.pos` data lines encode the full numerical state of the solver; a byte-identical diff is the cheapest complete proof that defaults changed nothing. String-level "looks same" review has already missed real regressions (the original `--diag` MAD coupling).

**Rules**:
- Re-run with the exact same command line as recorded in the baseline `.pos` header (`% inp file` lines), including path separator form (see the `expath()` warning in database-guidelines)
- `-k conf` runs are not byte-comparable to no-conf runs even with identical values: the `-k` path changes header program/time formatting. Compare `-k off.conf` output against a `-k`-produced baseline, and plain runs against plain baselines
- Both `--diag` on and off must be covered once a feature claims diag is read-only

## Scenario: RTK double-difference robust residual weighting

### 1. Scope / Trigger
- Trigger: any change to `ddres()`, `robustddres()`, residual diagnostics, or measurement variance scaling in `src/rtkpos.c`
- These paths directly affect ambiguity convergence and fix ratio, so statistics must respect GNSS residual units and filter phase

### 2. Signatures
- Residual flag contract: `vflg=(sat1<<16)|(sat2<<8)|(type<<4)|freq`, where `type=0` is carrier phase and `type=1` is code
- Robust switch: `prcopt_t.robust` / `pos2-robust`
- Diagnostic output: `sat_diag.csv` `decision`, `reason`, and `var_factor`

### 3. Contracts
- Carrier phase and code residuals must not share one MAD/median pool: phase residuals are typically millimeter-centimeter scale, while code residuals are meter scale
- Compute robust center/scale per observation type; if a pool has too few samples, skip that pool instead of falling back to a mixed pool
- Prefit double-difference phase residuals include unresolved ambiguity and can be meter-level on clean RTK data. Do not apply phase IGG-III downweighting to prefit residuals before ambiguity convergence; code robust weighting may still run prefit for gross code faults
- Postfit diagnostics should use the same grouping and scale contract as the actual robust weighting path
- Cap IGG-III variance inflation at the project reject factor so CSV diagnostics and covariance scaling use the same maximum

### 4. Validation & Error Matrix
- Mixed phase/code MAD pool -> clean RTK `pos2-robust=igg3` may reject many phase residuals and collapse fix ratio
- Prefit phase IGG-III -> clean RTK may fail ambiguity fixing even when postfit residuals would be healthy
- Pool sample count <= 2 -> leave that pool untouched for the epoch
- `robust=off` -> `Ri`/`Rj` and `.pos` output must remain byte-identical to the archived baseline

### 5. Good/Base/Bad Cases
- Good: clean RTK with `pos2-robust=igg3` keeps fix ratio near the off baseline while injected code faults show `var_factor>1`
- Base: all robust/SNR/smoothing switches off compares byte-for-byte against baseline `.pos`
- Bad: one residual statistic over `fabs(v[i])` across both `L` and `P`, or applying phase downweighting during the Kalman prefit call

### 6. Tests Required
- Clean RTK fixture: assert `robust=igg3` fix ratio remains close to the off baseline
- Injected code fault fixture: assert the target satellite receives `downweight` or `reject` in `sat_diag.csv` and `diag_max_var_factor>1`
- Zero regression: run GEOP SPP and RTK fixtures with all switches off and `cmp` outputs against `baseline/`

### 7. Wrong vs Correct
#### Wrong
```c
vals[n++]=fabs(v[i]); /* mixes carrier phase and code residuals */
```
#### Correct
```c
if (((vflg[i]>>4)&0xF)==type) vals[n++]=v[i];
```

---

## Code Review Checklist

Before accepting an optimization, check:

* Does it preserve `rtklib.h` public API and compile-time feature switches
* Does every changed allocation path free owned memory on failure and success
* Does it preserve return code semantics for callers
* Does trace output remain level-gated and compatible with `TRACE` off
* Does it avoid changing CLI output, file formats, and `.ini` keys unintentionally
* Are relevant makefile tests or unit tests run or explicitly documented as unavailable
