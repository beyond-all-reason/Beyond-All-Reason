
if gadgetHandler:IsSyncedCode() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name 	= "GUI Sound Effects player",
		desc	= "Custom sound effects for your units!",
		author	= "Damgam",
		date	= "2021",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled = true,
	}
end

-- no need to enable when sound is muted
local enabled = ((Spring.GetConfigInt("snd_unitsound", 1) or 1) ~= 0 and (Spring.GetConfigInt("snd_volmaster", 1) or 100) > 0 and ((Spring.GetConfigInt("snd_volui", 1) or 100) > 0 or (Spring.GetConfigInt("snd_volbattle", 1) or 100) > 0))

local DelayRandomization = 2 -- frames

local CommandUISoundDelayFrames = 1
local CommandUnitSoundDelayFrames = 10 -- don't make it smaller than CommandUISoundDelayFrames
local SelectSoundDelayFrames = 8
local UnitFinishedSoundDelayFrames = 1
local UnitCreatedSoundDelayFrames = 1
local UnitBuildOrderSoundDelayFrames = 10

local AllyUnitFinishedSoundDelayFrames = 1
local AllyUnitCreatedSoundDelayFrames = 1
local AllyCommandUnitDelayFrames = 1

local commandSoundLimit = 20
local commandSoundCount = commandSoundLimit

-- InitValues
local PreviouslySelectedUnits = {}
local ActiveStateTrackingUnitList = {}
local ActiveStatePrevFrameTrackingUnitList = {}
local selectionChanged = false

local CommandUISoundDelayLastFrame = 0
local CommandUnitSoundDelayLastFrame = 0
local SelectSoundDelayLastFrame = 0
local UnitFinishedSoundDelayLastFrame = 0
local UnitCreatedSoundDelayLastFrame = 0
local UnitBuildOrderSoundDelayLastFrame = 0

local AllyUnitFinishedSoundDelayLastFrame = 0
local AllyUnitCreatedSoundDelayLastFrame = 0
local AllyCommandUnitDelayLastFrame = 0

local CommandSoundEffects = {
	[CMD.GROUPSELECT]	= {'cmd-reclaim', 0.8}, -- not working yet
	[CMD.RESURRECT]		= {'cmd-rez', 0.8},
	[CMD.RECLAIM]		= {'cmd-reclaim', 0.8},
	[CMD.REPAIR]		= {'cmd-repair', 0.6},
	[CMD.REPEAT]		= {'cmd-repeat', 0.8},
	[CMD.ATTACK]		= {'cmd-attack', 0.8},
	[CMD.PATROL]		= {'cmd-patrol', 0.8},
	[CMD.FIGHT]			= {'cmd-fight', 0.8},
	[CMD.GUARD]			= {'cmd-guard', 0.8},
	[CMD.SELFD]			= {'cmd-selfd', 0.8},
	[CMD.STOP]			= {'cmd-stop', 0.7},
	[CMD.WAIT]			= {'cmd-wait', 0.6},
	[CMD.DGUN]			= {'cmd-dgun', 0.6},
	[CMD.MOVE]			= {'cmd-move-supershort', 0.4},
	[-1]				= {'cmd-build', 0.5},	-- build (cmd < 0 == -unitdefid)
	--[34923]			= {'cmd-settarget', 0.8},	-- settarget -- not working yet
	--[CMD.ONOFF]			= {'cmd-onoff', 0.8},
	--LineMove "cmd-move-swoosh"
	--LineFight "cmd-fight"
}

local CMD_MOVE = CMD.MOVE

VFS.Include('luarules/configs/gui_soundeffects.lua')

-- convert key: name -> unitdefid
-- + add scavenger units
local GUIUnitSoundEffects = GUIUnitSoundEffects
local newGUIUnitSoundEffects = {}
for name, defs in pairs(GUIUnitSoundEffects) do
	if UnitDefNames[name] then
		newGUIUnitSoundEffects[UnitDefNames[name].id] = defs
		if UnitDefNames[name..'_scav'] then
			newGUIUnitSoundEffects[UnitDefNames[name..'_scav'].id] = defs
		end
		-- only use sub-tables for selecting multiple sounds
		for key, value in pairs(defs) do
			if type(value) == "table" and #value == 1 then
				defs[key] = value[1]
			end
		end
		-- ensure activate-able units have deactivate sounds
		if not defs.BaseSoundDeactivate and defs.BaseSoundActivate then
			defs.BaseSoundDeactivate = defs.BaseSoundActivate
		end
	end
end
GUIUnitSoundEffects = newGUIUnitSoundEffects
newGUIUnitSoundEffects = nil

local CurrentGameFrame = Spring.GetGameFrame()
local myTeamID = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local spectator, fullview = Spring.GetSpectatingState()

local spGetUnitIsActive = Spring.GetUnitIsActive
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spIsUnitInView = Spring.IsUnitInView
local spIsUnitInLos = Spring.IsUnitInLos
local spPlaySoundFile = Spring.PlaySoundFile
local spIsUnitSelected = Spring.IsUnitSelected
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetGameFrame = Spring.GetGameFrame
local spGetMouseState = Spring.GetMouseState

local math_random = math.random

local UsedFrame
local units = {}
local unitsTeam = {}
local unitsAllyTeam = {}

local function pickSound(sound)
	return type(sound) == "string" and sound or sound[math_random(1, #sound)]
end

local function getFirstWithSound(unitList)
	local count = #unitList
	if count == 1 then
		return GUIUnitSoundEffects[spGetUnitDefID(unitList[1])]
	elseif count > 1 then
		local index = math_random(count)
		local tries = 0
		repeat
			local sound = GUIUnitSoundEffects[spGetUnitDefID(unitList[index])]
			if sound then
				return sound
			end
			index = (index % count) + 1
			tries = tries + 1
		until tries == count
	end
end

local function PlaySelectSound(selectedUnits)
	if CurrentGameFrame >= SelectSoundDelayLastFrame + SelectSoundDelayFrames then
		-- As long as all units have sound, this returns in O(1).
		local unitSoundEffects = getFirstWithSound(selectedUnits)

		if unitSoundEffects then
			local applyDelay = false
			local posx, posy, posz = spGetUnitPosition(unitID)

			if unitSoundEffects.BaseSoundSelectType then
				spPlaySoundFile(pickSound(unitSoundEffects.BaseSoundSelectType), 0.35, posx, posy, posz, 'sfx')
				applyDelay = true
			end

			if unitSoundEffects.BaseSoundWeaponType then
				spPlaySoundFile(pickSound(unitSoundEffects.BaseSoundWeaponType), 0.7, posx, posy, posz, 'sfx')
				applyDelay = true
			end

			if applyDelay then
				SelectSoundDelayLastFrame = CurrentGameFrame + math_random(-DelayRandomization,DelayRandomization)
			end
		end
	end
end

function gadget:Initialize()
	units = {}
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local unitDefID = spGetUnitDefID(unitID)
		if GUIUnitSoundEffects[unitDefID] then
			units[unitID] = unitDefID
			unitsTeam[unitID] = spGetUnitTeam(unitID)
			unitsAllyTeam[unitID] = spGetUnitAllyTeam(unitID)
		end
	end
end

local sec, cmd = 0, 0
function gadget:Update()
	local dt = Spring.GetLastUpdateSeconds()
	sec = sec + dt
	cmd = cmd + dt
	if sec > 0.5 then
		sec = 0
		myTeamID = Spring.GetMyTeamID()
		myAllyTeamID = Spring.GetMyAllyTeamID()
		spectator, fullview = Spring.GetSpectatingState()
		enabled = ((Spring.GetConfigInt("snd_unitsound", 1) or 1) ~= 0 and (Spring.GetConfigInt("snd_volmaster", 1) or 100) > 0 and ((Spring.GetConfigInt("snd_volui", 1) or 100) > 0 or (Spring.GetConfigInt("snd_volbattle", 1) or 100) > 0))
	end
	if cmd > 1 / 30 then
		commandSoundCount = commandSoundLimit
	end
end

function gadget:GameFrame(frame)
	if not enabled then return end

	CurrentGameFrame = frame

	if not selectionChanged then
		selectionChanged = false
		local selectedUnits = spGetSelectedUnits()
		local selectedUnitsCount = #selectedUnits
		if selectedUnitsCount == 0 then
			selectionChanged = false
			PreviouslySelectedUnits = nil
		elseif selectedUnitsCount > 0 then
			table.sort(selectedUnits)
			if not PreviouslySelectedUnits then
				selectionChanged = true
				PreviouslySelectedUnits = selectedUnits
			else
				for i = 1,selectedUnitsCount do
					if not PreviouslySelectedUnits[i] then
						selectionChanged = true
						PreviouslySelectedUnits = selectedUnits
					elseif selectedUnits[i] ~= PreviouslySelectedUnits[i] or #selectedUnits ~= #PreviouslySelectedUnits then
						selectionChanged = true
						PreviouslySelectedUnits = selectedUnits
						break
					else
						selectionChanged = false
						PreviouslySelectedUnits = selectedUnits
					end
				end
			end
		end
	end

	if selectionChanged then
		local _,_,LMBPress,_,_,offscreen = spGetMouseState()
		if not LMBPress and not offscreen then
			selectionChanged = false
			local selectedUnits = spGetSelectedUnits()
			table.sort(selectedUnits)
			PreviouslySelectedUnits = selectedUnits
			PlaySelectSound(selectedUnits)
		end
	end

	for unitID, previousActiveState in pairs(ActiveStateTrackingUnitList) do
		local unitDefID = units[unitID]

		local currentlyActive = spGetUnitIsActive(unitID)

		if previousActiveState ~= currentlyActive then
			local unitSoundEffects = GUIUnitSoundEffects[unitDefID]
			local posx, posy, posz = spGetUnitPosition(unitID)

			if currentlyActive == false then
				ActiveStateTrackingUnitList[unitID] = false
				if myTeamID == unitsTeam[unitID] then
					if unitSoundEffects.BaseSoundDeactivate then
						spPlaySoundFile(pickSound(unitSoundEffects.BaseSoundDeactivate), 1, posx, posy, posz, 'sfx')
					end
				elseif spIsUnitInView(unitID) and (spIsUnitInLos(unitID, myAllyTeamID) or fullview) then
					if unitSoundEffects.BaseSoundDeactivate then
						spPlaySoundFile(pickSound(unitSoundEffects.BaseSoundDeactivate), 0.5, posx, posy, posz, 'sfx')
					end
				end
			elseif currentlyActive == true then
				ActiveStateTrackingUnitList[unitID] = true
				if myTeamID == unitsTeam[unitID] then
					if unitSoundEffects.BaseSoundActivate then
						spPlaySoundFile(pickSound(unitSoundEffects.BaseSoundActivate), 1, posx, posy, posz, 'sfx')
					end
				elseif spIsUnitInView(unitID) and (spIsUnitInLos(unitID, myAllyTeamID) or fullview) then
					if unitSoundEffects.BaseSoundActivate then
						spPlaySoundFile(pickSound(unitSoundEffects.BaseSoundActivate), 0.5, posx, posy, posz, 'sfx')
					end
				end
			end
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if not enabled then return end

	local unitSoundEffects = GUIUnitSoundEffects[unitDefID]

	if builderID and unitSoundEffects then
		local _, buildProgress = Spring.GetUnitIsBeingBuilt(unitID)

		if buildProgress < 0.05 then
			if myTeamID == spGetUnitTeam(builderID) then
				if CurrentGameFrame >= UnitCreatedSoundDelayLastFrame + UnitCreatedSoundDelayFrames then
					local applyDelay = false
					local posx, posy, posz = spGetUnitPosition(unitID)

					if unitSoundEffects.BaseSoundSelectType then
						spPlaySoundFile(pickSound(unitSoundEffects.BaseSoundSelectType), 0.4, posx, posy, posz, 'sfx')
						applyDelay = true
					end

					if unitSoundEffects.BaseSoundWeaponType then
						spPlaySoundFile(pickSound(unitSoundEffects.BaseSoundWeaponType), 0.1, posx, posy, posz, 'sfx')
						applyDelay = true
					end

					if applyDelay then
						UnitCreatedSoundDelayLastFrame = CurrentGameFrame + math_random(-DelayRandomization, DelayRandomization)
					end
				end
			elseif (unitsAllyTeam[unitID] == myAllyTeamID or (spectator and fullview)) and spIsUnitInView(unitID) then
				if CurrentGameFrame >= AllyUnitCreatedSoundDelayLastFrame + AllyUnitCreatedSoundDelayFrames and spIsUnitInView(unitID) then
					local applyDelay = false
					local posx, posy, posz = spGetUnitPosition(unitID)

					if unitSoundEffects.BaseSoundSelectType then
						spPlaySoundFile(pickSound(unitSoundEffects.BaseSoundSelectType), 0.2, posx, posy, posz, 'sfx')
						applyDelay = true
					end

					if unitSoundEffects.BaseSoundWeaponType then
						spPlaySoundFile(pickSound(unitSoundEffects.BaseSoundWeaponType), 0.05, posx, posy, posz, 'sfx')
						applyDelay = true
					end

					if applyDelay then
						AllyUnitCreatedSoundDelayLastFrame = CurrentGameFrame + math_random(-DelayRandomization, DelayRandomization)						
					end
				end
			end
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	local unitSoundEffects = GUIUnitSoundEffects[unitDefID]

	if unitSoundEffects then
		units[unitID] = unitDefID
		unitsTeam[unitID] = unitTeam
		unitsAllyTeam[unitID] = spGetUnitAllyTeam(unitID)

		if enabled then
			if myTeamID == unitTeam then
				if CurrentGameFrame >= UnitFinishedSoundDelayLastFrame + UnitFinishedSoundDelayFrames then
					local applyDelay = false
					local posx, posy, posz = spGetUnitPosition(unitID)

					if unitSoundEffects.BaseSoundSelectType then
						spPlaySoundFile(pickSound(unitSoundEffects.BaseSoundSelectType), 0.8, posx, posy, posz, 'sfx')
						applyDelay = true
					end

					if unitSoundEffects.BaseSoundWeaponType then
						spPlaySoundFile(pickSound(unitSoundEffects.BaseSoundWeaponType), 0.2, posx, posy, posz, 'sfx')
						applyDelay = true
					end

					if applyDelay then
						UnitFinishedSoundDelayLastFrame = CurrentGameFrame + math_random(-DelayRandomization, DelayRandomization)
					end
				end
			elseif spIsUnitInView(unitID) and (unitsAllyTeam[unitID] == myAllyTeamID or (spectator and fullview)) then
				if CurrentGameFrame >= AllyUnitFinishedSoundDelayLastFrame + AllyUnitFinishedSoundDelayFrames and spIsUnitInView(unitID) then
					local applyDelay = false
					local posx, posy, posz = spGetUnitPosition(unitID)

					if unitSoundEffects.BaseSoundSelectType then
						spPlaySoundFile(pickSound(unitSoundEffects.BaseSoundSelectType), 0.4, posx, posy, posz, 'sfx')
					end

					if unitSoundEffects.BaseSoundWeaponType then
						spPlaySoundFile(pickSound(unitSoundEffects.BaseSoundWeaponType), 0.1, posx, posy, posz, 'sfx')
					end

					if applyDelay then
						AllyUnitFinishedSoundDelayLastFrame = CurrentGameFrame + math_random(-DelayRandomization, DelayRandomization)						
					end
				end
			end

			if unitSoundEffects.BaseSoundActivate then
				ActiveStateTrackingUnitList[unitID] = false
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	units[unitID] = nil
	unitsTeam[unitID] = nil
	unitsAllyTeam[unitID] = nil
	ActiveStateTrackingUnitList[unitID] = nil
end

function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if not enabled then return end

	if CurrentGameFrame ~= UsedFrame and commandSoundCount > 1 then
		commandSoundCount = commandSoundCount - 1

		if spIsUnitSelected(unitID) then
			local ValidCommandSound = false

			local unitSoundEffects = getFirstWithSound(spGetSelectedUnits())
			local posx, posy, posz = spGetUnitPosition(unitID)

			if unitSoundEffects then
				if CurrentGameFrame >= CommandUISoundDelayLastFrame + CommandUISoundDelayFrames then
					if CommandSoundEffects[cmdID] then
						if cmdID == CMD_MOVE and unitSoundEffects and unitSoundEffects.Move then
							spPlaySoundFile(unitSoundEffects.Move, CommandSoundEffects[cmdID][2], 'ui')
						else
							spPlaySoundFile(CommandSoundEffects[cmdID][1], CommandSoundEffects[cmdID][2], 'ui')
						end

						CommandUISoundDelayLastFrame = CurrentGameFrame + math_random(-DelayRandomization, DelayRandomization)
						ValidCommandSound = true
					elseif cmdID < 0 then
						if CurrentGameFrame >= UnitBuildOrderSoundDelayLastFrame + UnitBuildOrderSoundDelayFrames then
							-- NB: Technically shouldn't care whether we found `unitSoundEffects`:
							local buildingSoundEffects = GUIUnitSoundEffects[spGetUnitDefID(-cmdID)]

							if buildingSoundEffects then
								if buildingSoundEffects.BaseSoundSelectType then
									spPlaySoundFile(buildingSoundEffects.BaseSoundSelectType, 0.3, posx, posy, posz, 'sfx')
									ValidCommandSound = true
								end

								if buildingSoundEffects.BaseSoundWeaponType then
									spPlaySoundFile(buildingSoundEffects.BaseSoundWeaponType, 0.5, posx, posy, posz, 'sfx')
									ValidCommandSound = true
								end

								if ValidCommandSound then
									UnitBuildOrderSoundDelayLastFrame = CurrentGameFrame + math_random(-DelayRandomization, DelayRandomization)
								end
							end
						end
					end
				end
			end

			if ValidCommandSound and CurrentGameFrame >= CommandUnitSoundDelayLastFrame + CommandUnitSoundDelayFrames then
				if GUIUnitSoundEffects[unitDefID] then
					local applyDelay = false

					if GUIUnitSoundEffects[unitDefID].BaseSoundMovementType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundMovementType
						spPlaySoundFile(pickSound(sound), 0.8, posx, posy, posz, 'sfx')
						UsedFrame = CurrentGameFrame
						applyDelay = true
					end

					if GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType
						spPlaySoundFile(pickSound(sound), 0.2, posx, posy, posz, 'sfx')
						UsedFrame = CurrentGameFrame
						applyDelay = true
					end

					if applyDelay then
						CommandUnitSoundDelayLastFrame = CurrentGameFrame + math_random(-DelayRandomization, DelayRandomization)
					end
				end
			end
		end
	end

	if unitTeam ~= myTeamID and CurrentGameFrame >= AllyCommandUnitDelayLastFrame + AllyCommandUnitDelayFrames then
		if (unitsAllyTeam[unitID] == myAllyTeamID or (spectator and fullview)) and spIsUnitInView(unitID) then
			local unitSoundEffects = GUIUnitSoundEffects[unitDefID]

			if unitSoundEffects then
				local applyDelay = false
				local posx, posy, posz = spGetUnitPosition(unitID)

				if unitSoundEffects.BaseSoundMovementType then
					spPlaySoundFile(pickSound(unitSoundEffects.BaseSoundMovementType), 0.3, posx, posy, posz, 'sfx')
					applyDelay = true
				end

				if unitSoundEffects.BaseSoundWeaponType then
					spPlaySoundFile(pickSound(unitSoundEffects.BaseSoundWeaponType), 0.075, posx, posy, posz, 'sfx')
					applyDelay = true
				end

				if applyDelay then
					AllyCommandUnitDelayLastFrame = CurrentGameFrame + math_random(-DelayRandomization, DelayRandomization)						
				end
			end
		end
	end
end
