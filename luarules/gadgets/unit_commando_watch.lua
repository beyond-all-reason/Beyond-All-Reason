--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Commando Watch",
		desc = "Commando Watch",
		author = "TheFatController",
		date = "Aug 17, 2010",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local MAPSIZEX = Game.mapSizeX
local MAPSIZEZ = Game.mapSizeZ
local mines = {}
local MINE_BLAST = {}
MINE_BLAST[WeaponDefNames.mine_light.id] = true
MINE_BLAST[WeaponDefNames.mine_medium.id] = true
MINE_BLAST[WeaponDefNames.mine_heavy.id] = true

local isMine = {}
local isParatrooper = {}
local isMineResistant = {}
local isStealthsTransport = {}
for udid, ud in pairs(UnitDefs) do
	local cp = ud.customParams
	if cp.mine then
		isMine[udid] = true
	end
	if cp.paratrooper then
		isParatrooper[udid] = true
	end
	if cp.mine_resistant then
		isMineResistant[udid] = true
	end
	if cp.stealths_transport then
		isStealthsTransport[udid] = true
	end
end

function gadget:UnitPreDamaged(
	unitID,
	unitDefID,
	unitTeam,
	damage,
	paralyzer,
	weaponID,
	projectileID,
	attackerID,
	attackerDefID,
	attackerTeam
)
	if isParatrooper[unitDefID] and weaponID < 0 then
		local x, y, z = Spring.GetUnitPosition(unitID)
		if x < 0 or z < 0 or x > MAPSIZEX or z > MAPSIZEZ then
			Spring.DestroyUnit(unitID)
			return damage, 1
		end
		x, y, z = Spring.GetUnitVelocity(unitID)
		Spring.AddUnitImpulse(unitID, x * -0.66, y * -0.66, z * -0.66)
		return damage * 0.12, 0
	elseif isMineResistant[unitDefID] and MINE_BLAST[weaponID] then
		return damage * 0.12, 0.24
	elseif mines[unitID] and (attackerID == mines[unitID]) then
		return 0, 0
	end
	return damage, 1
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderID and isMine[unitDefID] and isMineResistant[Spring.GetUnitDefID(builderID)] then
		mines[unitID] = builderID
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	mines[unitID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	mines[unitID] = nil
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if isStealthsTransport[unitDefID] then
		Spring.SetUnitStealth(transportID, true)
	end
end

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	if isStealthsTransport[unitDefID] then
		Spring.SetUnitStealth(transportID, false)
	end
end
