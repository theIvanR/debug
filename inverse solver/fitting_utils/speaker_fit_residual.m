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
