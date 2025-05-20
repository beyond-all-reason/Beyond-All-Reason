local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
      name      = "Anti Stacking Hax",
      desc      = "123",
      author    = "Damgam",
      date      = "2021",
	  license   = "GNU GPL, v2 or later",
      layer     = -100,
      enabled   = true,
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local mapsizeX = Game.mapSizeX
local mapsizeZ = Game.mapSizeZ

local isAffectedUnit = {}
local canMove = {}
for udid, ud in pairs(UnitDefs) do
	if string.find(ud.id, "nanotc") then
		isAffectedUnit[udid] = {
			math.floor(((ud.xsize + ud.zsize)*0.5)*6),
			ud.minWaterDepth,
			ud.maxWaterDepth,
		}
	end
	if ud.canMove then
		canMove[udid] = true
	end
end

local affectedUnits = {}

function gadget:UnitCreated(unitID, unitDefID)
	if isAffectedUnit[unitDefID] then
		table.insert(affectedUnits, {unitID, unitDefID})
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if isAffectedUnit[unitDefID] then
		for i = 1, #affectedUnits do
			if affectedUnits[i][1] and affectedUnits[i][1] == unitID then
				table.remove(affectedUnits, i)
			end
		end
	end
end

function gadget:GameFrame(n)
	for i = 1, #affectedUnits do
		local unitID = affectedUnits[i][1]
		local unitDefID = affectedUnits[i][2]
		local nearestAlly = Spring.GetUnitNearestAlly(unitID, isAffectedUnit[unitDefID][1])
		if nearestAlly then
			if not canMove[Spring.GetUnitDefID(nearestAlly)] then
				if not Spring.GetUnitTransporter(unitID) then
					local x,_,z = Spring.GetUnitPosition(unitID)
					local ax,_,az = Spring.GetUnitPosition(nearestAlly)
					local r = math.random(1,3)
					local movementTargetX = 0
					local movementTargetZ = 0

					if r == 1 then
						if x == ax or z == az then
							local testRange = isAffectedUnit[unitDefID][1] * 2
							movementTargetX = math.random(-testRange, testRange)
							movementTargetZ = math.random(-testRange, testRange)
						end
					elseif r == 2 then
						if x > ax then
							movementTargetX = math.random(1,10)
						end
						if x < ax then
							movementTargetX = -math.random(1,10)
						end
					elseif r == 3 then
						if z > az then
							movementTargetZ = math.random(1,10)
						end
						if z < az then
							movementTargetZ = -math.random(1,10)
						end
					end
					local movementTargetY = Spring.GetGroundHeight(x+movementTargetX, z+movementTargetZ)
					local aboveMinWaterDepth = -(isAffectedUnit[unitDefID][2]) > movementTargetY
					local belowMaxWaterDepth = -(isAffectedUnit[unitDefID][3]) < movementTargetY

					local onMap = true
					if x+movementTargetX > mapsizeX or x+movementTargetX < 0 then
						onMap = false
					elseif z+movementTargetZ > mapsizeZ or z+movementTargetZ < 0 then
						onMap = false
					end

					if aboveMinWaterDepth and belowMaxWaterDepth and onMap then
						Spring.SetUnitPosition(unitID, x+movementTargetX, z+movementTargetZ)
					end
				end
			end
		end
	end
end
