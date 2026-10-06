local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Command Sounds",
		desc = "Order sounds of the GUI Sound Effects player",
		author = "Damgam",
		date = "2021",
		license = "GNU GPL, v2 or later",
		layer = 99999999, -- last in CommandNotify: set-target orders consumed by other widgets make no sound
		enabled = true,
	}
end

-- no need to enable when sound is muted
local enabled = (
	(Spring.GetConfigInt("snd_unitsound", 1) or 1) ~= 0
	and (Spring.GetConfigInt("snd_volmaster", 1) or 100) > 0
	and ((Spring.GetConfigInt("snd_volui", 1) or 100) > 0 or (Spring.GetConfigInt("snd_volbattle", 1) or 100) > 0)
)

local DelayRandomization = 2 -- frames

local CommandUISoundDelayFrames = 1
local CommandUnitSoundDelayFrames = 10 -- don't make it smaller than CommandUISoundDelayFrames
local UnitBuildOrderSoundDelayFrames = 10
local AllyCommandUnitDelayFrames = 1

-- Command sounds are limited by both game frames and by game time
-- So we reuse the time per frame for when the game is paused:
local commandSoundTimer = 1 / Game.gameSpeed
local commandSoundLimit = 20
local commandSoundCount = commandSoundLimit

local CommandUISoundDelayLastFrame = 0
local CommandUnitSoundDelayLastFrame = 0
local UnitBuildOrderSoundDelayLastFrame = 0
local AllyCommandUnitDelayLastFrame = 0

local CommandSoundEffects = {
	[CMD.GROUPSELECT] = { "cmd-reclaim", 0.8 }, -- not working yet
	[CMD.RESURRECT] = { "cmd-rez", 0.8 },
	[CMD.RECLAIM] = { "cmd-reclaim", 0.8 },
	[CMD.REPAIR] = { "cmd-repair", 0.6 },
	[CMD.REPEAT] = { "cmd-repeat", 0.8 },
	[CMD.ATTACK] = { "cmd-attack", 0.8 },
	[CMD.PATROL] = { "cmd-patrol", 0.8 },
	[CMD.FIGHT] = { "cmd-fight", 0.8 },
	[CMD.GUARD] = { "cmd-guard", 0.8 },
	[CMD.SELFD] = { "cmd-selfd", 0.8 },
	[CMD.STOP] = { "cmd-stop", 0.7 },
	[CMD.WAIT] = { "cmd-wait", 0.6 },
	[CMD.DGUN] = { "cmd-dgun", 0.6 },
	[CMD.MOVE] = { "cmd-move-supershort", 0.4 },
	[-1] = { "cmd-build", 0.5 }, -- build (cmd < 0 == -unitdefid)
	[GameCMD.UNIT_SET_TARGET] = { "cmd-settarget", 0.7 },
	[GameCMD.UNIT_SET_TARGET_NO_GROUND] = { "cmd-settarget", 0.7 },
	[GameCMD.WANT_CLOAK] = {
		on = { "cmd-on", 0.6 },
		off = { "cmd-off", 0.5 },
	},
}

local CMD_MOVE = CMD.MOVE
local CMD_UNIT_SET_TARGET = GameCMD.UNIT_SET_TARGET
local CMD_UNIT_SET_TARGET_NO_GROUND = GameCMD.UNIT_SET_TARGET_NO_GROUND
local CMD_UNIT_SET_TARGET_RECTANGLE = GameCMD.UNIT_SET_TARGET_RECTANGLE
local CMD_WANT_CLOAK = GameCMD.WANT_CLOAK

require("luarules/configs/gui_soundeffects")

-- convert key: name -> unitdefid
-- + add scavenger units
local newGUIUnitSoundEffects = {}
for name, defs in pairs(GUIUnitSoundEffects) do
	if UnitDefNames[name] then
		newGUIUnitSoundEffects[UnitDefNames[name].id] = defs
		if UnitDefNames[name .. "_scav"] then
			newGUIUnitSoundEffects[UnitDefNames[name .. "_scav"].id] = defs
		end
	end
end
GUIUnitSoundEffects = newGUIUnitSoundEffects
newGUIUnitSoundEffects = nil

local CurrentGameFrame = Spring.GetGameFrame()
local myTeamID = Spring.GetLocalTeamID()
local myAllyTeamID = Spring.GetLocalAllyTeamID()
local spectator, fullview = Spring.GetSpectatingState()

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spIsUnitInView = Spring.IsUnitInView
local spIsUnitSelected = Spring.IsUnitSelected
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetMyPlayerID = Spring.GetLocalPlayerID
local spGetMyTeamID = Spring.GetLocalTeamID
local spGetGameFrame = Spring.GetGameFrame
local spPlaySoundFile = Spring.PlaySoundFile

local math_random = math.random

local UsedFrame
local unitsAllyTeam = {}

local function pickSound(sound)
	return type(sound) == "string" and sound or sound[math_random(1, #sound)]
end

local function playSetTargetSounds(preferredUnitID, cmdID, forceUi)
	-- for set-target SFX
	CurrentGameFrame = spGetGameFrame()
	local soundDef = CommandSoundEffects[cmdID] or CommandSoundEffects[CMD_UNIT_SET_TARGET]
	if soundDef and (forceUi or CurrentGameFrame >= CommandUISoundDelayLastFrame + CommandUISoundDelayFrames) then
		spPlaySoundFile(soundDef[1], soundDef[2], "ui")
		if not forceUi then
			CommandUISoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization, DelayRandomization))
		end
	end

	if CurrentGameFrame < CommandUnitSoundDelayLastFrame + CommandUnitSoundDelayFrames then
		return
	end

	local unitID = (preferredUnitID and spIsUnitSelected(preferredUnitID)) and preferredUnitID
	if not unitID then
		local selCount = spGetSelectedUnitsCount()
		if selCount == 0 then
			return
		end
		local selUnits = spGetSelectedUnits()
		unitID = selUnits[math_random(1, #selUnits)]
	end

	local unitDefID = spGetUnitDefID(unitID)
	if unitDefID and GUIUnitSoundEffects[unitDefID] then
		local posx, posy, posz = spGetUnitPosition(unitID)
		if posx then
			if GUIUnitSoundEffects[unitDefID].BaseSoundMovementType then
				local sound = GUIUnitSoundEffects[unitDefID].BaseSoundMovementType
				spPlaySoundFile(pickSound(sound), 0.8, posx, posy, posz, "sfx")
				CommandUnitSoundDelayLastFrame = CurrentGameFrame
					+ (math_random(-DelayRandomization, DelayRandomization))
			end
			if GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType then
				local sound = GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType
				spPlaySoundFile(pickSound(sound), 0.2, posx, posy, posz, "sfx")
				CommandUnitSoundDelayLastFrame = CurrentGameFrame
					+ (math_random(-DelayRandomization, DelayRandomization))
			end
		end
	end
end

-- Line/rectangle set-target is initiated in synced code (unit_target_on_the_move.lua), the
-- GUI Sound Effects player gadget forwards its sync action here.
local function setTargetLineSound(teamID, playerID, unitID, cmdID)
	if not enabled then
		return
	end
	if playerID ~= spGetMyPlayerID() then
		if playerID ~= nil and playerID ~= -1 then
			return
		end
		if teamID ~= spGetMyTeamID() then
			return
		end
	end
	playSetTargetSounds(unitID, cmdID or CMD_UNIT_SET_TARGET_RECTANGLE, true)
end

function widget:Initialize()
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		if GUIUnitSoundEffects[spGetUnitDefID(unitID)] then
			unitsAllyTeam[unitID] = spGetUnitAllyTeam(unitID)
		end
	end
	widgetHandler:RegisterGlobal("SetTargetLineSound", setTargetLineSound)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("SetTargetLineSound")
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if not enabled then
		return
	end
	if
		cmdID ~= CMD_UNIT_SET_TARGET
		and cmdID ~= CMD_UNIT_SET_TARGET_NO_GROUND
		and cmdID ~= CMD_UNIT_SET_TARGET_RECTANGLE
	then
		return
	end
	if cmdOpts and cmdOpts.internal then
		return
	end

	-- Single-click set-target flows through CommandNotify
	playSetTargetSounds(nil, cmdID, false)
end

local slowTimer, fastTimer = 0, 0
function widget:Update(dt)
	fastTimer = fastTimer + dt
	if fastTimer > commandSoundTimer then
		fastTimer = 0
		commandSoundCount = commandSoundLimit
	end
	slowTimer = slowTimer + dt
	if slowTimer > 0.5 then
		slowTimer = 0
		myTeamID = Spring.GetLocalTeamID()
		myAllyTeamID = Spring.GetLocalAllyTeamID()
		spectator, fullview = Spring.GetSpectatingState()
		enabled = (
			(Spring.GetConfigInt("snd_unitsound", 1) or 1) ~= 0
			and (Spring.GetConfigInt("snd_volmaster", 1) or 100) > 0
			and (
				(Spring.GetConfigInt("snd_volui", 1) or 100) > 0
				or (Spring.GetConfigInt("snd_volbattle", 1) or 100) > 0
			)
		)
	end
end

function widget:GameFrame(n)
	if not enabled then
		return
	end
	CurrentGameFrame = spGetGameFrame()
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if enabled and GUIUnitSoundEffects[unitDefID] then
		unitsAllyTeam[unitID] = spGetUnitAllyTeam(unitID)
	end
end

function widget:UnitDestroyed(unitID)
	unitsAllyTeam[unitID] = nil
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if not enabled then
		return
	end

	if CurrentGameFrame ~= UsedFrame and commandSoundCount > 1 then
		commandSoundCount = commandSoundCount - 1

		if spIsUnitSelected(unitID) then
			local selectedUnitCount = spGetSelectedUnitsCount()
			if selectedUnitCount > 1 then
				local selUnits = spGetSelectedUnits()
				unitDefID = spGetUnitDefID(selUnits[math_random(1, #selUnits)])
			end

			local posx, posy, posz = spGetUnitPosition(unitID)
			if not posz then
				return
			end

			local ValidCommandSound = false

			if CurrentGameFrame >= CommandUISoundDelayLastFrame + CommandUISoundDelayFrames then
				if CommandSoundEffects[cmdID] then
					--allows two different cloak sounds for on and off
					if cmdID == CMD_WANT_CLOAK and cmdParams and cmdParams[1] ~= nil then
						if cmdParams[1] == 1 then
							spPlaySoundFile(CommandSoundEffects[cmdID].on[1], CommandSoundEffects[cmdID].on[2], "ui")
						else
							spPlaySoundFile(CommandSoundEffects[cmdID].off[1], CommandSoundEffects[cmdID].off[2], "ui")
						end
					elseif
						cmdID == CMD_MOVE
						and GUIUnitSoundEffects[unitDefID]
						and GUIUnitSoundEffects[unitDefID].Move
					then
						spPlaySoundFile(GUIUnitSoundEffects[unitDefID].Move, CommandSoundEffects[cmdID][2], "ui")
					else
						spPlaySoundFile(CommandSoundEffects[cmdID][1], CommandSoundEffects[cmdID][2], "ui")
					end
					CommandUISoundDelayLastFrame = CurrentGameFrame
						+ (math_random(-DelayRandomization, DelayRandomization))
					ValidCommandSound = true
				elseif cmdID < 0 then -- unit build
					local buildingDefID = -cmdID
					if
						GUIUnitSoundEffects[buildingDefID]
						and CurrentGameFrame >= UnitBuildOrderSoundDelayLastFrame + UnitBuildOrderSoundDelayFrames
					then
						if GUIUnitSoundEffects[buildingDefID].BaseSoundSelectType then
							local sound = GUIUnitSoundEffects[buildingDefID].BaseSoundSelectType
							spPlaySoundFile(pickSound(sound), 0.3, posx, posy, posz, "sfx")
							UnitBuildOrderSoundDelayLastFrame = CurrentGameFrame
								+ (math_random(-DelayRandomization, DelayRandomization))
						end
						if GUIUnitSoundEffects[buildingDefID].BaseSoundWeaponType then
							local sound = GUIUnitSoundEffects[buildingDefID].BaseSoundWeaponType
							spPlaySoundFile(pickSound(sound), 0.5, posx, posy, posz, "sfx")
							UnitBuildOrderSoundDelayLastFrame = CurrentGameFrame
								+ (math_random(-DelayRandomization, DelayRandomization))
						end
					end
				end
			end

			if CurrentGameFrame >= CommandUnitSoundDelayLastFrame + CommandUnitSoundDelayFrames then
				if ValidCommandSound and GUIUnitSoundEffects[unitDefID] then
					if GUIUnitSoundEffects[unitDefID].BaseSoundMovementType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundMovementType
						spPlaySoundFile(pickSound(sound), 0.8, posx, posy, posz, "sfx")
						UsedFrame = CurrentGameFrame
						CommandUnitSoundDelayLastFrame = CurrentGameFrame
							+ (math_random(-DelayRandomization, DelayRandomization))
					end

					if GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType
						spPlaySoundFile(pickSound(sound), 0.2, posx, posy, posz, "sfx")
						UsedFrame = CurrentGameFrame
						CommandUnitSoundDelayLastFrame = CurrentGameFrame
							+ (math_random(-DelayRandomization, DelayRandomization))
					end
				end
			end
		end
	end

	if unitTeam ~= myTeamID then
		if spIsUnitInView(unitID) and (unitsAllyTeam[unitID] == myAllyTeamID or (spectator and fullview)) then
			if CurrentGameFrame >= AllyCommandUnitDelayLastFrame + AllyCommandUnitDelayFrames then
				if GUIUnitSoundEffects[unitDefID] then
					local posx, posy, posz = spGetUnitPosition(unitID)

					if GUIUnitSoundEffects[unitDefID].BaseSoundMovementType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundMovementType
						spPlaySoundFile(pickSound(sound), 0.3, posx, posy, posz, "sfx")
						AllyCommandUnitDelayLastFrame = CurrentGameFrame
							+ (math_random(-DelayRandomization, DelayRandomization))
					end

					if GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType
						spPlaySoundFile(pickSound(sound), 0.075, posx, posy, posz, "sfx")
						AllyCommandUnitDelayLastFrame = CurrentGameFrame
							+ (math_random(-DelayRandomization, DelayRandomization))
					end
				end
			end
		end
	end
end
