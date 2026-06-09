# RTKLIB 源码优化计划

## 1. 版本选择

本次源码优化以 **原版 RTKLIB 2.4.3 b34** 作为主开发基线。

RTKLIB demo5，也就是项目中的 `RTKLIB-2.5.0`，只作为参考实现和实验对照，不作为主开发基线，也不直接移植其核心算法。这样可以避免把 demo5 中已经存在的低成本接收机优化误写成本次工作成果。

建议保留三份代码或三个分支：

- `rtklib-original`：原版 RTKLIB 2.4.3 b34，不修改，用作 baseline
- `rtklib-demo5`：RTKLIB demo5 / 2.5.0，不修改或少量配置，用作参考和对照
- `rtklib-my-opt`：从原版 RTKLIB 2.4.3 b34 拉出的优化版本，用于实现本次改动

## 2. 原版与 demo5 能力边界

原版 RTKLIB 已有不少基础机制，demo5 又对低成本接收机做了较多增强。因此本次优化不能简单写成“新增周跳检测”“新增质量控制”，也不能照搬 demo5 的 Doppler 周跳检测、AR filtering 或动态 ratio 逻辑。

| 方向 | 原版 RTKLIB 2.4.3 b34 | demo5 / 2.5.0 | 本次处理原则 |
| --- | --- | --- | --- |
| 解算状态输出 | 已有 solution status、residual、trace | 扩展了部分 `$SAT` 字段 | 不复制字段扩展，新增面向实验分析的解释型 CSV 诊断报告 |
| 周跳检测 | 已有 LLI、几何无关组合、Doppler 与相位差等基础检测 | 增加 code change 检测并改进 Doppler 处理 | 不移植 demo5 检测器，只基于原版结果做风险标记和原因分类 |
| 观测值质量控制 | 已有高度角、SNR mask、创新量阈值 | 增强 SNR 误差模型，拆分相位/伪距创新量阈值 | 不复制 demo5 参数结构，新增可解释质量评分和自适应降权 |
| 模糊度固定 | 已有 ratio test 和 fix-and-hold | 有 AR filter、动态 ratio、更多 AR 参数 | 不作为第一版主线，避免与 demo5 重复 |
| 多频支持 | 支持常规多频配置 | 扩展更多频点和观测码 | 不作为第一版主线，避免变成版本移植 |

## 3. 第一版创新功能

第一版新增功能定为：

**可解释观测质量评分与自适应抗差诊断功能**

该功能不是直接修改某一个已有阈值，而是为每个历元、每颗卫星、每个频点计算质量评分，给出使用、降权、剔除或周跳风险标记，并输出原因。它和原版已有状态输出不同，也不等同于 demo5 的低成本接收机算法增强。

### 3.1 每历元诊断输出

新增 `epoch_diag.csv`，用于记录每个历元的整体解算质量。

建议字段：

```text
time,stat,ns,ratio,gdop,n_slip,n_reject,n_downweight,n_low_snr,n_low_el,n_res_outlier
```

用途：

- 统计每个历元的定位状态变化
- 观察 fixed/float 状态与 ratio 值变化
- 统计周跳、剔除、降权、低信噪比、低高度角和残差异常数量
- 为报告中的曲线和表格提供数据

### 3.2 每卫星诊断输出

新增 `sat_diag.csv`，用于记录每颗卫星在每个历元的质量评价结果。

建议字段：

```text
time,sat,sys,freq,az,el,snr,resp,resc,slip,vsat,lock,outc,rejc,quality_score,decision,reason
```

其中 `decision` 建议包括：

- `use`：正常参与解算
- `downweight`：保留但降低权重
- `reject`：剔除该观测值
- `slip_risk`：存在周跳风险，需要重点分析

其中 `reason` 建议包括：

- `low_elevation`
- `low_snr`
- `large_phase_residual`
- `large_code_residual`
- `cycle_slip_lli`
- `cycle_slip_gf`
- `cycle_slip_doppler`
- `obs_outage`
- `poor_lock`

### 3.3 可解释观测质量评分

新增 `quality_score`，取值建议为 0 到 100，用于统一衡量观测值质量。

评分因素：

- 高度角：低高度角降低得分
- SNR：低信噪比降低得分
- 相位残差：相位残差异常降低得分
- 伪距残差：伪距残差异常降低得分
- 周跳标记：出现周跳直接标记高风险
- lock 计数：锁定时间过短降低得分
- outage 计数：中断次数过多降低得分

建议决策规则：

- `quality_score >= 70`：正常使用
- `40 <= quality_score < 70`：降权使用
- `quality_score < 40`：剔除
- 触发明确周跳标志时：标记为 `slip_risk`，并记录周跳来源

### 3.4 自适应抗差处理

在原版固定创新量阈值基础上增加自适应抗差思路，但不复制 demo5 的相位/伪距阈值拆分。

建议做法：

- 每个历元统计残差中位数和 MAD
- 根据当前历元残差分布判断异常观测值
- 对轻度异常观测值降权
- 对严重异常观测值剔除
- 将降权或剔除原因写入 `sat_diag.csv`

这样报告中可以说明：原版主要依赖固定阈值，本次优化引入了基于当前历元数据分布的自适应判断。

### 3.5 周跳风险分类

不新增一个照搬 demo5 的周跳检测器，而是利用原版已有周跳检测结果，进一步输出可解释的风险分类。

建议分类：

- `cycle_slip_lli`：由 LLI 标志触发
- `cycle_slip_gf`：由几何无关组合跳变触发
- `cycle_slip_doppler`：由 Doppler 与相位差异常触发
- `slip_risk_residual`：未直接触发周跳标志，但残差突变明显
- `slip_risk_lock`：lock 计数或 outage 状态异常

这部分属于解释增强，不与 demo5 的 `detslp_code` 或改进 Doppler 检测重复。

## 4. 避免与 demo5 重复的明确限制

第一版不做以下内容：

- 不移植 demo5 的 `detslp_code`
- 不复制 demo5 的 Doppler 周跳检测实现
- 不移植 demo5 的 AR filtering
- 不实现 demo5 风格的动态 ratio test
- 不复制 demo5 的 `prcopt_t` 参数结构扩展
- 不以多频频点扩展作为主要贡献

如果后续确实参考 demo5 的某个思路，报告中必须写成“对照参考”，不能写成直接贡献。

## 5. 建议修改位置

第一版主要修改原版 RTKLIB 2.4.3 b34 的以下位置：

- `src/rtkpos.c`：生成每历元和每卫星诊断信息，接入质量评分、风险分类和降权/剔除原因记录
- `src/rtklib.h`：增加必要的诊断配置、评分结果或状态字段
- `src/options.c`：增加诊断输出开关、评分阈值或输出路径配置
- `app/consapp/rnx2rtkp/rnx2rtkp.c`：增加命令行开关，用于启用诊断输出

建议命令行开关示例：

```text
--diag path
```

启用后输出：

```text
path/epoch_diag.csv
path/sat_diag.csv
```

## 6. 实验验证方案

使用同一组观测数据分别运行以下版本：

- 原版 RTKLIB 2.4.3 b34
- 本次优化版 RTKLIB
- 可选：RTKLIB demo5 / 2.5.0

对比指标：

- 定位误差
- fixed/float 解比例
- ratio 值变化
- 解算连续性
- 周跳风险历元数量
- 降权观测值数量
- 剔除观测值数量
- 低质量观测值与定位异常的对应关系

报告重点不是只证明定位结果更好，而是证明新增诊断功能能够解释定位异常来源，并在此基础上通过自适应降权减少低质量观测值对结果的影响。

## 7. 报告建议题目

推荐题目：

**基于 RTKLIB 2.4.3 b34 的可解释观测质量评价与自适应抗差定位优化**

备选题目：

**基于 RTKLIB 的观测质量诊断输出与低质量观测值自适应处理方法**

## 8. 最终结论

第一版计划确定为：

- 基线版本：原版 RTKLIB 2.4.3 b34
- 参考版本：RTKLIB demo5 / 2.5.0
- 新增功能：可解释观测质量评分与自适应抗差诊断
- 核心输出：`epoch_diag.csv` 和 `sat_diag.csv`
- 核心创新：用质量评分、原因分类和自适应残差判断解释每个观测值的使用、降权或剔除原因
- 避免重复：不移植 demo5 的周跳检测、AR filtering、动态 ratio 和多频扩展

该方案比单纯改周跳检测或照搬 demo5 更有创新点，也更适合课程报告展示。
