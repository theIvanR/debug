function src = make_point_source(position, Qfun, varargin)
%MAKE_POINT_SOURCE  Build a point source object.

p = inputParser;
addParameter(p, 'label', "point");
parse(p, varargin{:});

pos = position(:).';
if numel(pos) == 2
    pos(3) = 0;
end

src = struct();
src.type     = "point";
src.position = pos;
src.Q        = Qfun;              % Q(f,state) -> volume velocity
src.label    = string(p.Results.label);
end