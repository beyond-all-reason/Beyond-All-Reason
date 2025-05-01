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
local legmohoconDefIDScav = UnitDefNames["legmohocon_scav"] and UnitDefNames["legmohocon_scav"].id
local legmohoconctDefIDScav = UnitDefNames["legmohoconct_scav"] and UnitDefNames["legmohoconct_scav"].id
local mexesToSwap = {}

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitDefID ~= legmohoconDefID and unitDefID ~= legmohoconDefIDScav then
        return
    end

	mexesToSwap[unitID] = {unitDefID = unitDefID, unitTeam = unitTeam, frame = Spring.GetGameFrame() + 1}
end

local function swapMex(unitID, unitDefID, unitTeam)
	local scav = ""
	if UnitDefs[unitDefID].customParams.isscavenger or unitTeam == Spring.Utilities.GetScavTeamID() then scav = "_scav" end
	--Spring.Echo("isScav", UnitDefs[unitDefID].customParams.isscavenger, scav)
	local xx,yy,zz = Spring.GetUnitPosition(unitID)
	local facing = Spring.GetUnitBuildFacing(unitID)
	local buildTime, metalCost, energyCost = Spring.GetUnitCosts(unitID)
	local health = Spring.GetUnitHealth(unitID)																-- saves location, rotation, cost and health of mex
	local original = Spring.GetUnitNearestAlly(unitID)
	if original then
		local orgbuildTime, orgmetalCost, orgenergyCost = Spring.GetUnitCosts(original)							-- gets metal cost of thing you are building over
		local imex_id = Spring.CreateUnit("legmohoconin" .. scav,xx,yy,zz,facing,Spring.GetUnitTeam(unitID) )			-- creates imex on where mex was
		--Spring.Echo(unitID, original, orgmetalCost)
		if not Spring.GetUnitIsDead(unitID) then																-- if you build this over something then it doesnt remove mex, this removes and reclaims it
			Spring.DestroyUnit(unitID, false, true)
			Spring.AddTeamResource(unitTeam, "metal", metalCost)
			Spring.UseTeamResource(unitTeam, "metal", orgmetalCost)												-- for some reason the unit you build it over gets reclaimed twice, this removes the excess
		end
		Spring.UseTeamResource(unitTeam, "metal", metalCost)												-- creating imex reclaims mex, this removes the metal that would give. DestroyUnit doesnt prevent the reclaim
		if not imex_id then																					-- check incase the imex fails to spawn, removes and refunds the unit
			Spring.DestroyUnit(unitID, false, true)
			Spring.AddTeamResource(unitTeam, "metal", metalCost)
			Spring.AddTeamResource(unitTeam, "energy", energyCost)
			return
		end
		Spring.SetUnitBlocking(imex_id, true, true, false)													-- makes imex non interactive
		Spring.SetUnitNoSelect(imex_id,true)
		local nano_id = Spring.CreateUnit("legmohoconct" .. scav,xx,yy,zz,facing,Spring.GetUnitTeam(imex_id) )		-- creates con on imex
		--Spring.Echo('nano_id', nano_id)
		if not nano_id then																							-- check incase the con fails to spawn, removes and refunds the unit
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

		mexesToSwap[unitID] = nil
	end
end

function gadget:GameFrame(frame)
	for unitID, unitData in pairs(mexesToSwap) do
		if frame > unitData.frame then
			swapMex(unitID, unitData.unitDefID, unitData.unitTeam)
		end
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if unitDefID ~= legmohoconctDefID and unitDefID ~= legmohoconctDefIDScav then 
        return 
    end
	Spring.TransferUnit(Spring.GetUnitTransporter(unitID), newTeam)
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)

	if unitDefID ~= legmohoconctDefID and unitDefID ~= legmohoconctDefIDScav then
        return
    end
	local health,maxHealth = Spring.GetUnitHealth(unitID)
	if health-damage < 0 then																		-- when damaged and killed
		local xx,yy,zz = Spring.GetUnitPosition(unitID)
		local facing = Spring.GetUnitBuildFacing(unitID)
		local scav = ""
		if UnitDefs[unitDefID].customParams.isscavenger or unitTeam == Spring.Utilities.GetScavTeamID() then scav = "_scav" end
		
		if damage < (maxHealth / 4) then
			--Spring.Echo("Legmohocon feature created")															-- if damage is <25% of max health spawn wreck
			local featureID = Spring.CreateFeature("legmohocon" .. scav .. "_dead" , xx, yy, zz, facing, unitTeam)
			Spring.SetFeatureResurrect(featureID, "legmohocon" .. scav, facing, 0)
		end
		if damage > (maxHealth / 4) and damage < (maxHealth / 2) then								-- if damage is >25% and <50% of max health spawn heap
			Spring.CreateFeature("legmohocon_heap", xx, yy, zz, facing, unitTeam)
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)		-- if con dies remove imex
	
	if unitDefID ~= legmohoconctDefID and unitDefID ~= legmohoconctDefIDScav then 
        return 
    end
	if Spring.GetUnitTransporter(unitID) then
		Spring.DestroyUnit(Spring.GetUnitTransporter(unitID), false, true)
	end
	for destroyedUnitID, destroyedUnitData in pairs(mexesToSwap) do
		if unitID == destroyedUnitID then
			mexesToSwap[destroyedUnitID] = nil
		end
	end
end
