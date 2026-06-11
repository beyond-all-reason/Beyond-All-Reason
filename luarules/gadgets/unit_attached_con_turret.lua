local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Attached Construction Turret",
		desc = "Attaches a builder to another mobile unit, so builder can repair while moving",
		author = "Itanthias",
		version = "v1.1",
		date = "July 2023",
		license = "GNU GPL, v2 or later",
		layer = 12,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local CMD_REPAIR = CMD.REPAIR
local CMD_RECLAIM = CMD.RECLAIM
local CMD_STOP = CMD.STOP
local SpGetUnitCommands = Engine.Shared.GetUnitCommands
local SpGiveOrderToUnit = Engine.Shared.GiveOrderToUnit
local SpGetUnitPosition = Engine.Shared.GetUnitPosition
local SpGetFeaturePosition = Engine.Shared.GetFeaturePosition
local SpGetUnitDefID = Engine.Shared.GetUnitDefID
local SpGetUnitsInCylinder = Engine.Shared.GetUnitsInCylinder
local SpGetUnitAllyTeam = Engine.Shared.GetUnitAllyTeam
local SpGetFeaturesInCylinder = Engine.Shared.GetFeaturesInCylinder
local SpGetFeatureDefID = Engine.Shared.GetFeatureDefID
local SpGetFeatureResurrect = Engine.Shared.GetFeatureResurrect
local SpGetUnitHealth = Engine.Shared.GetUnitHealth
local SpGetUnitIsBeingBuilt = Engine.Shared.GetUnitIsBeingBuilt
local SpGetUnitDefDimensions = Engine.Shared.GetUnitDefDimensions
local SpGetFeatureRadius = Engine.Shared.GetFeatureRadius
local SpGetUnitRadius = Engine.Shared.GetUnitRadius
local SpGetUnitFeatureSeparation = Engine.Shared.GetUnitFeatureSeparation
local SpGetUnitSeparation = Engine.Shared.GetUnitSeparation
local SpGetUnitTransporter = Engine.Shared.GetUnitTransporter

local SpGetHeadingFromVector = Engine.Shared.GetHeadingFromVector
local SpGetUnitHeading = Engine.Shared.GetUnitHeading
local SpCallCOBScript = Engine.Synced.CallCOBScript

--repairs and reclaims start at the edge of the unit radius
--so we need to increase our search radius by the maximum unit radius
local max_unit_radius = 0
function gadget:Initialize()
	local radius = 0
	for ix, udef in pairs(UnitDefs) do
		dimensions = SpGetUnitDefDimensions(udef.id)
		radius = dimensions.radius
		max_unit_radius = math.max(radius, max_unit_radius)
	end
end

local function auto_repair_routine(nanoID, unitDefID, baseUnitID)
	local transporterID = SpGetUnitTransporter(baseUnitID)
	if transporterID then
		Engine.Shared.GiveOrderToUnit(nanoID, CMD_STOP, {}, 0)
		return
	end
	-- first, check command the body is performing
	local commandQueue = SpGetUnitCommands(attached_builders[nanoID], 1)
	if commandQueue[1] ~= nil and commandQueue[1]["id"] < 0 then
		-- build command
		-- The attached turret must have the same buildlist as the body for this to work correctly
		--for XX, YY, baseUnitID in pairs(commandQueue[1]["params"]) do
		--	Spring.Echo(XX, YY)
		--end
		SpGiveOrderToUnit(nanoID, commandQueue[1]["id"], commandQueue[1]["params"])
	end
	if commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_REPAIR then
		-- repair command
		--for XX, YY, baseUnitID in pairs(commandQueue[1]["params"]) do
		--	Spring.Echo(XX, YY)
		--end
		if #commandQueue[1]["params"] ~= 4 then
			SpGiveOrderToUnit(nanoID, CMD_REPAIR, commandQueue[1]["params"])
		end
	end
	if commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_RECLAIM then
		-- reclaim command
		if #commandQueue[1]["params"] ~= 4 then
			SpGiveOrderToUnit(nanoID, CMD_RECLAIM, commandQueue[1]["params"])
		end
	end

	-- next, check to see if current command (including command from chassis) is in range
	commandQueue = SpGetUnitCommands(nanoID, 1)
	local ux, uy, uz = SpGetUnitPosition(nanoID)
	local tx, ty, tz
	local radius = UnitDefs[unitDefID].buildDistance
	local distance = radius ^ 2 + 1
	local object_radius = 0
	if commandQueue[1] ~= nil and commandQueue[1]["id"] < 0 then
		-- out of range build command
		object_radius = SpGetUnitDefDimensions(-commandQueue[1]["id"]).radius
		distance = math.sqrt((ux - commandQueue[1]["params"][1]) ^ 2 + (uz - commandQueue[1]["params"][3]) ^ 2) - object_radius
	end
	if commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_REPAIR then
		-- out of range repair command
		if commandQueue[1]["params"][1] >= Game.maxUnits then
			tx, ty, tz = SpGetFeaturePosition(commandQueue[1]["params"][1] - Game.maxUnits)
			object_radius = SpGetFeatureRadius(commandQueue[1]["params"][1] - Game.maxUnits)
		else
			tx, ty, tz = SpGetUnitPosition(commandQueue[1]["params"][1])
			object_radius = SpGetUnitRadius(commandQueue[1]["params"][1])
		end
		if tx ~= nil then
			distance = math.sqrt((ux - tx) ^ 2 + (uz - tz) ^ 2) - object_radius
		end
	end
	if commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_RECLAIM then
		-- out of range reclaim command
		if commandQueue[1]["params"][1] >= Game.maxUnits then
			tx, ty, tz = SpGetFeaturePosition(commandQueue[1]["params"][1] - Game.maxUnits)
			object_radius = SpGetFeatureRadius(commandQueue[1]["params"][1] - Game.maxUnits)
		else
			tx, ty, tz = SpGetUnitPosition(commandQueue[1]["params"][1])
			object_radius = SpGetUnitRadius(commandQueue[1]["params"][1])
		end
		if tx ~= nil then
			distance = math.sqrt((ux - tx) ^ 2 + (uz - tz) ^ 2) - object_radius
		end
	end
	if tx and distance <= radius then
		--let auto con turret continue its thing
		--update heading, by calling into unit script
		heading1 = SpGetHeadingFromVector(ux - tx, uz - tz)
		heading2 = SpGetUnitHeading(nanoID)
		SpCallCOBScript(nanoID, "UpdateHeading", 0, heading1 - heading2 + 32768)
		return
	end

	-- next, check to see if valid repair/reclaim targets in range
	local near_units = SpGetUnitsInCylinder(ux, uz, radius + max_unit_radius)

	for XX, near_unit in pairs(near_units) do
		-- check for free repairs
		local near_defid = SpGetUnitDefID(near_unit)
		if SpGetUnitAllyTeam(near_unit) == SpGetUnitAllyTeam(nanoID) then
			if (SpGetUnitSeparation(near_unit, nanoID, true) - SpGetUnitRadius(near_unit)) < radius then
				local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = SpGetUnitHealth(near_unit)
				if buildProgress == 1 and health < maxHealth and UnitDefs[near_defid].repairable and near_unit ~= attached_builders[nanoID] then
					SpGiveOrderToUnit(nanoID, CMD_REPAIR, { near_unit })
					return
				end
			end
		end
	end

	for XX, near_unit in pairs(near_units) do
		-- check for enemy to reclaim
		local near_defid = SpGetUnitDefID(near_unit)
		if SpGetUnitAllyTeam(near_unit) ~= SpGetUnitAllyTeam(nanoID) then
			if (SpGetUnitSeparation(near_unit, nanoID, true) - SpGetUnitRadius(near_unit)) < radius then
				if UnitDefs[near_defid].reclaimable then
					SpGiveOrderToUnit(nanoID, CMD_RECLAIM, { near_unit })
					return
				end
			end
		end
	end

	local near_features = SpGetFeaturesInCylinder(ux, uz, radius + max_unit_radius)
	for XX, near_feature in pairs(near_features) do
		-- check for non resurrectable feature to reclaim
		local near_defid = SpGetFeatureDefID(near_feature)
		if (SpGetUnitFeatureSeparation(nanoID, near_feature, true) - SpGetFeatureRadius(near_feature)) < radius then
			if FeatureDefs[near_defid].reclaimable and SpGetFeatureResurrect(near_feature) == "" then
				SpGiveOrderToUnit(nanoID, CMD_RECLAIM, { near_feature + Game.maxUnits })
				return
			end
		end
	end

	for XX, near_unit in pairs(near_units) do
		-- check for nanoframe to build
		if SpGetUnitAllyTeam(near_unit) == SpGetUnitAllyTeam(nanoID) then
			if (SpGetUnitSeparation(near_unit, nanoID, true) - SpGetUnitRadius(near_unit)) < radius then
				if SpGetUnitIsBeingBuilt(near_unit) then
					SpGiveOrderToUnit(nanoID, CMD_REPAIR, { near_unit })
					return
				end
			end
		end
	end

	-- give stop command to attached con turret if nothing to do
	SpGiveOrderToUnit(nanoID, CMD.STOP)
end

attached_builders = {}
attached_builder_def = {}
function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	attached_builders[unitID] = nil
	attached_builder_def[unitID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	local unitDef = UnitDefs[unitDefID]
	-- for now, just corvac gets an attached con turret
	if unitDef.name == "corvac" then
		local xx, yy, zz = SpGetUnitPosition(unitID)
		nanoID = Engine.Synced.CreateUnit("corvacct", xx, yy, zz, 0, Engine.Shared.GetUnitTeam(unitID))
		if not nanoID then
			-- unit limit hit or invalid spawn surface
			return
		end
		Engine.Synced.UnitAttach(unitID, nanoID, 3)
		-- makes the attached con turret as non-interacting as possible
		Engine.Synced.SetUnitBlocking(nanoID, false, false, false)
		Engine.Unsynced.SetUnitNoSelect(nanoID, true)
		attached_builders[nanoID] = unitID
		attached_builder_def[nanoID] = SpGetUnitDefID(nanoID)
	end
	if unitDef.name == "legmohobp" then
		local xx, yy, zz = SpGetUnitPosition(unitID)
		nanoID = Engine.Synced.CreateUnit("legmohobpct", xx, yy, zz, 0, Engine.Shared.GetUnitTeam(unitID))
		if not nanoID then
			-- unit limit hit or invalid spawn surface
			return
		end
		Engine.Synced.UnitAttach(unitID, nanoID, 3)
		-- makes the attached con turret as non-interacting as possible
		Engine.Synced.SetUnitBlocking(nanoID, false, false, false)
		Engine.Unsynced.SetUnitNoSelect(nanoID, false)
		attached_builders[nanoID] = unitID
		attached_builder_def[nanoID] = SpGetUnitDefID(nanoID)
	end
end

function gadget:GameFrame(gameFrame)
	if gameFrame % 15 == 0 then
		-- go on a slowupdate cycle
		for nanoID, baseUnitID in pairs(attached_builders) do
			auto_repair_routine(nanoID, attached_builder_def[nanoID], baseUnitID)
		end
	end
end
