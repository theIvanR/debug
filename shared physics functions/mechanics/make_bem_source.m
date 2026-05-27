function src = make_bem_source(geom, Qfun, varargin)
%MAKE_BEM_SOURCE  Build a BEM surface source object.

p = inputParser;
addParameter(p, 'label', "surface");
addParameter(p, 'position', [0 0 0]);
parse(p, varargin{:});

pos = p.Results.position(:).';
if numel(pos) == 2
    pos(3) = 0;
end

src = struct();
src.type     = "bem_surface";
src.geom     = geom;
src.Q        = Qfun;              % Q(f,state) -> volume velocity
src.position = pos;
src.label    = string(p.Results.label);
end