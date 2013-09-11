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
local SetUnitCosts		= Spring.SetUnitCosts
local SetUnitSensorRadius = Spring.SetUnitSensorRadius

local COB_CRASHING = COB.CRASHING

local crashing = {}
local crashable  = {}

function gadget:Initialize()
	--set up table to check against
	for _,UnitDef in pairs(UnitDefs) do
		if UnitDef.canFly == true then
			crashable[UnitDef.id] = true
		end
	end

end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if paralyzer then return damage,1 end 
	if crashing[unitID] then 
		return 0,0
	end --hacky
	if crashable[unitDefID] and (damage>GetUnitHealth(unitID)) and random()<0.25 then
		crashing[unitID] = true
		SetUnitCOBValue(unitID, COB_CRASHING, 1)
		SetUnitNoSelect(unitID,true) --cause setting to neutral still allows selection (wtf?)
		
		SetUnitSensorRadius(unitID, "los", 0)
		SetUnitSensorRadius(unitID, "radar", 0)
		SetUnitSensorRadius(unitID, "sonar", 0)
	end
	return damage,1
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if crashing[unitID] then
		--Spring.Echo('CRASHING AIRCRAFT UNITDESTROYED CALLED!',unitID)
		crashing[unitID]=nil
	end
end