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
		-- Spring.Echo("shipyardbuilt")
		local uix, uiy, uiz = Spring.GetUnitPosition(unitID)
		shipyard[unitID] = {uix, uiy, uiz}
	end
end

function gadget:UnitDestroyed(unitID)
	shipyard[unitID] = nil
end

function gadget:UnitUnitCollision(colliderID, collideeID)
	if shipyard[collideeID] or shipyard[colliderID] then
	-- Spring.Echo("trigger")
		if shipyard[colliderID] then
			shipyardID = colliderID
			unitID = collideeID
		elseif shipyard[collideeID] then
			shipyardID = collideeID
			unitID = colliderID
		end
		-- Shipyard position
		local sx, sy, sz = shipyard[shipyardID][1], shipyard[shipyardID][2], shipyard[shipyardID][3]
		-- Unit position and direction
		local ux, uy, uz = Spring.GetUnitPosition(unitID)
		local udx, udy, udz = Spring.GetUnitDirection(unitID)
		-- Unit Velocity
		-- local vx, vy, vz = Spring.GetUnitVelocity(unitID)
		-- local velratio = 1
		-- Collision direction (unit to shipyard)
		local dx, dy, dz = sx - ux, sy - uy, sz - uz
		local ndx, ndy, ndz = Norm3D(dx, dy, dz)
		-- Stop and Move unit
		-- Spring.MoveCtrl.Enable(unitID)
		-- Spring.MoveCtrl.SetPosition(unitID, ux - 5*ndx, uy - 5*ndy, uz - 5*ndz)
		-- Spring.MoveCtrl.Disable(unitID)
		-- Change its direction (progressively)
		Spring.SetUnitDirection(unitID, udx*0.8 -ndx * 0.2, udy*0.8 -ndy * 0.2, udz*0.8 -ndz * 0.2)

		--Check UnitCMDQueue to stop when can't reach target
		-- local cmdQueue = Spring.GetUnitCommands(unitID, 1)
		-- if cmdQueue[1] and cmdQueue[1].id == CMD.MOVE then
			-- local cmdParams = {cmdQueue[1].params}
			-- if #cmdParams == 3 then
				-- if Spring.TestMoveOrder(Spring.GetUnitDefID[unitID], cmdParams[1], cmdParams[2], cmdParams[3]) == false then
				-- Erase move order
				-- end
			-- elseif #cmdParams == 6 then
				-- if Spring.TestMoveOrder(Spring.GetUnitDefID[unitID], cmdParams[4], cmdParams[5], cmdParams[6]) == false then
				-- Erase move order
				-- end
			-- end
		-- end
	end
end
end	