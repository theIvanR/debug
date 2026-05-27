function enc = build_enclosure_operator(encSpec, p, env)
%BUILD_ENCLOSURE_OPERATOR  Compile env.enc spec into callable operators.
%
% Supported types:
%   - sealed / ib / none / open
%   - ported
%   - custom
%
% Custom spec fields:
%   encSpec.Zmech   : function handle, Zmech(s)
%   encSpec.sources : function handle, sources = sources(state, f)
%   encSpec.Zrad    : optional function handle, Zrad(s)

    if nargin < 1 || isempty(encSpec)
        encSpec = struct('type',"sealed");
    end
    if nargin < 2
        p = struct();
    end
    if nargin < 3
        env = struct();
    end

    if ~isfield(env, 'rho') || isempty(env.rho)
        error('env.rho is required.');
    end
    if ~isfield(env, 'c') || isempty(env.c)
        error('env.c is required.');
    end

    rho = env.rho;
    c   = env.c;

    enc = struct();
    enc.type = lower(string(getfield_default(encSpec, 'type', "sealed")));
    enc.Zrad = @(s) zeros(size(s));  % default: no extra loading

    switch enc.type

        case {"sealed","ib","infinitebaffle","none","open"}
            localEnv = env;
            localEnv.enc = encSpec;
            enc.Zmech = @(s) z_box(s, p, localEnv);
            enc.sources = @(state,f) empty_sources();

        case "ported"
            Vb            = require_field(encSpec, 'Vb');
            Sport         = require_field(encSpec, 'Sport');
            Leff          = require_field(encSpec, 'Leff');
            portPosition  = normalize_position(require_field(encSpec, 'portPosition'));
            RportLoss     = getfield_default(encSpec, 'RportLoss', 0);

            Cab = Vb / (rho * c^2);
            Map = rho * Leff / Sport;
            Rap = RportLoss;

            Zap  = @(s) s .* Map + Rap;
            Zcab = @(s) 1 ./ (s .* Cab);
            Hport = @(s) 1 ./ (1 + s .* Cab .* Zap(s));

            % Reflected acoustic loading to the cone
            enc.Zmech = @(s) (p.Sd^2) .* (Zcab(s) .* Zap(s)) ./ (Zcab(s) + Zap(s));

            enc.Zrad = @(s) zeros(size(s));  % optional future hook
            enc.Hport = Hport;

            % Source carries a frequency-aware Q(f,state) handle
            enc.sources = @(state,f) struct( ...
                'type', "point", ...
                'Q', @(ff, st) st.Qd .* Hport(1i * 2*pi*ff), ...
                'position', portPosition, ...
                'label', "port" );

        case "custom"
            if ~isfield(encSpec, 'Zmech') || ~isa(encSpec.Zmech, 'function_handle')
                error('For type="custom", env.enc.Zmech must be a function handle.');
            end
            if ~isfield(encSpec, 'sources') || ~isa(encSpec.sources, 'function_handle')
                error('For type="custom", env.enc.sources must be a function handle.');
            end

            enc.Zmech  = encSpec.Zmech;
            enc.sources = encSpec.sources;

            if isfield(encSpec, 'Zrad') && isa(encSpec.Zrad, 'function_handle')
                enc.Zrad = encSpec.Zrad;
            end

        otherwise
            error('Unknown enclosure type: %s', enc.type);
    end
end

function x = getfield_default(st, field, default)
    if isstruct(st) && isfield(st, field) && ~isempty(st.(field))
        x = st.(field);
    else
        x = default;
    end
end

function x = require_field(st, field)
    if ~isfield(st, field) || isempty(st.(field))
        error('Missing required field env.enc.%s.', field);
    end
    x = st.(field);
end

function pos = normalize_position(pos)
    pos = pos(:).';
    if numel(pos) == 2
        pos(3) = 0;
    end
    if numel(pos) ~= 3
        error('Position must be [x y] or [x y z].');
    end
end

function sources = empty_sources()
    sources = struct('type', {}, 'Q', {}, 'position', {}, 'label', {});
end