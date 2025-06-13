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


local CMD_REPAIR = CMD.REPAIR
local CMD_RECLAIM = CMD.RECLAIM
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

--------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------

local attachedBuilderDefID = {}

local attachedUnits = {}
local attachedUnitBuildRadius = {}

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
			local nanoDef = UnitDefNames[unitDef.customParams.attached_con_turret]

			if checkSameBuildOptions(unitDef, nanoDef) then
				attachedBuilderDefID[unitDefID] = nanoDef and nanoDef.id or nil
				attachedUnitBuildRadius[unitDefID] = nanoDef.buildDistance
			else
				local message = "Unit and its attached con turret have different build lists: "
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, message .. unitDef.name)
			end
		end
	end

	if next(attachedBuilderDefID) then
		-- Support `luarules /reload` by reacquiring attached cons.
		for _, unitID in Spring.GetAllUnits() do
			local unitDefID = Spring.GetUnitDefID(unitID)

			if attachedBuilderDefID[unitDefID] then
				local attachedIDs = Spring.GetUnitIsTransporting(unitID)

				for _, attachedID in ipairs(attachedIDs) do
					local attachedDefID = Spring.GetUnitDefID(attachedID)

					if attachedDefID == attachedBuilderDefID[unitDefID] then
						attachedUnits[attachedID] = unitID
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

---Performs a search for the first executable automatic/smart behavior, in priority order:
---(1) repair ally (2) reclaim enemy (3) reclaim non-ressurectable feature (4) build-assist allied unit.
---@param turretID integer
---@param baseID integer
---@param unitX number
---@param unitZ number
---@param radius number
---@return number dx? for new turret heading
---@return number dz? for new turret heading
local function giveAutoOrderToTurret(turretID, baseID, unitX, unitZ, radius)
	local unitTeamID = Spring.GetUnitTeam(baseID) ---@type integer -- todo
	local assistUnits = {}

	local alliedUnits = CallAsTeam(unitTeamID, Spring.GetUnitsInCylinder, unitX, unitZ, radius + unitDefRadiusMax, FILTER_ALLY_UNITS)

	for _, unitID in ipairs(alliedUnits) do
		if unitID ~= baseID and unitID ~= turretID and radius > Spring.GetUnitSeparation(unitID, baseID, false, true) then
			local allyDefID = Spring.GetUnitDefID(maybeBuildID)

			if UnitDefs[allyDefID].repairable then
				local health, maxHealth, _, _, buildProgress = Spring.GetUnitHealth(unitID)

				if buildProgress == 1 and health < maxHealth then
					Spring.GiveOrderToUnit(turretID, CMD_REPAIR, { unitID }, EMPTY)
					local cx, _, cz = Spring.GetUnitPosition(unitID)
					return unitX - cx, unitZ - cz
				end
			end

			-- todo: bug fix, separate PR
			-- if not unitCannotBeAssisted[allyDefID] then
			-- 	assistUnits[#assistUnits+1] = allyID
			-- end
			assistUnits[#assistUnits+1] = unitID
		end
	end

	local enemyUnits = CallAsTeam(unitTeamID, Spring.GetUnitsInCylinder, unitX, unitZ, radius + unitDefRadiusMax, FILTER_ENEMY_UNITS)

	for _, unitID in ipairs(enemyUnits) do
		if radius > Spring.GetUnitSeparation(unitID, baseID, false, true) and not preventEnemyUnitReclaim(unitID, unitTeamID) then
			Spring.GiveOrderToUnit(turretID, CMD_RECLAIM, { unitID }, EMPTY)
			local cx, _, cz = Spring.GetUnitPosition(unitID)
			return unitX - cx, unitZ - cz
		end
	end

	local features = Spring.GetFeaturesInCylinder(unitX, unitZ, radius + unitDefRadiusMax)

	for _, featureID in ipairs(features) do
		if	FeatureDefs[Spring.GetFeatureDefID(featureID)].reclaimable and
			Spring.GetFeatureResurrect(featureID) == FEATURE_NO_UNITDEF and
			---@diagnostic disable-next-line: redundant-parameter
			radius > Spring.GetUnitFeatureSeparation(baseID, featureID, false, true) -- todo: function signature
		then
			Spring.GiveOrderToUnit(turretID, CMD_RECLAIM, { featureID + FEATURE_BASE_INDEX }, EMPTY)
			local cx, _, cz = Spring.GetFeaturePosition(featureID)
			return unitX - cx, unitZ - cz
		end
	end

	for _, maybeBuildID in ipairs(assistUnits) do
		if Spring.GetUnitIsBeingBuilt(maybeBuildID) then
			Spring.GiveOrderToUnit(turretID, CMD_REPAIR, { maybeBuildID }, EMPTY)
			local cx, _, cz = Spring.GetUnitPosition(maybeBuildID)
			return unitX - cx, unitZ - cz
		end
	end

	Spring.GiveOrderToUnit(turretID, CMD.STOP, EMPTY, EMPTY)
end

local function updateAttachedTurret(turretID, baseDefID)
	local baseID = attachedUnits[turretID]

	-- first, check command the body is performing
	local commandQueue = SpGetUnitCommands(baseID, 1)
	if (commandQueue[1] ~= nil and commandQueue[1]["id"] < 0) then
        -- build command
		-- The attached turret must have the same buildlist as the body for this to work correctly
		--for XX,YY, base_unit_id in pairs(commandQueue[1]["params"]) do
		--	Spring.Echo(XX,YY)
		--end
        SpGiveOrderToUnit(turretID, commandQueue[1]["id"], commandQueue[1]["params"], {})
    end
    if (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_REPAIR) then
        -- repair command
		--for XX,YY, base_unit_id in pairs(commandQueue[1]["params"]) do
		--	Spring.Echo(XX,YY)
		--end
		if #commandQueue[1]["params"] ~= 4 then
			SpGiveOrderToUnit(turretID, CMD_REPAIR, commandQueue[1]["params"], {})
		end
    end
	if (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_RECLAIM) then
        -- reclaim command
		if #commandQueue[1]["params"] ~= 4 then
			SpGiveOrderToUnit(turretID, CMD_RECLAIM, commandQueue[1]["params"], {})
		end
    end

	-- next, check to see if current command (including command from chassis) is in range
	commandQueue = SpGetUnitCommands(turretID, 1)
	local ux,uy,uz = SpGetUnitPosition(turretID)
	local tx, ty, tz
	local radius = attachedUnitBuildRadius[baseDefID]
	local distance = radius^2 + 1
	local objectRadius = 0
	if (commandQueue[1] ~= nil and commandQueue[1]["id"] < 0) then
        -- out of range build command
		objectRadius = SpGetUnitDefDimensions(-commandQueue[1]["id"]).radius
		distance = math.sqrt((ux-commandQueue[1]["params"][1])^2 + (uz-commandQueue[1]["params"][3])^2) - objectRadius
    end
    if (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_REPAIR) then
        -- out of range repair command
		if (commandQueue[1]["params"][1] >= Game.maxUnits) then
			tx,ty,tz = SpGetFeaturePosition(commandQueue[1]["params"][1] - Game.maxUnits)
			objectRadius = SpGetFeatureRadius(commandQueue[1]["params"][1] - Game.maxUnits)
		else
			tx,ty,tz = SpGetUnitPosition(commandQueue[1]["params"][1])
			objectRadius = SpGetUnitRadius(commandQueue[1]["params"][1])
		end
		if tx ~= nil then
			distance = math.sqrt((ux-tx)^2 + (uz-tz)^2) - objectRadius
		end
    end
	if (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_RECLAIM) then
		-- out of range reclaim command
		if (commandQueue[1]["params"][1] >= Game.maxUnits) then
			tx,ty,tz = SpGetFeaturePosition(commandQueue[1]["params"][1] - Game.maxUnits)
			objectRadius = SpGetFeatureRadius(commandQueue[1]["params"][1] - Game.maxUnits)
		else
			tx,ty,tz = SpGetUnitPosition(commandQueue[1]["params"][1])
			objectRadius = SpGetUnitRadius(commandQueue[1]["params"][1])
		end
		if tx ~= nil then
			distance = math.sqrt((ux-tx)^2 + (uz-tz)^2) - objectRadius
		end
    end
	if tx and distance <= radius then
		--let auto con turret continue its thing
		--update heading, by calling into unit script
		heading1 = SpGetHeadingFromVector(ux-tx,uz-tz)
		heading2 = SpGetUnitHeading(turretID)
		SpCallCOBScript(turretID, 'UpdateHeading', 0, heading1-heading2+32768)
		return
	end

	giveAutoOrderToTurret(turretID, baseID, ux, uz, radius)
end

local function attachToUnit(unitID, unitDefID, unitTeam)
	local attachedDefID = attachedBuilderDefID[unitDefID]
	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	local facing = Spring.GetUnitBuildFacing(unitID)

	---@diagnostic disable-next-line: param-type-mismatch
	local attachedID = Spring.CreateUnit(attachedDefID, ux, uy, uz, facing, unitTeam)

	if attachedID then
		Spring.UnitAttach(unitID, attachedID, 3)
		Spring.SetUnitBlocking(attachedID, false, false, false)
		Spring.SetUnitNoSelect(attachedID, true)
		attachedUnits[attachedID] = unitID
		attachedUnitBuildRadius[attachedID] = UnitDefs[attachedDefID].buildDistance
	else
		Spring.DestroyUnit(unitID)
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if attachedBuilderDefID[unitDefID] then
		attachToUnit(unitID, unitDefID, unitTeam)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	attachedUnits[unitID] = nil
	attachedBuilderDefID[unitID] = nil
end

function gadget:GameFrame(gameFrame)

	if gameFrame % 15 == 0 then
	    -- go on a slowupdate cycle
		for unitID, baseID in pairs(attachedUnits) do
			updateAttachedTurret(unitID,attachedBuilderDefID[unitID])
		end
	end

end
