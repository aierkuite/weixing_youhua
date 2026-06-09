# GUI Component Guidelines

> GUI components are VCL forms/dialogs or Qt widgets/dialogs, not React-style components.

---

## Overview

Keep GUI classes focused on user interaction, option editing, file selection, visualization, and calling RTKLIB library functions. Do not duplicate core processing algorithms inside form event handlers.

---

## VCL Component Structure

VCL files include `vcl.h`, the RTKLIB header where needed, and the dialog header. They use C++ Builder pragmas and resource declarations.

```cpp
#include <vcl.h>
#pragma hdrstop

#include "rtklib.h"
#include "aboutdlg.h"

#pragma package(smart_init)
#pragma resource "*.dfm"
TAboutDialog *AboutDialog;
```

Constructors usually delegate to the base `TForm` constructor, and user actions are handled by `__fastcall` methods:

```cpp
__fastcall TAboutDialog::TAboutDialog(TComponent* Owner)
    : TForm(Owner)
{
}

void __fastcall TAboutDialog::BtnOkClick(TObject *Sender)
{
    Close();
}
```

---

## Qt Component Structure

Qt classes use generated UI members, `Q_OBJECT` in headers, and signal-slot connections in constructors or setup routines.

```cpp
connect(BtnDownload,SIGNAL(clicked(bool)),this,SLOT(BtnDownloadClick()));
connect(DataType,SIGNAL(currentIndexChanged(int)),this,SLOT(DataTypeChange()));
connect(&Timer,SIGNAL(timeout()),this,SLOT(TimerTimer()));
```

Keep existing old-style `SIGNAL()` and `SLOT()` syntax unless a task explicitly modernizes a full dialog or app consistently.

---

## Props And Inputs

There are no frontend props. Inputs arrive through UI controls, command-line options, `.ini` files, or selected files. Convert UI state into RTKLIB options at the boundary before invoking core library logic.

Do not make core library code depend on Qt, VCL, `QString`, `AnsiString`, or widget classes.

---

## Styling And Resources

For VCL, visual layout is stored in `.dfm` files. For Qt, visual layout is stored in `.ui` files and resources in `.qrc`.

Avoid hand-editing large generated UI files for small behavior changes. Update the corresponding `.cpp` or `.h` when possible.

---

## Common Mistakes

Do not put long-running processing directly in a UI handler if the existing app already uses a worker thread or timer pattern. `app/qtapp/rtkget_qt/getmain.cpp` uses `DownloadThread`, `QTimer`, and `DownloadFinished()` for download progress.

Do not rename controls without updating all event handlers, saved option keys, and resource files.

Do not change GUI strings or window titles incidentally during source optimization.
