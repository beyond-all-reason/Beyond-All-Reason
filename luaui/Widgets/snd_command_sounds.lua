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

local delayRandomization = 2 -- frames
local commandUISoundDelayFrames = 1
local commandUnitSoundDelayFrames = 10 -- don't make it smaller than CommandUISoundDelayFrames
local unitBuildOrderSoundDelayFrames = 10
local allyCommandUnitDelayFrames = 1

local math_random = math.random

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
local spGetGameState = Spring.GetGameState
local spPlaySoundFile = Spring.PlaySoundFile

local CMD_UNIT_SET_TARGET = GameCMD.UNIT_SET_TARGET
local CMD_UNIT_SET_TARGET_NO_GROUND = GameCMD.UNIT_SET_TARGET_NO_GROUND
local CMD_UNIT_SET_TARGET_RECTANGLE = GameCMD.UNIT_SET_TARGET_RECTANGLE
local CMD_WANT_CLOAK = GameCMD.WANT_CLOAK

-- Command sounds are limited by both game frames and by game time
-- So we reuse the time per frame for when the game is paused:
local commandSoundTimer = 1 / Game.gameSpeed
local commandSoundLimit = 20
local commandSoundCount = commandSoundLimit

local commandUISoundDelayLastFrame = 0
local commandUnitSoundDelayLastFrame = 0
local unitBuildOrderSoundDelayLastFrame = 0
local allyCommandUnitDelayLastFrame = 0

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

require("luarules/configs/gui_soundeffects") -- provides GUIUnitSoundEffects

-- convert key: name -> unitdefid
-- + add scavenger units
local newGUIUnitSoundEffects = {}
for name, defs in pairs(GUIUnitSoundEffects) do
	if UnitDefNames[name] ~= nil then
		newGUIUnitSoundEffects[UnitDefNames[name].id] = defs
		if UnitDefNames[name .. "_scav"] then
			newGUIUnitSoundEffects[UnitDefNames[name .. "_scav"].id] = defs
		end
	end
end
GUIUnitSoundEffects = newGUIUnitSoundEffects
newGUIUnitSoundEffects = nil

local myTeamID = spGetMyTeamID()
local myAllyTeamID = Spring.GetLocalAllyTeamID()
local spectator, fullview = Spring.GetSpectatingState()
local pausedFrameCount = 0
local soundFrame = spGetGameFrame() -- the game frame, plus paused time in frames
local usedFrame = soundFrame - 1
local unitsAllyTeam = {}

local function isSoundEnabled()
	return (Spring.GetConfigInt("snd_unitsound", 1) or 1) ~= 0
		and (Spring.GetConfigInt("snd_volmaster", 1) or 100) > 0
		and ((Spring.GetConfigInt("snd_volui", 1) or 100) > 0 or (Spring.GetConfigInt("snd_volbattle", 1) or 100) > 0)
end
local hasSound = isSoundEnabled()

local function getRandomizedSoundFrame()
	return soundFrame + math_random(-delayRandomization, delayRandomization)
end

local function getRandomSelectedUnitID()
	local selectedUnits = spGetSelectedUnits()
	return selectedUnits[math_random(1, #selectedUnits)]
end

local function pickSound(sound)
	return type(sound) == "string" and sound or sound[math_random(1, #sound)]
end

local function playCommandSound(cmdID, cmdParams)
	local soundDef = CommandSoundEffects[cmdID]
	if cmdID == CMD_WANT_CLOAK and cmdParams and cmdParams[1] ~= nil then
		soundDef = cmdParams[1] == 1 and soundDef.on or soundDef.off
	end
	spPlaySoundFile(soundDef[1], soundDef[2], "ui")
end

local function playUnitSounds(sound, volume, weaponSound, weaponVolume, posx, posy, posz)
	if sound then
		spPlaySoundFile(pickSound(sound), volume, posx, posy, posz, "sfx")
	end
	if weaponSound then
		spPlaySoundFile(pickSound(weaponSound), weaponVolume, posx, posy, posz, "sfx")
	end
	return (sound or weaponSound) ~= nil
end

local function playSetTargetSounds(preferredUnitID, cmdID, forceUi)
	soundFrame = spGetGameFrame() + pausedFrameCount
	local soundDef = CommandSoundEffects[cmdID] or CommandSoundEffects[CMD_UNIT_SET_TARGET]
	if soundDef and (forceUi or soundFrame >= commandUISoundDelayLastFrame + commandUISoundDelayFrames) then
		spPlaySoundFile(soundDef[1], soundDef[2], "ui")
		if not forceUi then
			commandUISoundDelayLastFrame = getRandomizedSoundFrame()
		end
	end

	if soundFrame < commandUnitSoundDelayLastFrame + commandUnitSoundDelayFrames then
		return
	end

	local unitID = (preferredUnitID and spIsUnitSelected(preferredUnitID)) and preferredUnitID
	if not unitID then
		if spGetSelectedUnitsCount() == 0 then
			return
		end
		unitID = getRandomSelectedUnitID()
	end

	local unitSounds = GUIUnitSoundEffects[spGetUnitDefID(unitID)] ---@as table?
	if unitSounds then
		local posx, posy, posz = spGetUnitPosition(unitID)
		if
			posx
			and playUnitSounds(
				unitSounds.BaseSoundMovementType,
				0.8,
				unitSounds.BaseSoundWeaponType,
				0.2,
				posx,
				posy,
				posz
			)
		then
			commandUnitSoundDelayLastFrame = getRandomizedSoundFrame()
		end
	end
end

-- Line/rectangle set-target is initiated in synced code (unit_target_on_the_move.lua), the
-- GUI Sound Effects player gadget forwards its sync action here.
local function setTargetLineSound(teamID, playerID, unitID, cmdID)
	if not hasSound then
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
	widgetHandler:RegisterGlobal("SetTargetLineSound", setTargetLineSound)
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		if GUIUnitSoundEffects[spGetUnitDefID(unitID)] then
			unitsAllyTeam[unitID] = spGetUnitAllyTeam(unitID)
		end
	end
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("SetTargetLineSound")
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if not hasSound then
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
	playSetTargetSounds(nil, cmdID, false)
end

local slowTimer, fastTimer = 0, 0
function widget:Update(dt)
	fastTimer = fastTimer + dt
	if fastTimer > commandSoundTimer then
		local _, _, isPaused = spGetGameState()
		if isPaused then
			pausedFrameCount = pausedFrameCount + fastTimer * Game.gameSpeed
			soundFrame = spGetGameFrame() + pausedFrameCount
		end
		fastTimer = 0
		commandSoundCount = commandSoundLimit
	end
	slowTimer = slowTimer + dt
	if slowTimer > 0.5 then
		slowTimer = 0
		myTeamID = Spring.GetLocalTeamID()
		myAllyTeamID = Spring.GetLocalAllyTeamID()
		spectator, fullview = Spring.GetSpectatingState()
		hasSound = isSoundEnabled()
	end
end

function widget:GameFrame(n)
	if hasSound then
		soundFrame = spGetGameFrame() + pausedFrameCount
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if hasSound and GUIUnitSoundEffects[unitDefID] then
		unitsAllyTeam[unitID] = spGetUnitAllyTeam(unitID)
	end
end

function widget:UnitDestroyed(unitID)
	unitsAllyTeam[unitID] = nil
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if not hasSound then
		return
	end

	if soundFrame ~= usedFrame and commandSoundCount > 1 then
		commandSoundCount = commandSoundCount - 1

		if spIsUnitSelected(unitID) then
			if spGetSelectedUnitsCount() > 1 then
				unitDefID = spGetUnitDefID(getRandomSelectedUnitID())
			end

			local posx, posy, posz = spGetUnitPosition(unitID)
			if not posz then
				return
			end

			local ValidCommandSound = false

			if soundFrame >= commandUISoundDelayLastFrame + commandUISoundDelayFrames then
				if CommandSoundEffects[cmdID] then
					playCommandSound(cmdID, cmdParams)
					commandUISoundDelayLastFrame = getRandomizedSoundFrame()
					ValidCommandSound = true
				elseif cmdID < 0 then -- unit build
					local buildingSounds = GUIUnitSoundEffects[-cmdID] ---@as table?
					if
						buildingSounds
						and soundFrame >= unitBuildOrderSoundDelayLastFrame + unitBuildOrderSoundDelayFrames
						and playUnitSounds(
							buildingSounds.BaseSoundSelectType,
							0.3,
							buildingSounds.BaseSoundWeaponType,
							0.5,
							posx,
							posy,
							posz
						)
					then
						unitBuildOrderSoundDelayLastFrame = getRandomizedSoundFrame()
					end
				end
			end

			local tryUnitSound = ValidCommandSound
				and soundFrame >= commandUnitSoundDelayLastFrame + commandUnitSoundDelayFrames
			local unitSounds = tryUnitSound and GUIUnitSoundEffects[unitDefID] ---@as table?
			if
				unitSounds
				and playUnitSounds(
					unitSounds.BaseSoundMovementType,
					0.8,
					unitSounds.BaseSoundWeaponType,
					0.2,
					posx,
					posy,
					posz
				)
			then
				usedFrame = soundFrame
				commandUnitSoundDelayLastFrame = getRandomizedSoundFrame()
			end
		end
	end

	if unitTeam ~= myTeamID then
		if spIsUnitInView(unitID) and (unitsAllyTeam[unitID] == myAllyTeamID or (spectator and fullview)) then
			local unitSounds = GUIUnitSoundEffects[unitDefID] ---@as table?
			if unitSounds and soundFrame >= allyCommandUnitDelayLastFrame + allyCommandUnitDelayFrames then
				local posx, posy, posz = spGetUnitPosition(unitID)
				if
					playUnitSounds(
						unitSounds.BaseSoundMovementType,
						0.3,
						unitSounds.BaseSoundWeaponType,
						0.075,
						posx,
						posy,
						posz
					)
				then
					allyCommandUnitDelayLastFrame = getRandomizedSoundFrame()
				end
			end
		end
	end
end
