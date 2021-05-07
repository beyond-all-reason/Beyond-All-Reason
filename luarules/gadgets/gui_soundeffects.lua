
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

local unitNames = {}
for unitDefID, defs in pairs(UnitDefs) do
	unitNames[unitDefID] = defs.name
end

local CurrentGameFrame = Spring.GetGameFrame()
local myTeamID = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local spectator, fullview = Spring.GetSpectatingState()

local spGetUnitIsActive = Spring.GetUnitIsActive
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spIsUnitInView = Spring.IsUnitInView
local spIsUnitInLos = Spring.IsUnitInLos
local spPlaySoundFile = Spring.PlaySoundFile
local spGetUnitHealth = Spring.GetUnitHealth
local spIsUnitSelected = Spring.IsUnitSelected
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetGameFrame = Spring.GetGameFrame
local spGetMouseState = Spring.GetMouseState

local math_random = math.random

local UsedFrame

local function PlaySelectSound(unitID)
	local unitDefID = spGetUnitDefID(unitID)
	local posx, posy, posz = spGetUnitPosition(unitID)
	local unitName = unitNames[unitDefID]

	-- DEACTIVATE BELOW FOR NORMAL SOUNDS
	if CurrentGameFrame >= SelectSoundDelayLastFrame + SelectSoundDelayFrames then
		if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundSelectType then
			local sound = GUIUnitSoundEffects[unitName].BaseSoundSelectType
			if sound[2] then
				spPlaySoundFile(sound[math_random(1,#sound)], 0.25, posx, posy, posz, 'ui')
				SelectSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
			else
				spPlaySoundFile(sound, 0.35, posx, posy, posz, 'ui')
				SelectSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
			end
		end
		if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundWeaponType then
			local sound = GUIUnitSoundEffects[unitName].BaseSoundWeaponType
			if sound[2] then
				spPlaySoundFile(sound[math_random(1,#sound)], 0.75, posx, posy, posz, 'ui')
				SelectSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
			else
				spPlaySoundFile(sound, 0.7, posx, posy, posz, 'ui')
				SelectSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
			end
		end
	end
	selectionChanged = false
end

function gadget:GameFrame(n)
	if n%30 == 15 then
		myTeamID = Spring.GetMyTeamID()
		myAllyTeamID = Spring.GetMyAllyTeamID()
		spectator, fullview = Spring.GetSpectatingState()
	end

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

	local units = Spring.GetAllUnits()
	for i = 1, #units do
		local unitID = units[i]
		if ActiveStateTrackingUnitList[unitID] then
			local currentlyActive = spGetUnitIsActive(unitID) and 2 or 1

			if ActiveStateTrackingUnitList[unitID] ~= currentlyActive then
				local unitDefID = spGetUnitDefID(unitID)
				local unitName = unitNames[unitDefID]
				local unitTeam = spGetUnitTeam(unitID)
				local posx, posy, posz = spGetUnitPosition(unitID)
				local onScreen = spIsUnitInView(unitID)
				local inLos = spIsUnitInLos(unitID, myAllyTeamID)
				if currentlyActive == 1 then
					ActiveStateTrackingUnitList[unitID] = 1
					if not GUIUnitSoundEffects[unitName].BaseSoundDeactivate and GUIUnitSoundEffects[unitName].BaseSoundActivate then
						GUIUnitSoundEffects[unitName].BaseSoundDeactivate = GUIUnitSoundEffects[unitName].BaseSoundActivate
					end
					if myTeamID == unitTeam then
						if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundDeactivate then
							local sound = GUIUnitSoundEffects[unitName].BaseSoundDeactivate
							if sound[2] then
								spPlaySoundFile(sound[math_random(1,#sound)], 1, posx, posy, posz, 'ui')
							else
								spPlaySoundFile(sound, 1, posx, posy, posz, 'ui')
							end
						end
					elseif onScreen and (inLos or fullview) then
						if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundDeactivate then
							local sound = GUIUnitSoundEffects[unitName].BaseSoundDeactivate
							if sound[2] then
								spPlaySoundFile(sound[math_random(1,#sound)], 0.5, posx, posy, posz, 'ui')
							else
								spPlaySoundFile(sound, 0.5, posx, posy, posz, 'ui')
							end
						end
					end
				elseif currentlyActive == 2 then
					ActiveStateTrackingUnitList[unitID] = 2
					if myTeamID == unitTeam then
						if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundActivate then
							local sound = GUIUnitSoundEffects[unitName].BaseSoundActivate
							if sound[2] then
								spPlaySoundFile(sound[math_random(1,#sound)], 1, posx, posy, posz, 'ui')
							else
								spPlaySoundFile(sound, 1, posx, posy, posz, 'ui')
							end
						end
					elseif onScreen and (inLos or fullview) then
						if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundActivate then
							local sound = GUIUnitSoundEffects[unitName].BaseSoundActivate
							if sound[2] then
								spPlaySoundFile(sound[math_random(1,#sound)], 0.5, posx, posy, posz, 'ui')
							else
								spPlaySoundFile(sound, 0.5, posx, posy, posz, 'ui')
							end
						end
					end
				end
			end
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderID then
		if select(5, spGetUnitHealth(unitID)) < 0.05 then	--buildProgress
			local onScreen = spIsUnitInView(unitID)
			local inLos = spIsUnitInLos(unitID, myAllyTeamID)
			if myTeamID == spGetUnitTeam(builderID) then
				local unitName = unitNames[unitDefID]
				local posx, posy, posz = spGetUnitPosition(unitID)
				if CurrentGameFrame >= UnitCreatedSoundDelayLastFrame + UnitCreatedSoundDelayFrames then
					if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundSelectType then
						local sound = GUIUnitSoundEffects[unitName].BaseSoundSelectType
						if sound[2] then
							spPlaySoundFile(sound[math_random(1,#sound)], 0.4, posx, posy, posz, 'ui')
							UnitCreatedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
						else
							spPlaySoundFile(sound, 0.4, posx, posy, posz, 'ui')
							UnitCreatedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
						end
					end
					if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitName].BaseSoundWeaponType
						if sound[2] then
							spPlaySoundFile(sound[math_random(1,#sound)], 0.1, posx, posy, posz, 'ui')
							UnitCreatedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
						else
							spPlaySoundFile(sound, 0.1, posx, posy, posz, 'ui')
							UnitCreatedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
						end
					end
				end
			elseif onScreen and (inLos or fullview) then
				local unitName = unitNames[unitDefID]
				local posx, posy, posz = spGetUnitPosition(unitID)
				if CurrentGameFrame >= AllyUnitFinishedSoundDelayLastFrame + AllyUnitCreatedSoundDelayFrames and Spring.IsUnitInView(unitID) then
					if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundSelectType then
						local sound = GUIUnitSoundEffects[unitName].BaseSoundSelectType
						if sound[2] then
							spPlaySoundFile(sound[math_random(1,#sound)], 0.2, posx, posy, posz, 'ui')
							AllyUnitCreatedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
						else
							spPlaySoundFile(sound, 0.2, posx, posy, posz, 'ui')
							AllyUnitCreatedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
						end
					end
					if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitName].BaseSoundWeaponType
						if sound[2] then
							spPlaySoundFile(sound[math_random(1,#sound)], 0.05, posx, posy, posz, 'ui')
							AllyUnitCreatedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
						else
							spPlaySoundFile(sound, 0.05, posx, posy, posz, 'ui')
							AllyUnitCreatedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
						end
					end
				end
			end
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	local unitName = unitNames[unitDefID]
	local onScreen = spIsUnitInView(unitID)
	local inLos = spIsUnitInLos(unitID, myAllyTeamID)
	if myTeamID == unitTeam then
		local posx, posy, posz = spGetUnitPosition(unitID)
		if CurrentGameFrame >= UnitFinishedSoundDelayLastFrame + UnitFinishedSoundDelayFrames then
			UnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
			if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundSelectType then
				local sound = GUIUnitSoundEffects[unitName].BaseSoundSelectType
				if sound[2] then
					spPlaySoundFile(sound[math_random(1,#sound)], 0.8, posx, posy, posz, 'ui')
					UnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
				else
					spPlaySoundFile(sound, 0.8, posx, posy, posz, 'ui')
					UnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
				end
			end
			if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundWeaponType then
				local sound = GUIUnitSoundEffects[unitName].BaseSoundWeaponType
				if sound[2] then
					spPlaySoundFile(sound[math_random(1,#sound)], 0.2, posx, posy, posz, 'ui')
					UnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
				else
					spPlaySoundFile(sound, 0.2, posx, posy, posz, 'ui')
					UnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
				end
			end
		end
	elseif onScreen and (inLos or fullview) then
		local posx, posy, posz = spGetUnitPosition(unitID)
		if CurrentGameFrame >= UnitFinishedSoundDelayLastFrame + AllyUnitFinishedSoundDelayFrames and Spring.IsUnitInView(unitID) then
			if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundSelectType then
				local sound = GUIUnitSoundEffects[unitName].BaseSoundSelectType
				if sound[2] then
					spPlaySoundFile(sound[math_random(1,#sound)], 0.4, posx, posy, posz, 'ui')
					AllyUnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
				else
					spPlaySoundFile(sound, 0.4, posx, posy, posz, 'ui')
					AllyUnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
				end
			end
			if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundWeaponType then
				local sound = GUIUnitSoundEffects[unitName].BaseSoundWeaponType
				if sound[2] then
					spPlaySoundFile(sound[math_random(1,#sound)], 0.1, posx, posy, posz, 'ui')
					AllyUnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
				else
					spPlaySoundFile(sound, 0.1, posx, posy, posz, 'ui')
					AllyUnitFinishedSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
				end
			end
		end
	end
	if GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].BaseSoundActivate then
		ActiveStateTrackingUnitList[unitID] = 1
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if ActiveStateTrackingUnitList[unitID] then
		ActiveStateTrackingUnitList[unitID] = nil
	end
end

function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if CurrentGameFrame ~= UsedFrame then
		if spIsUnitSelected(unitID) then
			local selectedUnitCount = spGetSelectedUnitsCount()
			if selectedUnitCount > 1 then
			   local selUnits = spGetSelectedUnits()
			   unitDefID = spGetUnitDefID(selUnits[math_random(1,#selUnits)])
			end
			local unitName = unitNames[unitDefID]
			local posx, posy, posz = spGetUnitPosition(unitID)
			local ValidCommandSound = false
			if CurrentGameFrame >= CommandUISoundDelayLastFrame + CommandUISoundDelayFrames then
				if CommandSoundEffects[cmdID] then
					if cmdID == CMD_MOVE and GUIUnitSoundEffects[unitName] and GUIUnitSoundEffects[unitName].Move then
						spPlaySoundFile(GUIUnitSoundEffects[unitName].Move, CommandSoundEffects[cmdID][2], 'ui')
					else
						spPlaySoundFile(CommandSoundEffects[cmdID][1], CommandSoundEffects[cmdID][2], 'ui')
					end
					CommandUISoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization, DelayRandomization))
					ValidCommandSound = true
				elseif cmdID < 0 then
					local unitDefID = -(cmdID)
					local unitName = unitNames[unitDefID]
					if GUIUnitSoundEffects[unitName] and CurrentGameFrame >= UnitBuildOrderSoundDelayLastFrame + UnitBuildOrderSoundDelayFrames then
						if GUIUnitSoundEffects[unitName].BaseSoundSelectType then
							local sound = GUIUnitSoundEffects[unitName].BaseSoundSelectType
							spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.3, posx, posy, posz, 'ui')
							UnitBuildOrderSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
						end
						if GUIUnitSoundEffects[unitName].BaseSoundWeaponType then
							local sound = GUIUnitSoundEffects[unitName].BaseSoundWeaponType
							spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.5, posx, posy, posz, 'ui')
							UnitBuildOrderSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
						end
					end
					--spPlaySoundFile(CommandSoundEffects[-1][1], CommandSoundEffects[-1][2], 2)
					--ValidCommandSound = false
				end
			end

			if CurrentGameFrame >= CommandUnitSoundDelayLastFrame + CommandUnitSoundDelayFrames then
				if ValidCommandSound and GUIUnitSoundEffects[unitName] then

					if GUIUnitSoundEffects[unitName].BaseSoundMovementType then
						local sound = GUIUnitSoundEffects[unitName].BaseSoundMovementType
						spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.8, posx, posy, posz, 'ui')
						UsedFrame = CurrentGameFrame
						CommandUnitSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
					end

					if GUIUnitSoundEffects[unitName].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitName].BaseSoundWeaponType
						spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.2, posx, posy, posz, 'ui')
						UsedFrame = CurrentGameFrame
						CommandUnitSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
					end
				end
			end
		end
	end

	if unitTeam ~= myTeamID then

		local onScreen = spIsUnitInView(unitID)
		local inLos = spIsUnitInLos(unitID, myAllyTeamID)
		if onScreen == true and inLos == true then

			if CurrentGameFrame >= AllyCommandUnitDelayLastFrame + AllyCommandUnitDelayFrames then
				local unitName = unitNames[unitDefID]

				if GUIUnitSoundEffects[unitName] then
					local posx, posy, posz = spGetUnitPosition(unitID)

					if GUIUnitSoundEffects[unitName].BaseSoundMovementType then
						local sound = GUIUnitSoundEffects[unitName].BaseSoundMovementType
						spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.3, posx, posy, posz, 'ui')
						AllyCommandUnitDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
					end

					if GUIUnitSoundEffects[unitName].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitName].BaseSoundWeaponType
						spPlaySoundFile(sound[2] and sound[math_random(1,#sound)] or sound, 0.075, posx, posy, posz, 'ui')
						AllyCommandUnitDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization,DelayRandomization))
					end
				end
			end
		end
	end
end
