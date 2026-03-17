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
	[types.DespawnUnits] = actionFunctions.DespawnUnits,
	[types.TransferUnits] = actionFunctions.TransferUnits,
	[types.NameUnits] = actionFunctions.NameUnits,
	[types.UnnameUnits] = actionFunctions.UnnameUnits,
	[types.SpawnExplosion] = actionFunctions.SpawnExplosion,
	-- [types.SpawnWeapons] = ,
	-- [types.SpawnEffects] = ,
	-- [types.RevealLOS] = ,
	-- [types.UnrevealLOS] = ,
	-- [types.AlterMapZones] = ,
	-- [types.ControlCamera] = ,
	-- [types.Pause] = ,
	-- [types.Unpause] = ,
	[types.PlaySound] = actionFunctions.PlaySound,
	[types.SendMessage] = actionFunctions.SendMessage,
	[types.AddMarker] = actionFunctions.AddMarker,
	[types.EraseMarker] = actionFunctions.EraseMarker,
	[types.DrawLines] = actionFunctions.DrawLines,
	[types.ClearAllMarkers] = actionFunctions.ClearAllMarkers,
	[types.Victory] = actionFunctions.Victory,
	[types.Defeat] = actionFunctions.Defeat,
}

local function unpackActionParameters(action, mappedValues, i)
	local schema = parameterSchema[action.type]

	i = i or 1

	if i <= #schema then
		local parameterName = schema[i].name
		local parameterValue = action.parameters[parameterName] or mappedValues[parameterName]
		return parameterValue, unpackActionParameters(action, mappedValues, i + 1)
	end
end

local function invoke(actionId, providedValues)
	local action = actions[actionId]
	local actionFunction = typeMapping[action.type]

	local mappedValues = {}
	if action.provided then
		for k, value in pairs(providedValues or {}) do
			if action.provided[k] then
				mappedValues[action.provided[k]] = value
			end
		end
	end

	actionFunction(unpackActionParameters(action, mappedValues))
end

return {
	Invoke = invoke,
}
