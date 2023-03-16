local actionTypes = {
	EnableTrigger = 1,
	DisableTrigger = 2,
	-- TODO: Fix numbering
	IssueOrders = 4,
	AllowCommands = 5,
	RestrictCommands = 6,
	AlterBuildlist = 7,
	EnableBuildOption = 8,
	DisableBuildOption = 9,
	SpawnUnits = 10,
	SpawnConstruction = 11,
	DespawnUnits = 12,
	SpawnWeapons = 13,
	SpawnEffects = 14,
	RevealLOS = 15,
	UnrevealLOS = 16,
	AlterMapZones = 17,
	TransferUnits = 18,
	ControlCamera = 19,
	Pause = 20,
	Unpause = 21,
	PlayMedia = 22,
	SendMessage = 23,
	Victory = 24,
	Defeat = 25,
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