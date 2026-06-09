# Core Development Guidelines

> RTKLIB core library, console application, utility, data, logging, error handling, and quality guidelines.

---

## Overview

This directory maps Trellis `backend` guidance onto the RTKLIB C core, command-line tools, utilities, file-based data, and regression tests. It is the primary spec layer for source optimization work in `src/`, `app/consapp/`, `util/`, `lib/`, and `test/`.

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Core C library, console app, utility, and test layout | Filled |
| [Database Guidelines](./database-guidelines.md) | File-based data, options, generated outputs, and config state | Filled |
| [Error Handling](./error-handling.md) | C return codes, fatal allocation hooks, `showmsg()`, and trace errors | Filled |
| [Quality Guidelines](./quality-guidelines.md) | API compatibility, feature macros, regression targets, and optimization rules | Filled |
| [Logging Guidelines](./logging-guidelines.md) | RTKLIB trace levels, trace files, and sensitive data rules | Filled |

---

## How to Use These Guidelines

Before modifying RTKLIB core or command-line code:

1. Read [Directory Structure](./directory-structure.md) to identify the owning module
2. Read [Quality Guidelines](./quality-guidelines.md) before optimization or API changes
3. Read [Error Handling](./error-handling.md) and [Logging Guidelines](./logging-guidelines.md) when touching return codes, diagnostics, trace output, or user messages
4. Read [Database Guidelines](./database-guidelines.md) when touching options, file-backed data, generated files, or configuration state

The goal is to preserve actual RTKLIB behavior and conventions while making targeted improvements.

---

**Language**: All documentation should be written in **English**.
