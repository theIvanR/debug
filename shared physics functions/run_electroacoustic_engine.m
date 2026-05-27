function results = run_electroacoustic_engine(f, p, geom, env)
%RUN_ELECTROACOUSTIC_ENGINE  Unified electroacoustic forward solver
%
% Source interface (STRICT):
%   Q = src.Q(f, state)
%
% where:
%   f     = frequency vector (Hz)
%   state = precomputed driver state (struct)

    f = f(:).';
    w = 2*pi*f;
    s = 1i*w;

    validate_transducer(p);

    assert(isfield(env,'c')   && ~isempty(env.c),   'env.c required');
    assert(isfield(env,'rho') && ~isempty(env.rho), 'env.rho required');

    if ~isfield(env,'r_ref'), env.r_ref = 1.0; end
    if ~isfield(env,'off_axis'), env.off_axis = 0; end
    if ~isfield(env,'azimuth'), env.azimuth = 0; end

    % -------------------------------
    % Enclosure operator (if any)
    % -------------------------------
    if isfield(env,'enc') && ~isempty(env.enc)
        enc = build_enclosure_operator(env.enc, p, env);
    else
        enc.Zmech  = @(s) 0*s;
        enc.Zrad   = @(s) 0*s;
        enc.sources = @(state,f) [];
    end

    % -------------------------------
    % Driver BEM operator
    % -------------------------------
    A_driver = build_acoustic_operator(f, env, geom);

    Zdriver = z_driver(s, p);

    % radiation impedance (BEM self-consistency)
    v_unit = ones(size(geom.xc,1),1);

    Zrad_bem = zeros(1,numel(f));
    for fi = 1:numel(f)
        Zrad_bem(fi) = A_driver.impedance(fi, v_unit);
    end

    Zbox = enc.Zmech(s) + enc.Zrad(s);

    Zm_tot = Zdriver + Zrad_bem + Zbox;

    % Electrical impedance
    Ze = p.Re + s*p.Le + (p.Bl.^2) ./ Zm_tot;

    % Mechanical velocity
    Hv = p.Bl ./ (Zm_tot .* Ze);

    % Volume velocity
    state = struct();
    state.v     = Hv;
    state.Qd    = p.Sd .* Hv;
    state.ZmTot = Zm_tot;
    state.Ze    = Ze;

    % -------------------------------
    % Build unified source list
    % -------------------------------
    sources = struct('type',{},'geom',{},'position',{},'Q',{},'label',{});

    % Driver source (BEM surface)
    sources(end+1) = make_bem_source( ...
        geom, ...
        @(f, st) st.Qd, ...
        'label',"driver");

    % External sources (optional)
    if isfield(env,'sources') && ~isempty(env.sources)
        sources = [sources, normalize_sources(env.sources)];
    end

    % Enclosure-generated sources
    encSources = enc.sources(state, f);
    if ~isempty(encSources)
        sources = [sources, normalize_sources(encSources)];
    end

    % -------------------------------
    % Observation point
    % -------------------------------
    xobs = [env.r_ref*sin(env.off_axis)*cos(env.azimuth), ...
            env.r_ref*sin(env.off_axis)*sin(env.azimuth), ...
            env.r_ref*cos(env.off_axis)];

    % -------------------------------
    % Total acoustic response
    % -------------------------------
    Hp_total = zeros(1,numel(f));

    for k = 1:numel(sources)

        src = sources(k);

        % ---- FIXED INTERFACE ----
        Qk = src.Q(f, state);   % ALWAYS (f, state)

        switch lower(string(src.type))

            case "bem_surface"

                Asrc = build_acoustic_operator(f, env, src.geom);

                Gk = zeros(1,numel(f));
                area = sum(src.geom.A);

                for fi = 1:numel(f)
                    Gk(fi) = Asrc.pressure_at(fi, xobs, v_unit) / max(area,eps);
                end

                Hp_total = Hp_total + Gk .* Qk;

            case "point"

                Gk = source_pressure_transfer(f, env, xobs, src.position);
                Hp_total = Hp_total + Gk .* Qk;

            otherwise
                error("Unknown source type: %s", src.type);
        end
    end

    % -------------------------------
    % Pack results
    % -------------------------------
    results = struct();
    results.f       = f;
    results.s       = s;
    results.Zm_tot  = Zm_tot;
    results.Ze      = Ze;
    results.Hv      = Hv;
    results.Qd      = state.Qd;
    results.Hp      = Hp_total;
    results.sources = sources;
    results.geom    = geom;
    results.env     = env;
    results.p       = p;
end

function sources = normalize_sources(srcIn)
    if isempty(srcIn)
        sources = struct('type', {}, 'geom', {}, 'position', {}, 'Q', {}, 'label', {});
        return;
    end

    if iscell(srcIn)
        sources = [srcIn{:}];
    else
        sources = srcIn;
    end

    if isstruct(sources) && isscalar(sources)
        sources = sources(:).';
    end
end