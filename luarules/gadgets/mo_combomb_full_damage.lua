--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "mo_combomb_full_damage",
    desc      = "Flying Combombs Can Do Less Damage",
    author    = "TheFatController",
    date      = "Sept 06, 2010",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return false
end

local enabled = tonumber(Spring.GetModOptions().mo_combomb_full_damage) or 1

if (enabled == 1) then 
  return false
end

local COM_BLAST = WeaponDefNames['commander_blast'].id
local COMMANDER = {
  [UnitDefNames["corcom"].id] = true,
  [UnitDefNames["armcom"].id] = true,
}

local FAILBOMB = {}

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	FAILBOMB[unitID] = nil
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
  if COMMANDER[unitDefID] then
    local x,y,z = Spring.GetUnitBasePosition(unitID)
	local h = Spring.GetGroundHeight(x,z)
	if ((y-h) > 15) then
		FAILBOMB[unitID] = true
	end
  end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, 
                            weaponID, attackerID, attackerDefID, attackerTeam)
  if (weaponID == COM_BLAST) and FAILBOMB[attackerID] and (attackerID ~= unitID) then
    local x,y,z = Spring.GetUnitBasePosition(unitID)
	local h = Spring.GetGroundHeight(x,z)
	if ((y-h) < 10) then
      local _,hp = Spring.GetUnitHealth(unitID)
      local newdamage = math.min(damage,math.max(hp*0.6,400))
      return newdamage,0
	end
  end
  return damage,1
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------