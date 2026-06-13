# Hatch 载波平滑 + 抗差定权分组改进

> 需求来源：06-11 任务交接（PRD P2 顺延项 + check 阶段发现的真实缺陷）。上任务归档：
> `.trellis/tasks/archive/2026-06/06-11-quality-loop-adaptive-weighting/`（含完整决策记录）。
> 三个决策点已于 2026-06-12 brainstorm 拍板，见 Decision (ADR-lite)。

## Goal

一个任务、两个阶段：
- **Phase A 抗差定权分组改进（先行，缺陷修复）**：`robustddres()` 相位+伪距混池 MAD 标准化
  （相位双差残差 mm 级、伪距 m 级），导致干净 RTK 数据开 `pos2-robust=igg3` 后固定率
  1.0→0.12（1450 行中 1056 行被标 reject）。改为按观测类型分池标准化后再 IGG-III，
  目标干净数据固定率恢复接近 1.0，注入实验命中与恢复精度不退化。
- **Phase B Hatch 载波平滑（主体，新功能）**：启用已占位的 `prcopt_t.smoothwin` /
  `pos1-smoothwin`，在 `src/postpos.c` 后处理数据流自实现 `smoothcode()` 观测预处理
  （不抄 demo5），含 Qt smoothwin 控件与 GEOP STD 对比验证。

## Requirements

### Phase A 抗差定权分组改进

1. `residualstats()`（rtkpos.c:264）改造为支持按观测类型过滤的分组统计：相位池
   （`type=(vflg>>4)&0xF == 0`）与伪距池（`type==1`）各自计算 median + MAD；
   池内有效样本 `n<=2` 时跳过该池（不跨池回退、不复用全池统计）。
2. `robustddres()`（rtkpos.c:339）按所属池的 med/sigma 计算标准化残差再做 IGG-III 定权；
   k0/k1 与软剔除 ×1E6 机制不变。
3. `diagresiduals()`（rtkpos.c:378）与 robustddres 一致改为分组标准化，保证诊断 CSV 的
   decision/reason/var_factor 反映真实抗差行为。
4. 仅 `pos2-robust=igg3` 生效路径内行为变化；robust=off 路径与现状完全一致。
5. 复跑 06-11 实验矩阵验证（工具链 tools/matlab/ 三脚本 + 归档 run_p1b_metrics.m；
   原始产物与注入文件 baseline/p1b_artifacts/，clean 基线与 conf 在 baseline/）。

### Phase B Hatch 载波平滑

6. `src/postpos.c` 新增 `smoothcode()`：在 `execses`（postpos.c:903）内 `readobsnav`
   （:943）之后、`procpos` 之前，对全局 `obss` 做观测预处理。
7. 算法：标准递推 Hatch——`P̄_n = P_n/n + (n-1)/n · (P̄_{n-1} + (Φ_n − Φ_{n-1}))`，
   计数 n 逐历元增长、封顶 N=`opt->smoothwin`；按（接收机 rcv × 卫星 × 频点）独立通道，
   多系统（GEOP 为 G/R/E/C/J）自然支持。
8. 重置条件：LLI 非零、载波缺失（L=0）、通道数据中断（同通道相邻历元时间间隔显著超过
   标称采样间隔）时重置计数 n=1（当历元伪距原样）。
9. 生效门控：`smoothwin>=2` 生效；0/1 完全旁路（不触碰 obss，逐字节零回归）。
10. 平滑作用于所有接收机观测（流动+基准），代码注释与交付说明注明平滑同样作用于
    RTK 伪距。
11. Qt `rtkpost_qt` 选项界面（postopt.ui/.h/.cpp）补 smoothwin 数值控件（QSpinBox，
    0=off），映射 `prcopt_t.smoothwin`；QSettings `set/` 前缀持久化，严格沿用上任务
    robust/weightsnr 的接线清单（`.trellis/spec/frontend/state-management.md` Convention）。
12. 验证：GEOP 单点 smoothwin=0 vs 30 的 E/N/U STD 对比纳入 MATLAB 报表；RTK 数据
    smoothwin=30 跑通可用即可（不做专门指标实验）。

## Acceptance Criteria

> 执行顺序 Phase A → Phase B，每阶段完成立即跑对应验收再进入下一阶段。

- [ ] **AC-1 零回归（两阶段各跑一次）**：开关全关（robust=off、weightsnr=off、
      smoothwin=0）跑两组数据（GEOP 单点、0759/3040 RTK），`.pos` 与 baseline/ 下
      AC-0 基线 cmp 逐字节一致。
- [ ] **AC-2 分组修复效果**：干净 RTK 数据 `pos2-robust=igg3`，固定率从 0.12 恢复至
      ≥0.95；E/N/U STD/RMS 与 robust=off 干净基线相当。
- [ ] **AC-3 注入实验不退化**：复跑 06-11 注入矩阵，G07 粗差识别命中（sat_diag.csv
      decision=downweight/reject、var_factor>1），开抗差恢复 RMS 与上任务结果相当（~7cm）。
- [ ] **AC-4 smoothwin 选项生效**：`pos1-smoothwin` 配置可解析、可写回（loadopts/saveopts
      往返一致）；smoothwin=30 时 GEOP 单点解发生预期变化。
- [ ] **AC-5 GEOP STD 对比报表**：MATLAB 报表输出 smoothwin=0/30 两组 E/N/U STD/RMS
      对比（85 历元，前 30 收敛、后 55 稳态）。
- [ ] **AC-6 RTK 平滑可用性**：RTK 数据 smoothwin=30 跑通无崩溃、解状态正常。
- [ ] **AC-7 Qt 一致性**：qmake + mingw32-make 重编 `rtkpost_qt.exe` 成功；GUI 设置
      smoothwin=30 跑 GEOP 与 console 同配置 `.pos` 一致；控件值 QSettings 持久化往返；
      默认 0 时 GUI 行为与改动前一致。
- [ ] **AC-8 卫生检查**：`git diff --check` 干净；测试数据/diag 输出/`.pos`/构建产物
      不入库（沿用既有排除清单）。

## Definition of Done

- AC-1~AC-8 全部勾选。
- 新增 C 代码具备中文注释（总体作用、参数、返回值），遵守 `.trellis/spec/backend/`；
  Qt 改动遵守 `.trellis/spec/frontend/`。
- MinGW gcc console 构建通过（配方 baseline/README.md：CC=gcc、-DWIN32、去-lrt
  加-lwinmm，先建 iers.a）；Qt 构建通过（D:\QT\5.15.2\mingw81_64）。
- MATLAB 脚本经 matlab MCP 实跑验证（桌面未开时 `G:\matlab\bin\matlab.exe -batch` 回退），
  指标表 + 图入任务目录归档。

## Technical Approach

- **分组统计**：residualstats 加 type 过滤参数（按 vflg 类型位筛选样本），robustddres /
  diagresiduals 对相位、伪距两池分别取统计量再标准化；池间互不影响，池内样本不足即跳过，
  消除"伪距残差被相位 MAD 标准化"的量纲错配。
- **Hatch 平滑**：postpos 读完观测、解算前一次性预处理 obss（后处理数据流天然支持全量
  顺序扫描）；通道状态（上历元载波、平滑值、计数 n）按 rcv×sat×freq 维护；正反向解算
  （combined 模式）共用同一份平滑后观测，无方向耦合。频点载波波长经 `sat2freq`/nav 获取，
  载波周→米换算后做相位推距。
- **Qt**：postopt.ui 加 QSpinBox（范围 0~999），postopt.cpp load/save 双向映射
  `prcopt_t.smoothwin`，postmain QSettings `set/smoothwin` 持久化——逐项对照
  state-management.md 接线清单 Convention。
- **验证**：先 Phase A 复跑抗差矩阵（分组前后对比），后 Phase B GEOP STD 报表；
  全程 smoothwin=0 + robust=off 零回归卡点。

## Decision (ADR-lite)

**Context**: 06-11 交接提出三个待收敛决策：两方向任务组织、MAD 分组粒度、Hatch 窗口
取值。2026-06-12 brainstorm 经代码勘察（residualstats 混池实现、池样本规模、GEOP 1Hz
85 历元、RTK 30s 采样）后与用户拍板。

**Decision**:
1. **合并一个任务，分组修复（Phase A）先行**——两者改动文件几乎不重叠（rtkpos.c vs
   postpos.c）但共享验证工具链与实验矩阵；分组修复是已交付功能的正确性缺陷，先恢复
   正确基线，一次 Qt 会话与一套报表收尾。
2. **MAD 仅按观测类型分池（相位/伪距）**——同类型内 L1/L2 残差同量级，类型分池已消除
   核心缺陷；池样本 ~12-16 条/历元充足；池内 n<=2 跳过该池、不跨池回退。频率级细分
   留作将来（Out of Scope）。
3. **GEOP 实验窗口 smoothwin=30**（1Hz → 30s 时间常数）——85 历元中前 30 收敛、
   后 55 全平滑，STD 对比有足够稳态样本；文档建议值写"窗口×采样间隔 ≈ 30~100s，
   单频防电离层发散"；默认 0=off 不变是硬约束。

**Consequences**:
- 开 `pos2-robust=igg3` 的行为相对 06-11 交付发生变化（固定率大幅回升）——属缺陷修复
  预期变更，在交付说明明示；robust=off 路径零变化。
- 类型分池后 P2 码与 C1 码噪声差异仍混在伪距池内（可接受，同量级）；接口预留 type
  维度便于将来细分频率。
- 30 窗口对 RTK 30s 数据 = 900s 时间常数，超经典建议——RTK 平滑仅验证可用性不做指标
  实验，文档建议值已覆盖该取舍。
- 平滑在 postpos 层实现，rtknavi 实时流不受益（课程场景为后处理，接受）。

## Out of Scope

- 频率级分池（类型×频率）及自适应二级分池。
- divergence-free / 双频无电离层组合平滑；电离层发散补偿。
- demo5 代码移植；WinApp（VCL）前端；ppp.c；rtknavi 实时路径的平滑。
- RTK 平滑专门指标实验（仅可用性验证）。
- `epoch_diag.csv` 格式变更（sat_diag.csv 18 列格式亦不再变）。

## Technical Notes

### 已核实代码锚点（2026-06-12 勘察）

- 占位已在位：`rtklib.h:1031` `smoothwin` 字段；`options.c:88` `pos1-smoothwin`、
  `:112` `pos2-robust`、`:150` `stats-weightsnr`。默认 0 = 完全旁路。
- `residualstats()`：rtkpos.c:264，`vals[n++]=fabs(v[i])` 不分型混池；`nv<=2`/`n<=2`
  退出；`sigma=1.4826*MAD`，下限 1E-4。
- `robustddres()`：rtkpos.c:339（调用点 :1658）；`diagresiduals()`：rtkpos.c:378；
  `igg3varfactor()`：rtkpos.c:234（k0=2.0/k1=6.0/软剔除 ×1E6）。
- vflg 编码：`sat1=(vflg>>16)&0xFF`、`sat2=(vflg>>8)&0xFF`、`type=(vflg>>4)&0xF`
  （0=相位 L、1=伪距 P）、`freq=vflg&0xF`。
- postpos.c：`execses` :903、`readobsnav` :943（全局 `obss`，`sortobs` 排序后
  `nepoch` 可用）、`procpos` :988/:995/:1007/:1009（forward/backward/combined）。
- 数据特征：GEOP156M.26o = RINEX 3.04 多系统（G/R/E/C/J，GPS 含 L1+L5）、1 Hz、
  85 历元（2026-06-05 12:40:51 起）；07590920.05o/30400920.05o = RINEX 2.10 GPS
  L1/L2、30 s 采样。
- Qt 文件：`app/qtapp/rtkpost_qt/{postopt.ui,postopt.h,postopt.cpp,postmain.cpp,postmain.h}`；
  上任务 robust/weightsnr 接线为现成模板。上任务 GUI 冒烟（AC-6）已确认完成，无遗留项。

### 约束与环境

- 零回归方法：baseline/ 下 AC-0 基线 cmp 逐字节；rnx2rtkp 输入路径必须反斜杠
  （expath WIN32 陷阱）；-k 最小 conf 会把 pos1-posmode 重置为 single，RTK 必须显式
  `-p 2`（`.trellis/spec/backend/database-guidelines.md`）。
- console 构建配方 `baseline/README.md`；Qt 构建 D:\QT\5.15.2\mingw81_64；MATLAB
  桌面未开时 `G:\matlab\bin\matlab.exe -batch`。
- 源码根：`RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/`；测试数据/诊断输出/`.pos`/构建产物不入 git。
- 参考：06-11 归档 PRD（决策上下文）、`.trellis/spec/backend/`、`.trellis/spec/frontend/`。
