local actionsSchema = VFS.Include('luarules/mission_api/actions_schema.lua')
local parameterSchema = actionsSchema.Parameters
local types = GG['MissionAPI'].ActionTypes
local actions = GG['MissionAPI'].Actions

local function sendMessage(message)
	Spring.Echo(message)
end

local typeMapping = {
	-- types.EnableTrigger = ,
	-- types.DisableTrigger = ,
	-- types.IssueOrders = ,
	-- types.AllowCommands = ,
	-- types.RestrictCommands = ,
	-- types.AlterBuildlist = ,
	-- types.EnableBuildOption = ,
	-- types.DisableBuildOption = ,
	-- types.SpawnUnits = ,
	-- types.SpawnConstruction = ,
	-- types.DespawnUnits = ,
	-- types.SpawnWeapons = ,
	-- types.SpawnEffects = ,
	-- types.RevealLOS = ,
	-- types.UnrevealLOS = ,
	-- types.AlterMapZones = ,
	-- types.TransferUnits = ,
	-- types.ControlCamera = ,
	-- types.Pause = ,
	-- types.Unpause = ,
	-- types.PlayMedia = ,
	[types.SendMessage] = sendMessage,
	-- types.Victory = ,
	-- types.Defeat = ,
}

local function invoke(actionId)
	local type = actions[actionId].type
	local actionFunction = typeMapping[type]
	local parameters = {}

	for _, parameter in ipairs(parameterSchema[type]) do
		table.insert(parameters, actions[actionId].parameters[parameter.name])
	end

	actionFunction(unpack(parameters))
end

return {
	Invoke = invoke,
}