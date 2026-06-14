# P3 验证摘要

## 零回归

- `baseline/p0_rtk_0759.pos` 与 `baseline/p3_artifacts/clean_off_exact.pos` 的 SHA256 一致
- 两开关全关时 `.pos` 与 P0 基线逐字节一致

## MW 周跳检测

| 场景 | slipmw | GF 诊断 | MW 诊断 | 结论 |
| --- | --- | ---: | ---: | --- |
| 干净数据 | on | 0 | 0 | 无 MW 虚警 |
| GF 盲区注入 G07 L1+9/L2+7 | off | 0 | 0 | GF-only 漏检 |
| GF 盲区注入 G07 L1+9/L2+7 | on | 0 | 2 | MW 命中 G07 L1/L2 |
| 普通周跳注入 | off | 4 | 0 | GF 命中 |
| 普通周跳注入 | on | 4 | 0 | 保持 GF 命中，MW 不重复报 |

## 宽巷辅助 AR

默认 ratio 阈值下，干净数据 baseline 已经 100% fixed，固定率和 TTFF 没有上升空间；宽巷 AR 仍提升 ratio：

- `clean_off`: ratio_mean 153.46, ratio_median 149.40
- `clean_arwl_on`: ratio_mean 197.29, ratio_median 173.30
- `blind_off`: fix_ratio 0.8783, ratio_mean 24.90
- `blind_arwl_on`: fix_ratio 0.8783, ratio_mean 27.20

严格 ratio 阈值 `pos2-arthres=150` 用于把 ratio 提升转化为固定状态差异：

- `clean_off_strict150`: fix_ratio 0.4957, TTFF 750s
- `clean_arwl_strict150`: fix_ratio 0.5652, TTFF 540s，ENU RMS 未劣化
- `blind_off_strict150`: fix_ratio 0
- `blind_arwl_strict150`: fix_ratio 0.0174, TTFF 540s，ENU RMS 基本持平

## 归档文件

- 指标表：`artifacts/p3_metrics.csv`
- 汇总图：`artifacts/figures/solution_metrics.png`
- ratio 时序图：`artifacts/figures/ratio_timeseries.png`
