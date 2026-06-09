# RTKLIB 可解释观测质量评价与自适应抗差诊断

## Goal

基于原版 `RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/` 实现第一版源码优化：新增可解释观测质量评分、诊断 CSV 输出和轻量自适应抗差处理，用于解释每历元、每卫星、每频点观测值被使用、降权、剔除或标记周跳风险的原因。

本任务必须参考仓库根目录的 `plan.md`。`RTKLIB-2.5.0` / demo5 仅作为参考实现和实验对照，不作为主开发基线，不直接移植其核心算法。

## Requirements

* 主开发基线固定为原版 RTKLIB 2.4.3 b34：`RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/`
* 新增命令行开关 `--diag path`，在 `app/consapp/rnx2rtkp/rnx2rtkp.c` 中启用诊断输出
* 启用后在指定目录输出 `epoch_diag.csv` 和 `sat_diag.csv`
* 每历元输出整体解算诊断字段：`time,stat,ns,ratio,gdop,n_slip,n_reject,n_downweight,n_low_snr,n_low_el,n_res_outlier`
* 每卫星输出观测质量字段：`time,sat,sys,freq,az,el,snr,resp,resc,slip,vsat,lock,outc,rejc,quality_score,decision,reason`
* `quality_score` 取值范围为 0 到 100，综合高度角、SNR、相位残差、伪距残差、周跳标记、lock 计数和 outage 计数
* `decision` 至少支持 `use`、`downweight`、`reject`、`slip_risk`
* `reason` 至少覆盖 `low_elevation`、`low_snr`、`large_phase_residual`、`large_code_residual`、`cycle_slip_lli`、`cycle_slip_gf`、`cycle_slip_doppler`、`obs_outage`、`poor_lock`
* 自适应抗差逻辑基于每历元残差分布统计，中位数和 MAD 用于识别异常观测值
* 对轻度异常观测值降权，对严重异常观测值剔除，并把原因写入 `sat_diag.csv`
* 周跳风险分类基于原版已有检测结果和残差/lock/outage 异常，不新增 demo5 风格检测器
* 保持原版默认行为：未传 `--diag` 时输出、解算结果和已有 CLI 行为应尽量不变

## Acceptance Criteria

* [ ] `rnx2rtkp --diag <dir> ...` 能创建或使用 `<dir>` 并输出 `epoch_diag.csv` 与 `sat_diag.csv`
* [ ] 两个 CSV 含表头，字段顺序与 PRD 一致
* [ ] 未启用 `--diag` 时不生成诊断文件
* [ ] `quality_score` 始终限制在 0 到 100
* [ ] 每条卫星诊断记录都包含可读 `decision` 和 `reason`
* [ ] 明确周跳标志优先输出 `slip_risk` 及对应原因
* [ ] 自适应残差判断能统计并输出降权、剔除、残差异常数量
* [ ] 相关 rnx2rtkp 回归目标或等效样例命令可运行，若本机缺少工具链则记录未运行原因

## Definition of Done

* 代码遵守 `.trellis/spec/backend/` 中的 RTKLIB 核心规范
* 公共 API、结构体、选项扩展已在 `src/rtklib.h` 中清晰声明
* 新增 C 函数使用项目现有注释风格，并按用户要求使用中文注释说明总体作用、参数含义和返回值含义
* Windows 路径与中文文件读写场景保持明确编码和路径处理策略
* 编译、回归测试或可执行验证完成并记录结果
* 未直接复制 demo5 的 `detslp_code`、Doppler 检测实现、AR filtering、动态 ratio 或参数结构扩展

## Technical Approach

优先在 RTKLIB 2.4.3 b34 原始源码内做最小侵入式扩展：

* `src/rtklib.h`：新增诊断配置、决策枚举或结果结构，保持 C API 风格
* `src/options.c`：如需要，增加诊断开关、评分阈值或路径配置
* `src/rtkpos.c`：接入每历元/每卫星质量评分、风险分类、降权/剔除统计
* `app/consapp/rnx2rtkp/rnx2rtkp.c`：解析 `--diag path` 并把配置传入核心处理流程

若发现 `rtkpos.c` 内部数据不足以稳定输出 `resp/resc/slip/vsat/lock/outc/rejc`，先以原版已有结构字段为准，必要时在 PRD 中回滚补充设计，不直接大改数据流。

## Decision (ADR-lite)

**Context**: 原版 RTKLIB 已有基础状态输出、残差、trace 和周跳检测，demo5 对低成本接收机做了较多增强。直接做“新增周跳检测”或移植 demo5 会削弱本次工作独立性。

**Decision**: 第一版选择“可解释观测质量评分与自适应抗差诊断”，以 CSV 解释和轻量降权/剔除作为主线。

**Consequences**: 本任务更适合课程报告展示，可对定位异常来源做解释；风险是需要谨慎接入 RTKLIB 内部残差和卫星状态数据，避免破坏默认解算行为。

## Out of Scope

* 不移植 demo5 的 `detslp_code`
* 不复制 demo5 的 Doppler 周跳检测实现
* 不移植 demo5 的 AR filtering
* 不实现 demo5 风格动态 ratio test
* 不复制 demo5 的 `prcopt_t` 参数结构扩展
* 不以多频频点扩展作为第一版主要贡献
* 不重构整个 RTKLIB 构建系统
* 不改 GUI，除非后续任务明确要求

## Technical Notes

* 需求来源：`plan.md`
* 主源码目录：`RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/`
* 参考规范：`.trellis/spec/backend/index.md`
* 主要测试入口：`app/consapp/rnx2rtkp/gcc/makefile` 的 `test` 目标和 `test/utest/makefile`
* demo5 / `RTKLIB-2.5.0` 只能作为对照参考，不作为直接移植来源
