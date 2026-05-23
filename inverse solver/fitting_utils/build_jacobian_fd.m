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
