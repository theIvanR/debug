function plot_fit_result(result, cfg)

f  = result.f_plot;
Zm = result.Zmeas_plot;
Zf = result.Z_fit_plot;

fs = result.fs_refined;

figure('Name','Inverse Fit Result','Position',[350 250 1100 700]);

% =========================
% Magnitude
% =========================
subplot(2,1,1)
semilogx(f, abs(Zm), 'LineWidth', 1.1); hold on;
semilogx(f, abs(Zf), '--', 'LineWidth', 1.2);

xline(fs, ':', 'Fs');

if isfield(cfg, 'bandLow') && isfield(cfg, 'bandHigh')
    xline(cfg.bandLow * fs, '--', '0.7Fs');
    xline(cfg.bandHigh * fs, '--', '3Fs');
end

ylabel('|Z| (Ohm)');
legend('Measured','Fitted');
grid on;

% =========================
% Phase
% =========================
subplot(2,1,2)
semilogx(f, unwrap(angle(Zm))*180/pi, 'LineWidth', 1.1); hold on;
semilogx(f, unwrap(angle(Zf))*180/pi, '--', 'LineWidth', 1.2);

xline(fs, ':', 'Fs');

if isfield(cfg, 'bandLow') && isfield(cfg, 'bandHigh')
    xline(cfg.bandLow * fs, '--', '0.7Fs');
    xline(cfg.bandHigh * fs, '--', '3Fs');
end

ylabel('Phase (deg)');
xlabel('Frequency (Hz)');
legend('Measured','Fitted');
grid on;
end