# Journal - aierkuite (Part 1)

> AI development session journal
> Started: 2026-06-09

---



## Session 1: RTK observation diagnostics

**Date**: 2026-06-09
**Task**: RTK observation diagnostics
**Branch**: `main`

### Summary

Added backend-only rnx2rtkp observation diagnostics with diagnostic CSV output, robust scoring, cleanup fallback, and spec coverage.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `0343439` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 2: RTKPOST 诊断 CSV 前端收尾

**Date**: 2026-06-10
**Task**: RTKPOST 诊断 CSV 前端收尾
**Branch**: `main`

### Summary

在 RTKPOST WinApp 中展示并持久化诊断 CSV 输出入口，完成任务归档前记录；本机缺少 VCL 构建工具，未实际编译或运行 RTKPOST GUI。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `015359a` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 3: RTKPOST Qt 诊断 CSV 前端

**Date**: 2026-06-10
**Task**: RTKPOST Qt 诊断 CSV 前端
**Branch**: `main`

### Summary

修复 rtkpost_qt 构建与资源路径，添加诊断 CSV 输出控件，并归一化 Qt 拖拽 file URL，避免 no obs data。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `439a5c5` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 4: 修复 rtkpost_qt 诊断 CSV

**Date**: 2026-06-11
**Task**: 修复 rtkpost_qt 诊断 CSV
**Branch**: `feature/first_final`

### Summary

修复 Qt showmsg 返回语义导致诊断 CSV 只写表头的问题，补充单点解 vsat 字段语义和回调规范，并完成用户数据与 Qt release 构建验证

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `6b2d24f` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete

---

## Session 5: 质量闭环自适应定权——任务创建与 AC-0 基线（交接 codex）

**Date**: 2026-06-11
**Task**: .trellis/tasks/06-11-quality-loop-adaptive-weighting (in_progress)

### Summary

由 plan.md 创建任务并收敛 prd.md（代码锚点全部勘察核实，estpos 行号修正为 pntpos.c:368）；curate 两个 jsonl；task.py start。完成 AC-0 部分基线：原版编译 + GEOP 单点基线两份。未改任何源码。

### Main Changes

- 新建 .trellis/tasks/06-11-quality-loop-adaptive-weighting/{prd.md,implement.jsonl,check.jsonl}
- 新建 baseline/（不入库）：spp_geop.pos、spp_geop_diag.pos、diag_spp/、README.md（含 MinGW 构建配方与 RTK 卡点交接）
- 构建 lib/iers/gcc/iers.a + gcc/rnx2rtkp.exe（配方见 baseline/README.md：CC=gcc、-DWIN32、去 -lrt 加 -lwinmm）
- 清理：tmp_diag_repro/、gcc/diag_out/、RTK 排查临时文件

### Testing

- [OK] 原版 rnx2rtkp.exe 编译通过（MinGW 8.1.0）
- [OK] GEOP 单点基线两份 .pos 生成
- [BLOCKED] RTK 0759/3040 基线：`error : no obs data`，现象矛盾（带 --diag 时诊断 CSV 有 1091 行但 .pos 未生成），线索与排查方向见 baseline/README.md

### Status

[WIP] **In Progress** — AC-0 完成一半，交接 codex 继续

### Next Steps

- codex：排查 RTK 基线 no obs data 问题，补齐 rtk_0759.pos / rtk_0759_diag.pos 两份基线
- 然后按 prd.md P0 → P1a → P1b → P1c 派 trellis-implement 实现


## Session 6: 质量闭环自适应定权 P1c 收尾与交付

**Date**: 2026-06-12
**Task**: 质量闭环自适应定权 P1c 收尾与交付
**Branch**: `main`

### Summary

承接已完成的 P0/P1a/P1b：派 trellis-implement 核对 P1c Qt 代码（零缺陷）并重编 rtkpost_qt.exe（无新增告警，exe 内选项/QSettings 字符串静态冒烟全命中）；派 trellis-check 全面验收——零回归 4 组逐字节一致、选项往返闭合、CSV 兼容、卫生干净，修复尾随空白与 trace 缺失等 4 处小问题，并查明 RTK no obs data 根因（expath WIN32 正斜杠丢目录）。补齐 AC-3/AC-4 实验矩阵 clean×on 两组（RTK 需 -p 2 显式覆盖 -k 的 posmode 重置），MATLAB -batch 重生成 4 组指标表与对比图（原 3 组数值逐位复现）。trellis-update-spec 沉淀选项接入契约、diag CSV v2、expath 陷阱、零回归方法、Qt 接线清单。提交 bb0da87；实验原始产物按 AC-8 迁至 baseline/p1b_artifacts/（不入库），指标表/图/driver 随任务归档入库。遗留：AC-6 GUI 人工冒烟；P2 Hatch 平滑按 PRD 顺延；RTK 相位/伪距混池 MAD 致开抗差固定率下降，列为下任务改进方向。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `bb0da87` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 7: Hatch 平滑与抗差分组修复

**Date**: 2026-06-13
**Task**: Hatch 平滑与抗差分组修复
**Branch**: `main`

### Summary

完成 Hatch 载波平滑、RTK 抗差残差按类型分组修复、Qt smoothwin 接线和相关 spec 约束沉淀；验证零回归、配置往返、console/Qt 构建通过。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `25fde6b` | (see git log) |
| `5fd0027` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete
