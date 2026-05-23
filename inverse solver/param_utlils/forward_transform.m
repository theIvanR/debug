function y = forward_transform(x, tf)
switch lower(tf)
    case 'log'
        y = log(x);
    case {'identity', 'linear'}
        y = x;
    case 'log10'
        y = log10(x);
    otherwise
        error('Unsupported transform: %s', tf);
end
end