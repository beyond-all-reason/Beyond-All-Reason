function gadget:GetInfo()
	return {
		name = "Rez Exp",
		desc = "Restores experience upon resurrection",
		author = "BrainDamage",
		date = "-",
		version = 1,
		license = "WTFPL",
		layer = -999999,
		enabled = false, --  disabled, it doesnt reliably work most of the time
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local distThreshold = 1

local rezFrameDistance = 2

local GetUnitPosition = Spring.GetUnitPosition
local GetFeaturePosition = Spring.GetFeaturePosition
local GetFeatureDefID = Spring.GetFeatureDefID
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitExperience = Spring.GetUnitExperience
local SetUnitExperience = Spring.SetUnitExperience
local GetGameFrame = Spring.GetGameFrame
local requestMaverickExpUpdate = GG.requestMaverickExpUpdate

--wreckinfos is the only permanent storage across frames
local wreckInfos = {} -- featureID: unitDefID, experience

--this forgets after rezFrameDistance+1 frames
local deadUnits = {} -- creationFrame: wreckDefID: {experience,location}
--this is reset every frame
local rezzedUnits = {} -- unitDefID: location

local canResurrect = {}
local unitWreckDefID = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.corpse and FeatureDefNames[unitDef.corpse] then
		unitWreckDefID[unitDefID] = FeatureDefNames[unitDef.corpse].id
	end
	if unitDef.canResurrect then
		canResurrect[unitDefID] = true
	end
end

function GG.GetFeatureExperience(featureID)
	if wreckInfos[featureID] then
		return wreckInfos[featureID].experience
	end
end

local function sqDist(posA, posB)
	--we only consider 2d distance because ships gets rezzed on top of water surface instead of sea floor
	return (posA[1] - posB[1]) * (posA[1] - posB[1]) + (posA[3] - posB[3]) * (posA[3] - posB[3]) -- + (posA[2]-posB[2])*(posA[2]-posB[2])
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if not unitWreckDefID[unitDefID] then
		return
	end

	--wreck is created rezFrameDistance frames after unit died
	local wreckFrame = GetGameFrame() + rezFrameDistance
	local frameList = deadUnits[wreckFrame] or {}
	local wreckList = frameList[unitWreckDefID[unitDefID]] or {}
	wreckList[#wreckList + 1] = {
		location = { GetUnitPosition(unitID) },
		experience = GetUnitExperience(unitID),
		unitDefID = unitDefID,
	}
	frameList[unitWreckDefID[unitDefID]] = wreckList
	deadUnits[wreckFrame] = frameList
end

function gadget:FeatureCreated(featureID)
	local currentFrame = GetGameFrame()
	if currentFrame < 1 then
		return
	end -- dont proces all map features created on frame 0 by game
	local featureList = deadUnits[currentFrame]
	if not featureList then
		return
	end
	local featureDefID = GetFeatureDefID(featureID)
	local wreckList = featureList[featureDefID]
	if not wreckList then
		return
	end
	local featurePos = { GetFeaturePosition(featureID) }
	for index, wreckInfo in pairs(wreckList) do
		if sqDist(wreckInfo.location, featurePos) < distThreshold then
			wreckInfos[featureID] = {
				experience = wreckInfo.experience,
				unitDefID = wreckInfo.unitDefID,
			}
			deadUnits[currentFrame][featureDefID][index] = nil
			return
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if not builderID then
		return
	end
	--if unit that created it cannot resurrect, it wasn't for sure a resurrection
	if not canResurrect[GetUnitDefID(builderID)] then
		return
	end
	rezzedUnits[unitDefID] = rezzedUnits[unitDefID] or {}
	rezzedUnits[unitDefID][unitID] = { GetUnitPosition(unitID) }
end

function gadget:FeatureDestroyed(featureID)
	local wreckInfo = wreckInfos[featureID]
	wreckInfos[featureID] = nil
	if not wreckInfo then
		return
	end
	local rezzedList = rezzedUnits[wreckInfo.unitDefID]
	if not rezzedList then
		return
	end
	local wreckLocation = { GetFeaturePosition(featureID) }
	for unitID, unitPos in pairs(rezzedList) do
		if sqDist(unitPos, wreckLocation) < distThreshold then
			SetUnitExperience(unitID, wreckInfo.experience)
			requestMaverickExpUpdate(unitID)
			rezzedUnits[wreckInfo.unitDefID][unitID] = nil
			return
		end
	end
end

function gadget:GameFrame()
	--wrecks gets created exactly rezFrameDistance frames after unit death

	--UnitCreated gets called BEFORE FeatureDestroyed, but within the same frame

	-- reset dead units vector, if wreck wasn't created since rezFrameDistance+1 frames, it will never be
	local currentFrame = GetGameFrame()
	deadUnits[currentFrame - 1] = nil

	--reset rezzedUnits vector, if unit wasn't rezzed it will never be
	rezzedUnits = {}
end


