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

local SpGetUnitCommands = Spring.GetUnitCommands
local SpGiveOrderToUnit = Spring.GiveOrderToUnit
local SpGetUnitPosition = Spring.GetUnitPosition
local SpGetFeaturePosition = Spring.GetFeaturePosition
local SpGetUnitDefID = Spring.GetUnitDefID
local SpGetUnitsInCylinder = Spring.GetUnitsInCylinder
local SpGetUnitAllyTeam = Spring.GetUnitAllyTeam
local SpGetFeaturesInCylinder = Spring.GetFeaturesInCylinder
local SpGetFeatureDefID = Spring.GetFeatureDefID
local SpGetFeatureResurrect = Spring.GetFeatureResurrect
local SpGetUnitHealth = Spring.GetUnitHealth
local SpGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local SpGetUnitDefDimensions = Spring.GetUnitDefDimensions
local SpGetFeatureRadius = Spring.GetFeatureRadius
local SpGetUnitRadius = Spring.GetUnitRadius
local SpGetUnitFeatureSeparation = Spring.GetUnitFeatureSeparation
local SpGetUnitSeparation = Spring.GetUnitSeparation

local SpGetHeadingFromVector = Spring.GetHeadingFromVector
local SpGetUnitHeading = Spring.GetUnitHeading
local SpCallCOBScript = Spring.CallCOBScript

local CMD_REPAIR = CMD.REPAIR
local CMD_RECLAIM = CMD.RECLAIM

local FEATURE_BASE_INDEX = Game.maxUnits
local FEATURE_NO_UNITDEF = ""
local FILTER_ALLY_UNITS = -3
local FILTER_ENEMY_UNITS = -4
local EMPTY = {}

--------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------

local baseToTurretDefID = {}

local turretToBaseID = {}
local turretBuildRadius = {}

--repairs and reclaims start at the edge of the unit radius
--so we need to increase our search radius by the maximum unit radius
local unitDefRadiusMax = 0

---Constructors with attached construction turrets must pass this check.
---Technically, it seems fine for the turret to have extra buildoptions.
local function checkSameBuildOptions(unitDef1, unitDef2)
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

function gadget:Initialize()
	for unitDefID, unitDef in pairs(UnitDefs) do
		unitDefRadiusMax = math.max(unitDef.radius, unitDefRadiusMax)

		-- See unit_attached_con_turret_mex.lua for metal extractors.
		if unitDef.customParams.attached_con_turret and not (unitDef.extractsMetal and unitDef.extractsMetal > 0) then
			local turretDef = UnitDefNames[unitDef.customParams.attached_con_turret]

			if checkSameBuildOptions(unitDef, turretDef) then
				local turretDefID = turretDef.id
				baseToTurretDefID[unitDefID] = turretDefID
			else
				local message = "Unit and its attached con turret have different build lists: "
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, message .. unitDef.name)
			end
		end
	end

	if next(baseToTurretDefID) then
		-- Support `luarules /reload` by reacquiring attached cons.
		for _, unitID in Spring.GetAllUnits() do
			local unitDefID = Spring.GetUnitDefID(unitID)

			if baseToTurretDefID[unitDefID] then
				local attachedIDs = Spring.GetUnitIsTransporting(unitID)

				for _, attachedID in ipairs(attachedIDs) do
					local attachedDefID = Spring.GetUnitDefID(attachedID)

					if attachedDefID == baseToTurretDefID[unitDefID] then
						turretToBaseID[attachedID] = unitID
						break
					end
				end
			end
		end
	else
		gadgetHandler:RemoveGadget(self)
	end
end

---This gadget has a polling rate, so should not issue orders that will be disallowed.
---It will be unable to acquire a new order until its next poll attempt (which also may fail).
---See unit_prevent_cloaked_unit_reclaim for the order logic.
-- todo: don't hit UnitDefs; prevent_reclaim via other gadgets should be an API
local function preventEnemyUnitReclaim(enemyID, teamID)
	local enemyUnitDef = UnitDefs[spGetUnitDefID(enemyID)]
	return	(not enemyUnitDef.reclaimable) or
			(enemyUnitDef.canCloak and Spring.GetUnitIsCloaked(enemyID) and not Spring.IsUnitInRadar(enemyID, Spring.GetTeamAllyTeamID(teamID)))
end

local function updateTurretHeading(turretID, dx, dz, baseID)
	local headingCurrent = Spring.GetUnitHeading(turretID)
	local headingNew = dx and Spring.GetHeadingFromVector(dx, dz) - 32768 or Spring.GetUnitHeading(baseID)
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
	local command, _, _, param1, param2, param3, param4 = Spring.GetUnitCurrentCommand(baseID)

	if	not command
		or (command >= 0 and command ~= CMD_REPAIR and command ~= CMD_RECLAIM)
		or param4
		or not Spring.GiveOrderToUnit(turretID, command, { param1, param2, param3 }, EMPTY)
	then
		command, _, _, param1, param2, param3, param4 = Spring.GetUnitCurrentCommand(turretID)
	end

	if command and not param4 then
		if command < 0 and -command ~= baseID and -command ~= turretID then
			if radius > Spring.GetUnitSeparation(turretID, -command, false, true) then
				return baseX - param1, baseZ - param3
			end
		elseif command == CMD_REPAIR or command == CMD_RECLAIM then
			if param1 < FEATURE_BASE_INDEX then
				if radius > Spring.GetUnitSeparation(turretID, param1, false, true) then
					local cx, cy, cz = Spring.GetUnitPosition(param1)
					return baseX - cx, baseZ - cz
				end
			elseif radius > Spring.GetUnitFeatureSeparation(turretID, param1 - FEATURE_BASE_INDEX, false, true) then
				local cx, cy, cz = Spring.GetFeaturePosition(param1 - FEATURE_BASE_INDEX)
				return baseX - cx, baseZ - cz
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
---@return number dx for new turret heading
---@return number dz for new turret heading
local function giveAutoOrderToTurret(turretID, baseID, baseX, baseZ, radius)
	local unitTeamID = Spring.GetUnitTeam(baseID) ---@type integer -- todo
	local assistUnits = {}

	local alliedUnits = CallAsTeam(unitTeamID, Spring.GetUnitsInCylinder, baseX, baseZ, radius + unitDefRadiusMax, FILTER_ALLY_UNITS)

	for _, unitID in ipairs(alliedUnits) do
		if unitID ~= baseID and unitID ~= turretID and radius > Spring.GetUnitSeparation(unitID, baseID, false, true) then
			local allyDefID = Spring.GetUnitDefID(maybeBuildID)

			if UnitDefs[allyDefID].repairable then
				local health, maxHealth, _, _, buildProgress = Spring.GetUnitHealth(unitID)

				if buildProgress == 1 and health < maxHealth then
					Spring.GiveOrderToUnit(turretID, CMD_REPAIR, { unitID }, EMPTY)
					local cx, _, cz = Spring.GetUnitPosition(unitID)
					return baseX - cx, baseZ - cz
				end
			end

			-- todo: bug fix, separate PR
			-- if not unitCannotBeAssisted[allyDefID] then
			-- 	assistUnits[#assistUnits+1] = allyID
			-- end
			assistUnits[#assistUnits+1] = unitID
		end
	end

	local enemyUnits = CallAsTeam(unitTeamID, Spring.GetUnitsInCylinder, baseX, baseZ, radius + unitDefRadiusMax, FILTER_ENEMY_UNITS)

	for _, unitID in ipairs(enemyUnits) do
		if radius > Spring.GetUnitSeparation(unitID, baseID, false, true) and not preventEnemyUnitReclaim(unitID, unitTeamID) then
			Spring.GiveOrderToUnit(turretID, CMD_RECLAIM, { unitID }, EMPTY)
			local cx, _, cz = Spring.GetUnitPosition(unitID)
			return baseX - cx, baseZ - cz
		end
	end

	local features = Spring.GetFeaturesInCylinder(baseX, baseZ, radius + unitDefRadiusMax)

	for _, featureID in ipairs(features) do
		if	FeatureDefs[Spring.GetFeatureDefID(featureID)].reclaimable and
			Spring.GetFeatureResurrect(featureID) == FEATURE_NO_UNITDEF and
			---@diagnostic disable-next-line: redundant-parameter
			radius > Spring.GetUnitFeatureSeparation(baseID, featureID, false, true) -- todo: function signature
		then
			Spring.GiveOrderToUnit(turretID, CMD_RECLAIM, { featureID + FEATURE_BASE_INDEX }, EMPTY)
			local cx, _, cz = Spring.GetFeaturePosition(featureID)
			return baseX - cx, baseZ - cz
		end
	end

	for _, maybeBuildID in ipairs(assistUnits) do
		if Spring.GetUnitIsBeingBuilt(maybeBuildID) then
			Spring.GiveOrderToUnit(turretID, CMD_REPAIR, { maybeBuildID }, EMPTY)
			local cx, _, cz = Spring.GetUnitPosition(maybeBuildID)
			return baseX - cx, baseZ - cz
		end
	end

	Spring.GiveOrderToUnit(turretID, CMD.STOP, EMPTY, EMPTY)
end

local function updateAttachedTurret(baseID, turretID)
	local bx, by, bz = Spring.GetUnitPosition(baseID)
	local buildRadius = turretBuildRadius[turretID]

	local dx, dz = giveSameOrderToTurret(turretID, baseID, bx, bz, buildRadius)

	if not dx then
		dx, dz = giveAutoOrderToTurret(turretID, baseID, bx, bz, buildRadius)
	end

	if dx then
		updateTurretHeading(turretID, dx, dz, baseID)
	end
end

local function attachToUnit(unitID, unitDefID, unitTeam)
	local turretDefID = baseToTurretDefID[unitDefID]
	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	local facing = Spring.GetUnitBuildFacing(unitID)

	---@diagnostic disable-next-line: param-type-mismatch
	local turretID = Spring.CreateUnit(turretDefID, ux, uy, uz, facing, unitTeam)

	if turretID then
		Spring.UnitAttach(unitID, turretID, 3)
		Spring.SetUnitBlocking(turretID, false, false, false)
		Spring.SetUnitNoSelect(turretID, true)
		turretToBaseID[turretID] = unitID
		turretBuildRadius[turretID] = UnitDefs[turretDefID].buildDistance
	else
		Spring.DestroyUnit(unitID)
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
end

function gadget:GameFrame(gameFrame)
	if gameFrame % 15 == 0 then
	    -- go on a slowupdate cycle
		for turretID, baseID in pairs(turretToBaseID) do
			updateAttachedTurret(baseID, turretID)
		end
	end
end
