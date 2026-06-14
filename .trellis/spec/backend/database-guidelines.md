# Data And Configuration Guidelines

> RTKLIB does not use a database or ORM. This guide documents the project equivalents: static data files, configuration files, options structs, and generated output files.

---

## Overview

There are no migrations, database connections, transactions, or schema objects in the current source tree. Persistent state is represented by:

* configuration files loaded into RTKLIB option structs, such as `prcopt_t`, `solopt_t`, and `filopt_t`
* static data under `data/` and `test/data/`
* runtime output files such as `.pos`, RINEX, KML/GPX, logs, and trace files
* GUI `.ini` files managed by VCL or Qt application layers

Do not introduce a database abstraction for optimization tasks unless the task explicitly changes storage architecture.

---

## Option And Data Flow Patterns

Core processing APIs pass options by struct pointer instead of hidden global configuration where possible. `app/consapp/rnx2rtkp/rnx2rtkp.c` starts from `prcopt_default` and `solopt_default`, then calls `loadopts()`, `getsysopts()`, and finally `postpos()`.

```c
prcopt_t prcopt=prcopt_default;
solopt_t solopt=solopt_default;
filopt_t filopt={""};

if (!loadopts(argv[++i],sysopts)) return -1;
getsysopts(&prcopt,&solopt,&filopt);

ret=postpos(ts,te,tint,0.0,&prcopt,&solopt,&filopt,infile,n,outfile,"","");
```

Static constants and GNSS limits belong in `src/rtklib.h`, not scattered through application code. Examples include `MAXSAT`, `MAXOBS`, `MAXRCV`, `MAXSTRPATH`, and `MAXRAWLEN`.

---

## File-Based Data Handling

Use the existing RTKLIB file readers and writers before adding new parsing logic. Relevant modules include:

* `src/rinex.c` for RINEX data
* `src/solution.c` for solution input/output
* `src/preceph.c` for precise ephemeris and clock data
* `src/ionex.c` for IONEX data
* `src/tle.c` for TLE support
* `src/geoid.c` and `src/datum.c` for model data

When expanding file paths or time-template paths, use the established helpers in `src/rtkcmn.c`, such as `expath()`, `reppath()`, `reppaths()`, and `createdir()`.

> **Warning**: on WIN32, `expath()` splits the directory part only on `'\\'`. A relative input path written with forward slashes (`../../test/data/x.05o`) silently loses its directory and surfaces as `error : no obs data`. Always pass observation/nav input paths with backslashes on Windows (`..\..\test\data\x.05o`), and reproduce baseline runs with the same separator form recorded in the `.pos` header `% inp file` lines.

> **Warning**: a RINEX observation file can contain code, Doppler, and SNR fields while all carrier phase `L*` fields are blank. Carrier-based preprocessing such as Hatch smoothing must treat that as a graceful no-op, not a failure. Before claiming a smoothing window is ineffective, inspect observation availability by type and confirm whether any usable `L*` samples exist.

---

## Generated Files

Generated runtime files should remain outside the checked-in source tree unless they are deliberate regression fixtures under `test/data/` or `test/utest/`. The root `.gitignore` excludes build products and local state such as `*.o`, `*.d`, `*.obs`, `*.ini`, `*.local`, `Release`, `Debug`, `__history`, and `__astcache`.

For command-line app changes, prefer writing deterministic outputs that can be compared by tests. `app/consapp/rnx2rtkp/gcc/makefile` already contains test targets that generate `test*.pos` files from known fixtures.

## Scenario: RTK observation diagnostics

### 1. Scope / Trigger
- Trigger: a new command-line option and core API were added to emit observation diagnostics
- The feature writes deterministic CSV files that are consumed as runtime output, so the file contract must be explicit

### 2. Signatures
- CLI option: `rnx2rtkp --diag <dir> ...`
- Core API: `int rtkopendiag(const char *dir)` and `void rtkclosediag(void)`
- Output files: `<dir>/epoch_diag.csv` and `<dir>/sat_diag.csv`

### 3. Contracts
- `--diag` is optional and must not change default output when omitted
- `rtkopendiag()` must create the output directory if needed, then open both CSV files for writing
- `epoch_diag.csv` header:
  `time,stat,ns,ratio,gdop,n_slip,n_reject,n_downweight,n_low_snr,n_low_el,n_res_outlier`
- `sat_diag.csv` header (v2, task 06-11 appended `var_factor` as column 18):
  `time,sat,sys,freq,az,el,snr,resp,resc,slip,vsat,lock,outc,rejc,quality_score,decision,reason,var_factor`
- `quality_score` must remain in the inclusive range 0..100
- `decision` must be one of `use`, `downweight`, `reject`, or `slip_risk`
- `var_factor` is the actual measurement-variance inflation applied by robust weighting (1.0 = untouched). With all processing switches off it must be exactly `1` on every row
- Schema evolution rule: only append new columns at the end of the header; never rename, reorder, or remove existing columns (consumers read by column name, e.g. `tools/matlab/compare_solutions.m`)
- Since task 06-11, `--diag` is read-only: it must not modify `Ri`/`Rj` or any solver state. Robust downweighting lives behind `pos2-robust` (`robustddres()` in `src/rtkpos.c`), independent of `diag_enabled`

### 3.1 Mode-Specific Field Semantics

The CSV header is stable across processing modes, but several fields have mode-specific meaning:

| Field | Single-point mode | RTK / carrier-phase modes |
|-------|-------------------|---------------------------|
| `vsat` | Satellite-level participation from `ssat.vs`, because `pntpos()` updates the single-point validity flag | Frequency-level participation from `ssat.vsat[f]`, because relative and PPP processing update per-frequency validity |
| `ratio` | Usually `0.000`; this is a normal placeholder because ambiguity validation is not active | Meaningful for float/fix ambiguity validation |
| `resc` | May stay `0.0000` when no carrier-phase residual is estimated | Carrier-phase residual for the frequency |
| `slip`, `lock`, `outc`, `rejc` | May stay zero for long periods and should not by itself be treated as an error | Useful for carrier-phase tracking, outage, and rejection diagnostics |

For single-point diagnostic review, prefer `stat`, `ns`, `gdop`, `snr`, `resp`, `quality_score`, `decision`, and `reason`. Normal zero placeholders in `ratio`, `resc`, `slip`, `lock`, `outc`, or `rejc` are not evidence that the diagnostic output is broken.

### 4. Validation & Error Matrix
- Missing `dir` or empty `dir` -> `rtkopendiag()` returns 0
- Unable to create the directory or open either CSV -> `rtkopendiag()` returns 0
- `--diag` omitted -> no diagnostic files are created
- `rtkclosediag()` may be called more than once and must remain safe

### 5. Good/Base/Bad Cases
- Good: `--diag diag_out` creates both CSV files and writes one row per processed epoch/satellite
- Base: no `--diag` keeps the original `.pos` and trace behavior
- Bad: changing the CSV header order or allowing scores outside 0..100

### 6. Tests Required
- Run `rnx2rtkp --diag <dir> ...` on a known fixture and assert both CSVs exist
- Parse both CSVs and assert header order, non-empty rows, valid `decision` values, and `quality_score` range
- Run the same input without `--diag` and assert no diagnostic files are created

### 7. Wrong vs Correct
#### Wrong
```c
if (diagdir) {
    fopen("epoch_diag.csv", "w");
    fopen("sat_diag.csv", "w");
}
```
#### Correct
```c
if (*diagdir && rtkopendiag(diagdir)) {
    ret = postpos(...);
    rtkclosediag();
}
```

## Scenario: adding a `prcopt_t` processing switch

### 1. Scope / Trigger
- Trigger: task 06-11 added `robust`, `weightsnr`, `smoothwin` (`pos2-robust`, `stats-weightsnr`, `pos1-smoothwin`). Any new processing option is a cross-layer contract (conf file ↔ struct ↔ GUI) and must follow this scenario.

### 2. Signatures
Three places must change together, in this order:
- `src/rtklib.h`: append the field at the tail of `prcopt_t` (Chinese comment, document value domain, 0 = off/legacy behavior)
- `src/rtkcmn.c` `prcopt_default`: extend the positional initializer to cover the new tail fields — the initializer is order-sensitive; verify field-by-field against the struct declaration
- `src/options.c` `sysopts[]`: add the entry in the matching key-prefix section (`pos1-*`, `pos2-*`, `stats-*`); enum options get a `#define XXXOPT "0:off,1:..."` string next to the existing ones

### 3. Contracts
- Conf key naming follows the section prefix of the struct area it controls (e.g. RTK robust weighting → `pos2-robust`)
- Default value must be 0 / `off`: switches-all-off output must be byte-identical to the pre-change baseline
- `loadopts()`+`getsysopts()` → `setsysopts()`+`saveopts()` must round-trip the value losslessly

### 4. Validation & Error Matrix
- Conf file omits the key -> `getsysopts()` applies the sysopts default (0), NOT `prcopt_default`'s value
- `-k conf` given to rnx2rtkp -> `resetsysopts()` + full-table `getsysopts()` overwrite `prcopt`: every option not present in the conf is reset to table default. Notably `pos1-posmode` resets to `single`
- Initializer/declaration drift in `prcopt_default` -> wrong defaults with no compiler error (positional init); guard with the byte-identical zero-regression run

### 5. Good/Base/Bad Cases
- Good: `rnx2rtkp -p 2 -k on.conf ...` — `-k` is processed in a first pass, command-line `-p` overrides afterwards, so a minimal conf plus explicit mode works
- Base: no conf, no switches — behavior identical to upstream RTKLIB
- Bad: `rnx2rtkp -k on.conf <rtk inputs>` with a minimal conf lacking `pos1-posmode` — silently runs single-point and the RTK experiment "succeeds" with wrong-mode results

### 6. Tests Required
- Round-trip: load a conf with the new key, save it back, reload — assert value survives both directions
- Compile any round-trip helper with the same feature macros as the RTKLIB objects it links against (`NFREQ`, enabled constellations, `WIN32`, `TRACE` when relevant). A helper built with mismatched macros can read the wrong `prcopt_t` layout or option table behavior even though it links
- Zero regression: switches off (default and explicit-off conf), run fixture datasets, `cmp` the `.pos` byte-for-byte against the archived baseline
- Option effectiveness: switch on via `-k`, assert the output actually differs from the off run

### 7. Wrong vs Correct
#### Wrong
```bash
# minimal conf, RTK inputs: -k resets pos1-posmode to single
./rnx2rtkp.exe -k on.conf rover.obs base.nav base.obs -o out.pos
```
#### Correct
```bash
# explicit mode after -k, or include pos1-posmode in the conf
./rnx2rtkp.exe -p 2 -k on.conf rover.obs base.nav base.obs -o out.pos
```

## Scenario: RTK MW slip detection and wide-lane AR switches

### 1. Scope / Trigger
- Trigger: task 06-13 added RTK relative-positioning switches for Melbourne-Wubbena slip detection and wide-lane-assisted ambiguity resolution
- These switches affect `prcopt_t`, `ssat_t`, `sysopts[]`, diagnostic reasons, MATLAB validation tools, and Qt option state, so the executable contract must be captured across config and generated-output boundaries

### 2. Signatures
- Core fields: `prcopt_t.slipmw` and `prcopt_t.arwl`, both integer switches with `0=off` and `1=on`
- Satellite state: `ssat_t.mwm[NFREQ-1]` stores the MW sliding mean in meters, and `ssat_t.mwc[NFREQ-1]` stores the smoothing count
- Config keys: `pos2-slipmw` and `pos2-arwl`, both encoded with the standard switch option table (`0:off,1:on`)
- Diagnostic reason: MW slip detection writes `cycle_slip_mw` through existing `sat_diag.csv` `decision/reason` fields; the CSV header must not change
- Qt settings keys: `set/slipmw` and `set/arwl` mirror the core switches for `rtkpost_qt`

### 3. Contracts
- Both switches default to `0`; with all new switches off, `.pos` output must remain byte-identical to the archived pre-change baseline
- `pos2-slipmw=on` enables MW slip decisions and writes `cycle_slip_mw`; `pos2-arwl=on` may maintain MW smoothing state for AR, but must not mark slips or write MW slip diagnostics by itself
- MW smoothing may run when either `slipmw` or `arwl` is on, because the same `ssat_t.mwm/mwc` state feeds both detection and AR
- Wide-lane AR is RTK dual-frequency only: single-frequency, missing L2 pairs, IFLC mode, unsupported systems, short MW lock, fractional-width failure, or ratio failure must fall back to the original full LAMBDA path
- Wide-lane AR status belongs in trace/error messages only; do not add columns to `epoch_diag.csv` or `sat_diag.csv`
- GUI state is not authoritative; `rtkpost_qt` must translate `set/slipmw` and `set/arwl` into `prcopt_t` before `postpos()`

### 4. Validation & Error Matrix
- Config omits `pos2-slipmw` or `pos2-arwl` -> `getsysopts()` supplies `0`
- `slipmw=off, arwl=off` -> no MW observation path runs, and `.pos` matches the zero-regression baseline byte-for-byte
- `slipmw=off, arwl=on` -> MW smoothing may update, but `sat_diag.csv` must not contain `cycle_slip_mw`
- GF-blind L1/L2 cycle-slip injection with `slipmw=off` -> no MW slip diagnostic is expected
- Same injection with `slipmw=on` -> target satellite/frequencies should produce `cycle_slip_mw`
- Clean RTK data with `slipmw=on` -> no clean-epoch `cycle_slip_mw` false alarms
- Wide-lane confidence failure or unsupported mode -> return to original LAMBDA without crashing and without leaving a stale ratio decision

### 5. Good/Base/Bad Cases
- Good: `rnx2rtkp -p 2 -k arwl_on.conf ...` improves fix ratio, TTFF, or ratio statistics while clean-data ENU RMS does not degrade
- Base: `rnx2rtkp -p 2 -k all_off.conf ...` compares byte-for-byte against `baseline/p0_*.pos`
- Bad: `arwl=on` alone sets `ssat[].slip[]` or writes `cycle_slip_mw`
- Bad: adding a new `sat_diag.csv` column for wide-lane AR instead of using trace output

### 6. Tests Required
- Option round-trip: save and reload `pos2-slipmw=on` and `pos2-arwl=on`; compile any helper with the same `WIN32`, `TRACE`, `NFREQ`, and constellation macros as the linked RTKLIB objects
- Zero regression: run the RTK fixtures with both switches off and compare `.pos` against the pre-change baseline with `cmp` or SHA256
- Detection matrix: clean, GF-blind cycle-slip, and ordinary cycle-slip fixtures with `slipmw` off/on; assert MW hits only where expected and clean false alarms remain zero
- AR matrix: clean and injected fixtures with `arwl` off/on; assert fix ratio, TTFF, or ratio distribution improves while clean-data RMS does not degrade
- Tooling: run MATLAB Code Analyzer on `tools/matlab/inject_rinex_fault.m` and `tools/matlab/compare_solutions.m`, and archive metrics/figures under the task artifacts
- GUI: rebuild `app/qtapp/RTKLib.pro` and `app/qtapp/rtkpost_qt/rtkpost_qt.pro`; confirm the executable contains `set/slipmw`, `set/arwl`, `pos2-slipmw`, and `pos2-arwl`, then compare a manual/UI-automated GUI run against the equivalent console config when GUI execution is in scope

### 7. Wrong vs Correct
#### Wrong
```c
if (opt->slipmw || opt->arwl) {
    ssat->slip[0] |= 1; /* arwl-only mode must not mark cycle slips */
    markdiag(sat,0,RTKDIAG_SLIP_RISK,"cycle_slip_mw");
}
```
#### Correct
```c
if (opt->slipmw || opt->arwl) {
    detslp_mw(rtk,obs,iu[i],ir[i],nav,opt->slipmw);
}
```

---

## Common Mistakes

Do not treat GUI `.ini` state as source of truth for core calculations. GUI state should be translated into RTKLIB option structs before calling library functions.

Do not duplicate constants already declared in `src/rtklib.h`; changing one GNSS limit usually affects array sizes, binary decoders, tests, and GUI assumptions.

Do not create ad hoc parsers for formats already handled by RTKLIB modules. Search `src/` first.
