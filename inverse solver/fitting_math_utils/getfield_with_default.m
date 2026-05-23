function s = getfield_with_default(st, field, default)
if isstruct(st) && isfield(st, field) && ~isempty(st.(field))
    s = st.(field);
else
    s = default;
end
end
