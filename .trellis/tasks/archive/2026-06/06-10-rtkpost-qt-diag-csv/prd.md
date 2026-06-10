# RTKPOST Qt 修复与诊断 CSV 前端

## Goal

修复 `app/qtapp/rtkpost_qt` 在 Windows + Qt 5.15.2 + MinGW 8.1.0 工具链下的编译问题，并把 WinApp RTKPOST 已有的 `Diag CSV` 前端能力同步到 Qt 界面。该任务只让 Qt RTKPOST 能编译、能从界面启用诊断 CSV 输出，不改 `src/rtkpos.c` 里的诊断算法和 CSV 格式。

## What I already know

* 用户提供的 `plan_QT.md` 已限定任务范围：只处理 `rtkpost_qt`，不一次性修复所有 Qt App
* 目标工具链是 `D:\QT\5.15.2\mingw81_64\bin\qmake.exe` 和 `D:\QT\Tools\mingw810_64\bin\mingw32-make.exe`
* 当前 Qt 工程 `app/qtapp/rtkpost_qt/rtkpost_qt.pro` 引用 `../appcmn_qt/aboutdlg.*`，但实际文件在 `../appcmn_qt/appcmn_qt/aboutdlg.*`
* 当前 `app/qtapp/rtkpost_qt/postmain.h`、`postmain.cpp`、`postopt.h` 等仍引用旧的 `exterr_t` / `prcopt.exterr` 相关字段，当前核心 `rtklib.h` 已不提供这些接口
* WinApp RTKPOST 已实现 `DiagOutEna`、`DiagDir`、`BtnDiagDir`、`diagoutena`、`diagdir` 配置读写，以及 `rtkopendiag()` / `rtkclosediag()` 调用
* console `rnx2rtkp` 已支持并验证过 `--diag dir`，它只作为诊断接口行为参考，不属于本次 Qt 命令行功能范围
* 核心 `src/rtkpos.c` 当前输出 `epoch_diag.csv` 和 `sat_diag.csv`

## Requirements

* 修复 `rtkpost_qt.pro` 中 `appcmn_qt` 相关源文件、头文件、UI 文件路径，使 Qt 版 RTKPOST 可以找到实际存在的公共 Qt 组件
* 补齐或调整 RTKLib 静态库构建/链接入口，使 `rtkpost_qt.pro` 在 Windows + MinGW 下稳定链接 `libRTKLib.a`
* 保持 Qt Widgets + MinGW 目标，不引入 MSVC、C++Builder 或 VCL 依赖
* 移除或隔离 `exterr_t`、`ExtErr`、`prcopt.exterr` 旧接口引用，使 Qt 代码匹配当前 b34 核心接口
* 旧 ini 中 `exterr_*` 配置可以忽略，不能导致程序启动、配置读写或定位处理失败
* 在 Qt RTKPOST 主界面增加 `Diag CSV` 启用控件、输出目录输入框和浏览按钮
* Diag CSV 设置使用 Qt 现有 `QSettings` 风格保存到 `set/diagoutena`、`set/diagdir`
* 默认关闭诊断输出
* 未选择诊断目录时，按 WinApp 语义选择默认目录：优先使用输出目录，其次使用输出结果文件所在目录，最后使用当前工作目录
* 运行 `postpos()` 前按启用状态调用 `rtkopendiag(diagdir)`，结束后确保调用 `rtkclosediag()`
* 诊断打开失败时显示 `error : diagnostic output open error`，并且不继续执行定位处理
* 不改变 WinApp 已有行为
* 不修改核心定位算法或诊断 CSV 字段格式
* 不提交构建产物、测试输出或临时 RINEX/result 文件

## Acceptance Criteria

* [ ] 使用指定 Qt 5.15.2 + MinGW 工具链，`rtkpost_qt.exe` 能成功生成
* [ ] `rtkpost_qt` 编译不再出现 `appcmn_qt` 文件路径找不到错误
* [ ] `rtkpost_qt` 编译不再出现 `exterr_t`、`ExtErr` 或 `prcopt.exterr` 相关错误
* [ ] 主界面显示 `Diag CSV` 启用控件、目录输入框和浏览按钮
* [ ] `Diag CSV` 未启用时运行不生成 `epoch_diag.csv` / `sat_diag.csv`
* [ ] `Diag CSV` 启用并选择目录后，运行同一组 RINEX/NAV 测试数据生成 `epoch_diag.csv` 和 `sat_diag.csv`
* [ ] 未选择诊断目录时，输出目录/结果文件目录/当前工作目录 fallback 行为与 WinApp 语义一致
* [ ] 生成的诊断 CSV 文件名和表头与已验证的 console `rnx2rtkp --diag` 保持一致
* [ ] WinApp RTKPOST、console `rnx2rtkp --diag` 行为不因本任务回退

## Definition of Done

* 代码改动限于 Qt RTKPOST、Qt 工程配置、必要的 Qt 构建入口
* 本机完成 qmake + mingw32-make 编译验证，或记录无法验证的具体环境原因
* 至少执行一次 Diag CSV 启用/关闭行为验证，或记录缺少测试数据/GUI 环境的原因
* 检查 `git status`，避免误提交 build 目录、RINEX 测试数据、CSV 输出和 result 文件
* 若实现过程中发现可复用的 Qt/RTKLIB 约定，按 Trellis 流程评估是否更新 spec

## Technical Approach

首选直接复刻 WinApp RTKPOST 的 Diag CSV 前端语义到 Qt 版，而不是新增核心开关或重写诊断算法。Qt 侧只负责 UI 状态、ini 设置、目录选择、默认目录解析，以及在后台处理线程调用 `postpos()` 前后管理诊断输出生命周期。

构建修复先以 `rtkpost_qt` 单应用为目标：修正 `rtkpost_qt.pro` 的公共组件路径和静态库链接路径；如 `libRTKLib.a` 不存在，则补齐使用现有 `app/qtapp/RTKLib.pro` 或相邻项目约定构建静态库的入口。

旧扩展误差配置采用删除/隔离策略：不把废弃 `exterr_*` 配置读回不存在的核心字段，不在本任务重新设计扩展误差模型。

## Decision (ADR-lite)

**Context**: Qt RTKPOST 落后于当前核心接口，同时 WinApp/console 已经证明诊断 CSV 能通过 `rtkopendiag()` / `rtkclosediag()` 接入。

**Decision**: 本任务采用前端同步和构建修复方式，只修 `rtkpost_qt` 需要的 UI、配置和调用路径，不碰核心诊断算法。

**Consequences**: Qt 版会恢复与当前 b34 核心的兼容性，并获得与 WinApp/console 同语义的 Diag CSV 输出；旧 `exterr_*` ini 配置会被忽略，不再作为 Qt 版功能保留。

## Out of Scope

* 不修改 `src/rtkpos.c` 诊断算法、评分规则、CSV 字段或文件名
* 不重做 `exterr_t` 扩展误差模型
* 不修复全部 Qt App，只处理 `rtkpost_qt` 编译所需的最小公共组件路径/库链接问题
* 不迁移 WinApp 的其他新增 UI 功能
* 不提交或维护测试数据、构建目录、生成的 `.pos`、`.csv`、`.o`、`.a` 等产物

## Technical Notes

* Source plan: `plan_QT.md`
* Qt RTKPOST project: `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/app/qtapp/rtkpost_qt/rtkpost_qt.pro`
* Qt RTKPOST main UI/code: `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/app/qtapp/rtkpost_qt/postmain.ui`, `postmain.h`, `postmain.cpp`
* WinApp reference implementation: `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/app/winapp/rtkpost/postmain.cpp`, `postmain.h`, `postmain.dfm`
* Console reference implementation: `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/app/consapp/rnx2rtkp/rnx2rtkp.c`
* Core diagnostic API declarations: `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/src/rtklib.h`
* Core diagnostic implementation: `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/src/rtkpos.c`
* Relevant Trellis specs: `.trellis/spec/frontend/index.md`, `.trellis/spec/backend/index.md`
