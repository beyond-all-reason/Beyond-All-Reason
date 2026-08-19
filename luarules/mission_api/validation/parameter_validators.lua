---
--- Builds the parameter validators table.
---

local valueValidators = VFS.Include('luarules/mission_api/validation/parameter_validators/value_validators.lua')
local spatialValidators = VFS.Include('luarules/mission_api/validation/parameter_validators/spatial_validators.lua')
local teamValidators = VFS.Include('luarules/mission_api/validation/parameter_validators/team_validators.lua')
local orderValidators = VFS.Include('luarules/mission_api/validation/parameter_validators/order_validators.lua')
local loadoutValidators = VFS.Include('luarules/mission_api/validation/parameter_validators/loadout_validators.lua')

local function createParameterValidators(context)
	local parameterValidators = {}

	-- Registered in dependency order: later modules build on the earlier types.
	valueValidators.Register(parameterValidators, context)
	spatialValidators.Register(parameterValidators, context)
	teamValidators.Register(parameterValidators, context)
	orderValidators.Register(parameterValidators, context)
	loadoutValidators.Register(parameterValidators, context)

	return parameterValidators
end

return {
	CreateParameterValidators = createParameterValidators,
}
