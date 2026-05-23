function logZ = complex_log_impedance(Z)
Z = Z(:);
mag = max(abs(Z), 1e-12);
ph  = unwrap(angle(Z));
logZ = log(mag) + 1j * ph;
end
