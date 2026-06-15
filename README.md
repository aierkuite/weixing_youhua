# RTKLIB GNSS/RTK 课程优化实验仓库

本仓库基于 RTKLIB 2.4.3 b34，用于《卫星定位导航系统原理及应用》相关课程实验和源码优化。当前重点是保留 RTKLIB 原有后处理能力，同时补充可解释观测质量诊断、抗差定权、SNR 随机模型和 Hatch 载波平滑等实验功能。

原版 RTKLIB 说明仍保留在 `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/readme.txt`，本 README 只说明本仓库的二次开发结构、构建方式和常用验证流程。

## 当前增强能力

| 能力 | 入口 | 说明 |
|---|---|---|
| 观测质量诊断 CSV | `rnx2rtkp --diag <dir>` | 输出 `epoch_diag.csv` 和 `sat_diag.csv`，记录质量评分、决策、原因、方差放大因子等 |
| IGG-III 抗差定权 | `pos2-robust = igg3` | 在 SPP/RTK 相关残差路径中对异常观测降权或软剔除 |
| SNR 随机模型 | `stats-weightsnr = on` | 按信噪比调整观测方差 |
| Hatch 载波平滑 | `pos1-smoothwin = <N>` | 后处理时按接收机、卫星、频点维护伪距平滑窗口 |
| Qt rtkpost 选项同步 | `app/qtapp/rtkpost_qt` | GUI 中同步暴露抗差、SNR 定权和平滑窗口设置 |
| MATLAB 验证工具 | `tools/matlab` | 支持 RINEX 故障注入、解算指标汇总和诊断图绘制 |

默认配置保持保守：新增处理开关默认关闭或为 0，便于做零回归对比。

## 目录结构

```text
.
├── .gitignore                           # Git 忽略规则
├── README.md                            # 仓库说明文档
├── RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/  # 主要二次开发源码
│   ├── src/                             # RTKLIB 核心 C 库
│   ├── app/consapp/rnx2rtkp/            # 后处理命令行入口
│   ├── app/qtapp/rtkpost_qt/            # Qt 版后处理 GUI
│   ├── lib/iers/                        # IERS 静态库源码和 makefile
│   └── test/data/                       # RTKLIB 自带测试数据
└── tools/matlab/                        # 实验注入、指标统计、绘图脚本
```

工作树中可能还会出现 `baseline/`、`plan.md`、`RTKLIB-2.5.0/`、`RTKLIB_bin-rtklib_2.4.3/`、课程 PDF/DOCX 或 Office 临时锁文件。这些是参考资料、实验产物或本地材料，不是当前远端仓库结构的一部分。

## 环境要求

已验证的主环境是 Windows：

* PowerShell
* MinGW GCC/GFortran 8.1.0，例如 `D:\QT\Tools\mingw810_64\bin`
* MATLAB，用于运行 `tools/matlab` 下的辅助脚本
* 可选：Qt 5.15.2 + MinGW 8.1.0，用于构建 `rtkpost_qt`

原始 makefile 偏 Unix，Windows 下构建 `rnx2rtkp` 时需要覆盖 `CC`、`OPTS` 和 `LDLIBS`。

## 构建 rnx2rtkp

在仓库根目录执行：

```powershell
$env:Path = "D:\QT\Tools\mingw810_64\bin;$env:Path"

mingw32-make -C RTKLIB-2.4.3-b34\RTKLIB-2.4.3-b34\lib\iers\gcc

mingw32-make -C RTKLIB-2.4.3-b34\RTKLIB-2.4.3-b34\app\consapp\rnx2rtkp\gcc `
  CC=gcc `
  OPTS="-DWIN32 -DTRACE -DENAGLO -DENAQZS -DENAGAL -DENACMP -DENAIRN -DNFREQ=5" `
  LDLIBS="../../../../lib/iers/gcc/iers.a -lgfortran -lm -lwinmm"
```

生成物位于：

```text
RTKLIB-2.4.3-b34\RTKLIB-2.4.3-b34\app\consapp\rnx2rtkp\gcc\rnx2rtkp.exe
```

## 运行示例

以下命令从 `rnx2rtkp` 的 gcc 目录运行：

```powershell
Set-Location RTKLIB-2.4.3-b34\RTKLIB-2.4.3-b34\app\consapp\rnx2rtkp\gcc
```

SPP 示例使用本地放在 gcc 目录下的 RINEX 观测和导航文件：

```powershell
.\rnx2rtkp.exe -p 0 GEOP156M.26o brdc1560.26n `
  -o ..\..\..\..\..\..\baseline\spp_geop.pos
```

RTK 示例使用仓库自带测试数据：

```powershell
.\rnx2rtkp.exe -r -3978241.958 3382840.234 3649900.853 `
  ..\..\..\..\test\data\rinex\07590920.05o `
  ..\..\..\..\test\data\rinex\30400920.05n `
  ..\..\..\..\test\data\rinex\30400920.05o `
  -o ..\..\..\..\..\..\baseline\rtk_0759.pos
```

带诊断 CSV：

```powershell
.\rnx2rtkp.exe -r -3978241.958 3382840.234 3649900.853 `
  ..\..\..\..\test\data\rinex\07590920.05o `
  ..\..\..\..\test\data\rinex\30400920.05n `
  ..\..\..\..\test\data\rinex\30400920.05o `
  -o ..\..\..\..\..\..\baseline\rtk_0759_diag.pos `
  --diag ..\..\..\..\..\..\baseline\diag_rtk
```

Windows 构建下建议输入路径使用反斜杠。RTKLIB 的 `expath()` 在 WIN32 分支中对正斜杠路径兼容较差，可能导致输入文件目录被截断。

## 配置示例

可以在 RTKLIB 配置文件中打开实验开关：

```text
pos2-robust     = igg3
stats-weightsnr = on
pos1-smoothwin  = 30
```

做零回归时应保持这些新增开关关闭：

```text
pos2-robust     = off
stats-weightsnr = off
pos1-smoothwin  = 0
```

## MATLAB 工具

先在 MATLAB 中加入工具目录：

```matlab
addpath("tools\matlab")
```

常用脚本：

| 脚本 | 用途 |
|---|---|
| `inject_rinex_fault.m` | 向 RINEX OBS 注入伪距阶跃粗差和 SNR 压低 |
| `compare_solutions.m` | 读取 `.pos` 和 `sat_diag.csv`，输出固定率、ENU RMS/STD、诊断降权率等指标 |
| `plot_diag.m` | 绘制定位散点和诊断方差因子图 |

示例：

```matlab
metrics = compare_solutions( ...
    "baseline\rtk_0759_diag.pos", ...
    "baseline\diag_rtk\sat_diag.csv", ...
    "OutputCsv", "baseline\rtk_metrics.csv");

fig = plot_diag( ...
    "baseline\rtk_0759_diag.pos", ...
    "baseline\diag_rtk\sat_diag.csv", ...
    "OutputPng", "baseline\rtk_diag.png");
```

## 验证建议

* 新增开关默认关闭时，对同一命令行输出做字节级零回归对比
* 开启 `--diag` 后检查 `epoch_diag.csv`、`sat_diag.csv` 是否生成且表头稳定
* 对抗差/SNR/Hatch 相关改动，至少跑 SPP 和 RTK 两类样例
* 修改 C/Qt 源码后运行 `git diff --check`

Windows 下可用 `fc /b` 做二进制比较：

```powershell
fc /b baseline\rtk_0759.pos path\to\new_rtk_0759.pos
```

## 开发约定

* 核心算法修改优先放在 `src/`，命令行应用保持薄封装
* 新增 RTKLIB 公共函数沿用原项目 banner 注释风格
* 新增 C/MATLAB 代码注释使用中文，并说明函数作用、参数和返回值
* 不提交 `.exe`、`.o`、`.pos`、`.trace`、诊断 CSV、`baseline/` 产物、课程资料原件和本地临时文件
* 修改算法或配置读写逻辑前，先明确零回归样例和对比指标，避免破坏默认关闭开关下的原始行为

## 许可证

RTKLIB 原始许可证见 `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/LICENSE.txt`。本仓库中的 RTKLIB 源码修改应继续遵守原项目许可证；课程报告、实验数据和本地资料按课程要求管理。
