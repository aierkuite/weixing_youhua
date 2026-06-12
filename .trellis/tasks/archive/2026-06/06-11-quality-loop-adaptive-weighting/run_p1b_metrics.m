% 重新生成 P1b 实验矩阵指标表与对比图（4 组完整版：clean/clean_on/fault_off/fault_on）
addpath('G:/weixing_youhua/tools/matlab');
task = 'G:/weixing_youhua/.trellis/tasks/06-11-quality-loop-adaptive-weighting/';
base = 'G:/weixing_youhua/baseline/';

sols_g  = {[base 'spp_geop.pos'], [task 'geop_clean_on.pos'], [task 'geop_fault_off.pos'], [task 'geop_fault_on.pos']};
diags_g = {[base 'p1a_diag_spp/sat_diag.csv'], [task 'diag_geop_clean_on/sat_diag.csv'], [task 'diag_geop_fault_off/sat_diag.csv'], [task 'diag_geop_fault_on/sat_diag.csv']};
labels_g = {'spp_clean','spp_clean_on','spp_fault_off','spp_fault_on'};
m_g = compare_solutions(sols_g, diags_g, 'Labels', labels_g, 'Reference', [base 'spp_geop.pos'], 'InjectedSat', 'G10', 'OutputCsv', [task 'p1b_geop_metrics.csv']);
disp(m_g);

sols_r  = {[base 'rtk_0759.pos'], [task 'rtk_clean_on.pos'], [task 'rtk_fault_off.pos'], [task 'rtk_fault_on.pos']};
diags_r = {[base 'p1a_diag_rtk/sat_diag.csv'], [task 'diag_rtk_clean_on/sat_diag.csv'], [task 'diag_rtk_fault_off/sat_diag.csv'], [task 'diag_rtk_fault_on/sat_diag.csv']};
labels_r = {'rtk_clean','rtk_clean_on','rtk_fault_off','rtk_fault_on'};
m_r = compare_solutions(sols_r, diags_r, 'Labels', labels_r, 'Reference', [base 'rtk_0759.pos'], 'InjectedSat', 'G07', 'OutputCsv', [task 'p1b_rtk_metrics.csv']);
disp(m_r);

f1 = plot_diag(sols_g, diags_g, 'Labels', labels_g, 'OutputPng', [task 'p1b_geop_diag.png']); close(f1);
f2 = plot_diag(sols_r, diags_r, 'Labels', labels_r, 'OutputPng', [task 'p1b_rtk_diag.png']); close(f2);
disp('PNG regenerated');
