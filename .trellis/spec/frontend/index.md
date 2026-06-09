# GUI Development Guidelines

> RTKLIB Windows VCL and Qt desktop application guidelines.

---

## Overview

This directory maps Trellis `frontend` guidance onto RTKLIB desktop GUI applications under `app/winapp/` and `app/qtapp/`. There is no web frontend in this source tree.

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | VCL and Qt desktop app layout | Filled |
| [Component Guidelines](./component-guidelines.md) | VCL forms, Qt widgets/dialogs, resources, and UI/core boundaries | Filled |
| [Hook Guidelines](./hook-guidelines.md) | GUI event handlers, Qt slots, timers, and worker-thread patterns | Filled |
| [State Management](./state-management.md) | Form state, `.ini` settings, RTKLIB option structs, and stream state | Filled |
| [Quality Guidelines](./quality-guidelines.md) | GUI build targets, saved settings, event wiring, and core/UI separation | Filled |
| [Type Safety](./type-safety.md) | C/C++ boundary discipline across Qt/VCL types and RTKLIB structs | Filled |

---

## How to Use These Guidelines

Before modifying RTKLIB GUI code:

1. Read [Directory Structure](./directory-structure.md) to choose the correct VCL or Qt location
2. Read [Component Guidelines](./component-guidelines.md) and [Hook Guidelines](./hook-guidelines.md) before changing dialogs, event handlers, slots, timers, or worker threads
3. Read [State Management](./state-management.md) before changing `.ini` settings, form state, or RTKLIB option flow
4. Read [Type Safety](./type-safety.md) and [Quality Guidelines](./quality-guidelines.md) before touching C/C++ framework boundaries or GUI build targets

The goal is to preserve desktop workflows and keep GUI code as an orchestration layer over the RTKLIB core.

---

**Language**: All documentation should be written in **English**.
