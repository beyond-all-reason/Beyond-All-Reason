local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = 'Legion Con Turret Metal Extractor',
        desc      = 'Allows the mex to function as a con turret by replacing it with a fake mex with a con turret attached',
        author    = 'EnderRobo',
        version   = 'v1',
        date      = 'September 2024',
        license   = 'GNU GPL, v2 or later',
        layer     = 12, -- after unit_mex_upgrade_reclaimer
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local extractorToActualDefID = {}
local extractorToBackupDefID = {}
local extractorToTurretDefID = {}
local extractorPieceNumber = {}

local mexesToSwap = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	-- See unit_attached_con_turret for non-extractor attached turrets.
	if unitDef.extractsMetal and unitDef.extractsMetal > 0 and unitDef.customParams.attached_con_turret then
		-- The def used as a build option is a combination of both mex + con models.
		local actualDef = UnitDefNames[unitDef.customParams.attached_actual_mex]
		local turretDef = UnitDefNames[unitDef.customParams.attached_con_turret]
		local pieceNumber = tonumber(unitDef.customParams.attached_piece_number)

		-- When the two defs fail to spawn or attach, their IDs are forced free.
		-- Then, given that we have guaranteed +1 unit capacity, spawn the backup.
		local backupDef = UnitDefNames[unitDef.customParams.attached_backup_def]

		if not actualDef then
			local e = ("Extractor missing its finished unit def: %s"):format(unitDef.name)
			Spring.Log(gadget:GetInfo().name, LOG.ERROR, e)
		end

		if not turretDef then
			local e = ("Extractor missing its attached unit def: %s"):format(unitDef.name)
			Spring.Log(gadget:GetInfo().name, LOG.ERROR, e)
		end

		if not pieceNumber then
			local e = ("Extractor missing its attachment piece index: %s"):format(unitDef.name)
			Spring.Log(gadget:GetInfo().name, LOG.ERROR, e)
		end

		if actualDef and turretDef and pieceNumber then
			extractorToActualDefID[unitDefID] = actualDef.id
			extractorToBackupDefID[unitDefID] = backupDef.id
			extractorToTurretDefID[unitDefID] = turretDef.id
			extractorPieceNumber[unitDefID] = pieceNumber
		end
	end
end

local function swapMex(unitID, unitDefID, unitTeam)
	local scav = ""
	if UnitDefs[unitDefID].customParams.isscavenger or unitTeam == Spring.Utilities.GetScavTeamID() then scav = "_scav" end
	local xx, yy, zz = Spring.GetUnitPosition(unitID)
	local facing = Spring.GetUnitBuildFacing(unitID)
	local buildTime, metalCost, energyCost = Spring.GetUnitCosts(unitID)
	local health = Spring.GetUnitHealth(unitID)
	local original = Spring.GetUnitNearestAlly(unitID, 8)
	local orgExtractMetal = 0

	if original then
		local orgbuildTime, orgmetalCost, orgenergyCost = Spring.GetUnitCosts(original)
		local mexInertID = Spring.CreateUnit("legmohoconin" .. scav, xx, yy, zz, facing, Spring.GetUnitTeam(unitID))

		if not Spring.GetUnitIsDead(unitID) then
			Spring.DestroyUnit(unitID, false, true)
			Spring.AddTeamResource(unitTeam, "metal", metalCost)
			Spring.UseTeamResource(unitTeam, "metal", orgmetalCost)
			orgExtractMetal = Spring.GetUnitMetalExtraction(original)
		end

		Spring.UseTeamResource(unitTeam, "metal", metalCost)

		if not mexInertID then
			Spring.DestroyUnit(unitID, false, true)
			Spring.AddTeamResource(unitTeam, "metal", metalCost)
			Spring.AddTeamResource(unitTeam, "energy", energyCost)
			return
		end

		Spring.SetUnitBlocking(mexInertID, true, true, false)
		Spring.SetUnitNoSelect(mexInertID, true)
		local nano_id = Spring.CreateUnit("legmohoconct" .. scav, xx, yy, zz, facing, Spring.GetUnitTeam(mexInertID))

		if not nano_id then
			Spring.DestroyUnit(unitID, false, true)
			Spring.DestroyUnit(mexInertID, false, true)
			Spring.AddTeamResource(unitTeam, "metal", metalCost)
			Spring.AddTeamResource(unitTeam, "energy", energyCost)
			return
		end

		local extractMetal = Spring.GetUnitMetalExtraction(unitID)
		Spring.UnitAttach(mexInertID, nano_id, 6)
		Spring.SetUnitHealth(nano_id, health)
		Spring.SetUnitStealth(nano_id, true)
		Spring.SetUnitResourcing(nano_id, "umm", (extractMetal + orgExtractMetal))
		Spring.SetUnitResourcing(mexInertID, "umm", (-extractMetal - orgExtractMetal))

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

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitDefID ~= legmohoconDefID and unitDefID ~= legmohoconDefIDScav then
        return
    end

	mexesToSwap[unitID] = {unitDefID = unitDefID, unitTeam = unitTeam, frame = Spring.GetGameFrame() + 1}
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if unitDefID ~= legmohoconctDefID and unitDefID ~= legmohoconctDefIDScav then 
        return 
    end
	Spring.TransferUnit(Spring.GetUnitTransporter(unitID), newTeam)
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
