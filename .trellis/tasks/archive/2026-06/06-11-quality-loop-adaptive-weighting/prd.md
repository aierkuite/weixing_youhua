# 质量闭环自适应定权（IGG-III + SNR 随机模型 + 单点抗差）

> 需求来源：仓库根目录 `plan.md`（2026-06-11 grill-me 访谈收敛）。决策已全部拍板，本 PRD 为其任务化收敛版，所有代码锚点已于 2026-06-11 重新勘察核实。

## Goal

把第一阶段"只读诊断"升级为"质量闭环"：观测质量信息（残差分布、SNR）真正反馈进解算定权，同时把现挂在 `--diag` 上的 MAD 抗差降权解耦出来，使诊断回归纯输出、抗差成为独立可控的处理选项。交付 IGG-III 抗差定权（RTK 双差 + 单点）、SNR 随机模型、劣化注入验证工具链与 MATLAB 分析报表；Hatch 载波平滑为 P2 辅方向，可顺延。

## Requirements

### P0 解耦与选项骨架

1. `src/rtklib.h`：`prcopt_t` 尾部新增字段（中文注释）：
   - `int robust;`（0=off，1=IGG-III 抗差定权）
   - `int weightsnr;`（0/1，SNR 随机模型）
   - `int smoothwin;`（0=off，≥2 为 Hatch 平滑窗口历元数，P2 用，先占位）
2. `src/options.c`：`prcopt_default` 补默认值（全 0）；系统选项表新增：
   - `pos2-robust =off|igg3`（仿 options.c:90-111 `pos2-*` 区段写法）
   - `stats-weightsnr =off|on`（跟在 options.c:131 起的 `stats-*` 区段）
   - `pos1-smoothwin` 整数项（P2 用，先占位）
3. `src/rtkpos.c` 解耦：把 `diagresiduals()`（rtkpos.c:285，调用点 :1574）中"修改 Ri/Rj"的抗差逻辑拆出为独立函数 `robustddres()`，由 `opt->robust` 控制、不再依赖 `diag_enabled`；诊断侧只读记录 decision/reason 写 CSV，`--diag` 恢复为纯输出。
4. P0 完成后立即做零回归检查点（见验收标准 AC-1）。

### P1a IGG-III 闭环定权 + SNR 随机模型（主交付）

5. `robustddres()` 将 MAD 标准化残差的两段降权（现 3σ×9 / 6σ×1E6，rtkpos.c:79-82）升级为 IGG-III 三段权函数：
   - `|v̄|≤k0`：权 1（方差不变）
   - `k0<|v̄|≤k1`：方差乘 `1/w`，`w=(k0/|v̄|)·((k1−|v̄|)/(k1−k0))²`
   - `|v̄|>k1`：软剔除（沿用 ×1E6，不改矩阵结构）
   - 默认 `k0=2.0`、`k1=6.0`（`#define` + 中文注释说明取值）；相位/伪距分组与 `vflg` 解析沿用现实现。
6. `varerr()` 加 SNR 项（`weightsnr` 开启时，SIGMA-ε 风格）：`σ_snr²=errsnr²·10^((S_ref−S)/10)`，`S_ref=50 dBHz`、`errsnr=0.3 m`（`#define`）。需改签名传入 SNR：
   - rtkpos.c:765 `varerr()`，调用点 ddres rtkpos.c:1546-1547（流动/基准站各用各的 obs SNR）
   - pntpos.c:48 `varerr()`，调用点 `rescode()`（传 `obs->SNR[0]*SNR_UNIT`）
   - ppp.c 的 `varerr` 是独立同名函数，**不动**。
7. `src/pntpos.c` 单点抗差：`estpos()`（pntpos.c:368）LSQ 收敛后计算标准化残差，`robust` 开启时按 IGG-III 对 `var[]` 重加权再迭代（外层最多 3 轮）；`raim_fde()`（pntpos.c:436）与 `valsol()` 不动。
8. 诊断联动：`sat_diag.csv` 表头（rtkpos.c:377）末尾追加 `var_factor` 列（该星该频实际方差放大倍数，1.0=未降权），追加列向后兼容；`epoch_diag.csv` 不动。

### P1b 注入工具 + MATLAB 分析（验证交付）

9. `tools/matlab/inject_rinex_fault.m`（新建目录）：对 RINEX OBS 按卫星/时段注入伪距阶跃粗差（默认 +30 m）与 SNR 压低（默认 −15 dB），写出新文件；以本项目两组测试数据的 RINEX 版本为准，参数用法写注释。
10. `tools/matlab/compare_solutions.m` + `plot_diag.m`：读 `.pos` 与诊断 CSV，输出指标表（STD/RMS、解状态比例/固定率、残差统计、注入卫星被降权/剔除命中率）和对比图（开/关 × 干净/注入）。
11. 跑满实验矩阵（见验收标准 AC-3/AC-4），用 matlab MCP 实跑脚本核对指标与图。

### P1c Qt 前端同步（console 验证通过后做）

12. `app/qtapp/rtkpost_qt` 选项对话框（`postopt.ui`/`postopt.h`/`postopt.cpp`）新增 Robust 下拉（off/igg3）与 SNR 定权复选框，映射 `prcopt_t.robust`/`weightsnr`；默认 off，不改变现有界面行为。
13. 设置持久化：沿用上任务 `set/diagoutena`、`set/diagdir` 的 QSettings 模式，新增 `set/` 前缀键保存两个开关（`postmain.cpp`/`postmain.h`）。
14. Qt 5.15.2 + MinGW 8.1.0（`D:\QT\5.15.2\mingw81_64`）重编 `rtkpost_qt.exe` 并 GUI 冒烟（见 AC-6）。`smoothwin` 的 GUI 控件不在此阶段做，随 P2 一起。

### P2 Hatch 载波平滑（可顺延到下个任务，不阻塞本任务交付）

15. 自实现 `smoothcode()` 观测预处理（不抄 demo5）：在 `src/postpos.c` 后处理数据流（`execses` 读完观测、解算前）按星/频 Hatch 平滑，窗口 `opt->smoothwin`，LLI/周跳标志/数据中断重置；文档注明平滑同样作用于 RTK 伪距。
16. Qt 选项界面补 `smoothwin` 数值控件并持久化（与 P1c 同模式）。
17. 验证：GEOP 单点开/关 `smoothwin` 的 STD 对比，纳入 MATLAB 报表。

## Acceptance Criteria

> 执行顺序 P0 → P1a → P1b → P1c（P2 视进度），每阶段完成立即跑对应条目再进入下一阶段。

- [ ] **AC-0 基线存档（动工前）**：用未改动代码编译的 rnx2rtkp 跑两组数据（GEOP 单点、0759/3040 RTK），存档基线 `.pos` 供零回归 diff。
- [ ] **AC-1 零回归（P0 后、P1a 后各跑一次）**：开关全关（robust=0、weightsnr=0、smoothwin=0，含开/关 `--diag` 两种情况）跑两组数据，`.pos` 与 AC-0 基线逐字节一致；即 `--diag` 不再改变解算结果。
- [ ] **AC-2 选项生效**：`pos2-robust`/`stats-weightsnr` 在配置文件中可解析、可写回（loadopts/saveopts 往返一致），默认值 off；rnx2rtkp -k 配置驱动两开关。
- [ ] **AC-3 实验矩阵（单点）**：GEOP156M.26o + brdc1560.26n（干净/注入）×（robust+weightsnr 关/开）共 4 组，MATLAB 报表输出 E/N/U 散布 STD/RMS、解状态比例。
- [ ] **AC-4 实验矩阵（RTK）**：`test/data/rinex/07590920.05o`（流动）+ `30400920.05o`（基准）+ 对应 .05n（干净/注入流动站）×（关/开）共 4 组，统计固定率、E/N/U STD/RMS、残差统计。
- [ ] **AC-5 注入实验有效性**：关抗差时定位误差被注入粗差显著拉偏；开抗差时恢复接近干净基线；`sat_diag.csv` 中注入卫星 decision=downweight/reject、`var_factor`>1（注入卫星识别命中）。
- [ ] **AC-6 Qt 一致性**：qmake + mingw32-make 重编 `rtkpost_qt.exe` 成功；GUI 勾选 Robust/SNR 开关跑同组数据，`.pos` 与诊断 CSV 和 console 同配置结果一致；开关默认 off 时 GUI 行为与改动前一致。
- [ ] **AC-7 诊断 CSV 兼容**：`sat_diag.csv` 仅在表头末尾追加 `var_factor`；上一阶段消费脚本（列名读取）不受影响；`epoch_diag.csv` 无变化。
- [ ] **AC-8 卫生检查**：`git diff --check` 干净；测试数据/diag 输出/`.pos`/构建产物不入库（沿用既有排除清单）。
- [ ] **AC-9（仅当 P2 实施）**：GEOP 单点开/关 `smoothwin` 的 STD 对比纳入 MATLAB 报表；`smoothwin=0` 时零回归仍满足 AC-1。

## Definition of Done

- 上述 AC-0~AC-8 全部勾选（AC-9 仅当 P2 实施）。
- 新增 C 代码具备中文注释（总体作用、参数、返回值），遵守 `.trellis/spec/backend/`；Qt 改动遵守 `.trellis/spec/frontend/`。
- MinGW gcc console 构建通过（`app/consapp/rnx2rtkp/gcc/makefile`）；Qt 构建通过。
- MATLAB 脚本经 matlab MCP 实跑验证，指标表 + 图入任务目录归档（不入 git 库的产物除外）。
- 行为变更记录：MAD 降权从 `--diag` 迁出属预期行为变更，在任务交付说明中明示。

## Technical Approach

- **解耦**：`diagresiduals()` 现状（已核实）——rtkpos.c:292 `if (!diag_enabled||nv<=2) return;` 门控，:317-324 直接乘大 Ri/Rj（×9 / ×1E6，常量定义 rtkpos.c:79-82）。拆分后：`robustddres()` 负责改方差（受 `opt->robust` 门控），诊断函数只调 `markdiag()` 记录，不碰 Ri/Rj。
- **IGG-III**：在 MAD 标准化残差 `r=(|v|−med)/σ` 基础上替换两段为三段权函数；软剔除沿用 ×1E6 方差放大，最小侵入不改矩阵结构。
- **SNR 随机模型**：SIGMA-ε 风格加性方差项，仅 `weightsnr=on` 时启用；rtkpos 与 pntpos 两处 `varerr` 改签名传 SNR，ppp.c 不动。
- **单点抗差**：`estpos()` 外层重加权迭代（≤3 轮），复用 IGG-III 函数，对 `var[]` 重加权。
- **验证**：MATLAB 注入 + 对比脚本（本机 MATLAB + MCP 实跑），实验矩阵覆盖 单点/RTK × 干净/注入 × 关/开。

## Decision (ADR-lite)

**Context**: 第一阶段诊断把 MAD 抗差降权挂在 `--diag` 上，导致"开诊断改变解算结果"，无法做对照实验；随机模型缺 SNR 项；单点解无抗差。需求访谈（grill-me，2026-06-11）已对方向、数据、指标、范围逐项拍板，结论记录于 plan.md 决策表。

**Decision**: 主方向为质量闭环定权（IGG-III 抗差 + SNR 随机模型 + 单点抗差迭代），以独立处理选项实现、默认全关、与 `--diag` 解耦；辅方向 Hatch 平滑降为 P2 可顺延；验证采用干净对比 + 劣化注入双路径，MATLAB 工具链分析；Qt 同步开关（P1c），WinApp 不动；不移植 demo5 实现。

**Consequences**:
- 行为变更：`--diag` 不再降权（迁至 `pos2-robust`），属预期且有零回归保障；老用户若依赖"开诊断即抗差"需改用新开关。
- ×1E6 软剔除保持矩阵结构不变，代价是数值上仍参与滤波（量级可忽略）。
- `smoothwin` 字段与选项先占位，P2 顺延时不产生死代码负担（默认 0 = 完全旁路）。
- estpos 抗差为外层重加权而非改 `lsq()` 内部，收敛性风险低，但极端多粗差场景能力弱于严格 M 估计（接受，课程场景够用）。

## Out of Scope

- WinApp（VCL）前端同步——本机无 VCL 工具链，留待后续任务。
- demo5 代码移植（权函数、选项命名、参数结构均自行设计）。
- `raim_fde()`/`valsol()` 改动；ppp.c 的 `varerr`。
- `epoch_diag.csv` 格式变更。
- plan_continue.md 相关收尾项（上阶段已全部完成）。
- P2 Hatch 平滑若进度不足则整体顺延到下个任务（含其 GUI 控件）。

## Technical Notes

### 已核实代码锚点（2026-06-11 勘察）

- `diagresiduals()`：rtkpos.c:285（定义）、:1574（调用）、:292（diag_enabled 门控）、:317-324（直接修改 Ri/Rj）
- 现降权常量：rtkpos.c:79-82（DIAG_LIGHT_SIGMA 3.0 / DIAG_HEAVY_SIGMA 6.0 / DIAG_DOWNWEIGHT_FACTOR 9.0 / DIAG_REJECT_FACTOR 1E6）
- `varerr()`：rtkpos.c:765（定义）、:1546-1547（ddres 调用）；pntpos.c:48（定义）
- `snrmask()`：pntpos.c:76（SNR 现仅作硬门限）；`estpos()`：pntpos.c:368（plan.md 原写 382-433 为函数体行号，函数头在 368）；`raim_fde()`：pntpos.c:436
- options.c 选项表：`pos2-*` 区段 :90-111，`stats-*` 区段 :131 起
- `sat_diag.csv` 表头：rtkpos.c:377，现 17 列（time…reason），`var_factor` 追加为第 18 列
- 测试数据已确认在位：`test/data/rinex/{07590920.05o,07590920.05n,30400920.05o,30400920.05n}`；GEOP156M.26o + brdc1560.26n 在 `app/consapp/rnx2rtkp/gcc/`（未入库）
- Qt 文件已确认在位：`app/qtapp/rtkpost_qt/{postopt.ui,postopt.h,postopt.cpp,postmain.cpp,postmain.h}`

### 约束

- 默认行为零变化：开关全关 = 原版解算 + 纯诊断输出。
- 源码根：`RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/`；console 构建 MinGW gcc makefile；Qt 构建 Qt 5.15.2 + MinGW 8.1.0（`D:\QT\5.15.2\mingw81_64`）。
- 测试数据/诊断输出/`.pos`/构建产物不入 git。
- 参考：`plan.md`（需求全文）、`.trellis/spec/backend/`、`.trellis/spec/frontend/`。
