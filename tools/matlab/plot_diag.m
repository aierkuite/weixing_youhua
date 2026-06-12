function fig = plot_diag(solutionFiles, diagFiles, varargin)
%PLOT_DIAG 绘制RTKLIB解算轨迹偏差和诊断方差因子
% args   : cell/string solutionFiles I   .pos文件路径列表
%          cell/string diagFiles     I   sat_diag.csv路径列表，可为空
%          Name-Value varargin       I   可选参数，Labels、OutputPng
% return : matlab.ui.Figure fig      O   图窗句柄

opts = parseOptions(varargin{:});
solutionFiles = string(solutionFiles);
diagFiles = string(diagFiles);
labels = opts.Labels;
if isempty(labels)
    labels = solutionFiles;
end
labels = string(labels);

fig = figure('Color', 'w', 'Name', 'RTKLIB diagnostic comparison');
tiledlayout(fig, 2, 1, 'TileSpacing', 'compact');

nexttile;
hold on;
for i = 1:numel(solutionFiles)
    sol = localReadPosFile(solutionFiles(i));
    enu = localDemeanLlh(sol);
    if isempty(enu)
        continue
    end
    plot(enu.east, enu.north, '.', 'DisplayName', labels(i));
end
axis equal;
grid on;
xlabel('East error (m)');
ylabel('North error (m)');
legend('Interpreter', 'none', 'Location', 'best');
title('Position scatter');

nexttile;
hold on;
for i = 1:numel(diagFiles)
    if strlength(diagFiles(i)) == 0 || ~isfile(diagFiles(i))
        continue
    end
    diag = readtable(diagFiles(i), 'TextType', 'string');
    if ~ismember('var_factor', diag.Properties.VariableNames)
        continue
    end
    plot(1:height(diag), diag.var_factor, '.', 'DisplayName', labels(min(i,numel(labels))));
end
grid on;
xlabel('Diagnostic row');
ylabel('Variance factor');
set(gca, 'YScale', 'log');
legend('Interpreter', 'none', 'Location', 'best');
title('Diagnostic variance factor');

if strlength(opts.OutputPng) > 0
    exportgraphics(fig, opts.OutputPng, 'Resolution', 150);
end
end

function opts = parseOptions(varargin)
%PARSEOPTIONS 解析绘图脚本参数
% args   : Name-Value varargin I   参数键值列表
% return : struct opts         O   参数结构

p = inputParser;
addParameter(p, 'Labels', strings(0,1), @(x) ischar(x) || isstring(x) || iscellstr(x));
addParameter(p, 'OutputPng', "", @(x) ischar(x) || isstring(x));
parse(p, varargin{:});
opts = p.Results;
opts.Labels = string(opts.Labels);
opts.OutputPng = string(opts.OutputPng);
end

function sol = localReadPosFile(file)
%LOCALREADPOSFILE 读取RTKLIB llh格式.pos文件
% args   : char/string file I   .pos路径
% return : table sol        O   解算结果表

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

function enu = localDemeanLlh(sol)
%LOCALDEMEANLLH 以自身均值为参考计算近似ENU偏差
% args   : table sol I   解算结果
% return : table enu O   e/n/u偏差表

if isempty(sol)
    enu = table();
    return
end
lat0 = nanmeanLocal(sol.lat);
lon0 = nanmeanLocal(sol.lon);
h0 = nanmeanLocal(sol.height);
lat0Rad = deg2rad(lat0);
metersLat = 111132.92 - 559.82 .* cos(2 .* lat0Rad) + 1.175 .* cos(4 .* lat0Rad);
metersLon = 111412.84 .* cos(lat0Rad) - 93.5 .* cos(3 .* lat0Rad);
east = (sol.lon - lon0) .* metersLon;
north = (sol.lat - lat0) .* metersLat;
up = sol.height - h0;
enu = table(sol.time, east, north, up, sol.Q, sol.ns, 'VariableNames', {'time','east','north','up','Q','ns'});
end

function y = nanmeanLocal(x)
%NANMEANLOCAL 计算忽略NaN的均值
% args   : double x I   输入向量
% return : double y O   均值

x = double(x(:));
x = x(~isnan(x));
if isempty(x)
    y = NaN;
else
    y = mean(x);
end
end
