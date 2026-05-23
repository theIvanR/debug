function p = unpack_parameters(x, model, pFixed)
%UNPACK_PARAMETERS  Convert optimizer vector into physical parameter struct.

p = pFixed;
x = x(:);

for k = 1:numel(model.names)
    name = model.names{k};
    tf   = model.transform{k};
    p.(name) = inverse_transform(x(k), tf);
end

p.fs  = 1 / (2*pi*sqrt(max(p.Mms * p.Cms, eps)));
ws    = 2*pi*p.fs;

p.Qms = ws * p.Mms / max(p.Rms, eps);
p.Qes = ws * p.Mms * p.Re / max(p.Bl^2, eps);
p.Qts = (p.Qms * p.Qes) / max(p.Qms + p.Qes, eps);
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