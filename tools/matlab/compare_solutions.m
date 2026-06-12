function metrics = compare_solutions(solutionFiles, diagFiles, varargin)
%COMPARE_SOLUTIONS 对比RTKLIB解算结果和诊断CSV指标
% args   : cell/string solutionFiles I   .pos文件路径列表
%          cell/string diagFiles     I   sat_diag.csv路径列表，可为空
%          Name-Value varargin       I   可选参数，Labels、Reference、OutputCsv、InjectedSat
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
for i = 1:numel(solutionFiles)
    sol = readPosFile(solutionFiles(i));
    if strlength(opts.Reference) > 0
        ref = readPosFile(opts.Reference);
        enu = alignAndDiff(sol, ref);
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
parse(p, varargin{:});
opts = p.Results;
opts.Labels = string(opts.Labels);
opts.Reference = string(opts.Reference);
opts.OutputCsv = string(opts.OutputCsv);
opts.InjectedSat = string(opts.InjectedSat);
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
    tokens = textscan(line, '%f/%f/%f %f:%f:%f %f %f %f %f %f %f %f %f %f %f %f %f', 1);
    raw = cellfun(@(x) firstOrNan(x), tokens);
    time = datenum(raw(1), raw(2), raw(3), raw(4), raw(5), raw(6)) * 86400;
    weekTow = dateToGpsWeekTow(raw(1:6));
    values = [weekTow, raw(7:18)];
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

if isempty(sol)
    row = table(label, 0, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
        'VariableNames', metricNames());
    return
end
fixRatio = nanmeanLocal(sol.Q == 1);
singleRatio = nanmeanLocal(sol.Q == 5);
floatRatio = nanmeanLocal(sol.Q == 2);
stdE = nanstdLocal(enu.east);
stdN = nanstdLocal(enu.north);
stdU = nanstdLocal(enu.up);
rmsE = rmsValue(enu.east);
rmsN = rmsValue(enu.north);
rmsU = rmsValue(enu.up);
downRejectRate = NaN;
maxVarFactor = NaN;
if ~isempty(diag)
    decisions = string(diag.decision);
    downRejectRate = nanmeanLocal(decisions == "downweight" | decisions == "reject");
    if any(strcmp(diag.Properties.VariableNames, 'var_factor'))
        maxVarFactor = nanmaxLocal(diag.var_factor);
    end
    if strlength(injectedSat) > 0 && any(strcmp(diag.Properties.VariableNames, 'sat'))
        hitRows = diag(string(diag.sat) == injectedSat, :);
        if ~isempty(hitRows)
            hitDecision = string(hitRows.decision) == "downweight" | string(hitRows.decision) == "reject";
            if ismember('var_factor', hitRows.Properties.VariableNames)
                hitFactor = hitRows.var_factor > 1;
            else
                hitFactor = false(height(hitRows), 1);
            end
            downRejectRate = nanmeanLocal(hitDecision | hitFactor);
        end
    end
end
row = table(label, height(sol), fixRatio, floatRatio, singleRatio, stdE, stdN, stdU, ...
    rmsE, rmsN, rmsU, downRejectRate, maxVarFactor, 'VariableNames', metricNames());
end

function names = metricNames()
%METRICNAMES 返回指标表列名
% args   : 无
% return : cell names O   指标表列名

names = {'label','epochs','fix_ratio','float_ratio','single_ratio','std_e','std_n','std_u','rms_e','rms_n','rms_u','diag_down_reject_rate','diag_max_var_factor'};
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
