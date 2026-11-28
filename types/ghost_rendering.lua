---@meta

-- Temporary declarations for the proposed RecoilEngine DrawGhost API.
---@class GhostDrawInfo
---@field ghostID integer Observer-specific sighting ID.
---@field teamColor rgba RGBA team color captured on LOS loss.

---Draw only the current DrawGhost callback's stored model, using the active Lua shader.
---Available on GL4 and GLSL. Invalid outside DrawGhost.
function gl.GhostRaw() end
