---@class StartRegionFields the fields a start lends to other region types, so every type that names a start names it the same way
local Fields = {}

---@param overrides table<string, any>|nil what the borrowing type adds: required, unique
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
