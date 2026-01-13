function Data = Build_SocialBuffering_Data_From_Rat_AG(Rat, days, aggFun)
% Build_SocialBuffering_Data_From_Rat_AG
% Andrew Gibson, 2025
% Rangel Lab - Sanford Social Buffering Experiment
%
% Builds per-rat Solo vs Cagemate summaries for freeze/sway behaviors.
% Loops through each rat's days, extracts behavior intervals,
% and aggregates within each condition so we can compare Solo vs Cagemate.
%
% INPUTS
%   Rat: struct with fields for each rat
%   days: cell array of day labels, e.g. {'D1','D2',...} (defaults to D1-D8)
%   aggFun: function handle for aggregation: @mean, @median, @sum (default is mean)
%
% OUTPUTS
%   Data: struct with FreezeNum, FreezeDur, SwayNum, SwayDur (each Nx2)
%           column 1 = Solo, column 2 = Cagemate

% set up defaults
if nargin < 2 || isempty(days)
    days = arrayfun(@(k) sprintf('D%d', k), 1:8, 'UniformOutput', false);
end
if nargin < 3 || isempty(aggFun)
    aggFun = @mean;
end

% behavior keys - we look for these fields (case-insensitive)
freezeKeys = {'freezing', 'freeze'};
swayKeys   = {'sway', 'head_sway', 'vigilance'};

% figure out which rats we have
allFields = fieldnames(Rat);
rats = allFields(startsWith(allFields, 'CH'));
rats = sort(rats);
nRats = numel(rats);

% initialize storage
Store = struct();
for i = 1:nRats
    rr = rats{i};
    Store.(rr).Solo     = struct('FreezeNum', [], 'FreezeDur', [], 'SwayNum', [], 'SwayDur', []);
    Store.(rr).Cagemate = struct('FreezeNum', [], 'FreezeDur', [], 'SwayNum', [], 'SwayDur', []);
end

% loop through rats and days to extract behavior
for i = 1:nRats
    rr = rats{i};

    for d = 1:numel(days)
        dd = days{d};

        % skip if day missing
        if ~isfield(Rat.(rr), dd)
            continue
        end

        D = Rat.(rr).(dd);

        % figure out condition (Solo vs Cagemate)
        cond = inferCondition(D);
        if ~ismember(cond, {'Solo', 'Cagemate'})
            continue
        end

        % pick which marker struct to use
        intervals = [];
        if isfield(D, 'Markers_interval') && ~isempty(D.Markers_interval)
            intervals = D.Markers_interval;
        elseif isfield(D, 'Markersets') && ~isempty(D.Markersets)
            intervals = D.Markersets;
        else
            continue
        end

        % freeze
        [freezeIV, ~] = findBehaviorField(intervals, freezeKeys);
        if isempty(freezeIV)
            nFreeze = NaN;
            durFreeze = NaN;
        else
            nFreeze = size(freezeIV, 1);
            durFreeze = sum(max(0, freezeIV(:,2) - freezeIV(:,1)));
        end

        % sway
        [swayIV, ~] = findBehaviorField(intervals, swayKeys);
        if isempty(swayIV)
            nSway = NaN;
            durSway = NaN;
        else
            nSway = size(swayIV, 1);
            durSway = sum(max(0, swayIV(:,2) - swayIV(:,1)));
        end

        % only store if finite
        if isfinite(nFreeze),   Store.(rr).(cond).FreezeNum(end+1) = nFreeze; end
        if isfinite(durFreeze), Store.(rr).(cond).FreezeDur(end+1) = durFreeze; end
        if isfinite(nSway),     Store.(rr).(cond).SwayNum(end+1)   = nSway;   end
        if isfinite(durSway),   Store.(rr).(cond).SwayDur(end+1)   = durSway; end
    end
end

% aggregate across days for each rat
freezeNum = nan(nRats, 2);
freezeDur = nan(nRats, 2);
swayNum   = nan(nRats, 2);
swayDur   = nan(nRats, 2);

for i = 1:nRats
    rr = rats{i};

    freezeNum(i, 1) = safeAggregate(Store.(rr).Solo.FreezeNum, aggFun);
    freezeNum(i, 2) = safeAggregate(Store.(rr).Cagemate.FreezeNum, aggFun);

    freezeDur(i, 1) = safeAggregate(Store.(rr).Solo.FreezeDur, aggFun);
    freezeDur(i, 2) = safeAggregate(Store.(rr).Cagemate.FreezeDur, aggFun);

    swayNum(i, 1) = safeAggregate(Store.(rr).Solo.SwayNum, aggFun);
    swayNum(i, 2) = safeAggregate(Store.(rr).Cagemate.SwayNum, aggFun);

    swayDur(i, 1) = safeAggregate(Store.(rr).Solo.SwayDur, aggFun);
    swayDur(i, 2) = safeAggregate(Store.(rr).Cagemate.SwayDur, aggFun);
end

% package output
Data = struct();
Data.Rats      = rats(:);
Data.DaysUsed  = days(:);
Data.AggFun    = func2str(aggFun);
Data.FreezeNum = freezeNum;
Data.FreezeDur = freezeDur;
Data.SwayNum   = swayNum;
Data.SwayDur   = swayDur;

end

% helpers

function cond = inferCondition(D)
% inferCondition figures out Solo vs Cagemate from day struct
% checks social_cond field first and falls back to session_type if needed

cond = 'Unknown';
if ~isstruct(D), return; end

sc = "";
st = "";

if isfield(D, 'social_cond')
    sc = lower(string(D.social_cond));
end
if isfield(D, 'session_type')
    st = lower(string(D.session_type));
end

if strlength(sc) > 0
    if contains(sc, 'cage') || contains(sc, 'mate') || contains(sc, 'pair')
        cond = 'Cagemate'; return
    elseif contains(sc, 'solo') || contains(sc, 'alone')
        cond = 'Solo'; return
    end
end

txt = lower(join([sc, st], ' '));
if contains(txt, 'cage') || contains(txt, 'mate') || contains(txt, 'pair')
    cond = 'Cagemate';
elseif contains(txt, 'solo') || contains(txt, 'alone')
    cond = 'Solo';
end

end

function [iv, keyUsed] = findBehaviorField(S, keys)
% findBehaviorField is case-insensitive search for behavior field

iv = [];
keyUsed = '';

if ~isstruct(S)
    return
end

fnames = fieldnames(S);
fnamesLower = lower(string(fnames));

for k = 1:numel(keys)
    target = lower(string(keys{k}));
    idx = find(fnamesLower == target, 1);

    if ~isempty(idx)
        keyUsed = fnames{idx};
        if ~isempty(S.(keyUsed))
            iv = S.(keyUsed);
        end
        return
    end
end

end

function v = safeAggregate(x, aggFun)
% safeAggregate applies aggregation function, returns NaN if empty
% also filters out any non-finite values before aggregating

x = x(:);
x = x(isfinite(x));

if isempty(x)
    v = NaN;
else
    v = aggFun(x);
end

end
