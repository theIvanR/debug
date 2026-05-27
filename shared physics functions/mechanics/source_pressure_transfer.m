function G = source_pressure_transfer(f, env, xobs, pos)
%SOURCE_PRESSURE_TRANSFER  Geometry-only monopole transfer factor.

f = f(:).';
pos = pos(:).';

if numel(pos) == 2
    pos(3) = 0;
end

R = norm(xobs(:).' - pos);

if isfield(env, 'green_scale') && ~isempty(env.green_scale)
    g = env.green_scale;
else
    g = 2;
end

k = 2*pi*f / env.c;
G = 1i * 2*pi*f .* env.rho .* g .* exp(-1i * k * R) ./ (4*pi*max(R, eps));
end