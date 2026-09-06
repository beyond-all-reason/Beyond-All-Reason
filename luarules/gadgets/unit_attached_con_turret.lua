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
local SpGetFactoryCommands = Spring.GetFactoryCommands
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
local SpGetUnitTransporter = Spring.GetUnitTransporter

local SpGetHeadingFromVector = Spring.GetHeadingFromVector
local SpGetUnitHeading = Spring.GetUnitHeading
local SpCallCOBScript = Spring.CallCOBScript
local SendToUnsynced = SendToUnsynced

local resolveAttachPiece = VFS.Include("luarules/gadgets/include/unit_attachments.lua").ResolveAttachPiece
local SpUnitAttach = Spring.UnitAttach

--repairs and reclaims start at the edge of the unit radius
--so we need to increase our search radius by the maximum unit radius
local max_unit_radius = 0
local attached_builders = {} ---@type table<integer, integer?>
local attached_turrets = {} ---@type table<integer, integer?>
local cobScriptTurrets = {} ---@type table<integer, true?>

local function auto_repair_routine(nanoID, unitDefID, baseUnitID)
	local transporterID = SpGetUnitTransporter(baseUnitID)
	if transporterID then
		Spring.GiveOrderToUnit(nanoID, CMD_STOP, {}, 0)
		return
	end
	-- first, check command the body is performing
	local baseDefID = SpGetUnitDefID(baseUnitID)
	local getQueue = (baseDefID and UnitDefs[baseDefID].isFactory) and SpGetFactoryCommands or SpGetUnitCommands
	local commandQueue = getQueue(baseUnitID, 1) or {}
	if commandQueue[1] ~= nil and commandQueue[1].id < 0 then
		-- build command
		-- The attached turret must have the same buildlist as the body for this to work correctly
		--for XX, YY, baseUnitID in pairs(commandQueue[1]["params"]) do
		--	Spring.Echo(XX, YY)
		--end
		SpGiveOrderToUnit(nanoID, commandQueue[1].id, commandQueue[1].params)
	end
	if commandQueue[1] ~= nil and commandQueue[1].id == CMD_REPAIR then
		-- repair command
		--for XX, YY, baseUnitID in pairs(commandQueue[1]["params"]) do
		--	Spring.Echo(XX, YY)
		--end
		if #commandQueue[1].params ~= 4 then
			SpGiveOrderToUnit(nanoID, CMD_REPAIR, commandQueue[1].params)
		end
	end
	if commandQueue[1] ~= nil and commandQueue[1].id == CMD_RECLAIM then
		-- reclaim command
		if #commandQueue[1].params ~= 4 then
			SpGiveOrderToUnit(nanoID, CMD_RECLAIM, commandQueue[1].params)
		end
	end

	-- next, check to see if current command (including command from chassis) is in range
	commandQueue = SpGetUnitCommands(nanoID, 1)
	local ux, uy, uz = SpGetUnitPosition(nanoID)
	local tx, ty, tz
	local radius = UnitDefs[unitDefID].buildDistance
	local distance = radius ^ 2 + 1
	local object_radius = 0
	if commandQueue[1] ~= nil and commandQueue[1].id < 0 then
		-- out of range build command
		object_radius = SpGetUnitDefDimensions(-commandQueue[1].id).radius
		tx, tz = commandQueue[1].params[1], commandQueue[1].params[3]
		distance = math.sqrt((ux - tx) ^ 2 + (uz - tz) ^ 2) - object_radius
	end
	if commandQueue[1] ~= nil and commandQueue[1].id == CMD_REPAIR then
		-- out of range repair command
		if commandQueue[1].params[1] >= Game.maxUnits then
			tx, ty, tz = SpGetFeaturePosition(commandQueue[1].params[1] - Game.maxUnits)
			object_radius = SpGetFeatureRadius(commandQueue[1].params[1] - Game.maxUnits)
		else
			tx, ty, tz = SpGetUnitPosition(commandQueue[1].params[1])
			object_radius = SpGetUnitRadius(commandQueue[1].params[1])
		end
		if tx ~= nil then
			distance = math.sqrt((ux - tx) ^ 2 + (uz - tz) ^ 2) - object_radius
		end
	end
	if commandQueue[1] ~= nil and commandQueue[1].id == CMD_RECLAIM then
		-- out of range reclaim command
		if commandQueue[1].params[1] >= Game.maxUnits then
			tx, ty, tz = SpGetFeaturePosition(commandQueue[1].params[1] - Game.maxUnits)
			object_radius = SpGetFeatureRadius(commandQueue[1].params[1] - Game.maxUnits)
		else
			tx, ty, tz = SpGetUnitPosition(commandQueue[1].params[1])
			object_radius = SpGetUnitRadius(commandQueue[1].params[1])
		end
		if tx ~= nil then
			distance = math.sqrt((ux - tx) ^ 2 + (uz - tz) ^ 2) - object_radius
		end
	end
	if tx and distance <= radius then
		-- probably don't even need this for COB, but w/e:
		if cobScriptTurrets[unitDefID] then
			local heading1 = SpGetHeadingFromVector(ux - tx, uz - tz)
			local heading2 = SpGetUnitHeading(nanoID)
			SpCallCOBScript(nanoID, "UpdateHeading", 0, heading1 - heading2 + 32768)
		end
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
				if
					buildProgress == 1
					and health < maxHealth
					and UnitDefs[near_defid].repairable
					and near_unit ~= attached_builders[nanoID]
				then
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

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local hostID = attached_builders[unitID]
	if hostID then
		attached_turrets[hostID] = nil
	end
	attached_builders[unitID] = nil

	local nanoID = attached_turrets[unitID]
	if nanoID then
		attached_turrets[unitID] = nil
		attached_builders[nanoID] = nil
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	local nanoID = attached_turrets[unitID]
	-- Best-effort since the engine can refuse transfer:
	if nanoID and Spring.GetUnitTeam(nanoID) ~= newTeam then
		Spring.TransferUnit(nanoID, newTeam)
	end
end

-- customparams.attached_con_turret names the turret def to spawn and attach on finish;
-- customparams.attached_con_turret_noselect additionally hides it from selection/groups
--
-- By default, attached units are hidden; they are difficult to select and should not act
-- like a separate unit, rather as a "paired" set with one real and one virtual unit.
-- Scav copies inherit the params, but historically never got a turret, so are excluded.
local attachedTurretDef = {} -- unitDefID -> { con = defname, noSelect = bool }
local turretDefIDs = {}
for udid, ud in pairs(UnitDefs) do
	local con = ud.customParams.attached_con_turret
	if
		con
		and UnitDefNames[con]
		and not ud.customParams.isscavenger
		and not ud.customParams.attached_con_turret_mex
	then
		attachedTurretDef[udid] = {
			con = con,
			select = ud.customParams.attached_con_turret_select and true or false,
		}
		turretDefIDs[UnitDefNames[con].id] = true
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	local data = attachedTurretDef[unitDefID]
	if not data then
		return
	end

	local piece = resolveAttachPiece(unitID)
	if not piece then
		return
	end

	local xx, yy, zz = SpGetUnitPosition(unitID)
	local nanoID = Spring.CreateUnit(data.con, xx, yy, zz, 0, Spring.GetUnitTeam(unitID))
	if not nanoID then
		-- unit limit hit or invalid spawn surface
		return
	end
	Spring.UnitAttach(unitID, nanoID, piece, true)
	-- makes the attached con turret as non-interacting as possible
	Spring.SetUnitBlocking(nanoID, false, false, false)
	Spring.SetUnitNoSelect(nanoID, not data.select)
	if not data.select then
		SendToUnsynced("setUnitNoGroup", nanoID, true)
	end
	attached_builders[nanoID] = unitID
	attached_turrets[unitID] = nanoID
end

function gadget:GameFrame(gameFrame)
	if gameFrame % 15 == 0 then
		-- go on a slowupdate cycle
		for nanoID, baseUnitID in pairs(attached_builders) do
			auto_repair_routine(nanoID, SpGetUnitDefID(nanoID), baseUnitID)
		end
	end
end

function gadget:Initialize()
	-- For /luarules reload, get max unit dims and reattach+register turrets.
	local radius = 0
	for _, udef in pairs(UnitDefs) do
		radius = SpGetUnitDefDimensions(udef.id).radius
		max_unit_radius = math.max(radius, max_unit_radius)
	end
	for _, nanoID in pairs(Spring.GetAllUnits()) do
		if turretDefIDs[SpGetUnitDefID(nanoID)] then
			local hostID = SpGetUnitTransporter(nanoID)
			if hostID and attachedTurretDef[SpGetUnitDefID(hostID)] then
				attached_builders[nanoID] = hostID
				attached_turrets[hostID] = nanoID
			end
		end
	end
end
