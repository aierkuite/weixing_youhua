# MW 周跳检测 + 宽巷辅助模糊度解算（RTK）

> 需求来源：`plan.md`（grill-me 需求访谈收敛，2026-06-13）。决策已全部拍板，见 Decision (ADR-lite)。
> 上一阶段（质量闭环自适应定权 + Hatch 平滑）已归档：
> `.trellis/tasks/archive/2026-06/06-12-hatch-smoothing-robust-grouping/`、
> `.../06-11-quality-loop-adaptive-weighting/`。本任务在其交付状态之上增量开发。

## Goal

为 RTKLIB 2.4.3 b34 的 **RTK 相对定位**路径补两块互相协同的能力，均默认 off、可独立开关、最坏情况退化为原版行为：

1. **MW 宽巷周跳检测**：现有 RTK 周跳检测只有 `detslp_ll`（LLI）与 `detslp_gf`（几何无关相位），`detslp_dop`（多普勒）自 v2.3.0 起 `#if 0` 禁用。GF 有固有盲区——L1/L2 同向等量跳变（典型 L1+9/L2+7 周）使 GF 残差不超阈而漏检。新增站间单差 Melbourne–Wübbena 组合检测覆盖宽巷型跳变。
2. **MW 宽巷辅助 AR**：`resamb_LAMBDA` 把所有频点 DD 模糊度一次性堆给 LAMBDA，未利用宽巷波长长（λ_WL≈0.86 m ≫ L1≈0.19 m）易固定的特性。新增级联 WL→NL：先以 MW 整数宽巷约束降维、固窄巷，置信不足/失败回退原版 LAMBDA。

协同点：MW 宽巷组合算一次，既供周跳检测，又为宽巷辅助 AR 提供整数宽巷模糊度（`ssat[].mwm/mwc` 平滑态两方共用）。

## Requirements

### P0 选项骨架 + 零回归基线

1. `src/rtklib.h`：`prcopt_t` 尾部新增 `int slipmw;`（0=off/1=启用 MW 宽巷周跳检测）、`int arwl;`（0=off/1=启用宽巷辅助 AR），中文注释。
2. `ssat_t`：复用已有 `double mw[NFREQ-1]`（rtklib.h:1128，原 PPP 用）；新增 `double mwm[NFREQ-1];`（MW 滑动均值，m）、`uint32_t mwc[NFREQ-1];`（MW 平滑计数）。
3. `src/options.c`：`prcopt_default` 补默认值（全 0）；系统选项表新增 `pos2-slipmw =off|on`、`pos2-arwl =off|on`（仿 :112 `pos2-robust` 写法）。
4. 零回归基线：在动手改本任务代码**之前**，用**现有代码**（= 上一阶段 06-12 交付、本任务尚未改动的状态）MinGW gcc 编译 rnx2rtkp，跑 RTK 数据存档基线 `.pos`。此基线 = 上阶段结束状态（**非原版 RTKLIB**）；后续各阶段「两开关全关」时的 `.pos` 须与之逐字节一致。（默认 off 的开关不改变数值，故 P0 加完开关后再编出的「全关」`.pos` 应与此基线一致。）

### P1 MW 宽巷周跳检测（交付一）

5. `src/rtkpos.c` 新增 `mwobs()`：站间单差 MW 组合，仿 `gfobs`（:857）。公式（参考 `ppp.c:mwmeas` :357，改单差）：
   `MW = (L1_sd − L2_sd)·c/(f1−f2) − (f1·P1_sd + f2·P2_sd)/(f1+f2)`，`L*_sd/P*_sd` 用现成 `sdobs()`（:850）取流动−基准单差，返回单位 m。观测缺失返回 0.0。
6. `src/rtkpos.c` 新增 `detslp_mw()`：仿 `detslp_gf`（:1139）。
   - 计算当前 SD MW；用 `ssat[].mwm[]` 维护滑动均值 `mwm = mwm + (mw−mwm)/min(mwc,N)`（N=`#define MWSMOOTHWIN 20`），`mwc` 计数；
   - `|mw − mwm| > MWSLIPTHRES`（`#define`，单位 m，默认对应约 4 个宽巷周 ≈ 3.45 m；中文注释写明 λ_WL 换算，**可调**，靠 P3 误报率校准）时判周跳：置 `ssat[].slip[0]|=1; slip[k]|=1;`，重置 `mwm/mwc`，调 `markdiag(sat,0/k,RTKDIAG_SLIP_RISK,"cycle_slip_mw")`，`errmsg` 记录；
   - LLI/数据中断/已判周跳时重置 MW 平滑态。
7. 接入 `udbias()`：在 `detslp_gf` 调用点（:1214）之后插 `if (opt->slipmw||opt->arwl) detslp_mw(...)`。MW 平滑态被 P2 复用，故**任一开关开启都维护**；但**仅 `opt->slipmw` 开启时才置周跳标志/写诊断**，`arwl` 单开仅累计 MW、不改检测行为；两开关全关完全不执行（零回归）。
8. MW 周跳经 `markdiag` 写入 `sat_diag.csv` 的 decision/reason（机制已存在，**表头不变**，向后兼容）。

### P2 宽巷辅助 AR（交付二）

9. `src/rtkpos.c` 宽巷整数估计：在 `resamb_LAMBDA`（:1852）内 `ddidx()`（调用点 :1869）取得 DD 配对后，对每个 DD：取各历元累计的 SD MW 平滑值 `ssat[].mwm[]`（m）做星间 DD，除以 λ_WL=c/(f1−f2)（GPS L1/L2≈0.862 m）得宽巷浮点模糊度 `N_WL_float`（周）；四舍五入 `N_WL=round(N_WL_float)`，置信检验：`|frac|<WLFRACTHRES`（`#define`，默认 0.25）且 `mwc≥MWMINLOCK`（`#define`，默认 10）。
10. 级联固定：
    - 所有参与 DD 的宽巷均通过置信检验 → 以 `N1−N2=N_WL` 约束，LAMBDA 只解窄巷/N1（降维），固定后由宽巷反推 N2；
    - 任一宽巷置信不足 或 级联固定/ratio 验证失败 → **回退原版 `resamb_LAMBDA` 全频路径**（宽巷逻辑包在 `if (opt->arwl && 置信通过)` 内，else 走原代码）。
11. 接入：`opt->arwl` 关闭走原路径（零回归）。宽巷固定数/ratio 仅写 trace(`trace(3,...)`/`errmsg`)，不改 CSV 表头。
12. edge：单频/无双频观测的 DD 不参与宽巷约束，按原路径；`ionoopt==IFLC` 与宽巷 AR 互斥（本阶段实验不开 IFLC）。

### P3 注入工具 + MATLAB 验证（验证交付）

13. `tools/matlab/inject_rinex_fault.m` 扩展：新增「周跳注入」模式，对指定卫星/历元给 L1/L2 载波相位加整周跳（保留原伪距阶跃/SNR 压低）。**内置 GF 盲区组合**（L1+9 周、L2+7 周，使 GF 残差不超默认 `thresslip` 但宽巷组合显著跳变），参数与用法写注释。
14. `tools/matlab/compare_solutions.m` 扩展：读 `.pos`+`sat_diag.csv`，输出本阶段指标表与对比图。
15. 实验矩阵（RTK 0759/3040）：
    - **检测**：注入整周跳（普通型+GF 盲区型）×（slipmw 关/开），统计周跳检测命中率（MW vs GF-only）、误报率；
    - **定位**：干净+注入 ×（arwl 关/开），统计 RTK 固定率、首次固定时间(TTFF)、ratio 分布、E/N/U RMS/STD；
    - **零回归**：新开关全关 vs P0 基线 `.pos` 逐字节 diff。
16. 用 matlab MCP 实跑（桌面未开时 `G:\matlab\bin\matlab.exe -batch` 回退），核对指标与图。

### P4 Qt 前端同步（console 验证通过后做）

17. `app/qtapp/rtkpost_qt`（postopt.ui/.h/.cpp）：新增 MW 周跳检测复选框、宽巷 AR 复选框，映射 `prcopt_t.slipmw/arwl`；默认 off，不改现有界面行为；仿上阶段 robust/weightsnr 控件模式（postopt.cpp:676-678/822-824）。
18. 设置持久化（postmain.cpp/.h）：沿用 `set/robust`、`set/weightsnr` 的 QSettings 模式，新增 `set/slipmw`、`set/arwl`。
19. 构建与冒烟：Qt 5.15.2 + MinGW 8.1.0（`D:\QT\5.15.2\mingw81_64`）重编 `rtkpost_qt.exe`；GUI 勾选开关跑同组数据，确认 `.pos` 与诊断 CSV 和 console 同配置一致。

## Acceptance Criteria

> 执行顺序 P0→P1→P2→P3→P4；每阶段完成立即跑对应验收再进入下一阶段。

- [ ] **AC-1 零回归（P0/每阶段卡点）**：两开关全关（slipmw=off、arwl=off）跑 RTK 0759/3040，`.pos` 与 P0 基线（`baseline/` 下）`cmp` 逐字节一致。
- [ ] **AC-2 选项往返（P0）**：`pos2-slipmw`、`pos2-arwl` 可解析、可写回（loadopts/saveopts 往返一致），默认 off。
- [ ] **AC-3 MW 检测命中 GF 盲区（P1）**：注入 GF 盲区型周跳（L1+9/L2+7），slipmw=off 漏检（GF 不报）、slipmw=on 命中；`sat_diag.csv` 注入星 reason 含 `cycle_slip_mw`。普通型周跳两者均命中。
- [ ] **AC-4 检测不误报（P1）**：干净 RTK 数据 slipmw=on，无在干净历元上的 `cycle_slip_mw` 虚警（误报率相对基线不显著上升，阈值 MWSLIPTHRES 据此校准）。
- [ ] **AC-5 宽巷辅助 AR 生效（P2）**：干净+注入数据、armode=continuous/fix-hold 下 arwl=on vs off，**固定率↑ 或 TTFF↓**，且干净数据 E/N/U RMS 不劣化；置信不足/失败时正确回退原版 LAMBDA、无崩溃。
- [ ] **AC-6 实验矩阵报表（P3）**：MATLAB 出检测命中率表（MW vs GF-only、误报率）+ 定位指标表（固定率/TTFF/ratio/ENU RMS·STD）+ 对比图，入任务目录归档。
- [ ] **AC-7 Qt 一致性（P4）**：qmake+mingw32-make 重编 `rtkpost_qt.exe` 成功；GUI 勾选 slipmw/arwl 跑同组数据 `.pos` 与诊断 CSV 与 console 同配置一致；QSettings 持久化往返；默认 off 时 GUI 行为与改动前一致。
- [ ] **AC-8 卫生检查**：`git diff --check` 干净；测试数据/diag 输出/`.pos`/构建产物不入库（沿用既有排除清单）。

## Definition of Done

- AC-1~AC-8 全部勾选。
- 新增 C 代码具备中文注释（总体作用、参数、返回值），遵守 `.trellis/spec/backend/`；Qt 改动遵守 `.trellis/spec/frontend/`。
- MinGW gcc console 构建通过（配方见记忆 `rtklib-mingw-build-recipe.md` / `baseline/README.md`：先建 `iers.a`，`CC=gcc OPTS="-DWIN32 ..."`，去 `-lrt` 加 `-lwinmm`）；Qt 构建通过（`D:\QT\5.15.2\mingw81_64`）。
- MATLAB 脚本经 matlab MCP 实跑验证（桌面未开时 `G:\matlab\bin\matlab.exe -batch` 回退），指标表+图入任务目录归档。

## Technical Approach

- **MW 单差组合（mwobs）**：复用 `sdobs()` 取流动−基准单差，按 `mwmeas` 公式的单差版计算，返回 m；不重写单差逻辑。
- **MW 检测（detslp_mw）**：仿 `detslp_gf` 的「滑动统计 + 阈值」模式，状态存 `ssat[].mwm/mwc`；接在 `detslp_gf`（udbias :1214）之后，门控 `slipmw||arwl` 维护、`slipmw` 才置标志/写诊断。
- **宽巷级联 AR**：在 `resamb_LAMBDA` 内 `ddidx`（:1737 定义 / :1869 调用）取 DD 后，用 `mwm` 星间 DD/λ_WL 得宽巷浮点→取整→置信检验→约束降维解窄巷；任一环节不过则 `else` 回退原版全频 LAMBDA（`lambda` :1891）。失败回退是硬约束。
- **诊断/日志**：MW 周跳复用 `markdiag`（:300）写 `RTKDIAG_SLIP_RISK`+reason `cycle_slip_mw`，sat_diag.csv 表头不变；宽巷 AR 状态仅 trace，不进 CSV。
- **Qt**：postopt.ui 加两个 QCheckBox，postopt.cpp load/save 双向映射 `slipmw/arwl`，postmain QSettings `set/` 持久化——逐项对照 `state-management.md` 接线清单。
- **验证**：注入工具内置 GF 盲区组合 → 检测对比；实验矩阵分「检测改进」与「定位改进」两轴独立评估（两开关独立设计正为此）；全程两开关全关零回归卡点。

## Decision (ADR-lite)

**Context**: 经代码勘察（detslp_dop 已禁用、GF 盲区、resamb_LAMBDA 全频堆叠）确认两方向空白且协同。2026-06-13 grill-me 访谈与用户拍板。

**Decision**:
1. **只做 RTK 相对定位**（载波相位主战场），SPP 单点不动。
2. **周跳检测 = 现有 GF + 新增 MW 双检测**（GF 抓电离层型、MW 抓宽巷型）。
3. **MW 宽巷辅助 AR**：复用 MW 宽巷整数辅助 LAMBDA，**级联 WL→NL**（带置信检验），失败/置信不足**回退原版 LAMBDA**。
4. **两个独立开关 `pos2-slipmw`/`pos2-arwl`，默认全 off**，便于拆分评估检测改进 vs 定位改进。
5. **诊断联动**：MW 周跳走 `markdiag(reason="cycle_slip_mw")` 复用 `RTKDIAG_SLIP_RISK`，表头不变；宽巷 AR 状态只进 trace。
6. **console 先行，Qt 同步放最后一个子阶段**；不移植 demo5，公式参考原版 `ppp.c:mwmeas`/`rtkpos.c:gfobs/sdobs`，RTK 单差实现自行编写；WinApp 不动。
7. **数据 GPS-only 双频 L1/L2**（test/data/rinex 07590920.05o 流动 + 30400920.05o 基准 + nav）。

**Consequences**:
- 开 slipmw/arwl 行为变化属预期新增能力；两开关全关 = 上阶段结束状态，零回归硬约束。
- 三频不可行：07590920.05o 头 `TYPES OF OBSERV` 为 `L1 C1 L2 P2`（GPS-only 双频，无 L5），TCAR/三频组合排除，多频组合限 L1/L2 宽巷/窄巷。
- MWSLIPTHRES（≈4 WL 周）为初值，靠 P3 误报率校准，可能回调。
- 宽巷级联失败回退保证最坏退化为原版 LAMBDA，正确性兜底。

## Out of Scope

- SPP 单点定位路径的任何改动。
- 三频/TCAR、L5 组合；divergence-free 等其他多频组合。
- demo5 代码移植；WinApp（VCL）前端；`ppp.c` 修改；rtknavi 实时路径。
- `epoch_diag.csv`/`sat_diag.csv` 列格式变更（仅复用既有 decision/reason 机制）。
- IFLC（无电离层组合）模式下的宽巷 AR（与本阶段互斥，实验不开）。

## Technical Notes

### 已核实代码锚点（2026-06-13 勘察，rtkpos.c 除注明外）

- `sdobs()` :850（单差取值，mwobs 复用）；`gfobs()` :857（单差 GF，mwobs/detslp_mw 仿其结构）。
- `detslp_ll()` :1088；`detslp_gf()` :1139；`detslp_dop()` :1164（其体 :1167 `#if 0` 禁用，钟跳问题）。
- `udbias()` :1198；其中 `detslp_ll` 调用 :1210/1211、**`detslp_gf` 调用 :1214（detslp_mw 接入点，插其后）**、`detslp_dop` 调用 :1217/1218（在 #if 0 内不生效）。
- `ddidx()` **定义 :1737**（plan.md「可复用实现」误记为 :1869——:1869 实为 resamb_LAMBDA 内对 ddidx 的**调用点**）；`resamb_LAMBDA()` :1852；`lambda()` 调用 :1891。
- `markdiag()` :300；`RTKDIAG_SLIP_RISK` 枚举（rtklib.h:901，"周跳风险"）；既有 reason 串先例：cycle_slip_lli(:1110/1118/1127)、cycle_slip_gf(:1156/1157)、cycle_slip_doppler(:1190)。
- `mwmeas()` ppp.c:357（零差 MW 公式参考，改单差）。
- `ssat_t.mw[NFREQ-1]` rtklib.h:1128（原 PPP 用，本任务复用 + 新增 mwm/mwc）。

### 约束与环境

- 零回归方法：`baseline/` 下基线 `.pos` 用 `cmp` 逐字节；rnx2rtkp 输入路径必须**反斜杠**（expath WIN32 陷阱）；`-k` 最小 conf 会把 `pos1-posmode` 重置为 single，RTK 必须显式 `-p 2`（见 `.trellis/spec/backend/database-guidelines.md`）；实验须开 AR（`pos2-armode=continuous` 或 fix-hold），否则 arwl 无作用。
- console 构建配方 `baseline/README.md` + 记忆 `rtklib-mingw-build-recipe.md`；Qt 构建 `D:\QT\5.15.2\mingw81_64`；MATLAB 桌面未开时 `G:\matlab\bin\matlab.exe -batch`（记忆 `matlab-batch-fallback.md`）。
- 源码根 `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/`；测试数据/诊断输出/`.pos`/构建产物不入 git（沿用既有排除清单）。
- 参考：`plan.md`、06-11/06-12 归档 PRD（决策与工具链上下文）、`.trellis/spec/backend/`、`.trellis/spec/frontend/`。
