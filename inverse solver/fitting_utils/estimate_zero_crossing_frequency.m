
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
