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
	[types.SendMessage] = sendMessage,
	-- types.Victory = ,
	-- types.Defeat = ,
}

local function invoke(actionId)
	local actionFunction = typeMapping[actions[actionId].type]
	--local parameters = unpack(actions[actionId].parameters)

	actionFunction(actions[actionId].parameters)
end

return {
	Invoke = invoke,
}