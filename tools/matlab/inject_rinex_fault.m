function stats = inject_rinex_fault(inputFile, outputFile, varargin)
%INJECT_RINEX_FAULT 向RINEX OBS文件注入伪距阶跃、SNR压低或载波周跳
% args   : char/string inputFile   I   输入RINEX OBS文件路径
%          char/string outputFile  I   输出RINEX OBS文件路径
%          Name-Value varargin     I   可选参数，Mode、Satellite、StartTime、EndTime、CodeBias、SnrDrop、Systems、Codes、L1Slip、L2Slip
% return : table stats             O   每颗卫星被修改的记录数统计
%
% Mode="code"保留原行为，对伪距加CodeBias并压低SNR
% Mode="cycle-slip"对L1/L2载波相位加整周跳，默认L1+9周、L2+7周为GF盲区组合
% Mode="both"同时注入伪距/SNR故障和载波周跳

opts = parseOptions(varargin{:});
lines = readTextLines(inputFile);
[version, obsTypes, headerEnd] = parseHeader(lines);

statsMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
i = headerEnd + 1;
while i <= numel(lines)
    [isEpoch, epochTime, flag, sats, consumed] = parseEpoch(lines, i, version);
    if ~isEpoch
        i = i + 1;
        continue
    end
    i = i + consumed;
    activeEpoch = flag <= 2 && inTimeWindow(epochTime, opts.StartTime, opts.EndTime);
    for s = 1:numel(sats)
        if i > numel(lines)
            break
        end
        if version > 2.99
            satLine = padLine(lines{i}, 3);
            sat = normalizeSat(satLine(1:3));
        else
            sat = normalizeSat(sats{s});
        end
        sys = sat(1);
        types = getObsTypes(obsTypes, sys);
        nLines = obsRecordLines(version, types);
        satLines = lines(i:min(i+nLines-1, numel(lines)));
        if activeEpoch && shouldEditSatellite(sat, opts)
            [satLines, changed] = editObservationLines(satLines, types, opts, version);
            if changed
                key = char(sat);
                if isKey(statsMap, key)
                    statsMap(key) = statsMap(key) + 1;
                else
                    statsMap(key) = 1;
                end
            end
        end
        lines(i:i+nLines-1) = satLines;
        i = i + nLines;
    end
end

writeTextLines(outputFile, lines);
stats = mapToTable(statsMap);
end

function opts = parseOptions(varargin)
%PARSEOPTIONS 解析注入工具的Name-Value参数
% args   : Name-Value varargin I   参数键值列表
% return : struct opts         O   注入参数结构

p = inputParser;
addParameter(p, 'Mode', "code", @(x) ischar(x) || isstring(x));
addParameter(p, 'Satellite', "", @(x) ischar(x) || isstring(x) || iscellstr(x));
addParameter(p, 'StartTime', NaT, @(x) isdatetime(x) || ischar(x) || isstring(x));
addParameter(p, 'EndTime', NaT, @(x) isdatetime(x) || ischar(x) || isstring(x));
addParameter(p, 'CodeBias', 30.0, @isnumeric);
addParameter(p, 'SnrDrop', 15.0, @isnumeric);
addParameter(p, 'Systems', "G", @(x) ischar(x) || isstring(x));
addParameter(p, 'Codes', ["C1C","C1P","C1","P1"], @(x) ischar(x) || isstring(x) || iscellstr(x));
addParameter(p, 'L1Slip', 9.0, @isnumeric);
addParameter(p, 'L2Slip', 7.0, @isnumeric);
parse(p, varargin{:});
opts = p.Results;
opts.Mode = normalizeMode(opts.Mode);
opts.Satellite = normalizeStringList(opts.Satellite);
opts.Systems = char(string(opts.Systems));
opts.Codes = normalizeStringList(opts.Codes);
opts.StartTime = normalizeTime(opts.StartTime);
opts.EndTime = normalizeTime(opts.EndTime);
opts.CodeBias = double(opts.CodeBias);
opts.SnrDrop = double(opts.SnrDrop);
opts.L1Slip = double(opts.L1Slip);
opts.L2Slip = double(opts.L2Slip);
end

function mode = normalizeMode(mode)
%NORMALIZEMODE 标准化故障注入模式
% args   : char/string mode I   原始模式文本
% return : string mode      O   标准化模式，取值code、cycle-slip或both

mode = lower(strtrim(string(mode)));
if mode == "cycleslip" || mode == "cycle_slip"
    mode = "cycle-slip";
end
valid = ["code","cycle-slip","both"];
if ~any(mode == valid)
    error('inject_rinex_fault:mode', 'Mode必须为code、cycle-slip或both');
end
end

function values = normalizeStringList(value)
%NORMALIZESTRINGLIST 将字符、字符串或cellstr标准化为string数组
% args   : char/string/cell value I   输入文本列表
% return : string values          O   标准化后的字符串数组

if iscell(value)
    values = string(value);
elseif strlength(string(value)) == 0
    values = strings(0, 1);
else
    values = string(value);
end
values = strip(values(:));
values = values(values ~= "");
end

function value = normalizeTime(value)
%NORMALIZETIME 将输入时间转换为datetime
% args   : datetime/char/string value I   输入时间
% return : datetime value             O   标准化时间，空值为NaT

if isdatetime(value)
    return
end
if strlength(string(value)) == 0
    value = NaT;
else
    value = datetime(string(value), 'InputFormat', 'yyyy-MM-dd HH:mm:ss', 'TimeZone', 'UTC');
end
end

function lines = readTextLines(file)
%READTEXTLINES 以UTF-8按行读取文本文件
% args   : char/string file I   文件路径
% return : cell lines       O   行文本cell数组

txt = fileread(file);
txt = regexprep(txt, '\r\n|\r|\n', newline);
if endsWith(txt, newline)
    txt = extractBefore(txt, strlength(txt));
end
lines = cellstr(splitlines(txt));
end

function writeTextLines(file, lines)
%WRITETEXTLINES 以UTF-8无BOM和CRLF写入文本文件
% args   : char/string file I   文件路径
%          cell lines       I   行文本cell数组
% return : 无

folder = fileparts(char(file));
if ~isempty(folder) && ~exist(folder, 'dir')
    mkdir(folder);
end
fid = fopen(file, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid));
for i = 1:numel(lines)
    fprintf(fid, '%s\r\n', lines{i});
end
end

function [version, obsTypes, headerEnd] = parseHeader(lines)
%PARSEHEADER 解析RINEX版本和观测类型表
% args   : cell lines          I   RINEX文件行
% return : double version      O   RINEX版本
%          containers.Map obsTypes O 系统到观测类型的映射
%          double headerEnd    O   头结束行号

version = sscanf(lines{1}(1:min(9,end)), '%f', 1);
obsTypes = containers.Map('KeyType', 'char', 'ValueType', 'any');
headerEnd = 0;
i = 1;
while i <= numel(lines)
    line = padLine(lines{i}, 80);
    label = strtrim(line(61:80));
    if contains(label, 'SYS / # / OBS TYPES')
        sys = line(1);
        n = sscanf(line(4:6), '%d', 1);
        [types, used] = readRinex3Types(lines, i, n);
        obsTypes(sys) = types;
        i = i + used;
        continue
    elseif contains(label, '# / TYPES OF OBSERV')
        n = sscanf(line(1:6), '%d', 1);
        [types, used] = readRinex2Types(lines, i, n);
        for sys = ['G','R','E','J','S','C','I']
            obsTypes(sys) = convertRinex2Types(types);
        end
        i = i + used;
        continue
    elseif contains(label, 'END OF HEADER')
        headerEnd = i;
        break
    end
    i = i + 1;
end
if headerEnd == 0
    error('inject_rinex_fault:header', '未找到END OF HEADER');
end
end

function [types, used] = readRinex3Types(lines, startLine, n)
%READRINEX3TYPES 读取RINEX 3系统观测类型
% args   : cell lines       I   文件行
%          double startLine I   起始行号
%          double n         I   类型数量
% return : string types     O   观测类型
%          double used      O   消耗行数

types = strings(0, 1);
used = 0;
while numel(types) < n
    line = padLine(lines{startLine + used}, 80);
    for k = 8:4:60
        token = strtrim(line(k:min(k+2, 60)));
        if token ~= ""
            types(end+1, 1) = string(token); %#ok<AGROW>
        end
        if numel(types) >= n
            break
        end
    end
    used = used + 1;
end
end

function [types, used] = readRinex2Types(lines, startLine, n)
%READRINEX2TYPES 读取RINEX 2观测类型
% args   : cell lines       I   文件行
%          double startLine I   起始行号
%          double n         I   类型数量
% return : string types     O   观测类型
%          double used      O   消耗行数

types = strings(0, 1);
used = 0;
while numel(types) < n
    line = padLine(lines{startLine + used}, 80);
    for k = 11:6:59
        token = strtrim(line(k:min(k+1, 60)));
        if token ~= ""
            types(end+1, 1) = string(token); %#ok<AGROW>
        end
        if numel(types) >= n
            break
        end
    end
    used = used + 1;
end
end

function types = convertRinex2Types(types)
%CONVERTRINEX2TYPES 将RINEX 2观测类型扩展为三字符类型
% args   : string types I   RINEX 2观测类型
% return : string types O   三字符观测类型

for i = 1:numel(types)
    t = char(types(i));
    if numel(t) == 2
        if t(1) == 'C' || t(1) == 'P'
            types(i) = string([t(1), t(2), t(1)]);
        elseif t(1) == 'L' || t(1) == 'D' || t(1) == 'S'
            types(i) = string([t(1), t(2), 'C']);
        end
    end
end
end

function [isEpoch, epochTime, flag, sats, consumed] = parseEpoch(lines, i, version)
%PARSEEPOCH 解析RINEX历元行和卫星列表
% args   : cell lines       I   文件行
%          double i         I   当前行号
%          double version   I   RINEX版本
% return : logical isEpoch  O   是否为历元行
%          datetime epochTime O 历元时间
%          double flag      O   历元标志
%          cell sats        O   卫星编号列表
%          double consumed  O   历元头消耗行数

line = padLine(lines{i}, 80);
isEpoch = false;
epochTime = NaT;
flag = 0;
sats = {};
consumed = 1;
if version > 2.99
    if ~startsWith(line, '>')
        return
    end
    vals = sscanf(line(2:32), '%d %d %d %d %d %f');
    if numel(vals) < 6
        return
    end
    epochTime = datetime(vals(1), vals(2), vals(3), vals(4), vals(5), vals(6), 'TimeZone', 'UTC');
    flag = sscanf(line(32), '%d', 1);
    nsat = sscanf(line(33:35), '%d', 1);
    isEpoch = true;
    sats = cell(1, nsat);
    return
end
vals = sscanf(line(1:26), '%d %d %d %d %d %f');
if numel(vals) < 6
    return
end
year = vals(1);
if year < 80
    year = year + 2000;
elseif year < 100
    year = year + 1900;
end
epochTime = datetime(year, vals(2), vals(3), vals(4), vals(5), vals(6), 'TimeZone', 'UTC');
flag = sscanf(line(29), '%d', 1);
nsat = sscanf(line(30:32), '%d', 1);
satText = line(33:min(end, 80));
while numel(satText) < nsat * 3 && i + consumed <= numel(lines)
    satText = [satText, padLine(lines{i + consumed}, 80)]; %#ok<AGROW>
    consumed = consumed + 1;
end
sats = cell(1, nsat);
for k = 1:nsat
    sats{k} = strtrim(satText((k-1)*3+1:min(k*3, numel(satText))));
end
isEpoch = true;
end

function sat = normalizeSat(sat)
%NORMALIZESAT 将RINEX卫星号标准化为G07格式
% args   : char/string sat I   RINEX卫星号
% return : char sat        O   标准化卫星号

sat = char(strtrim(string(sat)));
if numel(sat) >= 2 && isletter(sat(1))
    num = sscanf(sat(2:end), '%d', 1);
    if ~isempty(num)
        sat = sprintf('%c%02d', sat(1), num);
    end
end
end

function ok = inTimeWindow(t, startTime, endTime)
%INTIMEWINDOW 判断历元是否落入注入时间窗
% args   : datetime t         I   历元时间
%          datetime startTime I   起始时间
%          datetime endTime   I   结束时间
% return : logical ok         O   是否在时间窗内

ok = true;
if ~isnat(startTime)
    ok = ok && t >= startTime;
end
if ~isnat(endTime)
    ok = ok && t <= endTime;
end
end

function ok = shouldEditSatellite(sat, opts)
%SHOULDEDITSATELLITE 判断卫星是否需要注入
% args   : char sat    I   卫星编号
%          struct opts I   注入参数
% return : logical ok  O   是否编辑该卫星

sat = string(strtrim(sat));
if sat == ""
    ok = false;
    return
end
if ~isempty(opts.Satellite)
    ok = any(opts.Satellite == sat);
else
    ok = contains(opts.Systems, extractBefore(sat, 2));
end
end

function nLines = obsRecordLines(version, types)
%OBSRECORDLINES 计算单颗卫星观测记录占用行数
% args   : double version I   RINEX版本
%          string types   I   观测类型列表
% return : double nLines  O   记录行数

if version > 2.99
    nLines = 1;
else
    nLines = max(1, ceil(numel(types) / 5));
end
end

function types = getObsTypes(obsTypes, sys)
%GETOBSTYPES 获取指定系统的观测类型列表
% args   : containers.Map obsTypes I   系统到观测类型的映射
%          char sys                I   系统字符
% return : string types            O   观测类型列表

if isKey(obsTypes, sys)
    types = obsTypes(sys);
else
    types = strings(0, 1);
end
end

function [satLines, changed] = editObservationLines(satLines, types, opts, version)
%EDITOBSERVATIONLINES 修改一个卫星的观测字段
% args   : cell satLines I   该卫星观测行
%          string types  I   观测类型列表
%          struct opts   I   注入参数
%          double version I   RINEX版本
% return : cell satLines O   修改后的观测行
%          logical changed O 是否发生修改

changed = false;
editCode = opts.Mode == "code" || opts.Mode == "both";
editSlip = opts.Mode == "cycle-slip" || opts.Mode == "both";
paddedLines = padLine(satLines, 80);
flat = [paddedLines{:}];
if isempty(flat)
    return
end
offset = version > 2.99;
base = 1 + 3 * offset;
for j = 1:numel(types)
    type = string(types(j));
    pos = base + (j - 1) * 16;
    if pos + 13 > numel(flat)
        continue
    end
    field = flat(pos:min(pos+15, numel(flat)));
    if numel(field) < 14
        continue
    end
    valueText = field(1:14);
    value = str2double(strtrim(valueText));
    if isnan(value)
        continue
    end
    if editCode && (startsWith(type, 'C') || startsWith(type, 'P'))
        if isempty(opts.Codes) || any(opts.Codes == type) || any(opts.Codes == extractBefore(type, 3))
            value = value + opts.CodeBias;
            flat(pos:pos+13) = char(formatObsValue(value));
            changed = true;
        end
    elseif editCode && startsWith(type, 'S')
        value = max(0, value - opts.SnrDrop);
        flat(pos:pos+13) = char(formatObsValue(value));
        changed = true;
    elseif editSlip && startsWith(type, 'L')
        slip = carrierSlipCycles(type, opts);
        if slip ~= 0.0
            value = value + slip;
            flat(pos:pos+13) = char(formatObsValue(value));
            changed = true;
        end
    end
end
satLines = reshapeObservationText(flat, numel(satLines), version);
end

function slip = carrierSlipCycles(type, opts)
%CARRIERSLIPCYCLES 返回指定载波观测类型需要注入的整周跳
% args   : string type I   RINEX观测类型，例如L1C或L2W
%          struct opts I   注入参数结构
% return : double slip O   需要叠加到载波相位字段的周数

text = char(type);
slip = 0.0;
if numel(text) < 2
    return
end
if text(2) == '1'
    slip = opts.L1Slip;
elseif text(2) == '2'
    slip = opts.L2Slip;
end
end

function value = formatObsValue(x)
%FORMATOBSVALUE 将观测数值格式化为14字符字段
% args   : double x     I   观测值
% return : string value O   14字符数值字段

value = string(sprintf('%14.3f', x));
end

function lines = reshapeObservationText(flat, nLines, version)
%RESHAPEOBSERVATIONTEXT 将扁平观测文本按80字符拆回多行
% args   : string flat  I   扁平观测文本
%          double nLines I  原行数
%          double version I RINEX版本
% return : cell lines   O   拆分后的行

chars = char(flat);
if version > 2.99
    lines = {strtrimRight(chars)};
    return
end
lines = cell(1, nLines);
for i = 1:nLines
    a = (i - 1) * 80 + 1;
    b = min(i * 80, numel(chars));
    if a <= numel(chars)
        lines{i} = strtrimRight(chars(a:b));
    else
        lines{i} = '';
    end
end
end

function out = strtrimRight(in)
%STRTRIMRIGHT 去除字符串右侧空白
% args   : char in  I   输入字符串
% return : char out O   去除右侧空白后的字符串

out = regexprep(in, '\s+$', '');
end

function out = padLine(in, width)
%PADLINE 将行补齐到指定宽度
% args   : char/cell in I   输入行或行列表
%          double width I   目标宽度
% return : char/cell out O  补齐后的行或行列表

if iscell(in)
    out = cellfun(@(x) padLine(x, width), in, 'UniformOutput', false);
    return
end
out = char(in);
if numel(out) < width
    out = [out, repmat(' ', 1, width - numel(out))];
end
end

function stats = mapToTable(statsMap)
%MAPTOTABLE 将修改统计映射转换为表
% args   : containers.Map statsMap I   卫星到修改记录数的映射
% return : table stats             O   统计表

keys = string(statsMap.keys)';
records = zeros(numel(keys), 1);
for i = 1:numel(keys)
    records(i) = statsMap(char(keys(i)));
end
stats = table(keys, records, 'VariableNames', {'sat', 'records'});
end
