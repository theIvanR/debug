function out = apply_defaults(in, defaults)
out = in;
f = fieldnames(defaults);
for i = 1:numel(f)
    if ~isfield(out, f{i}) || isempty(out.(f{i}))
        out.(f{i}) = defaults.(f{i});
    end
end
end
