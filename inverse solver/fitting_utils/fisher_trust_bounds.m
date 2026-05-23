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
