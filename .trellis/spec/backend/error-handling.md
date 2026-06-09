# Core Error Handling

> RTKLIB uses C-style return codes, progress callbacks, stderr messages, and trace output rather than exceptions.

---

## Overview

Core C functions usually return integer status values or null pointers. Existing conventions are module-specific but consistent enough to preserve during optimization:

* `0` commonly means failure, invalid input, unsupported data, or no result
* positive values commonly mean success or number of processed items
* negative values are used by some command-line entry points for fatal user-facing errors
* allocation helpers such as `mat()`, `imat()`, and `zeros()` call `fatalerr()` on allocation failure

Do not introduce C++ exceptions into `src/*.c` or `app/consapp/*.c`.

---

## Error Types

There are no custom error structs. Error context is carried through:

* return codes
* output parameters
* `showmsg()` user/progress messages
* `trace()` and `tracet()` diagnostic records
* application-specific stderr output in console programs

`src/rtkcmn.c` defines `fatalerr()` and `add_fatal()` so applications can register a fatal allocation callback:

```c
static void fatalerr(const char *format, ...)
{
    char msg[1024];
    va_list ap;
    va_start(ap,format); vsprintf(msg,format,ap); va_end(ap);
    if (fatalfunc) fatalfunc(msg);
    else fprintf(stderr,"%s",msg);
    exit(-9);
}
```

---

## Error Handling Patterns

Validate arguments early and return the local error sentinel. `satno()` in `src/rtkcmn.c` returns `0` for invalid PRN/system combinations.

```c
if (prn<=0) return 0;
if (prn<MINPRNGPS||MAXPRNGPS<prn) return 0;
```

When a function allocates multiple buffers manually, release already allocated resources on every error path. `src/convrnx.c` and `src/download.c` contain examples of freeing partial allocations before returning `0`.

For console apps, keep usage errors direct and deterministic. `app/consapp/rnx2rtkp/rnx2rtkp.c` reports missing input with `showmsg("error : no input file")` and returns `-2`.

---

## User-Facing Messages

Console applications commonly provide their own `showmsg()` implementation that writes to stderr and returns `0`:

```c
extern int showmsg(const char *format, ...)
{
    va_list arg;
    va_start(arg,format); vfprintf(stderr,format,arg); va_end(arg);
    fprintf(stderr,"\r");
    return 0;
}
```

Library code should not assume `showmsg()` displays a modal UI; GUI applications and console applications may override it differently.

---

## Common Mistakes

Do not change return code meaning while optimizing. Many callers treat `0`, negative values, and positive values differently.

Do not add `exit()` to library code except for existing fatal allocation paths. Normal parse, IO, and validation failures should return status.

Do not convert trace-only diagnostics into user-facing stderr output unless the task explicitly changes CLI behavior.
