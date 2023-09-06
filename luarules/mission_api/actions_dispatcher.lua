local actionsSchema = VFS.Include('luarules/mission_api/actions_schema.lua')
local parameterSchema = actionsSchema.Parameters
local types = GG['MissionAPI'].ActionTypes
local actions = GG['MissionAPI'].Actions
local trackedUnits = GG['MissionAPI'].TrackedUnits

local function sendMessage(message)
	Spring.Echo(message)
end

local function spawnUnits(nickname, unitDefName, quantity, x, y, z)
	y = y or Spring.GetGroundHeight(x, z)

	local unitId = Spring.CreateUnit(unitDefName, x, y, z, "south", 0)

	if unitId and nickname then
		trackedUnits[nickname] = unitId
		trackedUnits[unitId] = nickname
	end
end

local function despawnUnits(nickname, unitId)
	unitId = trackedUnits[nickname] or unitId
	nickname = trackedUnits[unitId]

	trackedUnits[nickname] = nil
	trackedUnits[unitId] = nil

	Spring.DestroyUnit(unitId, false, true)
end

local typeMapping = {
	-- [types.EnableTrigger] = ,
	-- [types.DisableTrigger] = ,
	-- [types.IssueOrders] = ,
	-- [types.AllowCommands] = ,
	-- [types.RestrictCommands] = ,
	-- [types.AlterBuildlist] = ,
	-- [types.EnableBuildOption] = ,
	-- [types.DisableBuildOption] = ,
	[types.SpawnUnits] = spawnUnits,
	-- [types.SpawnConstruction] = ,
	[types.DespawnUnits] = despawnUnits,
	-- [types.SpawnWeapons] = ,
	-- [types.SpawnEffects] = ,
	-- [types.RevealLOS] = ,
	-- [types.UnrevealLOS] = ,
	-- [types.AlterMapZones] = ,
	-- [types.TransferUnits] = ,
	-- [types.ControlCamera] = ,
	-- [types.Pause] = ,
	-- [types.Unpause] = ,
	-- [types.PlayMedia] = ,
	[types.SendMessage] = sendMessage,
	-- [types.Victory] = ,
	-- [types.Defeat] = ,
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