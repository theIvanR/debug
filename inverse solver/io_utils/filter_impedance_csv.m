function df_valid = filter_impedance_csv(filename, coh_threshold)
if nargin < 2 || isempty(coh_threshold), coh_threshold = 0.8; end

df = readtable(filename);
validate_columns(df, {'frequency_hz','Z_mag_ohm','Z_phase_deg','Coherence'});

mask = df.Coherence >= coh_threshold;
df_valid = sortrows(df(mask, :), 'frequency_hz');

fprintf('After coherence filter: %d\n', height(df_valid));
end

function validate_columns(df, req)
missing = req(~ismember(req, df.Properties.VariableNames));
if ~isempty(missing)
    error('Missing required column(s): %s', strjoin(missing, ', '));
end
end