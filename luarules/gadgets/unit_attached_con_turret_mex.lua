function gadget:GetInfo()
    return {
        name      = 'Legion Con Turret Metal Extractor',
        desc      = 'Allows the mex to function as a con turret by replacing it with a fake mex with a con turret attached',
        author    = 'EnderRobo',
        version   = 'v1',
        date      = 'September 2024',
        license   = 'GNU GPL, v2 or later',
        layer     = 12,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local legmohoconDefID = UnitDefNames["legmohocon"] and UnitDefNames["legmohocon"].id
local legmohoconctDefID = UnitDefNames["legmohoconct"] and UnitDefNames["legmohoconct"].id

function gadget:UnitFinished(unitID, unitDefID, unitTeam)

	if unitDefID ~= legmohoconDefID  then 
        return 
    end
	local xx,yy,zz = Spring.GetUnitPosition(unitID)
	local facing = Spring.GetUnitBuildFacing(unitID)
	local buildTime, metalCost, energyCost = Spring.GetUnitCosts(unitID)
	local health = Spring.GetUnitHealth(unitID)																-- saves location, rotation, cost and health of mex
	local imex_id = Spring.CreateUnit("legmohoconin",xx,yy,zz,facing,Spring.GetUnitTeam(unitID) )			-- creates imex on where mex was
	Spring.UseTeamResource(unitTeam, "metal", metalCost)												-- creating imex reclaims mex, this removes the metal that would give. DestroyUnit doesnt prevent the reclaim
	if not imex_id then
		Spring.DestroyUnit(unitID, false, true)
		Spring.AddTeamResource(unitTeam, "metal", metalCost)
		Spring.AddTeamResource(unitTeam, "energy", energyCost)
		return
	end
	Spring.SetUnitBlocking(imex_id, true, true, false)													-- makes imex non interactive
	Spring.SetUnitNoSelect(imex_id,true)
	local nano_id = Spring.CreateUnit("legmohoconct",xx,yy,zz,facing,Spring.GetUnitTeam(imex_id) )		-- creates con on imex
	if not nano_id then
		Spring.DestroyUnit(unitID, false, true)
		Spring.DestroyUnit(imex_id, false, true)
		Spring.AddTeamResource(unitTeam, "metal", metalCost)
		Spring.AddTeamResource(unitTeam, "energy", energyCost)
		return
	end
	Spring.UnitAttach(imex_id,nano_id,6)																-- attaches con to imex
	Spring.SetUnitHealth(nano_id, health)																-- sets con health to be the same as mex
	local extractMetal = Spring.GetUnitMetalExtraction(unitID)											-- moves the metal extraction from imex to turret.
	Spring.SetUnitResourcing(nano_id, "umm", extractMetal)
	Spring.SetUnitResourcing(imex_id, "umm", (-extractMetal))
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if unitDefID ~= legmohoconctDefID  then 
        return 
    end
	Spring.TransferUnit(Spring.GetUnitTransporter(unitID), newTeam)
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)

	if unitDefID ~= legmohoconctDefID  then 
        return 
    end
	local health,maxHealth = Spring.GetUnitHealth(unitID)
	if not (health > 0) then																		-- when damaged and killed
	local xx,yy,zz = Spring.GetUnitPosition(unitID)
	local facing = Spring.GetUnitBuildFacing(unitID)
		if damage < (maxHealth / 4) then															-- if damage is <25% of max health spawn wreck
			local featureID = Spring.CreateFeature("legmohocon_dead", xx, yy, zz, facing, unitTeam)
			Spring.SetFeatureResurrect(featureID, "legmohocon", facing, 0)
		end
		if damage > (maxHealth / 4) and damage < (maxHealth / 2) then								-- if damage is >25% and <50% of max health spawn heap
			Spring.CreateFeature("legmohocon_heap", xx, yy, zz, facing, unitTeam)
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)		-- if con dies remove imex
	
if unitDefID ~= legmohoconctDefID  then 
        return 
    end
	Spring.DestroyUnit(Spring.GetUnitTransporter(unitID), false, true)
end