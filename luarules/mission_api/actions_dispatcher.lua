local actionsSchema = VFS.Include('luarules/mission_api/actions_schema.lua')
local actionFunctions = VFS.Include('luarules/mission_api/actions.lua')
local parameterSchema = actionsSchema.Parameters
local types = GG['MissionAPI'].ActionTypes
local actions = GG['MissionAPI'].Actions

local typeMapping = {
-- TODO: Since the names are all the same, could we ditch this mapping and do it dynamically instead?
	[types.EnableTrigger] = actionFunctions.EnableTrigger,
	[types.DisableTrigger] = actionFunctions.DisableTrigger,
	[types.IssueOrders] = actionFunctions.IssueOrders,
	-- [types.AllowCommands] = ,
	-- [types.RestrictCommands] = ,
	-- [types.AlterBuildlist] = ,
	-- [types.EnableBuildOption] = ,
	-- [types.DisableBuildOption] = ,
	[types.SpawnUnits] = actionFunctions.SpawnUnits,
	-- [types.SpawnConstruction] = ,
	[types.DespawnUnits] = actionFunctions.DespawnUnits,
	-- [types.SpawnWeapons] = ,
	-- [types.SpawnEffects] = ,
	[types.TransferUnits] = actionFunctions.TransferUnits,
	[types.SpawnExplosion] = actionFunctions.SpawnExplosion,
	-- [types.RevealLOS] = ,
	-- [types.UnrevealLOS] = ,
	-- [types.AlterMapZones] = ,
	-- [types.TransferUnits] = ,
	-- [types.ControlCamera] = ,
	-- [types.Pause] = ,
	-- [types.Unpause] = ,
	-- [types.PlayMedia] = ,
	[types.SendMessage] = actionFunctions.SendMessage,
	[types.Victory] = actionFunctions.Victory,
	[types.Defeat] = actionFunctions.Defeat,
}

-- unpack() does not handle optional parameters, as it cannot pass a value as nil
local function unpackActionParameters(actionId, i)
	local type = actions[actionId].type
	local schema = parameterSchema[type]

	i = i or 1

	if i <= #schema then
		local parameterValue = actions[actionId].parameters[schema[i].name]
		return parameterValue, unpackActionParameters(actionId, i + 1)
	end
end

local function invoke(actionId)
	local type = actions[actionId].type
	local actionFunction = typeMapping[type]

	actionFunction(unpackActionParameters(actionId))
end

return {
	Invoke = invoke,
}
