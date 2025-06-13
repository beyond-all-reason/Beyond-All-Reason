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

local function updateAttachedTurret(unitID,unitDefID)

	-- first, check command the body is performing
	local commandQueue = SpGetUnitCommands(attachedUnits[unitID], 1)
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
	local radius = attachedUnitBuildRadius[unitDefID]
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
	local units = SpGetUnitsInCylinder(ux,uz,radius + unitDefRadiusMax)

	for _, nearID in pairs(units) do
		-- check for free repairs
		local nearDefID = SpGetUnitDefID(nearID)
		if SpGetUnitAllyTeam(nearID) == SpGetUnitAllyTeam(unitID) then
			if ( (SpGetUnitSeparation(nearID,unitID,true) - SpGetUnitRadius(nearID)) < radius) then
				local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = SpGetUnitHealth(nearID)
				if buildProgress == 1 and health < maxHealth and UnitDefs[nearDefID].repairable and nearID ~= attachedUnits[unitID] then
					SpGiveOrderToUnit(unitID,CMD_REPAIR,{nearID}, {})
					return
				end
			end
		end
	end

	for _, nearID in pairs(units) do
		-- check for enemy to reclaim
		local nearDefID = SpGetUnitDefID(nearID)
		if SpGetUnitAllyTeam(nearID) ~= SpGetUnitAllyTeam(unitID) then
			if ( (SpGetUnitSeparation(nearID,unitID,true) - SpGetUnitRadius(nearID)) < radius) then
				if UnitDefs[nearDefID].reclaimable then
					SpGiveOrderToUnit(unitID,CMD_RECLAIM,{nearID}, {})
					return
				end
			end
		end
	end

	local features = SpGetFeaturesInCylinder(ux,uz,radius + unitDefRadiusMax)
	for _, nearID in pairs(features) do
		-- check for non resurrectable feature to reclaim
		local nearDefID = SpGetFeatureDefID(nearID)
		if ( (SpGetUnitFeatureSeparation(unitID,nearID,true) - SpGetFeatureRadius(nearID)) < radius) then
			if FeatureDefs[nearDefID].reclaimable and SpGetFeatureResurrect(nearID) == "" then
				SpGiveOrderToUnit(unitID,CMD_RECLAIM,{nearID+Game.maxUnits}, {})
				return
			end
		end
	end

	for _, nearID in pairs(units) do
		-- check for nanoframe to build
		if SpGetUnitAllyTeam(nearID) == SpGetUnitAllyTeam(unitID) then
			if ( (SpGetUnitSeparation(nearID,unitID,true) - SpGetUnitRadius(nearID)) < radius) then
				if SpGetUnitIsBeingBuilt(nearID) then
					SpGiveOrderToUnit(unitID,CMD_REPAIR,{nearID}, {})
					return
				end
			end
		end
	end

	-- give stop command to attached con turret if nothing to do
	SpGiveOrderToUnit(unitID,CMD.STOP,{}, {})

end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	attachedUnits[unitID] = nil
	attachedBuilderDefID[unitID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)

	local unitDef = UnitDefs[unitDefID]
	-- for now, just corvac gets an attached con turret
	if unitDef.name == "corvac" then
		local xx,yy,zz = SpGetUnitPosition(unitID)
		turretID = Spring.CreateUnit("corvacct",xx,yy,zz,0,Spring.GetUnitTeam(unitID) )
		if not turretID then
			-- unit limit hit or invalid spawn surface
			return
		end
		Spring.UnitAttach(unitID,turretID,3)
		-- makes the attached con turret as non-interacting as possible
		Spring.SetUnitBlocking(turretID, false, false, false)
		Spring.SetUnitNoSelect(turretID,true)
		attachedUnits[turretID] = unitID
		attachedBuilderDefID[turretID] = SpGetUnitDefID(turretID)
	end
	if unitDef.name == "legmohobp" then
		local xx,yy,zz = SpGetUnitPosition(unitID)
		turretID = Spring.CreateUnit("legmohobpct",xx,yy,zz,0,Spring.GetUnitTeam(unitID) )
		if not turretID then
			-- unit limit hit or invalid spawn surface
			return
		end
		Spring.UnitAttach(unitID,turretID,3)
		-- makes the attached con turret as non-interacting as possible 
		Spring.SetUnitBlocking(turretID, false, false, false)
        Spring.SetUnitNoSelect(turretID,false)
		attachedUnits[turretID] = unitID
		attachedBuilderDefID[turretID] = SpGetUnitDefID(turretID)
	end

end

function gadget:GameFrame(gameFrame)

	if gameFrame % 15 == 0 then
	    -- go on a slowupdate cycle
		for unitID, baseID in pairs(attachedUnits) do
			updateAttachedTurret(unitID,attachedBuilderDefID[unitID])
		end
	end

end
