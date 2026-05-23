function w = resonance_window(f, fs, strength, widthFactor)
if isempty(fs) || ~isfinite(fs) || fs <= 0
    w = ones(size(f));
    return;
end

strength = min(max(strength, 0), 1);
widthFactor = max(widthFactor, 0.05);

lf = log(max(f(:), eps) ./ fs);
g  = exp(-(lf ./ widthFactor).^2);

w = (1 - strength) + strength * g;
w = max(w, 0.1);
end
