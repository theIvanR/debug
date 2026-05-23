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
