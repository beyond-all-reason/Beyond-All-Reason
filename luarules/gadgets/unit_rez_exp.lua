function gadget:GetInfo()
	return {
		name      = "Rez Exp",
		desc      = "Restores experience upon resurrection",
		author    = "BD",
		date      = "-",
		version   = 1,
		license   = "WTFPL",
		layer     = -math.huge,
		enabled   = true,  --  loaded by default?
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

function GG.GetFeatureExperience(featureID)
	if wreckInfos[featureID] then
		return wreckInfos[featureID].experience
	end
end

local function sqDist(posA,posB)
	--we only consider 2d distance because ships gets rezzed on top of water surface instead of sea floor
	return (posA[1]-posB[1])^2+(posA[3]-posB[3])^2 --+(posA[2]-posB[2])^2
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	local wreckName = UnitDefs[unitDefID].wreckName
	if not wreckName then
		return --unit has no wreck
	end
	local wreckDefID = (FeatureDefNames[wreckName] or {} ).id
	if not wreckDefID then
		return --wreck not found
	end
	--wreck is created rezFrameDistance frames after unit died
	local wreckFrame = GetGameFrame() + rezFrameDistance 
	local frameList = deadUnits[wreckFrame] or {}
	local wreckList = frameList[wreckDefID] or {}
	wreckList[#wreckList+1] = {
		location = {GetUnitPosition(unitID)},
		experience = GetUnitExperience(unitID),
		unitDefID = unitDefID,
	}
	frameList[wreckDefID] = wreckList
	deadUnits[wreckFrame] = frameList
end

function gadget:FeatureCreated(featureID)
	local currentFrame = GetGameFrame()
	local featureList = deadUnits[currentFrame]
	if not featureList then
		return
	end
	local featureDefID = GetFeatureDefID(featureID)
	local wreckList = featureList[featureDefID]
	if not wreckList then
		return
	end
	local featurePos = {GetFeaturePosition(featureID)}
	for index,wreckInfo in pairs(wreckList) do
		if sqDist(wreckInfo.location,featurePos) < distThreshold then
			wreckInfos[featureID] = {
				experience = wreckInfo.experience,
				unitDefID = wreckInfo.unitDefID,
			}
			deadUnits[currentFrame][featureDefID][index] = nil
			return
		end
	end
end

function gadget:UnitCreated(unitID,unitDefID,unitTeam,builderID)
	if not builderID then
		return
	end
	--if unit that created it cannot resurrect, it wasn't for sure a resurrection
	if not UnitDefs[GetUnitDefID(builderID)].canResurrect then
		return
	end
	rezzedUnits[unitDefID] = rezzedUnits[unitDefID] or {}
	rezzedUnits[unitDefID][unitID] = {GetUnitPosition(unitID)}
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
	local wreckLocation = {GetFeaturePosition(featureID)}
	for unitID, unitPos in pairs(rezzedList) do
		if sqDist(unitPos,wreckLocation) < distThreshold then
			SetUnitExperience(unitID,wreckInfo.experience)
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
	deadUnits[currentFrame-1] = nil

	--reset rezzedUnits vector, if unit wasn't rezzed it will never be
	rezzedUnits = {}
end


