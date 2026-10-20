if gadgetHandler:IsSyncedCode() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "GUI Sound Effects player",
		desc = "Custom sound effects for your units!",
		author = "Damgam",
		date = "2021",
		license = "GNU GPL, v2 or later",
		layer = 0,
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

local SelectSoundDelayFrames = 8
local UnitFinishedSoundDelayFrames = 1
local UnitCreatedSoundDelayFrames = 1

local AllyUnitFinishedSoundDelayFrames = 1
local AllyUnitCreatedSoundDelayFrames = 1

-- InitValues
local PreviouslySelectedUnits = {}
local ActiveStateTrackingUnitList = {}
local selectionChanged = false

local SelectSoundDelayLastFrame = 0
local UnitFinishedSoundDelayLastFrame = 0
local UnitCreatedSoundDelayLastFrame = 0

local AllyUnitFinishedSoundDelayLastFrame = 0
local AllyUnitCreatedSoundDelayLastFrame = 0

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
		-- ensure activate-able units have deactivate sounds
		if not defs.BaseSoundDeactivate and defs.BaseSoundActivate then
			defs.BaseSoundDeactivate = defs.BaseSoundActivate
		end
	end
end
GUIUnitSoundEffects = newGUIUnitSoundEffects
newGUIUnitSoundEffects = nil

local CurrentGameFrame = Spring.GetGameFrame()
local myTeamID = Spring.GetLocalTeamID()
local myAllyTeamID = Spring.GetLocalAllyTeamID()
local spectator, fullview = Spring.GetSpectatingState()

local spGetUnitIsActive = Spring.GetUnitIsActive
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spIsUnitInView = Spring.IsUnitInView
local spIsUnitInLos = Spring.IsUnitInLos
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetMouseState = Spring.GetMouseState
local spGetGameFrame = Spring.GetGameFrame
local spPlaySoundFile = Spring.PlaySoundFile

local math_random = math.random

local units = {}
local unitsTeam = {}
local unitsAllyTeam = {}

local function pickSound(sound)
	return type(sound) == "string" and sound or sound[math_random(1, #sound)]
end

local function PlaySelectSound(unitID)
	local unitDefID = spGetUnitDefID(unitID)

	-- DEACTIVATE BELOW FOR NORMAL SOUNDS
	if GUIUnitSoundEffects[unitDefID] and CurrentGameFrame >= SelectSoundDelayLastFrame + SelectSoundDelayFrames then
		local posx, posy, posz = spGetUnitPosition(unitID)
		if GUIUnitSoundEffects[unitDefID].BaseSoundSelectType then
			local sound = GUIUnitSoundEffects[unitDefID].BaseSoundSelectType
			spPlaySoundFile(pickSound(sound), 0.35, posx, posy, posz, "sfx")
			SelectSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization, DelayRandomization))
		end
		if GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType then
			local sound = GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType
			spPlaySoundFile(pickSound(sound), 0.7, posx, posy, posz, "sfx")
			SelectSoundDelayLastFrame = CurrentGameFrame + (math_random(-DelayRandomization, DelayRandomization))
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
	-- Line/rectangle set-target is initiated in synced code (unit_target_on_the_move.lua);
	-- the order sounds live in the Command Sounds widget
	gadgetHandler:AddSyncAction("settarget_line_sound", function(_, teamID, playerID, unitID, cmdID)
		if Script.LuaUI("SetTargetLineSound") then
			Script.LuaUI.SetTargetLineSound(teamID, playerID, unitID, cmdID)
		end
	end)
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction("settarget_line_sound")
end

local slowTimer = 0
function gadget:Update()
	local dt = Spring.GetLastUpdateSeconds()
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

function gadget:GameFrame(n)
	if not enabled then
		return
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
				for i = 1, selectedUnitsCount do
					if not PreviouslySelectedUnits[i] then
						selectionChanged = true
						PreviouslySelectedUnits = selectedUnits
					elseif
						selectedUnits[i] ~= PreviouslySelectedUnits[i] or #selectedUnits ~= #PreviouslySelectedUnits
					then
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
		local _, _, LMBPress, _, _, offscreen = spGetMouseState()
		if not LMBPress and not offscreen then
			selectionChanged = false
			local units = spGetSelectedUnits()
			table.sort(units)
			PreviouslySelectedUnits = units
			local unitcount = #units
			if unitcount > 1 then
				local unitID = units[math_random(1, unitcount)]
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
				if myTeamID == unitsTeam[unitID] then
					if GUIUnitSoundEffects[unitDefID].BaseSoundDeactivate then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundDeactivate
						spPlaySoundFile(pickSound(sound), 1, posx, posy, posz, "sfx")
					end
				elseif spIsUnitInView(unitID) and (spIsUnitInLos(unitID, myAllyTeamID) or fullview) then
					if GUIUnitSoundEffects[unitDefID].BaseSoundDeactivate then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundDeactivate
						spPlaySoundFile(pickSound(sound), 0.5, posx, posy, posz, "sfx")
					end
				end
			elseif currentlyActive == 2 then
				ActiveStateTrackingUnitList[unitID] = 2
				if myTeamID == unitsTeam[unitID] then
					if GUIUnitSoundEffects[unitDefID].BaseSoundActivate then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundActivate
						spPlaySoundFile(pickSound(sound), 1, posx, posy, posz, "sfx")
					end
				elseif spIsUnitInView(unitID) and (spIsUnitInLos(unitID, myAllyTeamID) or fullview) then
					if GUIUnitSoundEffects[unitDefID].BaseSoundActivate then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundActivate
						spPlaySoundFile(pickSound(sound), 0.5, posx, posy, posz, "sfx")
					end
				end
			end
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if not enabled then
		return
	end
	if builderID and GUIUnitSoundEffects[unitDefID] then
		local _, buildProgress = Spring.GetUnitIsBeingBuilt(unitID)
		if buildProgress < 0.05 then --buildProgress
			if myTeamID == spGetUnitTeam(builderID) then
				local posx, posy, posz = spGetUnitPosition(unitID)
				if CurrentGameFrame >= UnitCreatedSoundDelayLastFrame + UnitCreatedSoundDelayFrames then
					if GUIUnitSoundEffects[unitDefID].BaseSoundSelectType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundSelectType
						spPlaySoundFile(pickSound(sound), 0.4, posx, posy, posz, "sfx")
						UnitCreatedSoundDelayLastFrame = CurrentGameFrame
							+ (math_random(-DelayRandomization, DelayRandomization))
					end
					if GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType
						spPlaySoundFile(pickSound(sound), 0.1, posx, posy, posz, "sfx")
						UnitCreatedSoundDelayLastFrame = CurrentGameFrame
							+ (math_random(-DelayRandomization, DelayRandomization))
					end
				end
			elseif spIsUnitInView(unitID) and (unitsAllyTeam[unitID] == myAllyTeamID or (spectator and fullview)) then
				local posx, posy, posz = spGetUnitPosition(unitID)
				if
					CurrentGameFrame >= AllyUnitFinishedSoundDelayLastFrame + AllyUnitCreatedSoundDelayFrames
					and spIsUnitInView(unitID)
				then
					if GUIUnitSoundEffects[unitDefID].BaseSoundSelectType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundSelectType
						spPlaySoundFile(pickSound(sound), 0.2, posx, posy, posz, "sfx")
						AllyUnitCreatedSoundDelayLastFrame = CurrentGameFrame
							+ (math_random(-DelayRandomization, DelayRandomization))
					end
					if GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType
						spPlaySoundFile(pickSound(sound), 0.05, posx, posy, posz, "sfx")
						AllyUnitCreatedSoundDelayLastFrame = CurrentGameFrame
							+ (math_random(-DelayRandomization, DelayRandomization))
					end
				end
			end
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if not enabled then
		return
	end
	if GUIUnitSoundEffects[unitDefID] then
		units[unitID] = unitDefID
		unitsTeam[unitID] = unitTeam
		unitsAllyTeam[unitID] = spGetUnitAllyTeam(unitID)

		if enabled then
			if myTeamID == unitTeam then
				local posx, posy, posz = spGetUnitPosition(unitID)
				if CurrentGameFrame >= UnitFinishedSoundDelayLastFrame + UnitFinishedSoundDelayFrames then
					UnitFinishedSoundDelayLastFrame = CurrentGameFrame
						+ (math_random(-DelayRandomization, DelayRandomization))
					if GUIUnitSoundEffects[unitDefID].BaseSoundSelectType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundSelectType
						if sound[2] then
							spPlaySoundFile(sound[math_random(1, #sound)], 0.8, posx, posy, posz, "sfx")
							UnitFinishedSoundDelayLastFrame = CurrentGameFrame
								+ (math_random(-DelayRandomization, DelayRandomization))
						else
							spPlaySoundFile(sound, 0.8, posx, posy, posz, "sfx")
							UnitFinishedSoundDelayLastFrame = CurrentGameFrame
								+ (math_random(-DelayRandomization, DelayRandomization))
						end
					end
					if GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType
						if sound[2] then
							spPlaySoundFile(sound[math_random(1, #sound)], 0.2, posx, posy, posz, "sfx")
							UnitFinishedSoundDelayLastFrame = CurrentGameFrame
								+ (math_random(-DelayRandomization, DelayRandomization))
						else
							spPlaySoundFile(sound, 0.2, posx, posy, posz, "sfx")
							UnitFinishedSoundDelayLastFrame = CurrentGameFrame
								+ (math_random(-DelayRandomization, DelayRandomization))
						end
					end
				end
			elseif spIsUnitInView(unitID) and (unitsAllyTeam[unitID] == myAllyTeamID or (spectator and fullview)) then
				if
					CurrentGameFrame >= UnitFinishedSoundDelayLastFrame + AllyUnitFinishedSoundDelayFrames
					and spIsUnitInView(unitID)
				then
					local posx, posy, posz = spGetUnitPosition(unitID)
					if GUIUnitSoundEffects[unitDefID].BaseSoundSelectType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundSelectType
						spPlaySoundFile(pickSound(sound), 0.4, posx, posy, posz, "sfx")
						AllyUnitFinishedSoundDelayLastFrame = CurrentGameFrame
							+ (math_random(-DelayRandomization, DelayRandomization))
					end
					if GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType then
						local sound = GUIUnitSoundEffects[unitDefID].BaseSoundWeaponType
						spPlaySoundFile(pickSound(sound), 0.1, posx, posy, posz, "sfx")
						AllyUnitFinishedSoundDelayLastFrame = CurrentGameFrame
							+ (math_random(-DelayRandomization, DelayRandomization))
					end
				end
			end
			if GUIUnitSoundEffects[unitDefID].BaseSoundActivate then
				ActiveStateTrackingUnitList[unitID] = 1
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	units[unitID] = nil
	unitsTeam[unitID] = nil
	unitsAllyTeam[unitID] = nil
	if ActiveStateTrackingUnitList[unitID] then
		ActiveStateTrackingUnitList[unitID] = nil
	end
end
