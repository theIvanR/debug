function result = fit_speaker_params_smart(df_clean, driver, geom, env, cfg)
%FIT_SPEAKER_PARAMS_SMART  High-performance MAP inverse fitter.
%
% driver:
%   Declarative parameter specification, e.g.
%     driver.Re = struct('fit',true,'initial',6,'lower',5.2,'upper',7.5,'transform','log');
%     driver.Sd = struct('fit',false,'value',140e-4);
%
% Behavior preserved:
%   - pass 1: data + fs anchor
%   - pass 2: MAP with SVD prior + Fisher trust bounds
%   - complex-log residual geometry
%   - same CI propagation machinery

    if nargin < 5 || isempty(cfg)
        cfg = struct();
    end

    cfg = apply_defaults(cfg, struct( ...
        'bandLow', 0.7, ...
        'bandHigh', 3.0, ...
        'stride', 1, ...
        'cohThreshold', [], ...
        'magSigmaDb', 0.75, ...
        'phaseSigmaDeg', 2.0, ...
        'minSigmaLogMag', 1e-3, ...
        'minSigmaPhi', deg2rad(0.2), ...
        'minCoherence', 0.05, ...
        'cohExponent', 0.5, ...
        'fsAnchorLambda', 100, ...
        'maxIter', 100, ...
        'maxEval', 1200, ...
        'fdStep', 1e-7, ...
        'verbose', true, ...
        'regLambda', 1.0, ...
        'priorCenterMode', 'pass1', ...
        'priorSigmaMin', 0.05, ...
        'priorSigmaMax', 10.0, ...
        'priorSharpness', 1.5, ...
        'priorUsePass1SVD', true, ...
        'includePriorInFisher', true, ...
        'trustMinLogWidth', log(1.10), ...
        'trustMaxLogWidth', log(2.0), ...
        'fisherTrustSigma', 2.0, ...
        'useFreqWindow', false, ...
        'freqFocusStrength', 0.0, ...
        'freqFocusWidth', 0.55));

    validate_columns(df_clean, {'frequency_hz','Z_mag_ohm','Z_phase_deg','Coherence'});

    % ---------------------------------------------------------------------
    % Data unpacking
    % ---------------------------------------------------------------------
    f_all   = df_clean.frequency_hz(:).';
    Zmag    = df_clean.Z_mag_ohm(:);
    Zphase  = deg2rad(df_clean.Z_phase_deg(:));
    Zmeas   = Zmag .* exp(1j * Zphase);
    coh_all = df_clean.Coherence(:);

    if isfield(cfg, 'cohThreshold') && ~isempty(cfg.cohThreshold)
        mask = coh_all >= cfg.cohThreshold;
        f_all   = f_all(mask);
        Zmeas   = Zmeas(mask);
        coh_all = coh_all(mask);
    end

    % ---------------------------------------------------------------------
    % Initial feature extraction
    % ---------------------------------------------------------------------
    features = estimate_initial_features(f_all, Zmeas);
    fs0 = features.fs;

    if ~isfinite(fs0) || fs0 <= 0
        error('Could not estimate an initial resonance frequency.');
    end

    cfg.fs0 = fs0;

    % ---------------------------------------------------------------------
    % Compile declarative driver into numerical model
    % ---------------------------------------------------------------------
    [paramModel, pFixed] = compile_parameter_model(driver, features);

    % ---------------------------------------------------------------------
    % Fit band selection around fs0
    % ---------------------------------------------------------------------
    fLow  = cfg.bandLow  * fs0;
    fHigh = cfg.bandHigh * fs0;
    bandMask = f_all >= fLow & f_all <= fHigh;

    if ~any(bandMask)
        warning('Automatic fit band is empty. Falling back to full cleaned trace.');
        bandMask = true(size(f_all));
        fLow = min(f_all);
        fHigh = max(f_all);
    end

    idxBand = find(bandMask);
    if cfg.stride > 1
        idxBand = idxBand(1:cfg.stride:end);
    end

    f_fit      = f_all(idxBand);
    Z_fit_meas = Zmeas(idxBand);
    coh_fit    = coh_all(idxBand);

    if numel(f_fit) < 8
        warning('Very few points in the selected fit band; fit quality may be limited.');
    end

    if cfg.verbose
        fprintf('[SPEAKER FIT] Band: %.6g Hz to %.6g Hz | points = %d\n', fLow, fHigh, numel(f_fit));
        fprintf('[SPEAKER FIT] Initial fs0 = %.6g Hz\n', fs0);
    end

    % ---------------------------------------------------------------------
    % Initial parameter vector and broad bounds come from compiled model
    % ---------------------------------------------------------------------
    x0  = paramModel.x0;
    lb1 = paramModel.lb;
    ub1 = paramModel.ub;

    opts = optimoptions('lsqnonlin', ...
        'Display', ternary(cfg.verbose, 'iter', 'off'), ...
        'MaxFunctionEvaluations', cfg.maxEval, ...
        'MaxIterations', cfg.maxIter, ...
        'FunctionTolerance', 1e-12, ...
        'StepTolerance', 1e-12, ...
        'OptimalityTolerance', 1e-12);

    % =====================================================================
    % PASS 1: data + fs anchor, no prior
    % =====================================================================
    resid1 = @(x) speaker_fit_residual(x, f_fit, Z_fit_meas, coh_fit, geom, env, cfg, paramModel, pFixed);
    [x1, resnorm1, residual1, exitflag1, output1] = lsqnonlin(resid1, x0, lb1, ub1, opts);

    p1 = unpack_parameters(x1, paramModel, pFixed);
    [J1_data, ~, meta1] = build_jacobian_fd(x1, f_fit, Z_fit_meas, coh_fit, geom, env, cfg, [], paramModel, pFixed);
    [~, S1, V1] = svd(J1_data, 'econ');
    singular1 = diag(S1);

    % ---------------------------------------------------------------------
    % Build Bayesian prior aligned with pass-1 SVD basis
    % ---------------------------------------------------------------------
    if strcmpi(cfg.priorCenterMode, 'pass1')
        x_prior = x1;
    else
        x_prior = x0;
    end

    if cfg.priorUsePass1SVD
        Vprior = V1;
        s = singular1(:);
        smax = max(s);
        if ~isfinite(smax) || smax <= 0
            sNorm = ones(size(s));
        else
            sNorm = s ./ smax;
        end

        sigmaPrior = cfg.priorSigmaMin + ...
            (cfg.priorSigmaMax - cfg.priorSigmaMin) .* (sNorm .^ cfg.priorSharpness);
        sigmaPrior = max(min(sigmaPrior, cfg.priorSigmaMax), cfg.priorSigmaMin);
    else
        Vprior = eye(numel(x0));
        sigmaPrior = cfg.priorSigmaMax * ones(numel(x0),1);
    end

    prior = struct();
    prior.center = x_prior(:);
    prior.V = Vprior;
    prior.sigma = sigmaPrior(:);
    prior.weight = sqrt(max(cfg.regLambda, eps));
    prior.description = 'Anisotropic Gaussian prior aligned with pass-1 SVD directions';

    % ---------------------------------------------------------------------
    % Fisher-informed adaptive trust bounds for PASS 2
    % ---------------------------------------------------------------------
    [lb2, ub2, trustInfo] = fisher_trust_bounds(x_prior, J1_data, cfg);

    % =====================================================================
    % PASS 2: MAP fit with fs anchor + SVD prior
    % =====================================================================
    resid2 = @(x) speaker_residual(x, f_fit, Z_fit_meas, coh_fit, geom, env, cfg, prior, paramModel, pFixed);
    [xhat, resnorm, residual, exitflag, output] = lsqnonlin(resid2, x_prior, lb2, ub2, opts);

    phat = unpack_parameters(xhat, paramModel, pFixed);
    sim  = run_electroacoustic_engine(f_fit, phat, geom, env);

    % ---------------------------------------------------------------------
    % Jacobians at the optimum
    % ---------------------------------------------------------------------
    [J_data, J_total, meta] = build_jacobian_fd(xhat, f_fit, Z_fit_meas, coh_fit, geom, env, cfg, prior, paramModel, pFixed);

    F_data = J_data.' * J_data;
    F_map  = J_total.' * J_total;

    if cfg.includePriorInFisher
        F_use = F_map;
    else
        F_use = F_data;
    end

    [U, S, V] = svd(J_data, 'econ');
    singular = diag(S);
    condJ = singular(1) / max(singular(end), eps);
    condF = cond(F_use);

    if condF < 1e12
        Cov_log = inv(F_use);
    else
        Cov_log = pinv(F_use);
    end

    se_log = sqrt(max(diag(Cov_log), 0));
    corr = fisher_correlation(F_use);

    paramNames = strcat("log(", paramModel.names, ")");
    logVals = xhat(:);
    ci95_log = [logVals - 1.96 * se_log, logVals + 1.96 * se_log];

    linearNames = paramModel.names(:).';
    pVec = unpack_fit_vector(xhat, paramModel);
    ci95_lin = [exp(ci95_log(:,1)), exp(ci95_log(:,2))];

    derived = compute_derived_quantities(phat, env);
    [derivedCI, derivedCovLog] = propagate_derived_ci(xhat, Cov_log, phat, env, paramModel, pFixed);

    % ---------------------------------------------------------------------
    % Plotting data
    % ---------------------------------------------------------------------
    idxPlot = find(bandMask);
    if cfg.stride > 1
        idxPlot = idxPlot(1:cfg.stride:end);
    end
    f_plot     = f_all(idxPlot);
    Zmeas_plot = Zmeas(idxPlot);
    Zfit_plot  = run_electroacoustic_engine(f_plot, phat, geom, env).Ze;

    % ---------------------------------------------------------------------
    % Pack result
    % ---------------------------------------------------------------------
    result = struct();

    result.driver = driver;
    result.paramModel = paramModel;
    result.pFixed = pFixed;

    result.p = phat;
    result.pVec = pVec;
    result.f = f_all;
    result.Zmeas = Zmeas;
    result.coherence = coh_all;
    result.fitMask = bandMask;
    result.f_fit = f_fit;
    result.f_plot = f_plot;
    result.Zmeas_plot = Zmeas_plot;
    result.Z_fit_plot = Zfit_plot;
    result.sim = sim;

    result.noise = struct();
    result.noise.magSigmaDb = cfg.magSigmaDb;
    result.noise.phaseSigmaDeg = cfg.phaseSigmaDeg;
    result.noise.minSigmaLogMag = cfg.minSigmaLogMag;
    result.noise.minSigmaPhi = cfg.minSigmaPhi;
    result.noise.minCoherence = cfg.minCoherence;
    result.noise.cohExponent = cfg.cohExponent;

    result.fs0 = fs0;
    result.fs_refined = phat.fs;

    result.pass1 = struct( ...
        'x', x1, 'p', p1, 'resnorm', resnorm1, 'residual', residual1, ...
        'exitflag', exitflag1, 'output', output1, 'J_data', J1_data, ...
        'singular', singular1, 'sloppyVec', V1(:,end), ...
        'meta', meta1);

    result.fit = struct( ...
        'x', xhat, 'resnorm', resnorm, 'residual', residual, ...
        'exitflag', exitflag, 'output', output, 'meta', meta);

    result.prior = prior;

    result.J_data = J_data;
    result.J_total = J_total;
    result.F_data = F_data;
    result.F_map = F_map;
    result.F_used = F_use;
    result.U = U;
    result.S = S;
    result.V = V;
    result.singular = singular;
    result.condJ = condJ;
    result.condF = condF;
    result.corr = corr;
    result.paramNames = paramNames;
    result.linearNames = linearNames;

    result.Cov_log = Cov_log;
    result.se_log = se_log;
    result.ci95_log = ci95_log;
    result.ci95_linear = ci95_lin;

    result.derived = derived;
    result.derivedCI = derivedCI;
    result.derivedCovLog = derivedCovLog;

    result.trust = trustInfo;
    result.trust.lb2 = lb2;
    result.trust.ub2 = ub2;

    result.notes = struct();
    result.notes.parameterization = 'Driver-defined parameters with fitted Re/Le/Bl/Rms/Mms/Cms';
    result.notes.residualGeometry = 'Complex-log impedance residual';
    result.notes.prior = prior.description;
    result.notes.priorCenterMode = cfg.priorCenterMode;
    result.notes.priorSigmaMin = cfg.priorSigmaMin;
    result.notes.priorSigmaMax = cfg.priorSigmaMax;
    result.notes.priorSharpness = cfg.priorSharpness;
    result.notes.includePriorInFisher = cfg.includePriorInFisher;
    result.notes.fsAnchorLambda = cfg.fsAnchorLambda;
    result.notes.fs0 = fs0;
    result.notes.trustMinLogWidth = cfg.trustMinLogWidth;
    result.notes.trustMaxLogWidth = cfg.trustMaxLogWidth;
    result.notes.fisherTrustSigma = cfg.fisherTrustSigma;

    if cfg.verbose
        fprintf('[SPEAKER FIT] Pass 1 fs0 = %.6g Hz | refined fs = %.6g Hz\n', fs0, phat.fs);
        fprintf('[SPEAKER FIT] cond(J_data) = %.3e | cond(F_used) = %.3e\n', condJ, condF);
        fprintf('[SPEAKER FIT] Fit complete. Exitflag = %d\n', exitflag);
    end
end

% ========================================================================
% Residuals and Jacobian
% ========================================================================
function r = speaker_residual(x, f, Zmeas, coh, geom, env, cfg, prior, paramModel, pFixed)
    r = speaker_fit_residual(x, f, Zmeas, coh, geom, env, cfg, paramModel, pFixed);

    if nargin >= 8 && ~isempty(prior)
        delta = x(:) - prior.center(:);
        z = prior.V' * delta;
        r_prior = prior.weight * (z ./ max(prior.sigma, eps));
        r = [r; r_prior(:)];
    end
end

function r = speaker_fit_residual(x, f, Zmeas, coh, geom, env, cfg, paramModel, pFixed)
    p = unpack_parameters(x, paramModel, pFixed);
    sim = run_electroacoustic_engine(f, p, geom, env);

    if ~isfield(sim, 'Ze')
        error('run_electroacoustic_engine must return sim.Ze');
    end

    Zfit = sim.Ze(:);
    Zref = Zmeas(:);

    logZfit = complex_log_impedance(Zfit);
    logZref = complex_log_impedance(Zref);
    dlogZ   = logZfit - logZref;

    r_mag = real(dlogZ);
    r_phi = imag(dlogZ);

    sigmaMag = db_to_neper(getfield_with_default(cfg, 'magSigmaDb', 0.75));
    sigmaPhi = deg2rad(getfield_with_default(cfg, 'phaseSigmaDeg', 2.0));

    sigmaMag = max(sigmaMag, getfield_with_default(cfg, 'minSigmaLogMag', 1e-3));
    sigmaPhi = max(sigmaPhi, getfield_with_default(cfg, 'minSigmaPhi', deg2rad(0.2)));

    cohExp = getfield_with_default(cfg, 'cohExponent', 0.5);
    minCoh = getfield_with_default(cfg, 'minCoherence', 0.05);
    cohScale = max(coh(:), minCoh).^(-cohExp);

    sigmaMag = sigmaMag .* cohScale;
    sigmaPhi = sigmaPhi .* cohScale;

    r_data = [r_mag ./ sigmaMag; r_phi ./ sigmaPhi];

    if isfield(cfg, 'useFreqWindow') && cfg.useFreqWindow
        w_freq = resonance_window(f(:), p.fs, cfg.freqFocusStrength, cfg.freqFocusWidth);
        r_data(1:numel(r_mag)) = r_data(1:numel(r_mag)) .* w_freq;
        r_data(numel(r_mag)+1:end) = r_data(numel(r_mag)+1:end) .* w_freq;
    end

    r = r_data;

    if isfield(cfg, 'fsAnchorLambda') && cfg.fsAnchorLambda > 0 && ...
            isfield(cfg, 'fs0') && isfinite(cfg.fs0) && cfg.fs0 > 0
        r_fs = sqrt(cfg.fsAnchorLambda) * (log(p.fs) - log(cfg.fs0));
        r = [r; r_fs];
    end
end

function [J_data, J_total, meta] = build_jacobian_fd(x, f, Zmeas, coh, geom, env, cfg, prior, paramModel, pFixed)
    x = x(:);
    n = numel(x);

    r0 = speaker_fit_residual(x, f, Zmeas, coh, geom, env, cfg, paramModel, pFixed);
    m = numel(r0);
    J_data = zeros(m, n);

    for k = 1:n
        h = cfg.fdStep * max(1, abs(x(k)));
        dx = zeros(n, 1);
        dx(k) = h;

        rp = speaker_fit_residual(x + dx, f, Zmeas, coh, geom, env, cfg, paramModel, pFixed);
        rm = speaker_fit_residual(x - dx, f, Zmeas, coh, geom, env, cfg, paramModel, pFixed);

        J_data(:, k) = (rp - rm) / (2*h);
    end

    if nargin >= 8 && ~isempty(prior)
        J_prior = prior.weight * (diag(1 ./ max(prior.sigma, eps)) * prior.V');
        J_total = [J_data; J_prior];
    else
        J_total = J_data;
    end

    p = unpack_parameters(x, paramModel, pFixed);
    meta = struct('fs', p.fs, 'r0', r0);
end

% ========================================================================
% Initial feature estimation
% ========================================================================
function features = estimate_initial_features(f, Zmeas)
    f = f(:);
    Zmeas = Zmeas(:);

    ph = unwrap(angle(Zmeas));
    ph_deg = ph * 180/pi;
    fs = estimate_zero_crossing_frequency(f, ph_deg);

    Zmag = abs(Zmeas);
    idx_hf_start = max(round(0.8 * numel(f)), 1);
    idx_hf = idx_hf_start:numel(f);

    omega = 2*pi*f(idx_hf);
    Zhf = Zmeas(idx_hf);

    Re0 = median(real(Zhf), 'omitnan');
    Le0 = median(imag(Zhf) ./ max(omega, eps), 'omitnan');

    if ~isfinite(Re0) || Re0 <= 0
        Re0 = max(min(Zmag), 1e-3);
    end
    if ~isfinite(Le0) || Le0 <= 0
        Le0 = 1e-4;
    end

    features = struct('fs', fs, 'Re0', Re0, 'Le0', Le0);
end

function fs = estimate_zero_crossing_frequency(f, ph_deg)
    f = f(:);
    ph_deg = ph_deg(:);

    s = sign(ph_deg);
    s(s == 0) = NaN;

    idx = find(~isnan(s(1:end-1)) & ~isnan(s(2:end)) & (s(1:end-1) ~= s(2:end)), 1, 'first');

    if isempty(idx)
        [~, idx0] = min(abs(ph_deg));
        fs = f(idx0);
        return;
    end

    fs = interp1(ph_deg(idx:idx+1), f(idx:idx+1), 0, 'linear', 'extrap');
end

% ========================================================================
% Derived quantities and CI propagation
% ========================================================================
function q = compute_derived_quantities(p, env)
    ws = 2*pi*p.fs;
    Cms = p.Cms;
    Qms = ws * p.Mms / p.Rms;
    Qes = ws * p.Mms * p.Re / (p.Bl^2);
    Qts = (Qms * Qes) / max(Qms + Qes, eps);
    Vas = env.rho * env.c^2 * (p.Sd^2) * Cms;

    q = struct();
    q.fs = p.fs;
    q.Cms = Cms;
    q.Qms = Qms;
    q.Qes = Qes;
    q.Qts = Qts;
    q.Vas = Vas;
    q.Rms = p.Rms;
end

function [derivedCI, derivedCovLog] = propagate_derived_ci(xhat, Cov_log, p, env, paramModel, pFixed)
    q0 = compute_derived_quantities(p, env);
    qNames = {'fs','Cms','Qms','Qes','Qts','Vas','Rms'};

    epsStep = 1e-6;
    J = zeros(numel(qNames), numel(xhat));

    for k = 1:numel(xhat)
        dx = zeros(size(xhat));
        dx(k) = epsStep;

        p_plus = unpack_parameters(xhat + dx, paramModel, pFixed);
        p_minus = unpack_parameters(xhat - dx, paramModel, pFixed);

        q_plus = compute_derived_quantities(p_plus, env);
        q_minus = compute_derived_quantities(p_minus, env);

        for i = 1:numel(qNames)
            name = qNames{i};
            vp = q_plus.(name);
            vm = q_minus.(name);

            if vp > 0 && vm > 0
                J(i,k) = (log(vp) - log(vm)) / (2*epsStep);
            else
                J(i,k) = (vp - vm) / (2*epsStep);
            end
        end
    end

    derivedCovLog = J * Cov_log * J.';
    se = sqrt(max(diag(derivedCovLog), 0));

    derivedCI = struct();
    for i = 1:numel(qNames)
        name = qNames{i};
        mu = q0.(name);
        if mu > 0
            lo = exp(log(mu) - 1.96 * se(i));
            hi = exp(log(mu) + 1.96 * se(i));
        else
            lo = mu - 1.96 * se(i);
            hi = mu + 1.96 * se(i);
        end
        derivedCI.(name) = [lo, hi];
    end
end

% ========================================================================
% Fisher-informed adaptive trust bounds
% ========================================================================
function [lb, ub, info] = fisher_trust_bounds(x_center, J, cfg)
    x_center = x_center(:);

    F = J.' * J;
    F = 0.5 * (F + F.');

    if any(~isfinite(F(:))) || rcond(F) < 1e-14
        Cov = pinv(F + 1e-12 * eye(size(F)));
    else
        Cov = pinv(F);
    end

    sigma = sqrt(max(diag(Cov), eps));
    rawHalfWidth = cfg.fisherTrustSigma * sigma;
    halfWidth = min(max(rawHalfWidth, cfg.trustMinLogWidth), cfg.trustMaxLogWidth);

    lb = x_center - halfWidth(:);
    ub = x_center + halfWidth(:);

    info = struct();
    info.F = F;
    info.Cov = Cov;
    info.sigma = sigma;
    info.rawHalfWidth = rawHalfWidth;
    info.halfWidth = halfWidth;
end

% ========================================================================
% Small helpers
% ========================================================================
function logZ = complex_log_impedance(Z)
    Z = Z(:);
    mag = max(abs(Z), 1e-12);
    ph  = unwrap(angle(Z));
    logZ = log(mag) + 1j * ph;
end

function s = getfield_with_default(st, field, default)
    if isstruct(st) && isfield(st, field) && ~isempty(st.(field))
        s = st.(field);
    else
        s = default;
    end
end

function out = apply_defaults(in, defaults)
    out = in;
    f = fieldnames(defaults);
    for i = 1:numel(f)
        if ~isfield(out, f{i}) || isempty(out.(f{i}))
            out.(f{i}) = defaults.(f{i});
        end
    end
end

function validate_columns(df, req)
    missing = req(~ismember(req, df.Properties.VariableNames));
    if ~isempty(missing)
        error('Missing required column(s): %s', strjoin(missing, ', '));
    end
end

function y = ternary(cond, a, b)
    if cond
        y = a;
    else
        y = b;
    end
end

function sigma = db_to_neper(db)
    sigma = db ./ 8.685889638;
end

function w = resonance_window(f, fs, strength, widthFactor)
    if isempty(fs) || ~isfinite(fs) || fs <= 0
        w = ones(size(f));
        return;
    end

    strength = min(max(strength, 0), 1);
    widthFactor = max(widthFactor, 0.05);

    lf = log(max(f(:), eps) ./ fs);
    g  = exp(-(lf ./ widthFactor).^2);

    w = (1 - strength) + strength * g;
    w = max(w, 0.1);
end

function corr = fisher_correlation(F)
    d = sqrt(max(diag(F), eps));
    corr = F ./ (d * d.');
end