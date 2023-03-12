local actionTypes = {
	EnableTrigger = 1,
	DisableTrigger = 2,
	CreateTrigger = 3,
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

local function AddAction(id, type, ...)
	local action = {
		type = type,
		parameters = ...,
	}

	actions[id] = action
end

local function AddEnableTriggerAction(id, triggerId)
	AddAction(id, triggerId)
end

--example usage
--[[
AddEnableTriggerAction('monitorSea', 'builtSonar')
]]