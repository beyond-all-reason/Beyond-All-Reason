function gadget:GetInfo()
  return {
    name      = "Shipyards Collisions",
    desc      = "Makes sure units (boats only) are pushed away from shipyards",
    author    = "Doo",
    date      = "Sept 19th 2017",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then
defIDIsShipyard = {}
shipyard = {}
for id, uDef in pairs(UnitDefs) do
	if uDef.name == "armsy" or uDef.name == "armasy" or uDef.name == "corsy" or uDef.name == "corasy" then
		defIDIsShipyard[id] = true
		Script.SetWatchUnit(id, true)
	elseif uDef.moveDef and uDef.moveDef.name and string.find(uDef.moveDef.name, "boat") then
		Script.SetWatchUnit(id, true)
	end
end

function Norm3D(x, y , z)
	length = math.sqrt(x^2 + y^2 + z^2)
	local x2, y2, z2 = x/length, y/length, z/length
	return x2, y2, z2
end

function gadget:Initialize()
	for ct, unitID in pairs(Spring.GetAllUnits()) do
	gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if defIDIsShipyard[Spring.GetUnitDefID(unitID)] then
		Spring.Echo("shipyardbuilt")
		local uix, uiy, uiz = Spring.GetUnitPosition(unitID)
		shipyard[unitID] = {x = uix, y = uiy, z = uiz}
	end
end

function gadget:UnitDestroyed(unitID)
	shipyard[unitID] = nil
end

function gadget:UnitUnitCollision(colliderID, collideeID)
if shipyard[collideeID] or shipyard[colliderID] then
Spring.Echo("trigger")
	if shipyard[colliderID] then
		shipyardID = colliderID
		unitID = collideeID
	elseif shipyard[collideeID] then
		shipyardID = collideeID
		unitID = colliderID
	end
		-- Shipyard position
		local sx, sy, sz = shipyard[shipyardID].x, shipyard[shipyardID].y, shipyard[shipyardID].z
		-- Unit position
		local ux, uy, uz = Spring.GetUnitPosition(unitID)	
		-- Collision direction (unit to shipyard)
		local dx, dy, dz = sx - ux, sy - uy, sz - uz
		local ndx, ndy, ndz = Norm3D(dx, dy, dz)
		-- Move unit
		Spring.MoveCtrl.Enable(unitID)
		Spring.MoveCtrl.SetPosition(unitID, ux - 5*ndx, uy - 5*ndy, uz - 5*ndz)
		Spring.MoveCtrl.Disable(unitID)
end
end
end	