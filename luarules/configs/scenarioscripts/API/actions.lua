local actionTypes = {
	EnableTrigger = 1,
	DisableTrigger = 2,
	IssueOrders = 3,
	AllowCommands = 4,
	RestrictCommands = 5,
	AlterBuildlist = 6,
	EnableBuildOption = 7,
	DisableBuildOption = 8,
	SpawnUnits = 9,
	SpawnConstruction = 10,
	DespawnUnits = 11,
	SpawnWeapons = 12,
	SpawnEffects = 13,
	RevealLOS = 14,
	UnrevealLOS = 15,
	AlterMapZones = 16,
	TransferUnits = 17,
	ControlCamera = 18,
	Pause = 19,
	Unpause = 20,
	PlayMedia = 21,
	SendMessage = 22,
	Victory = 23,
	Defeat = 24,
}

local actions = {}

local function addAction(id, type, ...)
	local action = {
		type = type,
		parameters = ...,
	}

	actions[id] = action
end

local function addEnableTriggerAction(id, triggerId)
	addAction(id, actionTypes.EnableTrigger, triggerId)
end

local function addSendMessageAction(id, message)
	addAction(id, actionTypes.SendMessage, message)
end

local function getActions()
	return actions
end

--example usage
--[[
AddEnableTriggerAction('monitorSea', 'builtSonar')
]]

return {
	GetActions = getActions,
	AddEnableTriggerAction = addEnableTriggerAction,
	AddSendMessageAction = addSendMessageAction,
}