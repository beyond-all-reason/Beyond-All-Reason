---@class StartRegionFields
local Fields = {}

---@param overrides table<string, any>|nil
---@return RegionField
function Fields.Team(overrides)
	---@type RegionField
	local field = { key = "team", label = "Team", kind = "integer", picks = "start" }
	for k, v in pairs(overrides or {}) do
		field[k] = v
	end
	return field
end

return Fields
