function r = speaker_residual(x, f, Zmeas, coh, geom, env, cfg, prior, paramModel, pFixed)
r = speaker_fit_residual(x, f, Zmeas, coh, geom, env, cfg, paramModel, pFixed);

if nargin >= 8 && ~isempty(prior)
    delta = x(:) - prior.center(:);
    z = prior.V' * delta;
    r_prior = prior.weight * (z ./ max(prior.sigma, eps));
    r = [r; r_prior(:)];
end
end
