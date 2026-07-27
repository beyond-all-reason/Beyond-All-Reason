--- Tech tier resolution. The tax rate that reads a team's tier lives with
--- transfer, which owns what a transfer costs.
local TechTier = {}

-- Resolve a tech-level-varying modOption: _at_t3, then _at_t2, then base key.
---@param opts table modoptions
---@param baseKey string
---@param techLevel number
function TechTier.resolveByTechLevel(opts, baseKey, techLevel)
	if techLevel >= 3 then
		local v = opts[baseKey .. "_at_t3"]
		if v ~= nil and v ~= "" then
			return v
		end
	end
	if techLevel >= 2 then
		local v = opts[baseKey .. "_at_t2"]
		if v ~= nil and v ~= "" then
			return v
		end
	end
	return opts[baseKey]
end

-- Effective resource-sharing tax rate [0,1] for a team's tech level; _at_tN sentinel (<0/empty) falls back to base.

return TechTier
