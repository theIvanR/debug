%% Forward Problem Implementation
clear; close all; clc;
addpath(genpath(pwd));

% Frequency grid
f = logspace(1, 4, 100);

% Transducer intrinsic parameters
p = struct();
p.Re  = 4.7;
p.Le  = 0.34e-3;
p.Sd  = 0.0132;
p.Bl  = 9.46;
p.Rms = 0.93;
p.Mms = 0.019;
p.Cms = 294e-6;

% Geometry (source manifold)
Nrad   = 32;
Mtheta = 32;
geom = build_circle_mesh(p.Sd, Nrad, Mtheta);

% Environment / field
env = struct();
env.c = 343;
env.rho = 1.2000;
env.r_ref = 1.0;
env.off_axis = 0;
env.azimuth = 0;


% Example 1 Enclosure: (optional boundary condition)
% env.enc = struct( ...
%     'type','sealed', ...
%     'Vb', 20e-3, ...
%     'Rloss', 0, ...
%     'Rleak', 0);

% Example 2 Encosure: (custom, frequency-safe)
portXY = [0.08, 0.00];
Sport = 3.5e-4;
NradPort   = 16;
MthetaPort = 16;

geom_port = build_circle_mesh(Sport, NradPort, MthetaPort);
geom_port.xc(:,1) = geom_port.xc(:,1) + portXY(1);
geom_port.xc(:,2) = geom_port.xc(:,2) + portXY(2);

% Helmholtz transfer for the port volume velocity
Vb    = 20e-3;
Leff  = 0.06;
Rport = 0.2;

Cab = Vb / (env.rho * env.c^2);
Map = env.rho * Leff / Sport;

Hport = @(s) 1 ./ (1 + s .* Cab .* (s .* Map + Rport));

% Enclosure returns the port as another BEM source
env.enc = struct( ...
    'type', "custom", ...
    'Zmech', @(s) (p.Sd^2) .* ((1 ./ (s .* Cab)) .* (s .* Map + Rport)) ./ ...
                          ((1 ./ (s .* Cab)) + (s .* Map + Rport)), ...
    'sources', @(state, f) make_bem_source( ...
        geom_port, ...
        @(ff, st) st.Qd .* Hport(1i * 2*pi*ff), ...
        'label', "port") ...
);

% drive (normalized)
V_in = sqrt(p.Re);

% simulate
results = run_electroacoustic_engine(f, p, geom, env);

% post
metrics = speaker_power_metrics(results, V_in);
make_plots(results, metrics, V_in, env);