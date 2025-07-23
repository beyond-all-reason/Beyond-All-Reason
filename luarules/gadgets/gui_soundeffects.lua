
if gadgetHandler:IsSyncedCode() then
	return
end

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
local newGUIUnitSoundEffects = {}
for name, defs in pairs(GUIUnitSoundEffects) do
	if UnitDefNames[name] then
		newGUIUnitSoundEffects[UnitDefNames[name].id] = defs
		if UnitDefNames[name..'_scav'] then
			newGUIUnitSoundEffects[UnitDefNames[name..'_scav'].id] = defs
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

local function PlaySelectSound(unitID)
	local unitDefID = spGetUnitDefID(unitID)

	-- DEACTIVATE BELOW FOR NORMAL SOUNDS
	if GUIUnitSoundEffects[unitDefID] and CurrentGameFrame >= SelectSoundDelayLastFrame + SelectSoundDelayFrames then
		local posx, posy, posz = spGetUnitPosition(unitID)
		if GUIUnitSoundEffects[unitDefID].BaseSoundSelectType then
			local sound = GUIUnitSoundEffects[unitDefID].BaseSoundSelectType
			spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.35, posx, posy, posz, 'sfx')
			SelectSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
		end
		if GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType then
			local sound = GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType
			spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.7, posx, posy, posz, 'sfx')
			SelectSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
		end
	end
	selectionChanged = false
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

function gadget:GameFrame(n)
	if not enabled then return end

	CurrentGameFrame = spGetGameFrame()
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
	elseif selectionChanged then
		local _,_,LMBPress,_,_,offscreen = spGetMouseState()
		if not LMBPress and not offscreen then
			selectionChanged = false
			local units = spGetSelectedUnits()
			table.sort(units)
			PreviouslySelectedUnits = units
			local unitcount = #units
			if unitcount > 1 then
				local unitID = units[math_random(1,unitcount)]
				PlaySelectSound(unitID)
			elseif unitcount == 1 then
				local unitID = units[1]
				PlaySelectSound(unitID)
			end
		end
	end

	for unitID, previousActiveState in pairs(ActiveStateTrackingUnitList) do
		local unitDefID = units[unitID]

		local currentlyActive = spGetUnitIsActive(unitID) and 2 or 1

			if previousActiveState ~= currentlyActive then
				local posx, posy, posz = spGetUnitPosition(unitID)
				if currentlyActive == 1 then
					ActiveStateTrackingUnitList[unitID] = 1
					if not GUIUnitSoundEffects[unitDefID].BaseSoundDeactivate and GUIUnitSoundEffects[unitDefID].BaseSoundActivate then
						GUIUnitSoundEffects[unitDefID].BaseSoundDeactivate = GUIUnitSoundEffects[unitDefID].BaseSoundActivate
					end
					if myTeamID == unitsTeam[unitID] then
						if GUIUnitSoundEffects[unitDefID].BaseSoundDeactivate then
							local sound = GUIUnitSoundEffects[unitDefID].BaseSoundDeactivate
							spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 1, posx, posy, posz, 'sfx')
						end
					elseif spIsUnitInView(unitID) and (spIsUnitInLos(unitID, myAllyTeamID) or fullview) then
						if GUIUnitSoundEffects[unitDefID].BaseSoundDeactivate then
							local sound = GUIUnitSoundEffects[unitDefID].BaseSoundDeactivate
							spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.5, posx, posy, posz, 'sfx')
						end
					end
				elseif currentlyActive == 2 then
					ActiveStateTrackingUnitList[unitID] = 2
					if myTeamID == unitsTeam[unitID] then
						if GUIUnitSoundEffects[unitDefID].BaseSoundActivate then
							local sound = GUIUnitSoundEffects[unitDefID].BaseSoundActivate
							spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 1, posx, posy, posz, 'sfx')
						end
					elseif spIsUnitInView(unitID) and (spIsUnitInLos(unitID, myAllyTeamID) or fullview) then
						if GUIUnitSoundEffects[unitDefID].BaseSoundActivate then
							local sound = GUIUnitSoundEffects[unitDefID].BaseSoundActivate
							spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.5, posx, posy, posz, 'sfx')
						end
					end
				end
			end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if not enabled then return end
	if builderID and GUIUnitSoundEffects[unitDefID]then
		local _, buildProgress = Spring.GetUnitIsBeingBuilt(unitID)
		if buildProgress < 0.05 then	--buildProgress
			if myTeamID == spGetUnitTeam(builderID) then
				local posx, posy, posz = spGetUnitPosition(unitID)
				if CurrentGameFrame >= UnitCreatedSoundDelayLastFrame + UnitCreatedSoundDelayFrames then
					if GUIUnitSoundEffects[unitDefID].BaseSoundSelectType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundSelectType
						spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.4, posx, posy, posz, 'sfx')
						UnitCreatedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
					end
					if GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType
						spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.1, posx, posy, posz, 'sfx')
						UnitCreatedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
					end
				end
			elseif spIsUnitInView(unitID) and (unitsAllyTeam[unitID] == myAllyTeamID or (spectator and fullview)) then
				local posx, posy, posz = spGetUnitPosition(unitID)
				if CurrentGameFrame >= AllyUnitFinishedSoundDelayLastFrame + AllyUnitCreatedSoundDelayFrames and spIsUnitInView(unitID) then
					if GUIUnitSoundEffects[unitDefID].BaseSoundSelectType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundSelectType
						spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.2, posx, posy, posz, 'sfx')
						AllyUnitCreatedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
					end
					if GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType
						spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.05, posx, posy, posz, 'sfx')
						AllyUnitCreatedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
					end
				end
			end
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if not enabled then return end
	if GUIUnitSoundEffects[unitDefID] then
		units[unitID] = unitDefID
		unitsTeam[unitID] = unitTeam
		unitsAllyTeam[unitID] = spGetUnitAllyTeam(unitID)

		if enabled then
			if myTeamID == unitTeam then
				local posx, posy, posz = spGetUnitPosition(unitID)
				if CurrentGameFrame >= UnitFinishedSoundDelayLastFrame + UnitFinishedSoundDelayFrames then
					UnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
					if GUIUnitSoundEffects[unitDefID].BaseSoundSelectType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundSelectType
						if sound[2] then
							spPlaySoundFile(sound[math_random(1,#sound)], 0.8, posx, posy, posz, 'sfx')
							UnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
						else
							spPlaySoundFile(sound, 0.8, posx, posy, posz, 'sfx')
							UnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
						end
					end
					if GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType
						if sound[2] then
							spPlaySoundFile(sound[math_random(1,#sound)], 0.2, posx, posy, posz, 'sfx')
							UnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
						else
							spPlaySoundFile(sound, 0.2, posx, posy, posz, 'sfx')
							UnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
						end
					end
				end
			elseif spIsUnitInView(unitID) and (unitsAllyTeam[unitID] == myAllyTeamID or (spectator and fullview)) then
				if CurrentGameFrame >= UnitFinishedSoundDelayLastFrame + AllyUnitFinishedSoundDelayFrames and spIsUnitInView(unitID) then
					local posx, posy, posz = spGetUnitPosition(unitID)
					if GUIUnitSoundEffects[unitDefID].BaseSoundSelectType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundSelectType
						spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.4, posx, posy, posz, 'sfx')
						AllyUnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
					end
					if GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType
						spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.1, posx, posy, posz, 'sfx')
						AllyUnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
					end
				end
			end
			if GUIUnitSoundEffects[unitDefID].BaseSoundActivate then
				ActiveStateTrackingUnitList[unitID] = 1
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	units[unitID] = nil
	unitsTeam[unitID] = nil
	unitsAllyTeam[unitID] = nil
	if ActiveStateTrackingUnitList[unitID] then
		ActiveStateTrackingUnitList[unitID] = nil
	end
end

function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if not enabled then return end

	if CurrentGameFrame ~= UsedFrame and commandSoundCount > 1 then
		commandSoundCount = commandSoundCount - 1

		if spIsUnitSelected(unitID) then
			local selectedUnitCount = spGetSelectedUnitsCount()
			if selectedUnitCount > 1 then
			   local selUnits = spGetSelectedUnits()
			   unitDefID = spGetUnitDefID(selUnits[math_random(1,#selUnits)])
			end

			local posx, posy, posz = spGetUnitPosition(unitID)
			local ValidCommandSound = false

			if CurrentGameFrame >= CommandUISoundDelayLastFrame + CommandUISoundDelayFrames then

				if CommandSoundEffects[cmdID] then
					if cmdID == CMD_MOVE and GUIUnitSoundEffects[unitDefID] and GUIUnitSoundEffects[unitDefID].Move then
						spPlaySoundFile(GUIUnitSoundEffects[unitDefID].Move, CommandSoundEffects[cmdID][2], 'ui')
					else
						spPlaySoundFile(CommandSoundEffects[cmdID][1], CommandSoundEffects[cmdID][2], 'ui')
					end
					CommandUISoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization, DelayRandomization))
					ValidCommandSound = true

				elseif cmdID < 0 then	-- unit build
					local buildingDefID = -cmdID
					if GUIUnitSoundEffects[buildingDefID] and CurrentGameFrame >= UnitBuildOrderSoundDelayLastFrame + UnitBuildOrderSoundDelayFrames then
						if GUIUnitSoundEffects[buildingDefID].BaseSoundSelectType then
							local sound = GUIUnitSoundEffects[buildingDefID].BaseSoundSelectType
							spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.3, posx, posy, posz, 'sfx')
							UnitBuildOrderSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
						end
						if GUIUnitSoundEffects[buildingDefID].BaseSoundWeaponType then
							local sound = GUIUnitSoundEffects[buildingDefID].BaseSoundWeaponType
							spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.5, posx, posy, posz, 'sfx')
							UnitBuildOrderSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
						end
					end
					--spPlaySoundFile(CommandSoundEffects[-1][1], CommandSoundEffects[-1][2], 2)
					--ValidCommandSound = false
				end
			end

			if CurrentGameFrame >= CommandUnitSoundDelayLastFrame + CommandUnitSoundDelayFrames then
				if ValidCommandSound and GUIUnitSoundEffects[unitDefID] then

					if GUIUnitSoundEffects[unitDefID].BaseSoundMovementType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundMovementType
						spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.8, posx, posy, posz, 'sfx')
						UsedFrame = CurrentGameFrame
						CommandUnitSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
					end

					if GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType
						spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.2, posx, posy, posz, 'sfx')
						UsedFrame = CurrentGameFrame
						CommandUnitSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
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
						spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.3, posx, posy, posz, 'sfx')
						AllyCommandUnitDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
					end

					if GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType
						spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.075, posx, posy, posz, 'sfx')
						AllyCommandUnitDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
					end
				end
			end
		end
	end
end
