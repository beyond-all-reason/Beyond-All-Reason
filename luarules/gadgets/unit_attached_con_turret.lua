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

local SpGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
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

local CMD_CAPTURE = CMD.CAPTURE
local CMD_GUARD = CMD.GUARD
local CMD_RECLAIM = CMD.RECLAIM
local CMD_REPAIR = CMD.REPAIR
local CMD_STOP = CMD.STOP

local FEATURE_BASE_INDEX = Game.maxUnits

--------------------------------------------------------------------------------
-- Command introspection -------------------------------------------------------

-- Parameter counts used with commands
local always = {}; for i = 0, 8 do always[i] = true end
local withParams = {}; for i = 1, 8 do withParams[i] = true end
local never = {}
local buildOrder = { [4] = true, }
local buildTarget = { [1] = true, [5] = true }
local mapPosition = { [3] = true, [4] = true, }

local commandParamAllowed = {
	[CMD.STOP]       = always,
	[CMD.INSERT]     = always,
	[CMD.REMOVE]     = always,
	[CMD.WAIT]       = always,
	[CMD.DEATHWAIT]  = always,
	[CMD.GATHERWAIT] = always,
	[CMD.TIMEWAIT]   = always,

	[CMD.FIRE_STATE] = withParams,
	[CMD.MOVE_STATE] = withParams,
	[CMD.ONOFF]      = withParams,
	[CMD.TRAJECTORY] = withParams,

	[CMD.CAPTURE]    = buildTarget,
	[CMD.RECLAIM]    = buildTarget,
	[CMD.REPAIR]     = buildTarget,
	[CMD.RESURRECT]  = buildTarget,

	[CMD.RESTORE]    = mapPosition,
}

commandParamAllowed = setmetatable(commandParamAllowed, {
	__index = function(self, key)
		return key < 0 and buildOrder or never
	end
})

local moveStateTeamAssist = CMD.MOVESTATE_MANEUVER
local moveStateAllyAssist = CMD.MOVESTATE_ROAM

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

local repack5 -- Same as Lua `pack` but for reusing tables.
do
	local commandParams = table.new(5, 0)

	---@return number[] commandParams where #commandParams := 1|2|3|4|5
	repack5 = function(p1, p2, p3, p4, p5)
		local p = commandParams
		p[1], p[2], p[3], p[4], p[5] = p1, p2, p3, p4, p5
		return p
	end
end

---@return boolean found
local function findGuardOrder(turretID, guardedID)
	local health, healthMax, _, _, buildProgress = SpGetUnitHealth(guardedID)

	if health == nil then
		return false
	end

	local command, params

	if health < healthMax then
		command, params = CMD_REPAIR, guardedID
	elseif buildProgress < 1 then
		command, params = -guardedID, {}
	end

	return command ~= nil and SpGiveOrderToUnit(turretID, command, params)
end

local function auto_repair_routine(unitID, baseID)
	local command, _, _, param1, param2, param3, param4, param5 = SpGetUnitCurrentCommand(baseID)

	if command == CMD_GUARD then
		if findGuardOrder(unitID, param1) then
			return
		else
			-- The engine doesn't do anything special for chained GUARDs, so neither do we:
			command, _, _, param1, param2, param3, param4, param5 = SpGetUnitCurrentCommand(param1)
		end
	end

	local params = repack5(param1, param2, param3, param4, param5)

	if command ~= nil and commandParamAllowed[command][#params] then
		SpGiveOrderToUnit(unitID, command, params)
	end

	local unitDefID = attached_builder_def[unitID]
	local ux, uy, uz = SpGetUnitPosition(unitID)
	local radius = UnitDefs[unitDefID].buildDistance

	-- next, check to see if current command (including command from chassis) is in range

	-- The engine and call-ins can modify our orders, so we *must* re-fetch the current order;
	-- e.g., when executing the build command, the engine prepends orders to reclaim features.
	command, _, _, param1, param2, param3, param4, param5 = SpGetUnitCurrentCommand(unitID)

	local dx, dy, dz
	local distance

	if command ~= nil then
		local paramCount = #(repack5(param1, param2, param3, param4, param5))

		local allowed = commandParamAllowed[command]

		-- Blanket-verify all parameter counts to avoid (e.g.) area commands:
		if allowed == buildTarget then
			if buildTarget[paramCount] then
				local object_radius = 0
				local tx, ty, tz

				if param1 < FEATURE_BASE_INDEX then
					tx, ty, tz = SpGetUnitPosition(param1)
					object_radius = SpGetUnitDefDimensions(-command).radius
					object_radius = SpGetUnitRadius(param1)
				else
					local featureID = param1 - FEATURE_BASE_INDEX
					tx, ty, tz = SpGetFeaturePosition(featureID)
					object_radius = SpGetFeatureRadius(featureID)
				end

				dx = ux - tx
				dy = uy - ty
				dz = uz - tz

				distance = math.sqrt(dx * dx + dy * dy + dz * dz) - object_radius
			end
		elseif
			(allowed == buildOrder and buildOrder[paramCount]) or
			(allowed == mapPosition and mapPosition[paramCount])
		then
			local tx, ty, tz = param1, param2, param3

			dx = ux - tx
			dy = uy - ty
			dz = uz - tz

			distance = math.sqrt(dx * dx + dy * dy + dz * dz)
		elseif allowed[paramCount] then
			-- We may be WAITing, for example.
			return true
		end
	end

	if distance ~= nil and distance <= radius then
		--let auto con turret continue its thing
		--update heading, by calling into unit script
		heading1 = SpGetHeadingFromVector(dx, dz)
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
			auto_repair_routine(unitID, base_unit_id)
		end
	end

end
