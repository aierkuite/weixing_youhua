% 生成 Hatch 平滑窗口指标表、对比图和数据适用性证据
addpath('G:/weixing_youhua/tools/matlab');

task = 'G:/weixing_youhua/.trellis/tasks/06-12-hatch-smoothing-robust-grouping/';

geopSols = [task + "geop_smooth0.pos"; task + "geop_smooth30.pos"];
geopLabels = ["geop_smoothwin_0"; "geop_smoothwin_30"];
geopMetrics = smoothwinMetrics(geopSols, geopLabels, [0; 30], 30);
writetable(geopMetrics, task + "smoothwin_geop_metrics.csv");
disp(geopMetrics);

rtkSols = [task + "rtk_smooth0.pos"; task + "rtk_smooth30.pos"];
rtkLabels = ["rtk_smoothwin_0"; "rtk_smoothwin_30"];
rtkMetrics = smoothwinMetrics(rtkSols, rtkLabels, [0; 30], 30);
writetable(rtkMetrics, task + "smoothwin_rtk_metrics.csv");
disp(rtkMetrics);

geopFig = smoothwinPlot(geopSols, geopLabels, task + "smoothwin_geop_enu.png");
close(geopFig);
rtkFig = smoothwinPlot(rtkSols, rtkLabels, task + "smoothwin_rtk_enu.png");
close(rtkFig);

geopObs = rinexObsAvailability('G:/weixing_youhua/RTKLIB-2.4.3-b34/RTKLIB-2.4.3-b34/app/consapp/rnx2rtkp/gcc/GEOP156M.26o');
writetable(geopObs, task + "geop_obs_availability.csv");
disp(geopObs);

disp('smoothwin metrics regenerated');

function metrics = smoothwinMetrics(solutionFiles, labels, windows, convergenceEpochs)
%SMOOTHWINMETRICS 汇总Hatch平滑开关前后的全时段和稳态ENU指标
% args   : string solutionFiles     I   .pos文件路径列表
%          string labels            I   指标标签
%          double windows           I   Hatch平滑窗口历元数
%          double convergenceEpochs I   收敛期历元数量
% return : table metrics            O   每组全时段和稳态STD/RMS指标

rows = cell(numel(solutionFiles), 1);
for i = 1:numel(solutionFiles)
    sol = readPosFile(solutionFiles(i));
    enu = demeanLlh(sol);
    if height(enu) > convergenceEpochs
        stable = enu((convergenceEpochs + 1):height(enu), :);
    else
        stable = table();
    end
    rows{i} = table(labels(i), windows(i), height(enu), height(stable), ...
        nanstdLocal(enu.east), nanstdLocal(enu.north), nanstdLocal(enu.up), ...
        rmsValue(enu.east), rmsValue(enu.north), rmsValue(enu.up), ...
        nanstdLocal(stable.east), nanstdLocal(stable.north), nanstdLocal(stable.up), ...
        rmsValue(stable.east), rmsValue(stable.north), rmsValue(stable.up), ...
        'VariableNames', {'label','smoothwin','epochs','stable_epochs', ...
        'std_e','std_n','std_u','rms_e','rms_n','rms_u', ...
        'stable_std_e','stable_std_n','stable_std_u', ...
        'stable_rms_e','stable_rms_n','stable_rms_u'});
end
metrics = vertcat(rows{:});
end

function fig = smoothwinPlot(solutionFiles, labels, outputPng)
%SMOOTHWINPLOT 绘制Hatch平滑前后ENU时间序列和水平散点
% args   : string solutionFiles I   .pos文件路径列表
%          string labels        I   图例标签
%          string outputPng     I   输出PNG路径
% return : matlab.ui.Figure fig O   图窗句柄

fig = figure('Color', 'w', 'Name', 'Hatch smoothing comparison');
tiledlayout(fig, 2, 2, 'TileSpacing', 'compact');
axisNames = ["east", "north", "up"];
axisLabels = ["East (m)", "North (m)", "Up (m)"];

for a = 1:3
    nexttile;
    hold on;
    for i = 1:numel(solutionFiles)
        sol = readPosFile(solutionFiles(i));
        enu = demeanLlh(sol);
        plot(1:height(enu), enu.(axisNames(a)), '.', 'DisplayName', labels(i));
    end
    grid on;
    xlabel('Epoch');
    ylabel(axisLabels(a));
    legend('Interpreter', 'none', 'Location', 'best');
end

nexttile;
hold on;
for i = 1:numel(solutionFiles)
    sol = readPosFile(solutionFiles(i));
    enu = demeanLlh(sol);
    plot(enu.east, enu.north, '.', 'DisplayName', labels(i));
end
axis equal;
grid on;
xlabel('East (m)');
ylabel('North (m)');
legend('Interpreter', 'none', 'Location', 'best');

exportgraphics(fig, outputPng, 'Resolution', 150);
end

function availability = rinexObsAvailability(file)
%RINEXOBSAVAILABILITY 统计RINEX 3观测文件中各观测类型的非空数量
% args   : char/string file I   RINEX观测文件路径
% return : table availability O  系统、观测类型、非空数量和总数量

lines = splitlines(fileread(file));
types = containers.Map('KeyType', 'char', 'ValueType', 'any');
startLine = 0;
for i = 1:numel(lines)
    line = char(lines{i});
    if contains(line, 'SYS / # / OBS TYPES')
        sys = line(1);
        ntype = str2double(strtrim(line(4:6)));
        obsTypes = splitObsTypes(line);
        j = i;
        while numel(obsTypes) < ntype
            j = j + 1;
            obsTypes = [obsTypes, splitObsTypes(char(lines{j}))]; %#ok<AGROW>
        end
        types(sys) = obsTypes(1:ntype);
    end
    if contains(line, 'END OF HEADER')
        startLine = i + 1;
        break
    end
end

systems = strings(0, 1);
obsTypesOut = strings(0, 1);
nonblank = zeros(0, 1);
total = zeros(0, 1);
keysList = keys(types);
for k = 1:numel(keysList)
    sys = keysList{k};
    obsTypes = string(types(sys));
    count = zeros(numel(obsTypes), 1);
    denom = zeros(numel(obsTypes), 1);
    for i = startLine:numel(lines)
        line = char(lines{i});
        if isempty(line) || startsWith(line, '>')
            continue
        end
        if line(1) ~= sys
            continue
        end
        payload = line(4:end);
        for j = 1:numel(obsTypes)
            col1 = (j - 1) * 16 + 1;
            col2 = min(j * 16, length(payload));
            if col1 > length(payload)
                field = '';
            else
                field = payload(col1:col2);
            end
            denom(j) = denom(j) + 1;
            if strlength(strtrim(string(extractBefore(field + "              ", 15)))) > 0
                count(j) = count(j) + 1;
            end
        end
    end
    systems = [systems; repmat(string(sys), numel(obsTypes), 1)]; %#ok<AGROW>
    obsTypesOut = [obsTypesOut; obsTypes(:)]; %#ok<AGROW>
    nonblank = [nonblank; count]; %#ok<AGROW>
    total = [total; denom]; %#ok<AGROW>
end
availability = table(systems, obsTypesOut, nonblank, total, ...
    'VariableNames', {'system','obs_type','nonblank','total'});
end

function obsTypes = splitObsTypes(line)
%SPLITOBSTYPES 提取RINEX 3观测类型行中的观测类型
% args   : char line       I   RINEX头部观测类型行
% return : string obsTypes O   观测类型列表

if length(line) < 60
    line(end+1:60) = ' ';
end
obsTypes = string(strsplit(strtrim(line(8:60))));
obsTypes(obsTypes == "") = [];
end

function sol = readPosFile(file)
%READPOSFILE 读取RTKLIB llh格式.pos文件
% args   : char/string file I   .pos路径
% return : table sol        O   解算时间、经纬高和状态表

lines = splitlines(fileread(file));
data = strings(0, 1);
for i = 1:numel(lines)
    line = string(lines{i});
    if strlength(strtrim(line)) == 0 || startsWith(strtrim(line), "%")
        continue
    end
    data(end+1, 1) = line; %#ok<AGROW>
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
