function v = unpack_fit_vector(x, model)
%UNPACK_FIT_VECTOR  Convert optimizer vector to linear physical values.

x = x(:);
v = zeros(numel(model.names), 1);

for k = 1:numel(model.names)
    v(k) = inverse_transform(x(k), model.transform{k});
end
end

function x = inverse_transform(y, tf)
switch lower(tf)
    case 'log'
        x = exp(y);
    case {'identity', 'linear'}
        x = y;
    case 'log10'
        x = 10.^y;
    otherwise
        error('Unsupported transform: %s', tf);
end
end