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

--repairs and reclaims start at the edge of the unit radius
--so we need to increase our search radius by the maximum unit radius
local max_unit_radius = 0
function gadget:Initialize()

	local radius = 0
	for ix, udef in pairs(UnitDefs) do
		dimensions = SpGetUnitDefDimensions(udef.id)
		radius = dimensions.radius
		max_unit_radius = math.max(radius,max_unit_radius)
	end

end

local function auto_repair_routine(unitID,unitDefID)

	-- first, check command the body is performing
	local commandQueue = SpGetUnitCommands(attached_builders[unitID], 1)
	if (commandQueue[1] ~= nil and commandQueue[1]["id"] < 0) then
        -- build command
		-- The attached turret must have the same buildlist as the body for this to work correctly
		--for XX,YY, base_unit_id in pairs(commandQueue[1]["params"]) do
		--	Spring.Echo(XX,YY)
		--end
        SpGiveOrderToUnit(unitID, commandQueue[1]["id"], commandQueue[1]["params"], {})
    end
    if (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_REPAIR) then
        -- repair command
		--for XX,YY, base_unit_id in pairs(commandQueue[1]["params"]) do
		--	Spring.Echo(XX,YY)
		--end
		if #commandQueue[1]["params"] ~= 4 then
			SpGiveOrderToUnit(unitID, CMD_REPAIR, commandQueue[1]["params"], {})
		end
    end
	if (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_RECLAIM) then
        -- reclaim command
		if #commandQueue[1]["params"] ~= 4 then
			SpGiveOrderToUnit(unitID, CMD_RECLAIM, commandQueue[1]["params"], {})
		end
    end

	-- next, check to see if current command (including command from chassis) is in range
	commandQueue = SpGetUnitCommands(unitID, 1)
	local ux,uy,uz = SpGetUnitPosition(unitID)
	local tx, ty, tz
	local radius = UnitDefs[unitDefID].buildDistance
	local distance = radius^2 + 1
	local object_radius = 0
	if (commandQueue[1] ~= nil and commandQueue[1]["id"] < 0) then
        -- out of range build command
		object_radius = SpGetUnitDefDimensions(-commandQueue[1]["id"]).radius
		distance = math.sqrt((ux-commandQueue[1]["params"][1])^2 + (uz-commandQueue[1]["params"][3])^2) - object_radius
    end
    if (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_REPAIR) then
        -- out of range repair command
		if (commandQueue[1]["params"][1] >= Game.maxUnits) then
			tx,ty,tz = SpGetFeaturePosition(commandQueue[1]["params"][1] - Game.maxUnits)
			object_radius = SpGetFeatureRadius(commandQueue[1]["params"][1] - Game.maxUnits)
		else
			tx,ty,tz = SpGetUnitPosition(commandQueue[1]["params"][1])
			object_radius = SpGetUnitRadius(commandQueue[1]["params"][1])
		end
		if tx ~= nil then
			distance = math.sqrt((ux-tx)^2 + (uz-tz)^2) - object_radius
		end
    end
	if (commandQueue[1] ~= nil and commandQueue[1]["id"] == CMD_RECLAIM) then
		-- out of range reclaim command
		if (commandQueue[1]["params"][1] >= Game.maxUnits) then
			tx,ty,tz = SpGetFeaturePosition(commandQueue[1]["params"][1] - Game.maxUnits)
			object_radius = SpGetFeatureRadius(commandQueue[1]["params"][1] - Game.maxUnits)
		else
			tx,ty,tz = SpGetUnitPosition(commandQueue[1]["params"][1])
			object_radius = SpGetUnitRadius(commandQueue[1]["params"][1])
		end
		if tx ~= nil then
			distance = math.sqrt((ux-tx)^2 + (uz-tz)^2) - object_radius
		end
    end
	if tx and distance <= radius then
		--let auto con turret continue its thing
		--update heading, by calling into unit script
		heading1 = SpGetHeadingFromVector(ux-tx,uz-tz)
		heading2 = SpGetUnitHeading(unitID)
		SpCallCOBScript(unitID, 'UpdateHeading', 0, heading1-heading2+32768)
		return
	end

	-- next, check to see if valid repair/reclaim targets in range
	local near_units = SpGetUnitsInCylinder(ux,uz,radius + max_unit_radius)

	for XX, near_unit in pairs(near_units) do
		-- check for free repairs
		local near_defid = SpGetUnitDefID(near_unit)
		if SpGetUnitAllyTeam(near_unit) == SpGetUnitAllyTeam(unitID) then
			if ( (SpGetUnitSeparation(near_unit,unitID,true) - SpGetUnitRadius(near_unit)) < radius) then
				local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = SpGetUnitHealth(near_unit)
				if buildProgress == 1 and health < maxHealth and UnitDefs[near_defid].repairable and near_unit ~= attached_builders[unitID] then
					SpGiveOrderToUnit(unitID,CMD_REPAIR,{near_unit}, {})
					return
				end
			end
		end
	end

	for XX, near_unit in pairs(near_units) do
		-- check for enemy to reclaim
		local near_defid = SpGetUnitDefID(near_unit)
		if SpGetUnitAllyTeam(near_unit) ~= SpGetUnitAllyTeam(unitID) then
			if ( (SpGetUnitSeparation(near_unit,unitID,true) - SpGetUnitRadius(near_unit)) < radius) then
				if UnitDefs[near_defid].reclaimable then
					SpGiveOrderToUnit(unitID,CMD_RECLAIM,{near_unit}, {})
					return
				end
			end
		end
	end

	local near_features = SpGetFeaturesInCylinder(ux,uz,radius + max_unit_radius)
	for XX, near_feature in pairs(near_features) do
		-- check for non resurrectable feature to reclaim
		local near_defid = SpGetFeatureDefID(near_feature)
		if ( (SpGetUnitFeatureSeparation(unitID,near_feature,true) - SpGetFeatureRadius(near_feature)) < radius) then
			if FeatureDefs[near_defid].reclaimable and SpGetFeatureResurrect(near_feature) == "" then
				SpGiveOrderToUnit(unitID,CMD_RECLAIM,{near_feature+Game.maxUnits}, {})
				return
			end
		end
	end

	for XX, near_unit in pairs(near_units) do
		-- check for nanoframe to build
		if SpGetUnitAllyTeam(near_unit) == SpGetUnitAllyTeam(unitID) then
			if ( (SpGetUnitSeparation(near_unit,unitID,true) - SpGetUnitRadius(near_unit)) < radius) then
				if SpGetUnitIsBeingBuilt(near_unit) then
					SpGiveOrderToUnit(unitID,CMD_REPAIR,{near_unit}, {})
					return
				end
			end
		end
	end

	-- give stop command to attached con turret if nothing to do
	SpGiveOrderToUnit(unitID,CMD.STOP,{}, {})

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
		local xx,yy,zz = SpGetUnitPosition(unitID)
		nano_id = Spring.CreateUnit("corvacct",xx,yy,zz,0,Spring.GetUnitTeam(unitID) )
		if not nano_id then
			-- unit limit hit or invalid spawn surface
			return
		end
		Spring.UnitAttach(unitID,nano_id,3)
		-- makes the attached con turret as non-interacting as possible
		Spring.SetUnitBlocking(nano_id, false, false, false)
		Spring.SetUnitNoSelect(nano_id,true)
		attached_builders[nano_id] = unitID
		attached_builder_def[nano_id] = SpGetUnitDefID(nano_id)
	end
	if unitDef.name == "legmohobp" then
		local xx,yy,zz = SpGetUnitPosition(unitID)
		nano_id = Spring.CreateUnit("legmohobpct",xx,yy,zz,0,Spring.GetUnitTeam(unitID) )
		if not nano_id then
			-- unit limit hit or invalid spawn surface
			return
		end
		Spring.UnitAttach(unitID,nano_id,3)
		-- makes the attached con turret as non-interacting as possible 
		Spring.SetUnitBlocking(nano_id, false, false, false)
        Spring.SetUnitNoSelect(nano_id,false)
		attached_builders[nano_id] = unitID
		attached_builder_def[nano_id] = SpGetUnitDefID(nano_id)
	end

end

function gadget:GameFrame(gameFrame)

	if gameFrame % 15 == 0 then
	    -- go on a slowupdate cycle
		for unitID, base_unit_id in pairs(attached_builders) do
			auto_repair_routine(unitID,attached_builder_def[unitID])
		end
	end

end
