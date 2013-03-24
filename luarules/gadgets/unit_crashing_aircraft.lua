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

local crashing = {}
local crashable  ={ --strafemovetype sometimes doesnt take the damage it is dealt. 
	[UnitDefNames["armthund"].id] = true,
	[UnitDefNames["armpeep"].id] = true,
	[UnitDefNames["armfig"].id] = true,
	[UnitDefNames["armcybr"].id] = true,
	[UnitDefNames["armawac"].id] = true,
	[UnitDefNames["armlance"].id] = true,
	[UnitDefNames["armhawk"].id] = true,
	[UnitDefNames["armpnix"].id] = true,
	[UnitDefNames["armsehak"].id] = true,
	[UnitDefNames["armsfig"].id] = true,
	[UnitDefNames["armseap"].id] = true,
	[UnitDefNames["armsb"].id] = true,
	[UnitDefNames["corgripn"].id] = true,
	[UnitDefNames["corawac"].id] = true,
	[UnitDefNames["cortitan"].id] = true,
	[UnitDefNames["corvamp"].id] = true,
	[UnitDefNames["corhurc"].id] = true,
	[UnitDefNames["corshad"].id] = true,
	[UnitDefNames["corfink"].id] = true,
	[UnitDefNames["corveng"].id] = true,
	[UnitDefNames["corhunt"].id] = true,
	[UnitDefNames["corseap"].id] = true,
	[UnitDefNames["corsfig"].id] = true,
	[UnitDefNames["corsb"].id] = true,
}
function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if paralyzer then return damage,1 end --OOPS FORGOT THIS
	if crashing[unitID] then 
		return 0,0
	end --hacky
	if UnitDefs[unitDefID]["canFly"] == true and (damage>GetUnitHealth(unitID)) and random()<0.25 then
	--NOTE: strafe airmovetype aircraft crash since 92. only
		SetUnitCOBValue(unitID, COB.CRASHING, 1)
		SetUnitNoSelect(unitID,true) --cause setting to neutral still allows selection (wtf?)
		crashing[unitID]=true
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