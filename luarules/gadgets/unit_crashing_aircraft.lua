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
local crashing={}

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, attackerID, attackerDefID, attackerTeam)
	if UnitDefs[unitDefID]["canFly"] == true and (damage>GetUnitHealth(unitID)) and random()>0.5 then
	--NOTE: strafe airmovetype aircraft DO NOT CRASH, only regular stuff like bombers
		--Spring.Echo('CRASHING AIRCRAFT',unitID)
		SetUnitCOBValue(unitID, COB.CRASHING, 1)
		--SetUnitCosts(unitID,{10000,0,0}) this doesnt work either :)
		SetUnitNoSelect(unitID,true) --cause setting to neutral still allows selection (wtf?)
		crashing[unitID]=true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if crashing[unitID] then
		--Spring.Echo('CRASHING AIRCRAFT UNITDESTROYED CALLED!',unitID)
		crashing[unitID]=nil
	end
end

function gadget:AllowUnitBuildStep(builderID, builderTeamID, uID, uDefID, step) --THIS IS VERY HACKY AND BAD FOR PERFORMACE!
	--Spring.Echo('AllowUnitBuildStep',uID,step)
	if step<0 and crashing[uID] then
		--Spring.Echo('AllowUnitBuildStep ON CRASHING!')
		return false
	end
	return true
end
function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, attackerID, attackerDefID, attackerTeam)
	if crashing[unitID] then return false --hacky
	return true
end