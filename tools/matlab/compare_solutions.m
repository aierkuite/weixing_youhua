function metrics = compare_solutions(solutionFiles, diagFiles, varargin)
%COMPARE_SOLUTIONS 对比RTKLIB解算结果和诊断CSV指标
% args   : cell/string solutionFiles I   .pos文件路径列表
%          cell/string diagFiles     I   sat_diag.csv路径列表，可为空
%          Name-Value varargin       I   可选参数，Labels、Reference、OutputCsv、InjectedSat、OutputDir、MakeFigures
% return : table metrics             O   每组解算和诊断指标

opts = parseOptions(varargin{:});
solutionFiles = string(solutionFiles);
diagFiles = string(diagFiles);
labels = opts.Labels;
if isempty(labels)
    labels = solutionFiles;
end
labels = string(labels);
rows = cell(numel(solutionFiles), 1);
solutions = cell(numel(solutionFiles), 1);
for i = 1:numel(solutionFiles)
    sol = readPosFile(solutionFiles(i));
    solutions{i} = sol;
    if isempty(sol)
        enu = table();
    elseif strlength(opts.Reference) > 0
        ref = readPosFile(opts.Reference);
        if isempty(ref)
            enu = demeanLlh(sol);
        else
            enu = alignAndDiff(sol, ref);
        end
    else
        enu = demeanLlh(sol);
    end
    diag = table();
    if i <= numel(diagFiles) && strlength(diagFiles(i)) > 0 && isfile(diagFiles(i))
        diag = readtable(diagFiles(i), 'TextType', 'string');
    end
    rows{i} = buildMetricRow(labels(i), sol, enu, diag, opts.InjectedSat);
end
metrics = vertcat(rows{:});
if strlength(opts.OutputCsv) > 0
    writetable(metrics, opts.OutputCsv);
end
writeComparisonFigures(metrics, solutions, labels, opts);
end

function opts = parseOptions(varargin)
%PARSEOPTIONS 解析对比脚本参数
% args   : Name-Value varargin I   参数键值列表
% return : struct opts         O   参数结构

p = inputParser;
addParameter(p, 'Labels', strings(0,1), @(x) ischar(x) || isstring(x) || iscellstr(x));
addParameter(p, 'Reference', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'OutputCsv', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'InjectedSat', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'OutputDir', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'MakeFigures', false, @(x) islogical(x) || isnumeric(x));
parse(p, varargin{:});
opts = p.Results;
opts.Labels = string(opts.Labels);
opts.Reference = string(opts.Reference);
opts.OutputCsv = string(opts.OutputCsv);
opts.InjectedSat = string(opts.InjectedSat);
opts.OutputDir = string(opts.OutputDir);
opts.MakeFigures = logical(opts.MakeFigures) || strlength(opts.OutputDir) > 0;
end

function sol = readPosFile(file)
%READPOSFILE 读取RTKLIB llh格式.pos文件
% args   : char/string file I   .pos路径
% return : table sol        O   解算时间、经纬高、状态和协方差表

lines = splitlines(fileread(file));
data = strings(0, 1);
for i = 1:numel(lines)
    line = string(lines{i});
    if strlength(strtrim(line)) == 0 || startsWith(strtrim(line), "%")
        continue
    end
    data(end+1, 1) = line; %#ok<AGROW>
end
if isempty(data)
    sol = table();
    return
end
rows = zeros(numel(data), 15);
time = zeros(numel(data), 1);
for i = 1:numel(data)
    [time(i), vals] = parsePosLine(data(i));
    rows(i,1:min(15,numel(vals))) = vals(1:min(15,numel(vals)));
end
sol = array2table(rows, 'VariableNames', {'week','tow','lat','lon','height','Q','ns','sdn','sde','sdu','sdne','sdeu','sdun','age','ratio'});
sol.time = time;
sol = movevars(sol, 'time', 'Before', 1);
end

function [time, values] = parsePosLine(line)
%PARSEPOSLINE 解析RTKLIB周秒或日历时间格式的解算行
% args   : char/string line I   .pos数据行
% return : double time      O   统一时间秒
%          double values    O   周秒和解算数值共15列

line = char(line);
if contains(line(1:min(10,end)), '/')
    tokens = textscan(line, '%f/%f/%f %f:%f:%f %f %f %f %f %f %f %f %f %f %f %f %f %f', 1);
    raw = cellfun(@(x) firstOrNan(x), tokens);
    time = datenum(raw(1), raw(2), raw(3), raw(4), raw(5), raw(6)) * 86400;
    weekTow = dateToGpsWeekTow(raw(1:6));
    values = [weekTow, raw(7:19)];
else
    values = sscanf(line, '%f')';
    time = datenum(1980, 1, 6) * 86400 + values(1) * 604800 + values(2);
end
end

function value = firstOrNan(values)
%FIRSTORNAN 返回数组首元素或NaN
% args   : double values I   输入数组
% return : double value  O   首元素或NaN

if isempty(values)
    value = NaN;
else
    value = values(1);
end
end

function weekTow = dateToGpsWeekTow(dateValues)
%DATETOGPSWEEKTOW 将GPST日历时间转换为GPS周秒
% args   : double dateValues I   年月日时分秒
% return : double weekTow    O   GPS周和周内秒

gpsDays = datenum(dateValues(1), dateValues(2), dateValues(3), ...
    dateValues(4), dateValues(5), dateValues(6)) - datenum(1980, 1, 6);
week = floor(gpsDays / 7);
tow = (gpsDays - week * 7) * 86400;
weekTow = [week, tow];
end

function enu = demeanLlh(sol)
%DEMEANLLH 以自身均值为参考计算近似ENU偏差
% args   : table sol I   解算结果
% return : table enu O   e/n/u偏差表

if isempty(sol)
    enu = table();
    return
end
lat0 = mean(sol.lat, 'omitnan');
lon0 = mean(sol.lon, 'omitnan');
h0 = mean(sol.height, 'omitnan');
enu = llhDiff(sol, lat0, lon0, h0);
end

function enu = alignAndDiff(sol, ref)
%ALIGNANDDIFF 按GPS周秒对齐两组解并计算ENU偏差
% args   : table sol I   待评估解
%          table ref I   参考解
% return : table enu O   e/n/u偏差表

[~, ia, ib] = intersect(round(sol.time * 1000), round(ref.time * 1000));
sol = sol(ia,:);
ref = ref(ib,:);
enu = llhDiff(sol, ref.lat, ref.lon, ref.height);
end

function enu = llhDiff(sol, lat0, lon0, h0)
%LLHDIFF 将经纬高差近似转换为ENU
% args   : table sol        I   解算结果
%          double lat0/lon0 I   参考经纬度(deg)
%          double h0        I   参考高程(m)
% return : table enu        O   e/n/u偏差表

lat0Rad = deg2rad(lat0);
metersLat = 111132.92 - 559.82 .* cos(2 .* lat0Rad) + 1.175 .* cos(4 .* lat0Rad);
metersLon = 111412.84 .* cos(lat0Rad) - 93.5 .* cos(3 .* lat0Rad);
east = (sol.lon - lon0) .* metersLon;
north = (sol.lat - lat0) .* metersLat;
up = sol.height - h0;
enu = table(sol.time, east, north, up, sol.Q, sol.ns, 'VariableNames', {'time','east','north','up','Q','ns'});
end

function row = buildMetricRow(label, sol, enu, diag, injectedSat)
%BUILDMETRICROW 汇总单组解算和诊断指标
% args   : string label       I   组标签
%          table sol          I   解算结果
%          table enu          I   ENU偏差
%          table diag         I   诊断CSV
%          string injectedSat I   注入卫星编号
% return : table row          O   单行指标表

epochs = height(sol);
fixRatio = NaN;
singleRatio = NaN;
floatRatio = NaN;
ttff = NaN;
ratioMean = NaN;
ratioMedian = NaN;
ratioP95 = NaN;
stdE = NaN;
stdN = NaN;
stdU = NaN;
rmsE = NaN;
rmsN = NaN;
rmsU = NaN;
if ~isempty(sol)
    fixRatio = nanmeanLocal(sol.Q == 1);
    singleRatio = nanmeanLocal(sol.Q == 5);
    floatRatio = nanmeanLocal(sol.Q == 2);
    ttff = ttffSeconds(sol);
    [ratioMean, ratioMedian, ratioP95] = ratioSummary(sol.ratio);
    stdE = nanstdLocal(enu.east);
    stdN = nanstdLocal(enu.north);
    stdU = nanstdLocal(enu.up);
    rmsE = rmsValue(enu.east);
    rmsN = rmsValue(enu.north);
    rmsU = rmsValue(enu.up);
end
diagStats = diagnosticMetrics(diag, injectedSat);
row = table(label, epochs, fixRatio, floatRatio, singleRatio, ttff, ratioMean, ratioMedian, ratioP95, ...
    stdE, stdN, stdU, rmsE, rmsN, rmsU, diagStats.downRejectRate, diagStats.maxVarFactor, ...
    diagStats.mwCount, diagStats.mwRate, diagStats.gfCount, diagStats.gfRate, ...
    diagStats.injectedMwHitCount, diagStats.injectedMwHitRate, diagStats.injectedGfHitCount, diagStats.injectedGfHitRate, ...
    diagStats.mwFalseAlarmCount, diagStats.mwFalseAlarmRate, 'VariableNames', metricNames());
end

function names = metricNames()
%METRICNAMES 返回指标表列名
% args   : 无
% return : cell names O   指标表列名

names = {'label','epochs','fix_ratio','float_ratio','single_ratio','ttff_s','ratio_mean','ratio_median','ratio_p95', ...
    'std_e','std_n','std_u','rms_e','rms_n','rms_u','diag_down_reject_rate','diag_max_var_factor', ...
    'cycle_slip_mw_count','cycle_slip_mw_rate','cycle_slip_gf_count','cycle_slip_gf_rate', ...
    'injected_mw_hit_count','injected_mw_hit_rate','injected_gf_hit_count','injected_gf_hit_rate', ...
    'mw_false_alarm_count','mw_false_alarm_rate'};
end

function ttff = ttffSeconds(sol)
%TTFFSECONDS 计算首次固定时间
% args   : table sol I   解算结果
% return : double ttff O  首历元到首次Q=1固定解的秒数

idx = find(sol.Q == 1, 1, 'first');
if isempty(idx)
    ttff = NaN;
else
    ttff = sol.time(idx) - sol.time(1);
end
end

function [meanValue, medianValue, p95Value] = ratioSummary(ratio)
%RATIOSUMMARY 计算AR ratio分布指标
% args   : double ratio I   ratio序列
% return : double meanValue   O   忽略无效值后的均值
%          double medianValue O   忽略无效值后的中位数
%          double p95Value    O   忽略无效值后的95百分位

ratio = double(ratio(:));
ratio(ratio <= 0) = NaN;
meanValue = nanmeanLocal(ratio);
medianValue = nanmedianLocal(ratio);
p95Value = nanpercentileLocal(ratio, 95);
end

function stats = diagnosticMetrics(diag, injectedSat)
%DIAGNOSTICMETRICS 汇总sat_diag.csv中的周跳和权重诊断指标
% args   : table diag         I   sat_diag.csv表，可为空
%          string injectedSat I   注入卫星编号
% return : struct stats       O   诊断指标结构

stats.downRejectRate = NaN;
stats.maxVarFactor = NaN;
stats.mwCount = 0;
stats.mwRate = NaN;
stats.gfCount = 0;
stats.gfRate = NaN;
stats.injectedMwHitCount = 0;
stats.injectedMwHitRate = NaN;
stats.injectedGfHitCount = 0;
stats.injectedGfHitRate = NaN;
stats.mwFalseAlarmCount = 0;
stats.mwFalseAlarmRate = NaN;
if isempty(diag)
    return
end
if any(strcmp(diag.Properties.VariableNames, 'decision'))
    decisions = string(diag.decision);
    stats.downRejectRate = nanmeanLocal(decisions == "downweight" | decisions == "reject");
end
if any(strcmp(diag.Properties.VariableNames, 'var_factor'))
    stats.maxVarFactor = nanmaxLocal(diag.var_factor);
end
reason = strings(height(diag), 1);
if any(strcmp(diag.Properties.VariableNames, 'reason'))
    reason = string(diag.reason);
end
mwRows = contains(reason, "cycle_slip_mw");
gfRows = contains(reason, "cycle_slip_gf");
stats.mwCount = sum(mwRows);
stats.gfCount = sum(gfRows);
stats.mwRate = stats.mwCount / max(height(diag), 1);
stats.gfRate = stats.gfCount / max(height(diag), 1);
targetRows = false(height(diag), 1);
if strlength(injectedSat) > 0 && any(strcmp(diag.Properties.VariableNames, 'sat'))
    targetRows = string(diag.sat) == injectedSat;
end
if any(targetRows)
    stats.injectedMwHitCount = sum(mwRows & targetRows);
    stats.injectedGfHitCount = sum(gfRows & targetRows);
    stats.injectedMwHitRate = stats.injectedMwHitCount / sum(targetRows);
    stats.injectedGfHitRate = stats.injectedGfHitCount / sum(targetRows);
    stats.mwFalseAlarmCount = sum(mwRows & ~targetRows);
    stats.mwFalseAlarmRate = stats.mwFalseAlarmCount / max(sum(~targetRows), 1);
else
    stats.mwFalseAlarmCount = stats.mwCount;
    stats.mwFalseAlarmRate = stats.mwCount / max(height(diag), 1);
end
end

function writeComparisonFigures(metrics, solutions, labels, opts)
%WRITECOMPARISONFIGURES 输出定位和ratio对比图
% args   : table metrics  I   指标表
%          cell solutions I   解算结果表列表
%          string labels  I   标签列表
%          struct opts    I   输出参数
% return : 无

if ~opts.MakeFigures || strlength(opts.OutputDir) == 0
    return
end
outDir = char(opts.OutputDir);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
try
    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));
    tiledlayout(fig, 2, 2);
    nexttile;
    bar(metrics.fix_ratio);
    title('Fixed Rate');
    set(gca, 'XTick', 1:height(metrics), 'XTickLabel', cellstr(labels));
    nexttile;
    bar(metrics.ttff_s);
    title('TTFF (s)');
    set(gca, 'XTick', 1:height(metrics), 'XTickLabel', cellstr(labels));
    nexttile;
    bar([metrics.rms_e, metrics.rms_n, metrics.rms_u]);
    title('ENU RMS (m)');
    legend({'E','N','U'}, 'Location', 'best');
    set(gca, 'XTick', 1:height(metrics), 'XTickLabel', cellstr(labels));
    nexttile;
    bar([metrics.cycle_slip_mw_count, metrics.cycle_slip_gf_count]);
    title('Slip Diagnostics');
    legend({'MW','GF'}, 'Location', 'best');
    set(gca, 'XTick', 1:height(metrics), 'XTickLabel', cellstr(labels));
    saveFigure(fig, fullfile(outDir, 'solution_metrics.png'));

    fig2 = figure('Visible', 'off');
    cleanup2 = onCleanup(@() close(fig2));
    hold on;
    for i = 1:numel(solutions)
        sol = solutions{i};
        if isempty(sol)
            continue
        end
        t = sol.time - sol.time(1);
        plot(t, sol.ratio, 'DisplayName', char(labels(i)));
    end
    xlabel('Time (s)');
    ylabel('Ratio');
    legend('Location', 'best');
    grid on;
    saveFigure(fig2, fullfile(outDir, 'ratio_timeseries.png'));
catch err
    warning('compare_solutions:figure', '生成对比图失败: %s', err.message);
end
end

function saveFigure(fig, file)
%SAVEFIGURE 保存不可见图窗到PNG文件
% args   : handle fig       I   图窗句柄
%          char/string file I   输出文件路径
% return : 无

if exist('exportgraphics', 'file')
    exportgraphics(fig, file, 'Resolution', 150);
else
    saveas(fig, file);
end
end

function y = rmsValue(x)
%RMSVALUE 计算向量RMS
% args   : double x I   输入向量
% return : double y O   RMS值

y = sqrt(nanmeanLocal(x.^2));
end

function y = nanmeanLocal(x)
%NANMEANLOCAL 计算忽略NaN的均值
% args   : double/logical x I   输入向量
% return : double y         O   均值

x = double(x(:));
x = x(~isnan(x));
if isempty(x)
    y = NaN;
else
    y = mean(x);
end
end

function y = nanmedianLocal(x)
%NANMEDIANLOCAL 计算忽略NaN的中位数
% args   : double x I   输入向量
% return : double y O   中位数

x = sort(double(x(:)));
x = x(~isnan(x));
if isempty(x)
    y = NaN;
else
    n = numel(x);
    mid = floor((n + 1) / 2);
    if mod(n, 2) == 1
        y = x(mid);
    else
        y = (x(mid) + x(mid + 1)) / 2;
    end
end
end

function y = nanpercentileLocal(x, pct)
%NANPERCENTILELOCAL 计算忽略NaN的线性插值百分位
% args   : double x   I   输入向量
%          double pct I   百分位，0到100
% return : double y   O   百分位值

x = sort(double(x(:)));
x = x(~isnan(x));
if isempty(x)
    y = NaN;
    return
end
rank = 1 + (numel(x) - 1) * pct / 100;
lo = floor(rank);
hi = ceil(rank);
if lo == hi
    y = x(lo);
else
    y = x(lo) + (x(hi) - x(lo)) * (rank - lo);
end
end

function y = nanstdLocal(x)
%NANSTDLOCAL 计算忽略NaN的标准差
% args   : double x I   输入向量
% return : double y O   标准差

x = double(x(:));
x = x(~isnan(x));
if numel(x) <= 1
    y = NaN;
else
    y = std(x);
end
end

function y = nanmaxLocal(x)
%NANMAXLOCAL 计算忽略NaN的最大值
% args   : double x I   输入向量
% return : double y O   最大值

x = double(x(:));
x = x(~isnan(x));
if isempty(x)
    y = NaN;
else
    y = max(x);
end
end
