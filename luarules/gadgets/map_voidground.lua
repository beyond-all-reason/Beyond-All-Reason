
local function detectVoidGround()
	local voidTerrainTypes = {
		Space = true,
		Asteroid = true
	}
	local sampleDist = 48
	for x=1, Game.mapSizeX, sampleDist do
		for z=1, Game.mapSizeZ, sampleDist do
			if voidTerrainTypes[ select(2, Spring.GetGroundInfo(x,z)) ] then
				return true
			end
		end
	end
	return false
end

if not detectVoidGround() then
	return
end

function gadget:GetInfo()
	return {
		name = "Map VoidGround",
		desc = "Destroys units in the void",
		author = "Floris",
		date = "October 2021",
		license = "",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local isVoidGroundTarget = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if not unitDef.canFly and (not unitDef.isBuilding or unitDef.speed == 0) then
		isVoidGroundTarget[unitDefID] = true
	end
end

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetFeaturePosition = Spring.GetFeaturePosition

local gaiaTeamID = Spring.GetGaiaTeamID()

function gadget:FeatureCreated(featureID)
	if select(2, spGetFeaturePosition(featureID)) <= 1 then
		Spring.DestroyFeature(featureID, false)
	end
end

-- periodically destroy units that end up in the void
function gadget:GameFrame(gf)

	if gf % 49 == 1 then
		local units = Spring.GetAllUnits()
		for k = 1, #units do
			local unitID = units[k]
			if isVoidGroundTarget[spGetUnitDefID(unitID)] then
				if select(2, spGetUnitPosition(unitID)) <= 0 then
					Spring.DestroyUnit(unitID)
				end
			end
		end
	end
end
