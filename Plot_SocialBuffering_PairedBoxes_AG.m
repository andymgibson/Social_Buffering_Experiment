function Data = Plot_SocialBuffering_PairedBoxes_AG(Obj, outpath, type, alpha, days, aggFun)
% Plot_SocialBuffering_PairedBoxes_AG
% Andrew Gibson, 2025
% Rangel Lab - Sanford Social Buffering Experiment
%
% Makes paired boxplots comparing Solo vs Cagemate conditions.
% Runs Wilcoxon signed-rank test (signrank) on each metric and saves figures.
%
% INPUTS
%   Obj: for our lab this takes the Rat struct
%   outpath: where to save figures (defaults to ./Behavior_Figures)
%   type: 'MEAN', 'MEDIAN', or 'SUM' (default is mean)
%   alpha: significance threshold for signrank test (default is 0.05)
%   days: cell array of day labels (defaults to D1-D8)
%   aggFun: overrides the aggregation function (optional)
%
% OUTPUTS
%   Data: the Data struct used for plotting
%
% For now, we are plotting D1-4 which is the Arena condition separately from 
% D5-8 which is the Box condition

% defaults
if nargin < 2 || isempty(outpath)
    outpath = fullfile(pwd, 'Behavior_Figures');
end
if nargin < 3 || isempty(type)
    type = 'MEAN';
end
if nargin < 4 || isempty(alpha)
    alpha = 0.05;
end
if nargin < 5 || isempty(days)
    days = arrayfun(@(k) sprintf('D%d', k), 1:8, 'UniformOutput', false);
end

% pick the aggregation function based on type if not specified
if nargin < 6 || isempty(aggFun)
    switch upper(type)
        case 'MEAN'
            aggFun = @mean;
        case 'MEDIAN'
            aggFun = @median;
        case 'SUM'
            aggFun = @sum;
        otherwise
            aggFun = @mean;
    end
end

% build data if needed
if isRatStruct(Obj)
    Data = Build_SocialBuffering_Data_From_Rat_AG(Obj, days, aggFun);
else
    Data = Obj;
end

% set up output folder
outdir = fullfile(outpath, upper(type));
if ~exist(outdir, 'dir')
    mkdir(outdir);
end

fprintf('Saving figures to: %s\n', outdir);
fprintf('Days: %s\n', strjoin(string(days), ', '));
fprintf('Aggregation: %s\n', func2str(aggFun));

% define what plots to make
plotDefs = {
    'Freeze', 'Num', 'Event count';
    'Freeze', 'Dur', 'Duration (s)';
    'Sway',   'Num', 'Event count';
    'Sway',   'Dur', 'Duration (s)'
};

% loop through plots
for k = 1:size(plotDefs, 1)
    beh = plotDefs{k, 1};
    suffix = plotDefs{k, 2};
    ylab = plotDefs{k, 3};

    fieldName = [beh suffix]; % e.g. 'FreezeNum', 'SwayDur'

    if ~isfield(Data, fieldName)
        fprintf('Field %s not found, skipping\n', fieldName);
        continue
    end

    M = Data.(fieldName);

    if ~isnumeric(M) || size(M, 2) ~= 2
        fprintf('Field %s has wrong shape, skipping\n', fieldName);
        continue
    end

    if isfield(Data, 'Rats')
        ratNames = string(Data.Rats);
    else
        ratNames = string((1:size(M, 1))');
    end

    soloVals = M(:, 1);
    cageVals = M(:, 2);

    % only keep rats that have data in both conditions so it's a paired
    % test
    paired = isfinite(soloVals) & isfinite(cageVals);

    if sum(paired) < 2
        fprintf('%s: only %d paired rats, skipping\n', fieldName, sum(paired));
        continue
    end

    xs = soloVals(paired);
    ys = cageVals(paired);
    ratsUsed = ratNames(paired);
    n = numel(xs);

    % run wilcoxon signed-rank test
    pval = NaN;
    zval = NaN;
    try
        [pval, ~, stats] = signrank(xs, ys, 'alpha', alpha, 'method', 'approximate', 'tail', 'both');
        if isfield(stats, 'zval'), zval = stats.zval; end
    catch
        [pval, ~, stats] = signrank(xs, ys, 'alpha', alpha);
        if isfield(stats, 'zval'), zval = stats.zval; end
    end

    fprintf('%s: p = %.4g, n = %d pairs\n', fieldName, pval, n);
    fprintf('  Rats: %s\n', strjoin(ratsUsed, ', '));

    % make the figure
    fig = figure('Visible', 'off', 'Position', [100 100 900 650]);
    ax = axes(fig);
    hold(ax, 'on');

    soloColor = [0 137 255] / 255;    % blue
    cageColor = [175 82 222] / 255;   % purple
    lineColor = [0.55 0.55 0.55];     % paired lines are gray

    bxw = 0.35;

    boxchart(ax, ones(n, 1) - 0.15, xs, 'BoxWidth', bxw, ...
        'BoxFaceColor', soloColor, 'BoxFaceAlpha', 0.35, ...
        'MarkerColor', soloColor, 'JitterOutliers', 'on');

    boxchart(ax, 2*ones(n, 1) + 0.15, ys, 'BoxWidth', bxw, ...
        'BoxFaceColor', cageColor, 'BoxFaceAlpha', 0.35, ...
        'MarkerColor', cageColor, 'JitterOutliers', 'on');

    for i = 1:n
        plot(ax, [1 2], [xs(i) ys(i)], '-', 'Color', lineColor, ...
            'LineWidth', 1.0, 'HandleVisibility', 'off');
    end

    jitter = 0.06;
    scatter(ax, 1 + (rand(n, 1) - 0.5) * 2 * jitter, xs, 30, ...
        'MarkerFaceColor', soloColor, 'MarkerEdgeColor', 'w', ...
        'MarkerFaceAlpha', 0.95, 'HandleVisibility', 'off');
    scatter(ax, 2 + (rand(n, 1) - 0.5) * 2 * jitter, ys, 30, ...
        'MarkerFaceColor', cageColor, 'MarkerEdgeColor', 'w', ...
        'MarkerFaceAlpha', 0.95, 'HandleVisibility', 'off');

    xlim(ax, [0.5 2.5]);
    set(ax, 'XTick', [1 2], 'XTickLabel', {'Solo', 'Cagemate'});
    ylabel(ax, ylab);
    grid(ax, 'on');
    box(ax, 'off');

    ttl = sprintf('%s - %s (%s across %s)', beh, ylab, upper(type), strjoin(string(days), ','));
    title(ax, ttl, 'Interpreter', 'none', 'FontWeight', 'bold');

    % put the legend on the outside so it can't mess with the title
    h1 = plot(ax, nan, nan, 's', 'MarkerSize', 10, ...
        'MarkerFaceColor', soloColor, 'MarkerEdgeColor', 'none', 'DisplayName', 'Solo');
    h2 = plot(ax, nan, nan, 's', 'MarkerSize', 10, ...
        'MarkerFaceColor', cageColor, 'MarkerEdgeColor', 'none', 'DisplayName', 'Cagemate');
    lg = legend(ax, [h1 h2], 'Location', 'northeastoutside', 'Box', 'off');
    lg.FontSize = 11;

    % add significance bracket on top
    yTop = max([xs; ys], [], 'omitnan');
    yBot = min([xs; ys], [], 'omitnan');
    yRange = yTop - yBot;
    if ~isfinite(yRange) || yRange == 0
        yRange = 1;
    end

    yBar = yTop + 0.10 * yRange;
    yTick = 0.03 * yRange;
    yText = yTop + 0.15 * yRange;

    ylim(ax, [yBot - 0.05 * yRange, yTop + 0.22 * yRange]);

    plot(ax, [1 1 2 2], [yBar yBar+yTick yBar+yTick yBar], '-k', ...
        'LineWidth', 1.4, 'HandleVisibility', 'off');

    text(ax, 1.5, yText, pToStars(pval), 'HorizontalAlignment', 'center', ...
        'FontSize', 16, 'FontWeight', 'bold');

    % save as .pngs
    fname = fullfile(outdir, sprintf('%s_%s_%s.png', upper(type), beh, suffix));
    saveFigSafe(fig, fname, 300);
    close(fig);
end

end

% helper functions

function tf = isRatStruct(S)
tf = isstruct(S) && any(startsWith(fieldnames(S), 'CH'));
end

function stars = pToStars(p) % sig asterisks
if ~isfinite(p)
    stars = 'n.s.';
elseif p < 0.001
    stars = '***';
elseif p < 0.01
    stars = '**';
elseif p < 0.05
    stars = '*';
else
    stars = 'n.s.';
end
end

function saveFigSafe(fig, outPath, dpi)
if nargin < 3 || isempty(dpi)
    dpi = 300;
end

outDir = fileparts(outPath);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

if exist(outPath, 'file')
    try, delete(outPath); catch, end
end

drawnow;

try
    if exist('exportgraphics', 'file')
        exportgraphics(fig, outPath, 'Resolution', dpi);
    else
        set(fig, 'PaperPositionMode', 'auto');
        print(fig, outPath, '-dpng', ['-r' num2str(dpi)]);
    end
catch
    tmpFile = [tempname '.png'];
    if exist('exportgraphics', 'file')
        exportgraphics(fig, tmpFile, 'Resolution', dpi);
    else
        set(fig, 'PaperPositionMode', 'auto');
        print(fig, tmpFile, '-dpng', ['-r' num2str(dpi)]);
    end
    movefile(tmpFile, outPath, 'f');
end

end
