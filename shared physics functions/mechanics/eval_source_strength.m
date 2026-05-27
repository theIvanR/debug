function Q = eval_source_strength(src, f, state)
%EVAL_SOURCE_STRENGTH  Return a row vector Q(f) for one source.

if isfield(src, 'Q') && isa(src.Q, 'function_handle')
    Q = src.Q(f, state);
elseif isfield(src, 'Q')
    Q = src.Q;
else
    error('Source must define Q or Q(f,state).');
end

Q = Q(:).';

if isscalar(Q)
    Q = repmat(Q, size(f(:).'));
end

if numel(Q) ~= numel(f)
    error('Source Q must be scalar or match the frequency grid length.');
end
end