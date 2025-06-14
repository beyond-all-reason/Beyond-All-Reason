local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = 'Attached Construction Turret',
        desc      = 'Attaches a builder to another mobile unit, so builder can repair while moving',
        author    = 'Itanthias',
        version   = 'v1.1',
        date      = 'July 2023',
        license   = 'GNU GPL, v2 or later',
        layer     = 12,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeatureRadius = Spring.GetFeatureRadius
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetFeaturesInCylinder = Spring.GetFeaturesInCylinder
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitFeatureSeparation = Spring.GetUnitFeatureSeparation
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitSeparation = Spring.GetUnitSeparation
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitTeam = Spring.GetUnitTeam
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local CallAsTeam = CallAsTeam

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
local combatReclaimDefID = {}
local unitDefRadiusMax = 0

local turretToBaseID = {}
local turretBuildRadius = {}
local turretOrderPending = {}
local transportedUnits = {}

---Constructors with attached construction turrets must pass this check.
---Technically, it seems fine for the turret to have extra buildoptions.
local function checkSameBuildOptions(unitDef1, unitDef2)
	if #unitDef1.buildOptions == #unitDef2.buildOptions then
		for i, unitName in ipairs(unitDef1.buildOptions) do
			if not table.contains(unitDef2.buildOptions, unitName) then
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, "Build option missing.")
				return false
			elseif unitName ~= unitDef2.buildOptions[i] then
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, "Build option in different position.")
				return false
			end
		end
		return true
	end
	return false
end

local function updateTurretHeading(turretID, dx, dz, baseID)
	local headingCurrent = Spring.GetUnitHeading(turretID)
	local headingNew = Spring.GetHeadingFromVector(dx, dz) - 32768
	Spring.CallCOBScript(turretID, "UpdateHeading", 0, headingNew - headingCurrent)
end

---Share the ongoing command from the base unit to the turret, if possible to do so.
---If the turret cannot act on that command immediately, it may pursue another task.
---@param turretID integer
---@param baseID integer
---@param baseX number
---@param baseZ number
---@param radius number
---@return number? dx for new turret heading
---@return number? dz for new turret heading
local function giveSameOrderToTurret(turretID, baseID, baseX, baseZ, radius)
	local command, _, _, param1, param2, param3, param4 = spGetUnitCurrentCommand(baseID)

	if	not command
		or (command >= 0 and command ~= CMD_REPAIR and command ~= CMD_RECLAIM)
		or param4
		or not spGiveOrderToUnit(turretID, command, { param1, param2, param3 }, EMPTY)
	then
		command, _, _, param1, param2, param3, param4 = spGetUnitCurrentCommand(turretID)
	end

	if command and not param4 then
		if command < 0 then
			if radius >= spGetUnitSeparation(turretID, -command, false, true) then
				return baseX - param1, baseZ - param3
			end
		elseif command == CMD_REPAIR or command == CMD_RECLAIM then
			if param1 < FEATURE_BASE_INDEX then
				-- Targets go out of sight (mostly) or are blocked, so this is nillable:
				local separation = spGetUnitSeparation(turretID, param1, false, true)

				if separation and radius >= separation then
					local cx, cy, cz = spGetUnitPosition(param1)
					return baseX - cx, baseZ - cz
				end
			else
				local featureID = param1 - FEATURE_BASE_INDEX
				local separation = spGetUnitFeatureSeparation(turretID, featureID)

				if separation and radius >= separation - spGetFeatureRadius(featureID) then
					local cx, cy, cz = spGetFeaturePosition(featureID)
					return baseX - cx, baseZ - cz
				end
			end
		end
	end
end

---Performs a search for the first executable automatic/smart behavior, in priority order:
---(1) repair ally (2) reclaim enemy (3) reclaim non-ressurectable feature (4) build-assist allied unit.
---@param turretID integer
---@param baseID integer
---@param baseX number
---@param baseZ number
---@param radius number
---@return number? dx for new turret heading
---@return number? dz for new turret heading
local function giveAutoOrderToTurret(turretID, baseID, baseX, baseZ, radius, forbidden)
	local unitTeamID = spGetUnitTeam(baseID) ---@type integer -- todo
	local assistUnits = {}

	local alliedUnits = CallAsTeam(unitTeamID, spGetUnitsInCylinder, baseX, baseZ, radius + unitDefRadiusMax, FILTER_ALLY_UNITS)

	for _, unitID in ipairs(alliedUnits) do
		if not forbidden[unitID] and radius >= spGetUnitSeparation(unitID, baseID, false, true) then
			local allyDefID = spGetUnitDefID(unitID)

			-- This is designed for combat, so repair is prioritized over assist.
			if not spGetUnitIsBeingBuilt(unitID) then
				if repairableDefID[allyDefID] then
					local health, maxHealth, _, _, buildProgress = spGetUnitHealth(unitID)

					if buildProgress == 1 and health < maxHealth then
						forbidden[unitID] = true
						spGiveOrderToUnit(turretID, CMD_REPAIR, { unitID }, EMPTY)
						local cx, _, cz = spGetUnitPosition(unitID)
						return baseX - cx, baseZ - cz
					end
				end
			else
				assistUnits[#assistUnits+1] = unitID
			end
		end
	end

	local enemyUnits = CallAsTeam(unitTeamID, spGetUnitsInCylinder, baseX, baseZ, radius + unitDefRadiusMax, FILTER_ENEMY_UNITS)

	for _, unitID in ipairs(enemyUnits) do
		if not forbidden[unitID] and reclaimableDefID[spGetUnitDefID(unitID)] then
			local separation = spGetUnitSeparation(unitID, baseID, false, true)

			if separation and radius >= separation then
				forbidden[unitID] = true
				spGiveOrderToUnit(turretID, CMD_RECLAIM, { unitID }, EMPTY)
				local cx, _, cz = spGetUnitPosition(unitID)
				return baseX - cx, baseZ - cz
			end
		end
	end

	local features = spGetFeaturesInCylinder(baseX, baseZ, radius + unitDefRadiusMax)

	for _, featureID in ipairs(features) do
		local sequentialID = featureID + FEATURE_BASE_INDEX

		if not forbidden[sequentialID] and combatReclaimDefID[spGetFeatureDefID(featureID)] then
			local separation = spGetUnitFeatureSeparation(baseID, featureID)

			if separation and radius >= separation - spGetFeatureRadius(featureID) then
				forbidden[sequentialID] = true
				spGiveOrderToUnit(turretID, CMD_RECLAIM, { sequentialID }, EMPTY)
				local cx, _, cz = spGetFeaturePosition(featureID)
				return baseX - cx, baseZ - cz
			end
		end
	end

	for _, unitID in ipairs(assistUnits) do
		forbidden[unitID] = true
		spGiveOrderToUnit(turretID, CMD_REPAIR, { unitID }, EMPTY)
		local cx, _, cz = spGetUnitPosition(unitID)
		return baseX - cx, baseZ - cz
	end

	spGiveOrderToUnit(turretID, CMD_STOP, EMPTY, EMPTY)
end

local function updateAttachedTurret(baseID, turretID)
	if transportedUnits[baseID] then
		spGiveOrderToUnit(turretID, CMD_STOP, EMPTY, EMPTY)
	else
		local bx, by, bz = spGetUnitPosition(baseID)
		local buildRadius = turretBuildRadius[turretID]

		local dx, dz = giveSameOrderToTurret(turretID, baseID, bx, bz, buildRadius)

		if not dx then
			turretOrderPending[turretID] = true -- gate around our retries

			local forbidID = {
				baseID   = true,
				turretID = true,
			}

			local retries = 3

			repeat
				dx, dz = giveAutoOrderToTurret(turretID, baseID, bx, bz, buildRadius, forbidID)
				retries = retries - 1
			until not dx or retries == 0 or not turretOrderPending[turretID]

			turretOrderPending[turretID] = nil
		end

		if dx then
			updateTurretHeading(turretID, dx, dz, baseID)
		end
	end
end

local function attachToUnit(unitID, unitDefID, unitTeam)
	local turretDefID = baseToTurretDefID[unitDefID]
	local ux, uy, uz = spGetUnitPosition(unitID)
	local facing = Spring.GetUnitBuildFacing(unitID)

	---@diagnostic disable-next-line: param-type-mismatch
	local turretID = Spring.CreateUnit(turretDefID, ux, uy, uz, facing, unitTeam)

	if turretID then
		Spring.UnitAttach(unitID, turretID, 3)
		Spring.SetUnitBlocking(turretID, false, false, false)
		Spring.SetUnitNoSelect(turretID, true)
		turretToBaseID[turretID] = unitID
		turretBuildRadius[turretID] = UnitDefs[turretDefID].buildDistance

		return true
	else
		Spring.DestroyUnit(unitID)
	end
end

function gadget:Initialize()
	for unitDefID, unitDef in pairs(UnitDefs) do
		unitDefRadiusMax = math.max(unitDef.radius, unitDefRadiusMax)

		if unitDef.repairable then
			repairableDefID[unitDefID] = true
		end

		if unitDef.reclaimable then
			reclaimableDefID[unitDefID] = true
		end

		-- See unit_attached_con_turret_mex.lua for metal extractors.
		if unitDef.customParams.attached_con_turret and not (unitDef.extractsMetal and unitDef.extractsMetal > 0) then
			local turretDef = UnitDefNames[unitDef.customParams.attached_con_turret]

			if turretDef then
				if unitDef.buildOptions and turretDef.buildOptions and checkSameBuildOptions(unitDef, turretDef) then
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
	end

	if next(baseToTurretDefID) then
		-- Support `luarules /reload` by reacquiring attached cons.
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			local unitDefID = spGetUnitDefID(unitID)

			if baseToTurretDefID[unitDefID] then
				local attachedIDs = Spring.GetUnitIsTransporting(unitID)

				if attachedIDs then
					for _, attachedID in ipairs(attachedIDs) do
						local attachedDefID = spGetUnitDefID(attachedID)

						if attachedDefID == baseToTurretDefID[unitDefID] then
							turretToBaseID[attachedID] = unitID
							break
						end
					end
				-- The error state may be recoverable, so we reattempt; however,
				-- recall that `attachToUnit` will destroy the unit on a failure:
				elseif not attachToUnit(unitID, unitDefID, spGetUnitTeam(unitID)) then
					local e = ("Missing attached unit: %s @ %.1f, %.1f, %.1f"):format(UnitDefs[unitDefID].name, spGetUnitPosition(unitID))
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
	baseToTurretDefID[unitID] = nil
	transportedUnits[unitID] = nil
end

function gadget:GameFrame(gameFrame)
	if gameFrame % 6 == 0 then
		for turretID, baseID in pairs(turretToBaseID) do
			updateAttachedTurret(baseID, turretID)
		end
	end
end

function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdId, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	turretOrderPending[unitID] = nil
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	transportedUnits[unitID] = true
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam,  transportID, transportTeam)
	transportedUnits[unitID] = nil
end
