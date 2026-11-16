---@meta

-- Temporary declarations for the proposed RecoilEngine DrawGhost API.
---@class GhostDrawInfo
---@field unitID integer Historical unit ID, not a live-unit lookup handle.
---@field transform number[] Column-major model-to-world matrix, 16 values.
---@field aimPos number[] Frozen XYZ aimpoint.
---@field teamColor number[] RGBA team color captured on LOS loss.
---@field color number[] Configured RGBA modulation.
---@field state "ghost"|"ghostHighlight"|"radarGhost"|"radarGhostHighlight"
---@field drawPass integer Normal=1, reflection=3, refraction=4.

---Draw only the current DrawGhost callback's stored model, using the active Lua shader.
---Available on GL4 and GLSL. Invalid outside DrawGhost.
function gl.GhostRaw() end
