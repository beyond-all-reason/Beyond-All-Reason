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

local CallAsTeam = CallAsTeam

local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetFeatureRadius = Spring.GetFeatureRadius
local spGetFeaturesInCylinder = Spring.GetFeaturesInCylinder
local spGetHeadingFromVector = Spring.GetHeadingFromVector
local spGetUnitBuildFacing = Spring.GetUnitBuildFacing
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitFeatureSeparation = Spring.GetUnitFeatureSeparation
local spGetUnitHeading = Spring.GetUnitHeading
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitSeparation = Spring.GetUnitSeparation
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitTeam = Spring.GetUnitTeam

local spCallCOBScript = Spring.CallCOBScript
local spGiveOrderToUnit = Spring.GiveOrderToUnit

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

local baseToTurretID = {}
local turretBuildRadius = {}
local turretOrderPending = {}
local transportedUnits = {}

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

---Constructors with attached construction turrets must pass this check.
---Technically, it seems fine for the turret to have extra buildoptions.
local function matchBuildOptions(unitDef1, unitDef2)
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

local function attachToUnit(baseID, baseDefID, baseTeam)
	local turretDefID = baseToTurretDefID[baseDefID]
	local ux, uy, uz = spGetUnitPosition(baseID)
	local facing = spGetUnitBuildFacing(baseID)

	local turretID = Spring.CreateUnit(turretDefID, ux, uy, uz, facing, baseTeam)

	if turretID then
		Spring.UnitAttach(baseID, turretID, 3)
		Spring.SetUnitBlocking(turretID, false, false, false)
		Spring.SetUnitNoSelect(turretID, true)

		baseToTurretID[baseID] = turretID
		turretBuildRadius[turretID] = UnitDefs[turretDefID].buildDistance

		return true
	else
		Spring.DestroyUnit(baseID)
	end
end

local function echoTurretOrders(baseID, turretID, turretX, turretZ, radius)
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
				return turretX - param1, turretZ - param3
			end
		elseif command == CMD_REPAIR or command == CMD_RECLAIM then
			local teamID = spGetUnitTeam(turretID)

			if param1 < FEATURE_BASE_INDEX then
				-- Targets outside the team's LOS will return nil:
				local separation = CallAsTeam(teamID, spGetUnitSeparation, turretID, param1, false, true)

				if separation and radius >= separation then
					local cx, cy, cz = spGetUnitPosition(param1)
					return turretX - cx, turretZ - cz
				end
			else
				local featureID = param1 - FEATURE_BASE_INDEX
				local separation = CallAsTeam(teamID, Spring.GetUnitFeatureSeparation, turretID, featureID)

				if separation and radius >= separation - spGetFeatureRadius(featureID) then
					local cx, cy, cz = spGetFeaturePosition(featureID)
					return turretX - cx, turretZ - cz
				end
			end
		end
	end
end

local function findTurretOrders(baseID, turretID, turretX, turretZ, radius, forbidden)
	local unitTeamID = spGetUnitTeam(baseID) ---@type integer -- todo
	local assistUnits = {}

	local alliedUnits = CallAsTeam(unitTeamID, spGetUnitsInCylinder, turretX, turretZ, radius + unitDefRadiusMax, FILTER_ALLY_UNITS)

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
						return turretX - cx, turretZ - cz
					end
				end
			else
				assistUnits[#assistUnits+1] = unitID
			end
		end
	end

	local enemyUnits = CallAsTeam(unitTeamID, spGetUnitsInCylinder, turretX, turretZ, radius + unitDefRadiusMax, FILTER_ENEMY_UNITS)

	for _, unitID in ipairs(enemyUnits) do
		if not forbidden[unitID] and reclaimableDefID[spGetUnitDefID(unitID)] then
			local separation = spGetUnitSeparation(unitID, baseID, false, true)

			if separation and radius >= separation then
				forbidden[unitID] = true
				spGiveOrderToUnit(turretID, CMD_RECLAIM, { unitID }, EMPTY)
				local cx, _, cz = spGetUnitPosition(unitID)
				return turretX - cx, turretZ - cz
			end
		end
	end

	local features = spGetFeaturesInCylinder(turretX, turretZ, radius + unitDefRadiusMax)

	for _, featureID in ipairs(features) do
		local sequentialID = featureID + FEATURE_BASE_INDEX

		if not forbidden[sequentialID] and combatReclaimDefID[spGetFeatureDefID(featureID)] then
			local separation = spGetUnitFeatureSeparation(baseID, featureID)

			if separation and radius >= separation - spGetFeatureRadius(featureID) then
				forbidden[sequentialID] = true
				spGiveOrderToUnit(turretID, CMD_RECLAIM, { sequentialID }, EMPTY)
				local cx, _, cz = spGetFeaturePosition(featureID)
				return turretX - cx, turretZ - cz
			end
		end
	end

	for _, unitID in ipairs(assistUnits) do
		forbidden[unitID] = true
		spGiveOrderToUnit(turretID, CMD_REPAIR, { unitID }, EMPTY)
		local cx, _, cz = spGetUnitPosition(unitID)
		return turretX - cx, turretZ - cz
	end

	spGiveOrderToUnit(turretID, CMD_STOP, EMPTY, EMPTY)
end

local function updateTurretHeading(turretID, dx, dz)
	local headingCurrent = spGetUnitHeading(turretID)
	local headingNew = spGetHeadingFromVector(dx, dz) - 32768
	spCallCOBScript(turretID, "UpdateHeading", 0, headingNew - headingCurrent)
end

local function updateAttachedTurret(baseID, turretID)
	if not transportedUnits[baseID] then
		local ux, uy, uz = spGetUnitPosition(turretID)
		local buildRadius = turretBuildRadius[turretID]

		local dx, dz = echoTurretOrders(baseID, turretID, ux, uz, buildRadius)

		if dx == nil then
			turretOrderPending[turretID] = true -- gate around our retries

			local retries = 3
			local forbidID = {
				baseID   = true,
				turretID = true,
			}

			repeat
				dx, dz = findTurretOrders(baseID, turretID, ux, uz, buildRadius, forbidID)
				retries = retries - 1
			until dx == nil or retries == 0 or not turretOrderPending[turretID]

			turretOrderPending[turretID] = nil
		end

		if dx then
			updateTurretHeading(turretID, dx, dz)
		end
	end
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
			local unitDefID = spGetUnitDefID(unitID)

			if baseToTurretDefID[unitDefID] then
				local attachedIDs = Spring.GetUnitIsTransporting(unitID)

				if attachedIDs then
					for _, attachedID in ipairs(attachedIDs) do
						local attachedDefID = spGetUnitDefID(attachedID)

						if attachedDefID == baseToTurretDefID[unitDefID] then
							baseToTurretID[unitID] = attachedID
							break
						end
					end
					-- The error state may be recoverable, so we reattempt; however,
					-- recall that `attachToUnit` will destroy the unit on a failure:
				elseif not attachToUnit(unitID, unitDefID, spGetUnitTeam(unitID)) then
					local s = "Missing attached unit: %s @ %.1f, %.1f, %.1f"
					local e = s:format(UnitDefs[unitDefID].name, spGetUnitPosition(unitID))
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

function gadget:GameFrame(gameFrame)
	if gameFrame % 15 == 0 then
		for baseID, turretID in pairs(baseToTurretID) do
			updateAttachedTurret(baseID, turretID)
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if baseToTurretDefID[unitDefID] then
		attachToUnit(unitID, unitDefID, unitTeam)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	baseToTurretID[unitID] = nil
	turretBuildRadius[unitID] = nil
	turretOrderPending[unitID] = nil
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
	return not transportedUnits[unitID]
end

function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdId, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	turretOrderPending[unitID] = nil
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if baseToTurretID[unitID] then
		local turretID = baseToTurretID[unitID]
		transportedUnits[unitID] = true
		transportedUnits[turretID] = true
		spGiveOrderToUnit(turretID, CMD_STOP, EMPTY, EMPTY)
	end
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam,  transportID, transportTeam)
	transportedUnits[unitID] = nil
end
