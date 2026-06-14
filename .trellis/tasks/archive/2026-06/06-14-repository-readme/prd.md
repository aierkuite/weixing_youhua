# Write Repository README

## Goal

为仓库根目录新增一份中文 `README.md`，让后续开发者或课程验收人员能快速理解本仓库基于 RTKLIB 2.4.3 b34 的 GNSS/RTK 优化实验用途、核心目录、已完成能力、构建运行方式和验证工具。

## Requirements

* 新增根目录 `README.md`
* README 使用中文为主，面向 Windows/MinGW/MATLAB 使用场景
* 说明本仓库包含 RTKLIB 2.4.3 b34 源码、课程资料、基线产物和 MATLAB 辅助脚本
* 概括已实现的增强能力：诊断 CSV、IGG-III 抗差定权、SNR 随机模型、Hatch 平滑、Qt 选项同步
* 给出已验证的 `rnx2rtkp` MinGW 构建命令和 RTK/SPP 运行示例
* 说明 `tools/matlab` 中三个脚本的用途
* 提醒不要提交构建产物、基线产物、课程资料原件和本地临时文件

## Acceptance Criteria

* [ ] 根目录存在 `README.md`
* [ ] README 能从仓库当前文件中追溯，不编造不存在的命令或目录
* [ ] README 包含项目简介、目录结构、环境要求、构建方式、运行示例、MATLAB 工具、开发约定和许可说明
* [ ] 新增文件使用 UTF-8 无 BOM，CRLF 行分隔符
* [ ] 不修改 RTKLIB 源码和无关实验产物

## Definition of Done

* 检查 README 内容与仓库现状一致
* 检查 `git diff --check`
* 检查本次改动范围只包含 README 和 Trellis 任务记录

## Technical Approach

通过读取 `plan.md`、`baseline/README.md`、`.gitignore`、RTKLIB 目录结构、`tools/matlab` 脚本和源码中的自定义选项，编写根目录 README。README 不替代 RTKLIB 原始 `readme.txt`，只解释本课程实验仓库在原版基础上的组织方式和常用流程。

## Decision (ADR-lite)

**Context**: 仓库当前没有根目录 README，RTKLIB 原始说明位于子目录内，无法解释课程实验改动和本地验证流程。

**Decision**: 新增中文根 README，保留原版 RTKLIB 文档作为参考链接，不移动或重写原始源码文档。

**Consequences**: README 会覆盖本仓库常用流程，但不会详述所有 RTKLIB 原版工具；后续新增阶段能力时需要同步更新根 README。

## Out of Scope

* 不修改 RTKLIB C/C++/Qt/MATLAB 源码
* 不整理或删除未跟踪的基线/构建产物
* 不运行耗时构建或 MATLAB 实验矩阵
* 不提交 git commit

## Technical Notes

* `plan.md` 记录当前第三阶段 MW 周跳检测与宽巷辅助 AR 计划
* `baseline/README.md` 记录已验证的 MinGW 构建配方、RTK/SPP 基线命令和 Windows 反斜杠路径注意事项
* `tools/matlab/compare_solutions.m` 汇总 `.pos` 和诊断 CSV 指标
* `tools/matlab/inject_rinex_fault.m` 向 RINEX OBS 注入伪距阶跃粗差和 SNR 压低
* `tools/matlab/plot_diag.m` 绘制定位散点和诊断方差因子图
* 自定义 RTKLIB 选项包括 `pos2-robust`、`stats-weightsnr`、`pos1-smoothwin`
