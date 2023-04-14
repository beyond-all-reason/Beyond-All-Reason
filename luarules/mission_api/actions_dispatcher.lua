local types = GG['MissionAPI'].ActionsController.Types
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
	[types.SendMessage] = {
		actionFunction = sendMessage,
		parameters = { 'message' }
	}
	-- types.Victory = ,
	-- types.Defeat = ,
}

local function invoke(actionId)
	local type = actions[actionId].type
	local actionFunction = typeMapping[type].actionFunction
	local parameters = {}

	for _, parameterName in ipairs(typeMapping[type].parameters) do
		table.insert(parameters, actions[actionId].parameters[parameterName])
	end

	actionFunction(unpack(parameters))
end

return {
	Invoke = invoke,
}