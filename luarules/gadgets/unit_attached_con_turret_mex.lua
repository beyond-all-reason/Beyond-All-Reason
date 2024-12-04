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

local SpGetUnitPosition = Spring.GetUnitPosition
local SpGetUnitDefID = Spring.GetUnitDefID
local SpGetUnitAllyTeam = Spring.GetUnitAllyTeam
local SpGetUnitHealth = Spring.GetUnitHealth
local SpGetUnitBuildFacing = Spring.GetUnitBuildFacing
local SpGetUnitIsDead = Spring.GetUnitIsDead
local SpGetUnitStates = Spring.GetUnitStates

function gadget:UnitFinished(unitID, unitDefID, unitTeam)

	local unitDef = UnitDefs[unitDefID]
	if unitDef.name == "legmohocon" then																-- checks for mex
		local nano_id
		local imex_id
		local health
		local facing
		local xx,yy,zz
		xx,yy,zz = SpGetUnitPosition(unitID)
		facing = SpGetUnitBuildFacing(unitID)
		health = SpGetUnitHealth(unitID)																-- saves location, rotation and health of mex
		imex_id = Spring.CreateUnit("legmohoconin",xx,yy,zz,facing,Spring.GetUnitTeam(unitID) )			-- creates imex on mex
		if not imex_id then
			return
		end
		Spring.SetUnitBlocking(imex_id, true, false, false)												-- makes imex non interactive
		Spring.SetUnitNoSelect(imex_id,true)
		nano_id = Spring.CreateUnit("legmohoconct",xx,yy,zz,facing,Spring.GetUnitTeam(imex_id) )		-- creates con on imex
		if not nano_id then
			return
		end
		Spring.UnitAttach(imex_id,nano_id,6)															-- attaches con to imex
		Spring.SetUnitHealth(nano_id, health)															-- sets con health to be the same as mex
		Spring.DestroyUnit(unitID, false, true)															-- removes mex
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	local unitDef = UnitDefs[unitDefID]
	if unitDef.name == "legmohoconct" then
		Spring.TransferUnit(Spring.GetUnitTransporter(unitID), newTeam)
	end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)

	local unitDef = UnitDefs[unitDefID]
	if unitDef.name == "legmohoconct" then
		local health
		local maxHealth
		health, maxHealth = SpGetUnitHealth(unitID)
		if not (health > 0) then																		-- when damaged and killed
		local xx,yy,zz
		local facing
		xx,yy,zz = SpGetUnitPosition(unitID)
		facing = SpGetUnitBuildFacing(unitID)
			if damage < (maxHealth / 3) then															-- if damage is <33% of max health spawn wreck
				local featureID
				featureID = Spring.CreateFeature("legmohocon_dead", xx, yy, zz, facing, unitTeam)
				Spring.SetFeatureResurrect(featureID, "legmohocon", facing, 0)
			end
			if damage > (maxHealth / 3) and damage < ((maxHealth / 3) * 2) then							-- if damage is >33% and <66% of max health spawn heap
				Spring.CreateFeature("legmohocon_heap", xx, yy, zz, facing, unitTeam)
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)		-- if con dies remove imex
	
	local unitDef = UnitDefs[unitDefID]
	if unitDef.name == "legmohoconct" then
		Spring.DestroyUnit(Spring.GetUnitTransporter(unitID), false, true)
	end
end
	


--[[
mex built							done
place imex on mex					done
attach con turret to imex			done
copy mex health to con Turret		done
remove mex							done
on turret death remove imex			done
make it spawn wrecks and heaps		done

To do:
if damaged during construction cons continue to repair 
on off switch for mex via turret
make turret display metal income and energy upkeep of mex