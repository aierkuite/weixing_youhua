# RTKLIB 第二阶段优化计划：质量闭环自适应定权（主）+ Hatch 载波平滑（辅）

> 本计划由 grill-me 需求访谈收敛产出（2026-06-11），作为下一个 Trellis 任务的需求来源文档。
> 执行入口见文末「执行流程」。

## Context

项目基于原版 RTKLIB 2.4.3 b34（`RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/`）做课程优化。第一阶段已交付"可解释观测质量诊断"：`rnx2rtkp --diag` 输出 `epoch_diag.csv`/`sat_diag.csv`（quality_score/decision/reason），并同步到 WinApp 与 Qt 前端。上一阶段收尾项（plan_continue.md）已全部完成，本计划不再涉及。

第二阶段要解决的问题（均经代码勘察确认）：

1. **诊断与抗差耦合**：MAD 抗差降权挂在 `--diag` 上——`diagresiduals()`（rtkpos.c:285，调用点 rtkpos.c:1574）仅在 `diag_enabled` 时放大测量方差（≥3σ ×9，≥6σ ×1E6），即"开诊断会改变解算结果"，无法做"只看诊断不改解"的对照。
2. **随机模型无 SNR**：`varerr()`（rtkpos.c:765、pntpos.c:48）只有高度角项 `a²+b²/sin²el`，SNR 仅作硬门限（pntpos.c:76 snrmask）；quality 信息没有反馈进定权。
3. **单点解无抗差**：`estpos()`（pntpos.c:382-433）为普通迭代加权 LSQ；`raim_fde()`（pntpos.c:436）只能单故障剔除。
4. **伪距未做载波平滑**。

已拍板的决策：

| 决策点 | 结论 |
|---|---|
| 主方向 | 质量评分闭环定权：IGG-III 抗差 + SNR 随机模型 + 单点抗差迭代，与 `--diag` 解耦 |
| 辅方向 | Hatch 载波平滑伪距，**P2 优先级，可顺延到下个任务** |
| 验证数据 | 双路径：单点 GEOP156M.26o + brdc1560.26n；RTK 用 repo 自带 `test/data/rinex/07590920.05o`（流动）+ `30400920.05o`（基准）+ 对应 nav |
| 实验设计 | 干净数据对比 + **劣化注入实验**（人工伪距粗差/压 SNR，看抗差恢复能力） |
| 指标 | E/N/U 散布 STD/RMS、解状态比例与 RTK 固定率、残差统计与注入卫星识别命中率、零回归（开关全关输出与改动前一致） |
| 分析工具链 | MATLAB 脚本（本机有 MATLAB + MCP 可直接运行） |
| 开关设计 | 新增独立处理选项，默认全关；`--diag` 回归纯输出（行为变更：MAD 降权从 `--diag` 迁出） |
| 范围 | 注入工具入库；**Qt rtkpost_qt 同步新开关（P1c）**，WinApp 不动（本机无 VCL 工具链）；不移植 demo5 实现 |

## 实现步骤

### P0 解耦与选项骨架

1. **`src/rtklib.h`**：`prcopt_t` 尾部新增字段（中文注释）：
   - `int robust;`（0=off，1=IGG-III 抗差定权）
   - `int weightsnr;`（0/1，SNR 随机模型）
   - `int smoothwin;`（0=off，≥2 为 Hatch 平滑窗口历元数，P2 用）
2. **`src/options.c`**：`prcopt_default` 补默认值（全 0）；系统选项表新增：
   - `pos2-robust =off|igg3`（仿 :90-111 的 `pos2-*` 写法）
   - `stats-weightsnr =off|on`（跟在 :131-135 `stats-*` 区段）
   - `pos1-smoothwin` 整数项（P2 用，先占位）
3. **`src/rtkpos.c` 解耦**：把 `diagresiduals()` 中"修改 Ri/Rj"的抗差逻辑拆出为独立函数（如 `robustddres()`），由 `opt->robust` 控制、不再依赖 `diag_enabled`；诊断侧只读记录 decision/reason 写 CSV。`--diag` 恢复为纯输出。
4. 此步完成后立即做**零回归检查点**：开关全关跑两组数据，`.pos` 输出与改动前完全一致。

### P1a IGG-III 闭环定权 + SNR 随机模型（主交付）

5. **`src/rtkpos.c` `robustddres()`**：MAD 标准化残差升级为 IGG-III 三段权函数（替代现 3σ/6σ 两段）：
   - `|v̄|≤k0`：权 1（方差不变）
   - `k0<|v̄|≤k1`：方差乘 `1/w`，`w=(k0/|v̄|)·((k1−|v̄|)/(k1−k0))²`
   - `|v̄|>k1`：软剔除（沿用 ×1E6，不改矩阵结构，最小侵入）
   - 默认 `k0=2.0`、`k1=6.0`（`#define` + 中文注释说明取值）；相位/伪距分组与 `vflg` 解析沿用现实现。
6. **`varerr()` 加 SNR 项**（`weightsnr` 开启时，SIGMA-ε 风格）：`σ_snr²=errsnr²·10^((S_ref−S)/10)`，`S_ref=50 dBHz`、`errsnr=0.3 m`（`#define`）。需改签名传入 SNR：
   - rtkpos.c:765 `varerr()`，调用点 ddres rtkpos.c:1546-1547（流动/基准站各用各的 obs SNR）
   - pntpos.c:48 `varerr()`，调用点 `rescode()`（传 `obs->SNR[0]*SNR_UNIT`）
   - ppp.c 的 `varerr` 是独立函数，**不动**。
7. **`src/pntpos.c` 单点抗差**：`estpos()` LSQ 收敛后计算标准化残差，`robust` 开启时按 IGG-III 对 `var[]` 重加权再迭代（外层最多 3 轮）；`raim_fde()`/`valsol()` 不动。
8. **诊断联动**：`sat_diag.csv` 表头末尾追加 `var_factor` 列（该星该频实际方差放大倍数，1.0=未降权），追加列向后兼容；`epoch_diag.csv` 不动。

### P1b 注入工具 + MATLAB 分析（验证交付）

9. **`tools/matlab/inject_rinex_fault.m`**：对 RINEX OBS 按卫星/时段注入伪距阶跃粗差（默认 +30 m）与 SNR 压低（默认 −15 dB），写出新文件；以本项目两组测试数据的 RINEX 版本为准，参数用法写注释。
10. **`tools/matlab/compare_solutions.m` + `plot_diag.m`**：读 `.pos` 与诊断 CSV，输出指标表（STD/RMS、解状态比例/固定率、残差统计、注入卫星被降权/剔除命中率）和对比图（开/关 × 干净/注入）。
11. **实验矩阵**：
    - 单点：GEOP 数据（干净/注入）×（robust+weightsnr 关/开）
    - RTK：0759/3040 样例（干净/注入流动站）×（关/开），统计固定率与残差
    - 零回归：开关全关 vs 改动前基线 `.pos` 逐字节 diff（两组数据）
12. 用 matlab MCP 实跑脚本，核对指标与图。

### P1c Qt 前端同步（console 验证通过后做）

13. **`app/qtapp/rtkpost_qt` 选项界面**：选项对话框（`postopt.ui`/`postopt.h`/`postopt.cpp`）新增 Robust 下拉（off/igg3）与 SNR 定权复选框，映射 `prcopt_t.robust`/`weightsnr`；默认 off，不改变现有界面行为。
14. **设置持久化**：沿用上个任务 `set/diagoutena`、`set/diagdir` 的 QSettings 读写模式，新增 `set/` 前缀键保存两个开关（`postmain.cpp`/`postmain.h`）。
15. **构建与冒烟**：用已打通的 Qt 5.15.2 + MinGW 8.1.0 工具链（`D:\QT\5.15.2\mingw81_64`）重编 `rtkpost_qt.exe`；GUI 冒烟验证：勾选开关跑同组数据，确认 `.pos` 与诊断 CSV 和 console 同配置结果一致。
16. `smoothwin` 的 GUI 控件不在此阶段做，随 P2 一起。

### P2 Hatch 载波平滑（可顺延，不阻塞交付）

17. 实现 `smoothcode()` 观测预处理（自行实现，不抄 demo5）：在 `src/postpos.c` 后处理数据流（`execses` 读完观测、解算前）对整段 obs 按星/频 Hatch 平滑，窗口 `opt->smoothwin`，LLI/周跳标志/数据中断重置；说明文档注明平滑同样作用于 RTK 伪距。
18. Qt 选项界面补 `smoothwin` 数值控件并持久化（与 P1c 同模式）。
19. 验证：GEOP 单点开/关 `smoothwin` 的 STD 对比，纳入 MATLAB 报表。

## 关键文件

- `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/src/rtklib.h` — prcopt_t 新字段
- `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/src/options.c` — 选项表 + 默认值
- `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/src/rtkpos.c` — 解耦、robustddres、varerr
- `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/src/pntpos.c` — varerr、estpos 抗差迭代
- `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/src/postpos.c`（仅 P2 Hatch）
- `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/app/qtapp/rtkpost_qt/postopt.ui`/`.h`/`.cpp`、`postmain.cpp`/`.h` — Qt 开关与持久化（P1c）
- `tools/matlab/`（新建）— 注入工具 + 分析脚本

## 验证方法（执行时逐项）

1. **动工前先存基线**：用未改动代码编译的 rnx2rtkp 跑两组数据，存档基线 `.pos` 供零回归 diff
2. MinGW gcc 重编 console：`app/consapp/rnx2rtkp/gcc/makefile`
3. 零回归：开关全关，两组数据 `.pos` 与基线 diff 一致
4. 跑满实验矩阵（P1b 第 11 条），MATLAB 出指标表 + 图
5. 注入实验预期：关抗差时误差被粗差拉偏，开抗差时恢复接近干净基线，且 `sat_diag.csv` 中注入卫星 decision=downweight/reject、var_factor>1
6. Qt：qmake + mingw32-make 重编 `rtkpost_qt.exe` 成功；GUI 勾选开关跑同组数据，与 console 同配置结果一致
7. `git diff --check`；测试数据/diag 输出/`.pos`/构建产物不入库（沿用既有排除清单）

## 约束

- 不移植 demo5 代码；权函数、选项命名、参数结构自行设计
- 默认行为零变化：开关全关 = 原版解算 + 纯诊断输出
- 新增 C 代码中文注释（总体作用、参数、返回值），遵守 `.trellis/spec/backend/`；Qt 改动遵守 `.trellis/spec/frontend/`
- Qt 只暴露已实现的开关（P1c 做 robust/weightsnr，P2 再加 smoothwin）；WinApp 本次不动，留待后续任务
- 不考虑 plan_continue.md（已完成）

## 执行流程（Trellis）

1. `python ./.trellis/scripts/task.py create "质量闭环自适应定权"` 创建任务
2. 用 trellis-brainstorm 把本计划收敛成任务 prd.md（决策已定，重点是核对验收标准）
3. `task.py start <task-dir>` 进入实现，按 P0 → P1a → P1b → P1c 顺序执行（P2 视进度）
4. 每个阶段完成后立即跑「验证方法」中对应条目，再进入下一阶段
