--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name = "Commando Watch",
		desc = "Commando Watch",
		author = "TheFatController",
		date = "Aug 17, 2010",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local MAPSIZEX = Game.mapSizeX
local MAPSIZEZ = Game.mapSizeZ
local MINE2 = UnitDefNames["cormine4"].id
local mines = {}
local orderQueue = {}
local MINE_BLAST = {}
MINE_BLAST[WeaponDefNames["mine_light"].id] = true
MINE_BLAST[WeaponDefNames["mine_medium"].id] = true
MINE_BLAST[WeaponDefNames["mine_heavy"].id] = true

local isBuilding = {}
local isCommando = {}
for udid, ud in pairs(UnitDefs) do
	if string.find(ud.name, 'cormando') then
		isCommando[udid] = true
	end
	if ud.isBuilding then
		isBuilding[udid] = true
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
	if isCommando[unitDefID] then
		if weaponID < 0 then
			local x, y, z = Spring.GetUnitPosition(unitID)
			if x < 0 or z < 0 or x > MAPSIZEX or z > MAPSIZEZ then
				Spring.DestroyUnit(unitID)
				return damage, 1
			end
			x, y, z = Spring.GetUnitVelocity(unitID)
			Spring.AddUnitImpulse(unitID, x * -0.66, y * -0.66, z * -0.66)
			return damage * 0.12, 0
		elseif MINE_BLAST[weaponID] then
			return damage * 0.12, 0.24
		end
	elseif mines[unitID] and (attackerID == mines[unitID]) then
		return 0, 0
	end
	return damage, 1
end

function gadget:GameFrame(n)
	for unitID, coords in pairs(orderQueue) do
		Spring.GiveOrderToUnit(unitID, MINE2 * -1, coords, 0)
		orderQueue[unitID] = nil
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderID and unitDefID == MINE2 and isCommando[Spring.GetUnitDefID(builderID)] then
		mines[unitID] = builderID
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	mines[unitID] = nil
	orderQueue[unitID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	mines[unitID] = nil
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if isCommando[unitDefID] then
		Spring.SetUnitStealth(transportID, true)
	end
end

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	if isCommando[unitDefID] then
		Spring.SetUnitStealth(transportID, false)
	end
end
