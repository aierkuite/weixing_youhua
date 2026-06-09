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

---

## Generated Files

Generated runtime files should remain outside the checked-in source tree unless they are deliberate regression fixtures under `test/data/` or `test/utest/`. The root `.gitignore` excludes build products and local state such as `*.o`, `*.d`, `*.obs`, `*.ini`, `*.local`, `Release`, `Debug`, `__history`, and `__astcache`.

For command-line app changes, prefer writing deterministic outputs that can be compared by tests. `app/consapp/rnx2rtkp/gcc/makefile` already contains test targets that generate `test*.pos` files from known fixtures.

---

## Common Mistakes

Do not treat GUI `.ini` state as source of truth for core calculations. GUI state should be translated into RTKLIB option structs before calling library functions.

Do not duplicate constants already declared in `src/rtklib.h`; changing one GNSS limit usually affects array sizes, binary decoders, tests, and GUI assumptions.

Do not create ad hoc parsers for formats already handled by RTKLIB modules. Search `src/` first.
