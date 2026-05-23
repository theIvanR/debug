function validate_columns(df, req)
missing = req(~ismember(req, df.Properties.VariableNames));
if ~isempty(missing)
    error('Missing required column(s): %s', strjoin(missing, ', '));
end
end
