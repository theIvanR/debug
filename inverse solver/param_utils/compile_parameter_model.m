function [model, pFixed] = compile_parameter_model(driver, features)
%COMPILE_PARAMETER_MODEL  Compile declarative driver into numerical model.
%
% Inputs
%   driver   : parameter specification struct
%   features : optional struct with data-driven seeds (Re0, Le0)
%
% Outputs
%   model    : numerical fit model for the optimizer
%   pFixed   : fixed physical parameters

    if nargin < 2 || isempty(features)
        features = struct();
    end

    fitOrder  = {'Re','Le','Bl','Rms','Mms','Cms'};
    fixedOrder = {'Sd','rho','c'};

    model = struct();
    model.names     = {};
    model.transform  = {};
    model.x0        = [];
    model.lb        = [];
    model.ub        = [];
    model.fitMask   = [];
    model.priorSpec = struct();

    pFixed = struct();

    for i = 1:numel(fitOrder)
        name = fitOrder{i};

        if ~isfield(driver, name)
            error('driver.%s is missing.', name);
        end

        spec = driver.(name);
        fitFlag = getfield_default(spec, 'fit', false);

        if fitFlag
            init = getfield_default(spec, 'initial', []);
            lo   = getfield_default(spec, 'lower', []);
            hi   = getfield_default(spec, 'upper', []);
            tf   = lower(getfield_default(spec, 'transform', 'log'));

            if isempty(init) || isempty(lo) || isempty(hi)
                error('driver.%s must define initial/lower/upper when fit=true.', name);
            end

            % Preserve the old behavior: use data-driven seeds for Re/Le if available
            if strcmp(name, 'Re') && isfield(features, 'Re0') && isfinite(features.Re0) && features.Re0 > 0
                init = features.Re0;
            elseif strcmp(name, 'Le') && isfield(features, 'Le0') && isfinite(features.Le0) && features.Le0 > 0
                init = features.Le0;
            end

            model.names{end+1,1} = name;
            model.transform{end+1,1} = tf;
            model.fitMask(end+1,1) = true;
            model.x0(end+1,1) = forward_transform(init, tf);
            model.lb(end+1,1) = forward_transform(lo, tf);
            model.ub(end+1,1) = forward_transform(hi, tf);
            model.priorSpec.(name) = spec;
        else
            if ~isfield(spec, 'value')
                error('driver.%s must define value when fit=false.', name);
            end
            pFixed.(name) = spec.value;
        end
    end

    for i = 1:numel(fixedOrder)
        name = fixedOrder{i};

        if ~isfield(driver, name)
            error('driver.%s is missing.', name);
        end

        spec = driver.(name);
        if ~isfield(spec, 'value')
            error('driver.%s must define value when fit=false.', name);
        end

        pFixed.(name) = spec.value;
    end

    model.fitNames  = model.names;
    model.fixedNames = fixedOrder;
    model.nFit      = numel(model.names);
end

function v = getfield_default(st, field, default)
    if isstruct(st) && isfield(st, field) && ~isempty(st.(field))
        v = st.(field);
    else
        v = default;
    end
end

