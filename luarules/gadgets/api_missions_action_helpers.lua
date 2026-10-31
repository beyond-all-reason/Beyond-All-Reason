local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mission API Actions Helper",
		desc = "Execute certain Mission API actions which cannot be completely done within the actions currently.",
		date = "2026",
		layer = 0,
		enabled = true,
	}
end

local SYNC_ACTION_SKIPPABLE = "MissionCutsceneSkippable"
local MESSAGE_SKIP_CUTSCENE = "MissionSkipCutscene"

if not gadgetHandler:IsSyncedCode() then
	local KEY_ESCAPE = Spring.GetKeyCode("esc")

	local cutsceneSkippable = false

	local function setCutsceneSkippable(_, skippable)
		cutsceneSkippable = skippable
	end

	function gadget:KeyPress(key, mods, isRepeat)
		if cutsceneSkippable and key == KEY_ESCAPE and not Spring.GetSpectatingState() then
			if not isRepeat then
				Spring.SendLuaRulesMsg(MESSAGE_SKIP_CUTSCENE)
			end
			return true
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction(SYNC_ACTION_SKIPPABLE, setCutsceneSkippable)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction(SYNC_ACTION_SKIPPABLE)
	end

	return -- end unsynced
end

local spAddTeamResource = Spring.AddTeamResource
local spUseTeamResource = Spring.UseTeamResource

local formationSpeed = VFS.Include("luarules/mission_api/formation_speed.lua")

GG["MissionAPIActionHelper"] = {}

local framesHalfSecond = math.round(0.5 * Game.gameSpeed, 0)

local resourcing = {
	active = false,
	metalPerSecond = {},
	energyPerSecond = {},
}

GG["MissionAPIActionHelper"].addMetalPerSecond = function(teamID, metalPerSecond)
	if not resourcing.metalPerSecond[teamID] then
		resourcing.metalPerSecond[teamID] = 0
	end
	resourcing.metalPerSecond[teamID] = resourcing.metalPerSecond[teamID] + metalPerSecond

	resourcing.active = true
end

GG["MissionAPIActionHelper"].addEnergyPerSecond = function(teamID, energyPerSecond)
	if not resourcing.energyPerSecond[teamID] then
		resourcing.energyPerSecond[teamID] = 0
	end
	resourcing.energyPerSecond[teamID] = resourcing.energyPerSecond[teamID] + energyPerSecond

	resourcing.active = true
end

GG["MissionAPIActionHelper"].matchFormationSpeed = formationSpeed.Match

function gadget:GameFrame(frame)
	---------------
	-- Formation speed
	---------------
	if formationSpeed.IsActive() and frame % framesHalfSecond == 0 then
		formationSpeed.Update()
	end

	---------------
	-- Resourcing
	---------------
	if resourcing.active and frame % framesHalfSecond == 0 then
		for teamID, amount in pairs(resourcing.metalPerSecond) do
			if amount > 0 then
				spAddTeamResource(teamID, "metal", amount * 0.5)
			elseif amount < 0 then
				spUseTeamResource(teamID, "metal", -amount * 0.5)
			end
		end
		for teamID, amount in pairs(resourcing.energyPerSecond) do
			if amount > 0 then
				spAddTeamResource(teamID, "energy", amount * 0.5)
			elseif amount < 0 then
				spUseTeamResource(teamID, "energy", -amount * 0.5)
			end
		end
	end
end

function gadget:RecvLuaMsg(message, playerID)
	if message == MESSAGE_SKIP_CUTSCENE then
		local isSpectator = select(3, Spring.GetPlayerInfo(playerID, false))
		if not isSpectator and GG["MissionAPI"] then
			GG["MissionAPI"].Modules.Cutscenes.SkipCutscene()
		end
		return true
	end
end
