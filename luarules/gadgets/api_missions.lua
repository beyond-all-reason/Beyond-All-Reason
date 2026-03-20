local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mission API loader",
		desc = "Load and populate global mission table",
		date = "2023.03.14",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local sounds = VFS.Include('luarules/mission_api/sounds.lua')

local triggersController, actionsController

local function loadMission(scriptPath)
	local mission = VFS.Include(scriptPath)
	local rawTriggers = mission.Triggers
	local rawActions = mission.Actions

	GG['MissionAPI'].Triggers = triggersController.ProcessRawTriggers(rawTriggers, rawActions)
	GG['MissionAPI'].Actions = actionsController.ProcessRawActions(rawActions)

	local validateReferences = VFS.Include('luarules/mission_api/validation.lua').ValidateReferences
	validateReferences()
end

local function setAiNames(ais)
	for i, name in pairs(ais) do
		Spring.SetGameRulesParam('ainame_' .. i, name)
	end
end

function gadget:Initialize()
	local missionOptions = Spring.GetModOptions().missionoptions
	if not missionOptions then
		gadgetHandler:RemoveGadget()
		return
	end
	missionOptions = Json.decode(string.base64Decode(missionOptions))

	setAiNames(missionOptions.ais)

	GG['MissionAPI'] = {}
	GG['MissionAPI'].Difficulty = missionOptions.difficulty or 0
	GG['MissionAPI'].AllyTeams  = missionOptions.allyTeams or {}
	GG['MissionAPI'].Teams      = missionOptions.teams or {}
	GG['MissionAPI'].AIs        = missionOptions.ais or {}
	GG['MissionAPI'].Players    = missionOptions.players or {}

	local triggersSchema = VFS.Include('luarules/mission_api/triggers_schema.lua')
	local actionsSchema = VFS.Include('luarules/mission_api/actions_schema.lua')
	GG['MissionAPI'].TriggerTypes = triggersSchema.Types
	GG['MissionAPI'].ActionTypes = actionsSchema.Types
	GG['MissionAPI'].trackedUnitIDs = {}
	GG['MissionAPI'].trackedUnitNames = {}
	GG['MissionAPI'].soundFiles = {}
	GG['MissionAPI'].soundQueue = {}

	triggersController = VFS.Include('luarules/mission_api/triggers_loader.lua')
	actionsController = VFS.Include('luarules/mission_api/actions_loader.lua')

	loadMission(missionOptions.missionScriptPath);
end

function gadget:GameFrame(frameNumber)
	sounds.ProcessSoundQueue(frameNumber)
end

function gadget:Shutdown()
	GG['MissionAPI'] = nil
end
