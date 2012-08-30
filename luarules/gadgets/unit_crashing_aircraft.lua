   function gadget:GetInfo()
      return {
        name      = "Crashing Aircraft",
        desc      = "Half of all aircraft destroyed and on the crash list crash instead of exploding",
        author    = "Beherith",
        date      = "aug 2012",
        license   = "PD",
        layer     = 1000,
        enabled   = true,
      }
    end
     
if (not gadgetHandler:IsSyncedCode()) then
  return
end
local GetUnitHealth 	= Spring.GetUnitHealth 
local random			= math.random 
local SetUnitCOBValue 	= Spring.SetUnitCOBValue
local SetUnitNoSelect	= Spring.SetUnitNoSelect

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, attackerID, attackerDefID, attackerTeam)
	if UnitDefs[unitDefID]["canFly"] == true and (damage>GetUnitHealth(unitID)) and random()>0.5 then
	--NOTE: strafe airmovetype aircraft DO NOT CRASH, only regular stuff like bombers
		--Spring.Echo('CRASHING AIRCRAFT')
		SetUnitCOBValue(unitID, COB.CRASHING, 1)
		Spring.SetUnitNoSelect(unitID,true) --cause setting to neutral still allows selection (wtf?)
	end
end

