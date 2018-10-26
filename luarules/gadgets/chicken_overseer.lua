--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Chicken Overseer",
    desc      = "Chicken Overseer",
    author    = "TheFatController",
    date      = "Sep 01, 2013",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
  }
end

local teams = Spring.GetTeamList()
for i =1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 9) == 'Chicken: ' then
		chickensEnabled = true
	end
end

if chickensEnabled == true then
	Spring.Echo("[ChickenDefense: Chicken Overseer] Activated!")
else
	Spring.Echo("[ChickenDefense: Chicken Overseer] Deactivated!")
	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return false
end

local OVERSEER = UnitDefNames["chickenh5"].id
local RAGE_BLOB = WeaponDefNames['chickenh5_controlblob'].id
local controlled = {}
local controllers = {}

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
  if (weaponID == RAGE_BLOB) and (attackerID) and (not controllers[attackerID]) and (attackerTeam) and (unitTeam) and (not Spring.AreTeamsAllied(attackerTeam,unitTeam)) then
	controllers[attackerID] = Spring.GetGameFrame() + 210
	local x,_,z = Spring.GetUnitPosition(unitID)
	if (x and z) then
		local nearchicks = Spring.GetUnitsInCylinder(x,z,390,attackerTeam)
		for i=1, #nearchicks, 1 do
			if (nearchicks[i] ~= attackerID) then
				Spring.GiveOrderToUnit(nearchicks[i], CMD.ATTACK, {unitID}, {})
				controlled[nearchicks[i]] = attackerID
			end
		end
		local x,_,z = Spring.GetUnitPosition(attackerID)
		if (x and z) then
			local nearchicks = Spring.GetUnitsInCylinder(x,z,620,attackerTeam)
			for i=1, #nearchicks, 1 do
				if (nearchicks[i] ~= attackerID) then
					Spring.GiveOrderToUnit(nearchicks[i], CMD.ATTACK, {unitID}, {})
					controlled[nearchicks[i]] = attackerID
				end
			end
		end
	end
  end
  return damage,1
end

function gadget:GameFrame(n)
	for id,t in pairs(controllers) do
		if (n > t) then
			controlled[id] = nil
			controllers[id] = nil
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if (controllers[unitID]) then
		for id,c in pairs(controlled) do
			if (c == unitID) and Spring.ValidUnitID(id) then
				Spring.GiveOrderToUnit(id, CMD.STOP, {}, {})
			end
		end
		controllers[unitID] = nil
	end
	controlled[unitID] = nil
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------