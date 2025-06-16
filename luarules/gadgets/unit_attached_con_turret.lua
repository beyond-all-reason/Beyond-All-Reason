local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Attached Construction Turret',
		desc    = 'Attaches a builder to another mobile unit, so builder can repair while moving',
		author  = 'Itanthias',
		version = 'v1.1',
		date    = 'July 2023',
		license = 'GNU GPL, v2 or later',
		layer   = 12,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local CMD_REPAIR = CMD.REPAIR
local CMD_RECLAIM = CMD.RECLAIM
local CMD_STOP = CMD.STOP

local FEATURE_BASE_INDEX = Game.maxUnits
local FILTER_ALLY_UNITS = -3
local FILTER_ENEMY_UNITS = -4
local EMPTY = {}

--------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------

local baseToTurretDefID = {}
local repairableDefID = {}
local reclaimableDefID = {}
local unitDefRadiusMax = 0
local combatReclaimDefID = {}

local turretToBaseID = {}
local turretBuildRadius = {}

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

---Constructors with attached construction turrets must pass this check.
---Technically, it seems fine for the turret to have extra buildoptions.
local function matchBuildOptions(unitDef1, unitDef2)
	if #unitDef1.buildoptions == #unitDef2.buildoptions then
		for i, unitName in ipairs(unitDef1.buildoptions) do
			if not table.contains(unitDef2.buildoptions, unitName) then
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, "Build option missing.")
				return false
			elseif unitName ~= unitDef2.buildoptions[i] then
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, "Build option in different position.")
				return false
			end
		end
		return true
	end
	return false
end

local function attachToUnit(baseID, baseDefID, baseTeam)
	local turretDefID = baseToTurretDefID[baseDefID]
	local ux, uy, uz = Spring.GetUnitPosition(baseID)
	local facing = Spring.GetUnitBuildFacing(baseID)

	local turretID = Spring.CreateUnit(turretDefID, ux, uy, uz, facing, baseTeam)

	if turretID then
		Spring.UnitAttach(baseID, turretID, 3)
		Spring.SetUnitBlocking(turretID, false, false, false)
		Spring.SetUnitNoSelect(turretID, true)

		turretToBaseID[turretID] = baseID
		turretBuildRadius[turretID] = UnitDefs[turretDefID].buildDistance

		return true
	else
		Spring.DestroyUnit(baseID)
	end
end

local function updateTurretOrder(turretID, baseID)
	local teamID = Spring.GetUnitTeam(turretID)
	local ux, uy, uz = Spring.GetUnitPosition(turretID)
	local radius = turretBuildRadius[turretID]

	local command, _, _, param1, param2, param3, param4 = Spring.GetUnitCurrentCommand(baseID)

	if	not command
		or (command >= 0 and command ~= CMD_REPAIR and command ~= CMD_RECLAIM)
		or param4
		or not Spring.GiveOrderToUnit(turretID, command, { param1, param2, param3 }, EMPTY)
	then
		command, _, _, param1, param2, param3, param4 = Spring.GetUnitCurrentCommand(turretID)
	end

	if command and not param4 then
		if command < 0 then
			if radius >= Spring.GetUnitSeparation(turretID, -command, false, true) then
				return ux - param1, uz - param3
			end
		elseif command == CMD_REPAIR or command == CMD_RECLAIM then
			if param1 < FEATURE_BASE_INDEX then
				-- Targets leave LOS (mostly) or are blocked, so this is nillable:
				local separation = CallAsTeam(teamID, Spring.GetUnitSeparation, turretID, param1, false, true)

				if separation and radius >= separation then
					local cx, cy, cz = Spring.GetUnitPosition(param1)
					return ux - cx, uz - cz
				end
			else
				local featureID = param1 - FEATURE_BASE_INDEX
				local separation = CallAsTeam(teamID, Spring.GetUnitFeatureSeparation, turretID, featureID)

				if separation and radius >= separation - Spring.GetFeatureRadius(featureID) then
					local cx, cy, cz = Spring.GetFeaturePosition(featureID)
					return ux - cx, uz - cz
				end
			end
		end
	end

	local assistUnits = {}

	local alliedUnits = CallAsTeam(teamID, Spring.GetUnitsInCylinder, ux, uz, radius + unitDefRadiusMax, FILTER_ALLY_UNITS)

	for _, unitID in ipairs(alliedUnits) do
		if unitID ~= baseID and unitID ~= turretID and radius >= Spring.GetUnitSeparation(unitID, baseID, false, true) then
			local allyDefID = Spring.GetUnitDefID(unitID)

			-- This is coded for a combat engineer, so repair is prioritized over assist.
			if not Spring.GetUnitIsBeingBuilt(unitID) then
				if repairableDefID[allyDefID] then
					local health, maxHealth, _, _, buildProgress = Spring.GetUnitHealth(unitID)

					if buildProgress == 1 and health < maxHealth then
						Spring.GiveOrderToUnit(turretID, CMD_REPAIR, { unitID }, EMPTY)
						local cx, _, cz = Spring.GetUnitPosition(unitID)
						return ux - cx, uz - cz
					end
				end
			else
				assistUnits[#assistUnits+1] = unitID
			end
		end
	end

	local enemyUnits = CallAsTeam(teamID, Spring.GetUnitsInCylinder, ux, uz, radius + unitDefRadiusMax, FILTER_ENEMY_UNITS)

	for _, unitID in ipairs(enemyUnits) do
		if unitID ~= baseID and unitID ~= turretID and reclaimableDefID[Spring.GetUnitDefID(unitID)] then
			local separation = CallAsTeam(teamID, Spring.GetUnitSeparation, turretID, unitID, false, true)

			if separation and radius >= separation then
				Spring.GiveOrderToUnit(turretID, CMD_RECLAIM, { unitID }, EMPTY)
				local cx, _, cz = Spring.GetUnitPosition(unitID)
				return ux - cx, uz - cz
			end
		end
	end

	local features = Spring.GetFeaturesInCylinder(ux, uz, radius + unitDefRadiusMax)

	for _, featureID in ipairs(features) do
		if unitID ~= baseID and unitID ~= turretID and combatReclaimDefID[Spring.GetFeatureDefID(featureID)] then
			local separation = CallAsTeam(teamID, Spring.GetUnitFeatureSeparation, turretID, featureID)

			if separation and radius >= separation - Spring.GetFeatureRadius(featureID) then
				Spring.GiveOrderToUnit(turretID, CMD_RECLAIM, { featureID + FEATURE_BASE_INDEX }, EMPTY)
				local cx, _, cz = Spring.GetFeaturePosition(featureID)
				return ux - cx, uz - cz
			end
		end
	end

	for _, unitID in ipairs(assistUnits) do
		Spring.GiveOrderToUnit(turretID, CMD_REPAIR, { unitID }, EMPTY)
		local cx, _, cz = Spring.GetUnitPosition(unitID)
		return ux - cx, uz - cz
	end

	Spring.GiveOrderToUnit(turretID, CMD_STOP, EMPTY, EMPTY)
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:Initialize()
	for unitDefID, unitDef in pairs(UnitDefs) do
		-- See unit_attached_con_turret_mex.lua for metal extractors.
		if unitDef.customParams.attached_con_turret and not (unitDef.extractsMetal and unitDef.extractsMetal > 0) then
			local turretDef = UnitDefNames[unitDef.customParams.attached_con_turret]

			if turretDef then
				if not unitDef.buildOptions or (turretDef.buildOptions and matchBuildOptions(unitDef, turretDef)) then
					local turretDefID = turretDef.id
					baseToTurretDefID[unitDefID] = turretDefID
				else
					local message = "Unit and its attached con turret have different build lists: "
					Spring.Log(gadget:GetInfo().name, LOG.ERROR, message .. unitDef.name)
				end
			else
				local message = "Unit has an incorrect or missing attached con def:"
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, message .. unitDef.name)
			end
		end

		unitDefRadiusMax = math.max(unitDef.radius, unitDefRadiusMax)

		if unitDef.repairable then
			repairableDefID[unitDefID] = true
		end

		if unitDef.reclaimable then
			reclaimableDefID[unitDefID] = true
		end
	end

	if next(baseToTurretDefID) then
		-- Support `luarules /reload` by reacquiring attached cons.
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			local unitDefID = Spring.GetUnitDefID(unitID)

			if baseToTurretDefID[unitDefID] then
				local attachedIDs = Spring.GetUnitIsTransporting(unitID)

				if attachedIDs then
					for _, attachedID in ipairs(attachedIDs) do
						local attachedDefID = Spring.GetUnitDefID(attachedID)

						if attachedDefID == baseToTurretDefID[unitDefID] then
							turretToBaseID[attachedID] = unitID
							break
						end
					end
					-- The error state may be recoverable, so we reattempt; however,
					-- recall that `attachToUnit` will destroy the unit on a failure:
				elseif not attachToUnit(unitID, unitDefID, Spring.GetUnitTeam(unitID)) then
					local s = "Missing attached unit: %s @ %.1f, %.1f, %.1f"
					local e = s:format(UnitDefs[unitDefID].name, Spring.GetUnitPosition(unitID))
					Spring.Log(gadget:GetInfo().name, LOG.ERROR, e)
				end
			end
		end

		-- Feature auto-reclaim is "smart" so ignores resurrectable features.
		for featureDefID, featureDef in ipairs(FeatureDefs) do
			if featureDef.reclaimable and (featureDef.resurrectable == 0 or not featureDef.customParams.fromunit) then
				combatReclaimDefID[featureDefID] = true
			end
		end
	else
		gadgetHandler:RemoveGadget(self)
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if baseToTurretDefID[unitDefID] then
		attachToUnit(unitID, unitDefID, unitTeam)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	turretToBaseID[unitID] = nil
	turretBuildRadius[unitID] = nil
end

function gadget:GameFrame(gameFrame)
	if gameFrame % 15 == 0 then
		-- go on a slowupdate cycle
		for turretID, baseID in pairs(turretToBaseID) do
			local dx, dz = updateTurretOrder(turretID, baseID)

			if dx then
				local ux, uy, uz = Spring.GetUnitPosition(turretID)
				local headingNew = Spring.GetHeadingFromVector(ux - dx, uz - dz)
				local headingOld = Spring.GetUnitHeading(turretID) - 32768
				Spring.CallCOBScript(turretID, 'UpdateHeading', 0, headingNew - headingOld)
				return
			end
		end
	end
end
