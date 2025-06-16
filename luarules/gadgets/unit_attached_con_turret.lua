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
	local ux, uy, uz = Spring.GetUnitPosition(turretID)
	local dx, dy, dz

	local command, _, _, param1, param2, param3, param4 = Spring.GetUnitCurrentCommand(baseID)

	if	not command
		or (command >= 0 and command ~= CMD_REPAIR and command ~= CMD_RECLAIM)
		or param4
		or not Spring.GiveOrderToUnit(turretID, command, { param1, param2, param3 }, EMPTY)
	then
		command, _, _, param1, param2, param3, param4 = Spring.GetUnitCurrentCommand(turretID)
	end

	if command and not param4 then
		local radius = turretBuildRadius[turretID]

		if command < 0 then
			if radius >= Spring.GetUnitSeparation(turretID, -command, false, true) then
				dx, dz = ux - param1, uz - param3
			end
		elseif command == CMD_REPAIR or command == CMD_RECLAIM then
			local teamID = Spring.GetUnitTeam(turretID)

			if param1 < FEATURE_BASE_INDEX then
				-- Targets leave LOS (mostly) or are blocked, so this is nillable:
				local separation = CallAsTeam(teamID, Spring.GetUnitSeparation, turretID, param1, false, true)

				if separation and radius >= separation then
					local cx, cy, cz = Spring.GetUnitPosition(param1)
					dx, dz = ux - cx, uz - cz
				end
			else
				local featureID = param1 - FEATURE_BASE_INDEX
				local separation = CallAsTeam(teamID, Spring.GetUnitFeatureSeparation, turretID, featureID)

				if separation and radius >= separation - Spring.GetFeatureRadius(featureID) then
					local cx, cy, cz = Spring.GetFeaturePosition(featureID)
					dx, dz = ux - cx, uz - cz
				end
			end
		end
	end

	if dx then
		--let auto con turret continue its thing
		--update heading, by calling into unit script
		local heading1 = Spring.GetHeadingFromVector(ux - dx, uz - dz)
		local heading2 = Spring.GetUnitHeading(turretID)
		Spring.CallCOBScript(turretID, 'UpdateHeading', 0, heading1 - heading2 + 32768)
		return
	end

	-- next, check to see if valid repair/reclaim targets in range
	local nearUnits = Spring.GetUnitsInCylinder(ux, uz, radius + unitDefRadiusMax)

	for _, nearID in pairs(nearUnits) do
		-- check for free repairs
		local nearDefID = Spring.GetUnitDefID(nearID)
		if Spring.GetUnitAllyTeam(nearID) == Spring.GetUnitAllyTeam(turretID) then
			if ((Spring.GetUnitSeparation(nearID, turretID, true) - Spring.GetUnitRadius(nearID)) < radius) then
				local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth(nearID)
				if buildProgress == 1 and health < maxHealth and UnitDefs[nearDefID].repairable and nearID ~= turretToBaseID[turretID] then
					Spring.GiveOrderToUnit(turretID, CMD_REPAIR, { nearID }, {})
					return
				end
			end
		end
	end

	for _, nearID in pairs(nearUnits) do
		-- check for enemy to reclaim
		local nearDefID = Spring.GetUnitDefID(nearID)
		if Spring.GetUnitAllyTeam(nearID) ~= Spring.GetUnitAllyTeam(turretID) then
			if ((Spring.GetUnitSeparation(nearID, turretID, true) - Spring.GetUnitRadius(nearID)) < radius) then
				if UnitDefs[nearDefID].reclaimable then
					Spring.GiveOrderToUnit(turretID, CMD_RECLAIM, { nearID }, {})
					return
				end
			end
		end
	end

	local nearFeatures = Spring.GetFeaturesInCylinder(ux, uz, radius + unitDefRadiusMax)

	for _, nearID in pairs(nearFeatures) do
		-- check for non resurrectable feature to reclaim
		local nearDefID = Spring.GetFeatureDefID(nearID)
		if ((Spring.GetUnitFeatureSeparation(turretID, nearID, true) - Spring.GetFeatureRadius(nearID)) < radius) then
			if FeatureDefs[nearDefID].reclaimable and Spring.GetFeatureResurrect(nearID) == "" then
				Spring.GiveOrderToUnit(turretID, CMD_RECLAIM, { nearID + Game.maxUnits }, {})
				return
			end
		end
	end

	for _, nearID in pairs(nearUnits) do
		-- check for nanoframe to build
		if Spring.GetUnitAllyTeam(nearID) == Spring.GetUnitAllyTeam(turretID) then
			if ((Spring.GetUnitSeparation(nearID, turretID, true) - Spring.GetUnitRadius(nearID)) < radius) then
				if Spring.GetUnitIsBeingBuilt(nearID) then
					Spring.GiveOrderToUnit(turretID, CMD_REPAIR, { nearID }, {})
					return
				end
			end
		end
	end

	-- give stop command to attached con turret if nothing to do
	Spring.GiveOrderToUnit(turretID, CMD_STOP, {}, {})
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
			updateTurretOrder(turretID, baseID)
		end
	end
end
