function gadget:GetInfo()
	return {
		name      = "Shipyards Collisions",
		desc      = "Makes sure units (boats only) are pushed away from shipyards",
		author    = "Doo",
		date      = "Sept 19th 2017",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = false  --  loaded by default?
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local math_sqrt = math.sqrt

local defIDIsShipyard = {}
local shipyard = {}
local defIDIsBoat = {}
local boat = {}

for id, uDef in pairs(UnitDefs) do
	if string.find(uDef.name, 'armsy') or string.find(uDef.name, 'armasy') or string.find(uDef.name, 'corsy') or string.find(uDef.name, 'corasy') then
		defIDIsShipyard[id] = true
		Script.SetWatchUnit(id, true)
	elseif uDef.moveDef and uDef.moveDef.name and string.find(uDef.moveDef.name, "boat") then
		defIDIsBoat[id] = true
		Script.SetWatchUnit(id, true)
	end
end

function Norm3D(x, y , z)
	local length = math_sqrt(x*x + y*y + z*z)
	local x2, y2, z2 = x/length, y/length, z/length
	return x2, y2, z2
end

function gadget:Initialize()
	for ct, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if defIDIsShipyard[unitDefID] then
		local uix, uiy, uiz = Spring.GetUnitPosition(unitID)
		shipyard[unitID] = {uix, uiy, uiz}
	end
end

function gadget:UnitFinished(unitID, unitDefID)
	if defIDIsBoat[unitDefID] then
		boat[unitID] = Spring.GetGameFrame() + 30*15 --(15 seconds)
	end
end

function gadget:GameFrame(f)
	for unitID, frame in pairs(boat) do
		if f >= frame then
			boat[unitID] = nil
		end
	end
end

function gadget:UnitDestroyed(unitID)
	shipyard[unitID] = nil
	boat[unitID] = nil
end

function gadget:UnitUnitCollision(colliderID, collideeID)
	if not (boat[colliderID] or boat[collideeID]) then
		if shipyard[collideeID] or shipyard[colliderID] then
			local shipyardID, unitID
			if shipyard[colliderID] then
				shipyardID = colliderID
				unitID = collideeID
			elseif shipyard[collideeID] then
				shipyardID = collideeID
				unitID = colliderID
			end
			local sx, sy, sz = shipyard[shipyardID][1], shipyard[shipyardID][2], shipyard[shipyardID][3]
			local ux, uy, uz = Spring.GetUnitPosition(unitID)
			local udx, udy, udz = Spring.GetUnitDirection(unitID)
			local dx, dy, dz = sx - ux, sy - uy, sz - uz
			local ndx, ndy, ndz = Norm3D(dx, dy, dz)
			Spring.SetUnitDirection(unitID, udx*0.8 -ndx * 0.2, udy, udz*0.8 -ndz * 0.2)
		end
	end
end