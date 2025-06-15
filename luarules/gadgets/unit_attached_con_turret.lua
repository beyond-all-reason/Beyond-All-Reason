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

--------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------

local attachedBuilders = {}
local attachedBuilderDefID = {}
local unitDefRadiusMax = 0

for unitDefID, unitDef in pairs(UnitDefs) do
	local dimensions = Spring.GetUnitDefDimensions(unitDef.id)
	if dimensions then
		unitDefRadiusMax = math.max(dimensions.radius, unitDefRadiusMax)
	end
end

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function updateTurretOrder(unitID, unitDefID)
	-- first, check command the body is performing
	local commandQueue = Spring.GetUnitCommands(attachedBuilders[unitID], 1)

	if (commandQueue[1] ~= nil and commandQueue[1]["id"] < 0) then
		-- build command
		-- The attached turret must have the same buildlist as the body for this to work correctly
		--for XX,YY, base_unit_id in pairs(commandQueue[1]["params"]) do
		--	Spring.Echo(XX,YY)
		--end
		Spring.GiveOrderToUnit(unitID, commandQueue[1]["id"], commandQueue[1]["params"], {})
	end

	if (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_REPAIR) then
		-- repair command
		--for XX,YY, base_unit_id in pairs(commandQueue[1]["params"]) do
		--	Spring.Echo(XX,YY)
		--end
		if #commandQueue[1]["params"] ~= 4 then
			Spring.GiveOrderToUnit(unitID, CMD_REPAIR, commandQueue[1]["params"], {})
		end
	end

	if (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_RECLAIM) then
		-- reclaim command
		if #commandQueue[1]["params"] ~= 4 then
			Spring.GiveOrderToUnit(unitID, CMD_RECLAIM, commandQueue[1]["params"], {})
		end
	end

	-- next, check to see if current command (including command from chassis) is in range
	commandQueue = Spring.GetUnitCommands(unitID, 1)
	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	local tx, ty, tz
	local radius = UnitDefs[unitDefID].buildDistance
	local distance = radius ^ 2 + 1
	local targetRadius = 0

	if (commandQueue[1] ~= nil and commandQueue[1]["id"] < 0) then
		-- out of range build command
		targetRadius = Spring.GetUnitDefDimensions(-commandQueue[1]["id"]).radius
		distance = math.sqrt((ux - commandQueue[1]["params"][1]) ^ 2 + (uz - commandQueue[1]["params"][3]) ^ 2) -
			targetRadius
	end

	if (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_REPAIR) then
		-- out of range repair command
		if (commandQueue[1]["params"][1] >= Game.maxUnits) then
			tx, ty, tz = Spring.GetFeaturePosition(commandQueue[1]["params"][1] - Game.maxUnits)
			targetRadius = Spring.GetFeatureRadius(commandQueue[1]["params"][1] - Game.maxUnits)
		else
			tx, ty, tz = Spring.GetUnitPosition(commandQueue[1]["params"][1])
			targetRadius = Spring.GetUnitRadius(commandQueue[1]["params"][1])
		end

		if tx ~= nil then
			distance = math.sqrt((ux - tx) ^ 2 + (uz - tz) ^ 2) - targetRadius
		end
	end

	if (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_RECLAIM) then
		-- out of range reclaim command
		if (commandQueue[1]["params"][1] >= Game.maxUnits) then
			tx, ty, tz = Spring.GetFeaturePosition(commandQueue[1]["params"][1] - Game.maxUnits)
			targetRadius = Spring.GetFeatureRadius(commandQueue[1]["params"][1] - Game.maxUnits)
		else
			tx, ty, tz = Spring.GetUnitPosition(commandQueue[1]["params"][1])
			targetRadius = Spring.GetUnitRadius(commandQueue[1]["params"][1])
		end

		if tx ~= nil then
			distance = math.sqrt((ux - tx) ^ 2 + (uz - tz) ^ 2) - targetRadius
		end
	end

	if tx and distance <= radius then
		--let auto con turret continue its thing
		--update heading, by calling into unit script
		local heading1 = Spring.GetHeadingFromVector(ux - tx, uz - tz)
		local heading2 = Spring.GetUnitHeading(unitID)
		Spring.CallCOBScript(unitID, 'UpdateHeading', 0, heading1 - heading2 + 32768)
		return
	end

	-- next, check to see if valid repair/reclaim targets in range
	local nearUnits = Spring.GetUnitsInCylinder(ux, uz, radius + unitDefRadiusMax)

	for _, nearID in pairs(nearUnits) do
		-- check for free repairs
		local nearDefID = Spring.GetUnitDefID(nearID)
		if Spring.GetUnitAllyTeam(nearID) == Spring.GetUnitAllyTeam(unitID) then
			if ((Spring.GetUnitSeparation(nearID, unitID, true) - Spring.GetUnitRadius(nearID)) < radius) then
				local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth(nearID)
				if buildProgress == 1 and health < maxHealth and UnitDefs[nearDefID].repairable and nearID ~= attachedBuilders[unitID] then
					Spring.GiveOrderToUnit(unitID, CMD_REPAIR, { nearID }, {})
					return
				end
			end
		end
	end

	for _, nearID in pairs(nearUnits) do
		-- check for enemy to reclaim
		local nearDefID = Spring.GetUnitDefID(nearID)
		if Spring.GetUnitAllyTeam(nearID) ~= Spring.GetUnitAllyTeam(unitID) then
			if ((Spring.GetUnitSeparation(nearID, unitID, true) - Spring.GetUnitRadius(nearID)) < radius) then
				if UnitDefs[nearDefID].reclaimable then
					Spring.GiveOrderToUnit(unitID, CMD_RECLAIM, { nearID }, {})
					return
				end
			end
		end
	end

	local nearFeatures = Spring.GetFeaturesInCylinder(ux, uz, radius + unitDefRadiusMax)

	for _, nearID in pairs(nearFeatures) do
		-- check for non resurrectable feature to reclaim
		local nearDefID = Spring.GetFeatureDefID(nearID)
		if ((Spring.GetUnitFeatureSeparation(unitID, nearID, true) - Spring.GetFeatureRadius(nearID)) < radius) then
			if FeatureDefs[nearDefID].reclaimable and Spring.GetFeatureResurrect(nearID) == "" then
				Spring.GiveOrderToUnit(unitID, CMD_RECLAIM, { nearID + Game.maxUnits }, {})
				return
			end
		end
	end

	for _, nearID in pairs(nearUnits) do
		-- check for nanoframe to build
		if Spring.GetUnitAllyTeam(nearID) == Spring.GetUnitAllyTeam(unitID) then
			if ((Spring.GetUnitSeparation(nearID, unitID, true) - Spring.GetUnitRadius(nearID)) < radius) then
				if Spring.GetUnitIsBeingBuilt(nearID) then
					Spring.GiveOrderToUnit(unitID, CMD_REPAIR, { nearID }, {})
					return
				end
			end
		end
	end

	-- give stop command to attached con turret if nothing to do
	Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {})
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	attachedBuilders[unitID] = nil
	attachedBuilderDefID[unitID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	local unitDef = UnitDefs[unitDefID]

	-- for now, just corvac gets an attached con turret
	if unitDef.name == "corvac" then
		local xx, yy, zz = Spring.GetUnitPosition(unitID)
		local turretID = Spring.CreateUnit("corvacct", xx, yy, zz, 0, Spring.GetUnitTeam(unitID))
		if not turretID then
			-- unit limit hit or invalid spawn surface
			return
		end
		Spring.UnitAttach(unitID, turretID, 3)
		-- makes the attached con turret as non-interacting as possible
		Spring.SetUnitBlocking(turretID, false, false, false)
		Spring.SetUnitNoSelect(turretID, true)
		attachedBuilders[turretID] = unitID
		attachedBuilderDefID[turretID] = Spring.GetUnitDefID(turretID)
	end

	if unitDef.name == "legmohobp" then
		local xx, yy, zz = Spring.GetUnitPosition(unitID)
		local turretID = Spring.CreateUnit("legmohobpct", xx, yy, zz, 0, Spring.GetUnitTeam(unitID))
		if not turretID then
			-- unit limit hit or invalid spawn surface
			return
		end
		Spring.UnitAttach(unitID, turretID, 3)
		-- makes the attached con turret as non-interacting as possible
		Spring.SetUnitBlocking(turretID, false, false, false)
		Spring.SetUnitNoSelect(turretID, false)
		attachedBuilders[turretID] = unitID
		attachedBuilderDefID[turretID] = Spring.GetUnitDefID(turretID)
	end
end

function gadget:GameFrame(gameFrame)
	if gameFrame % 15 == 0 then
		-- go on a slowupdate cycle
		for unitID in pairs(attachedBuilders) do
			updateTurretOrder(unitID, attachedBuilderDefID[unitID])
		end
	end
end
