# Core Logging Guidelines

> RTKLIB logging is based on compile-time `TRACE` support and runtime trace levels.

---

## Overview

The core logging mechanism lives in `src/rtkcmn.c` behind `#ifdef TRACE`. When `TRACE` is disabled, trace functions compile to empty stubs. Optimization work must preserve both builds.

Console and GUI tools enable tracing through options such as `-x level`, `-t level`, `TraceLevel`, `traceopen()`, and `tracelevel()`.

---

## Trace Levels

Existing code uses numeric levels instead of named log levels:

* `1` is severe enough to also print to stderr inside `trace()`
* `2` is warnings or important abnormal conditions
* `3` is high-level function entry or operation status
* `4` is detailed algorithm progress
* `5` is very detailed data dumps or per-step values

Examples from existing modules:

```c
trace(3,"convgpx : infile=%s outfile=%s\n",infile,outfile);
trace(2,"no ssr orbit correction: %s sat=%2d\n",time_str(time,0),sat);
tracet(3,"stropen: type=%d mode=%d path=%s\n",type,mode,path);
```

---

## Trace File Handling

`traceopen()` stores the trace path, initializes the lock, records the start tick, and supports time-based file swapping through `traceswap()`.

```c
extern void traceopen(const char *file)
{
    gtime_t time=utc2gpst(timeget());
    char path[1024];

    reppath(file,path,time,"","");
    if (!*path||!(fp_trace=fopen(path,"w"))) fp_trace=stderr;
    strcpy(file_trace,file);
    tick_trace=tickget();
    time_trace=time;
    initlock(&lock_trace);
}
```

Do not write directly to `fp_trace` outside trace helper functions. Use `trace()`, `tracet()`, `tracemat()`, `traceobs()`, or the other existing trace helpers.

---

## What To Log

Log function entry at level `3` for long-running operations, file paths, stream types, satellite IDs, and conversion formats when this matches nearby code.

Log recoverable abnormal conditions at level `2`, especially missing ephemeris, invalid correction data, stream errors, and file open errors.

Use level `4` or `5` for high-volume numerical details, observations, navigation data, and stream buffers.

---

## What Not To Log

Do not log passwords, proxy credentials, NTRIP credentials, or raw command strings that may include secrets. Stream paths and receiver commands can contain sensitive values.

Do not add unconditional `printf()` debugging to library files. It breaks console output formats and GUI embedding.

Do not add trace output inside tight numerical loops unless it is guarded by an appropriate high trace level and follows existing nearby style.
