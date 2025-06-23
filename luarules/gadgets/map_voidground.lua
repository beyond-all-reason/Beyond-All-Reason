if not gadgetHandler:IsSyncedCode() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Map VoidWater",
		desc = "Destroys units in the void",
		author = "Floris, Beherith",
		date = "October 2021",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local success, mapinfo= pcall(VFS.Include,"mapinfo.lua") -- load mapinfo.lua confs
if not success or mapinfo == nil then
  Spring.Echo("Map VoidWater failed to load the mapinfo.lua")
  return
end

if mapinfo.voidwater then
  --Spring.Echo("Map has voidwater")
else
  --Spring.Echo("Map does not have voidwater")
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
local mapx = Game.mapSizeX
local mapz = Game.mapSizeZ


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
        local x,y,z = spGetUnitPosition(unitID)
				if x ~= nil and (y < 0) and ( x > 0 and x < mapx ) and (z > 0 and z < mapz) then
					Spring.DestroyUnit(unitID)
				end
			end
		end
	end
end
