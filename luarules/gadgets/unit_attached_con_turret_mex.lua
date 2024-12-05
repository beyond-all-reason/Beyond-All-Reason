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
		local bt,mc,ec
		local em
		xx,yy,zz = SpGetUnitPosition(unitID)
		facing = SpGetUnitBuildFacing(unitID)
		bt,mc,ec = Spring.GetUnitCosts(unitID)
		health = SpGetUnitHealth(unitID)																-- saves location, rotation, cost and health of mex
		Spring.DestroyUnit(unitID, false, true)															-- removes mex
		imex_id = Spring.CreateUnit("legmohoconin",xx,yy,zz,facing,Spring.GetUnitTeam(unitID) )			-- creates imex on where mex was
		Spring.UseTeamResource(unitTeam, "metal", mc)													-- creating imex reclaims mex, even though there is the destroy command before it. this removes the metal that would give.
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
		em = Spring.GetUnitMetalExtraction(unitID)
		Spring.SetUnitResourcing(nano_id, "umm", em)
		Spring.SetUnitResourcing(imex_id, "umm", (-em))
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


if health < max health
check for nearby builders
check if any nearby builders were building this unit
give command to those builders to repair new unit to front of queue

--[[		while( true )
		do
			local firestate, movestate, repeata, cloak, active = SpGetUnitStates(nano_id)
			if active =/= activeold
			do
				Spring.GiveOrderToUnit(imex_id, onoff)
			end
			Sleep(5000)
		end]]--
		
		
--Spring.GetUnitMetalExtraction(unitID)
--Spring.SetUnitResourcing(unitID, c, m, m, 80)
--[[
Spring.SetUnitResourcing(unitID, res, amount)
Parameters:

    "unitID" number
    "res" {[string]=number,...} keys are: "[u|c][u|m][m|e]" unconditional | conditional, use | make, metal | energy. Values are amounts
    "amount" number
	
]]--