local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "gaia critter units",
		desc = "units spawn and wander around the map",
		author = "Floris (original: knorke, 2013)",
		date = "2016",
		license = "GNU GPL, v2 or later",
		layer = -100, --negative, otherwise critters spawned by gadget do not disappear on death (spawned with /give they always die)
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local critterConfig = VFS.Include("LuaRules/configs/critters.lua")

local amountMultiplier = tonumber(Spring.GetModOptions().critters) or 1.0
local minMultiplier = 0.2
local maxMultiplier = 5.0

local minTotalUnits = 3000
local maxTotalUnits = 6000
local minCritterFraction = 0.2
local minCritters = math.ceil((Game.mapSizeX * Game.mapSizeZ) / 6000000)

local updateFramesCompanions = 77
local updateFramesPopulation = 202

local patrolPoints = 6
local patrolRadiusCreated = 300
local patrolRadiusIdle = 220
local flyingPatrolRadiusCreated = 1500
local flyingPatrolRadiusIdle = 750
local waterPatrolRadius = 1000
local waterPatrolAttempts = 150

local companionRadiusStart = 140
local companionRadiusAfterStart = 13
local companionPatrolRadius = 200

local random = math.random
local round, ceil, max, min, abs = math.round, math.ceil, math.max, math.min, math.abs
local mix, smoothstep = math.mix, math.smoothstep
local sin, cos, rad = math.sin, math.cos, math.rad

local GetGroundHeight = Spring.GetGroundHeight
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitTeam = Spring.GetUnitTeam
local GetUnitHealth = Spring.GetUnitHealth
local GetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local GetUnitRulesParam = Spring.GetUnitRulesParam
local SetUnitHealth = Spring.SetUnitHealth
local SetUnitMaxHealth = Spring.SetUnitMaxHealth
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit
local CreateUnit = Spring.CreateUnit
local DestroyUnit = Spring.DestroyUnit

local CMD_PATROL = CMD.PATROL
local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_ATTACK = CMD.ATTACK
local CMD_OPT_SHIFT = CMD.OPT_SHIFT

local GaiaTeamID = Spring.GetGaiaTeamID()
local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ

local isCritter = {} ---@type table<UnitDefID, true?>
local isFlyingCritter = {} ---@type table<UnitDefID, true?>
local isCommander = {} ---@type table<UnitDefID, true?>
local moveTypeDataSetter = {} ---@type table<UnitDefID, function?> -- TODO: replace with new attributes module

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.iscritter then
		isCritter[unitDefID] = true
		if unitDef.canFly then
			isFlyingCritter[unitDefID] = true
			if unitDef.isHoveringAirUnit then
				moveTypeDataSetter[unitDefID] = Spring.MoveCtrl.SetGunshipMoveTypeData
			else
				moveTypeDataSetter[unitDefID] = Spring.MoveCtrl.SetAirMoveTypeData
			end
		elseif not unitDef.isImmobile then
			moveTypeDataSetter[unitDefID] = Spring.MoveCtrl.SetGroundMoveTypeData
		end
	elseif unitDef.customParams.iscommander then
		isCommander[unitDefID] = true
	end
end

local mapConfig
local spawningMapCritters = false
local mapCritters = {} ---@type table<UnitID, string?>
local mapCritterBackup = {} ---@type table[]
local commanders = {} ---@type table<UnitID, true?>
local companionCritters = {} ---@type table<UnitID, table?>
local companionData = {} ---@type table<UnitID, table?>

local function getRandomPointInArea(area)
	if area.x1 then
		return area.x1 + random() * (area.x2 - area.x1), area.z1 + random() * (area.z2 - area.z1)
	end
	local a = rad(random(0, 360))
	local r = random() * area.radius
	return area.x + r * sin(a), area.z + r * cos(a)
end

local function givePatrolOrders(unitID, area, maxWaterHeight)
	local orders = {}
	local attempts = maxWaterHeight and waterPatrolAttempts or patrolPoints
	for _ = 1, attempts do
		local x, z = getRandomPointInArea(area)
		if x > 0 and z > 0 and x < mapSizeX and z < mapSizeZ then
			local y = GetGroundHeight(x, z)
			if not maxWaterHeight or y < maxWaterHeight then
				orders[#orders + 1] = { CMD_PATROL, { x, y, z }, #orders == 0 and 0 or CMD_OPT_SHIFT }
				if #orders == patrolPoints then
					break
				end
			end
		end
	end
	if #orders > 0 then
		GiveOrderArrayToUnit(unitID, orders)
	end
end

local function patrolAround(unitID, radius)
	local x, _, z = GetUnitPosition(unitID)
	if x then
		givePatrolOrders(unitID, { x = x, z = z, radius = radius })
	end
end

local function getWaterPatrolArea(spawnArea, x, z)
	if spawnArea.x1 then
		return {
			x1 = max(spawnArea.x1, x - waterPatrolRadius),
			z1 = max(spawnArea.z1, z - waterPatrolRadius),
			x2 = min(spawnArea.x2, x + waterPatrolRadius),
			z2 = min(spawnArea.z2, z + waterPatrolRadius),
		}
	elseif spawnArea.radius < waterPatrolRadius then
		return spawnArea
	end
	return { x = x, z = z, radius = waterPatrolRadius }
end

local function spawnMapCritters(config)
	spawningMapCritters = true
	for _, area in pairs(config) do
		local spawnArea = area.spawnBox or area.spawnCircle
		for unitName, unitAmount in pairs(area.unitNames or {}) do
			local unitDef = UnitDefNames[unitName]
			if not unitDef then
				Spring.Echo("[Gaia Critters] Unknown critter " .. tostring(unitName))
			else
				local maxWaterHeight
				if unitDef.minWaterDepth > 0 and not area.nowatercheck then
					maxWaterHeight = -unitDef.minWaterDepth
				end
				-- Give small amounts with small multipliers a chance to spawn, else bias downward slightly.
				-- A tiny amount of randomness prevents companions from becoming an info leak on commanders.
				local amount = unitAmount * amountMultiplier
				amount = amount <= 0 and 0 or amount + random() * 0.75 * (amount < 1 and 1 or -1)
				for _ = 1, round(amount, 0) do
					local x, z = getRandomPointInArea(spawnArea)
					local y = GetGroundHeight(x, z)
					if not maxWaterHeight or y < maxWaterHeight then
						local unitID = CreateUnit(unitName, x, y, z, 0, GaiaTeamID)
						if not unitID then
							Spring.Echo("[Gaia Critters] Failed to create " .. unitName)
						elseif maxWaterHeight then
							givePatrolOrders(unitID, getWaterPatrolArea(spawnArea, x, z), maxWaterHeight)
						else
							givePatrolOrders(unitID, spawnArea)
						end
					end
				end
			end
		end
	end
	spawningMapCritters = false
end

local function setGaiaCritterSpecifics(unitID, unitDefID)
	Spring.SetUnitNeutral(unitID, true)
	Spring.SetUnitNoSelect(unitID, true)
	Spring.SetUnitStealth(unitID, true)
	Spring.SetUnitNoMinimap(unitID, true)
	Spring.SetUnitMaxHealth(unitID, 2)
	Spring.SetUnitBlocking(unitID, false)
	Spring.SetUnitSensorRadius(unitID, "los", 0)
	Spring.SetUnitSensorRadius(unitID, "airLos", 0)
	Spring.SetUnitSensorRadius(unitID, "radar", 0)
	Spring.SetUnitSensorRadius(unitID, "sonar", 0)
	if #UnitDefs[unitDefID].weapons > 0 then
		GiveOrderToUnit(unitID, CMD_FIRE_STATE, { 0 }, 0)
	end
end

local function getPlayerUnitCount()
	local count = 0
	local teamList = Spring.GetTeamList()
	for i = 1, #teamList do
		local teamID = teamList[i]
		if teamID ~= GaiaTeamID then
			count = count + (Spring.GetTeamUnitCount(teamID) or 0)
		end
	end
	return count
end

local function getMapCritterCount()
	local count = 0
	for _ in pairs(mapCritters) do
		count = count + 1
	end
	return count
end

local function cullMapCritters(count)
	for unitID, unitName in pairs(mapCritters) do
		if count <= 0 then
			break
		end
		local x, y, z = GetUnitPosition(unitID)
		if x then
			mapCritters[unitID] = nil
			mapCritterBackup[#mapCritterBackup + 1] = { unitName = unitName, x = x, y = y, z = z }
			DestroyUnit(unitID, false, true)
			count = count - 1
		end
	end
end

local function restoreMapCritters(count)
	while count > 0 and #mapCritterBackup > 0 do
		local critter = mapCritterBackup[#mapCritterBackup]
		mapCritterBackup[#mapCritterBackup] = nil
		CreateUnit(critter.unitName, critter.x, critter.y, critter.z, 0, GaiaTeamID)
		count = count - 1
	end
end

local function adjustMapCritterPopulation()
	local alive = getMapCritterCount()
	local total = alive + #mapCritterBackup
	if total == 0 then
		return
	end
	local crowding = smoothstep(minTotalUnits, maxTotalUnits, getPlayerUnitCount())
	local critterFraction = mix(1.0, minCritterFraction, crowding)
	local target = max(ceil(total * critterFraction), min(minCritters, total))
	if target < alive then
		cullMapCritters(alive - target)
	elseif target > alive then
		restoreMapCritters(target - alive)
	end
end

local function setCompanionSpeed(companionID, speed)
	local setMoveTypeData = moveTypeDataSetter[GetUnitDefID(companionID)]
	if setMoveTypeData then
		setMoveTypeData(companionID, { maxSpeed = speed, maxWantedSpeed = speed })
	end
end

local function syncCompanionToCommander(companionID, data, commanderID)
	local health = GetUnitHealth(companionID)
	local _, commanderMaxHealth = GetUnitHealth(commanderID)
	local commanderMoveType = GetUnitMoveTypeData(commanderID)
	if not health or not commanderMaxHealth or not commanderMoveType then
		return
	end
	local boostedMaxHealth = max(data.maxHealth, commanderMaxHealth)
	local damage = data.boostedMaxHealth - health
	data.boostedMaxHealth = boostedMaxHealth
	SetUnitMaxHealth(companionID, boostedMaxHealth)
	SetUnitHealth(companionID, boostedMaxHealth - damage)
	setCompanionSpeed(companionID, max(data.speed, commanderMoveType.maxSpeed))
end

local function addCompanion(companionID, data, commanderID)
	local companions = companionCritters[commanderID] or {}
	companions[companionID] = true
	companionCritters[commanderID] = companions
	data.commanderID = commanderID
	syncCompanionToCommander(companionID, data, commanderID)
end

local function removeCompanion(companionID, data)
	companionData[companionID] = nil
	local companions = companionCritters[data.commanderID]
	if companions then
		companions[companionID] = nil
	end
end

local function revertCompanion(companionID, data)
	removeCompanion(companionID, data)
	local health = GetUnitHealth(companionID)
	if not health then
		return
	end
	health = data.maxHealth - (data.boostedMaxHealth - health)
	if health <= 0 then
		DestroyUnit(companionID)
		return
	end
	SetUnitMaxHealth(companionID, data.maxHealth)
	SetUnitHealth(companionID, health)
	setCompanionSpeed(companionID, data.speed)
	mapCritters[companionID] = data.mapCritterName
end

local function pairCompanion(companionID, commanderID)
	if companionData[companionID] then
		return
	end
	local _, maxHealth = GetUnitHealth(companionID)
	local moveType = GetUnitMoveTypeData(companionID)
	if not maxHealth or not moveType then
		return
	end
	local data = {
		commanderID = commanderID,
		maxHealth = maxHealth,
		speed = moveType.maxSpeed,
		boostedMaxHealth = maxHealth,
		mapCritterName = mapCritters[companionID],
	}
	mapCritters[companionID] = nil
	companionData[companionID] = data
	addCompanion(companionID, data, commanderID)
end

local function getNearestCommander(x, z, radius, teamID)
	local nearestID
	local nearestDistanceSq = radius * radius
	for commanderID in pairs(commanders) do
		if not teamID or GetUnitTeam(commanderID) == teamID then
			local cx, _, cz = GetUnitPosition(commanderID)
			if cx then
				local distanceSq = (x - cx) * (x - cx) + (z - cz) * (z - cz)
				if distanceSq < nearestDistanceSq then
					nearestID = commanderID
					nearestDistanceSq = distanceSq
				end
			end
		end
	end
	return nearestID ---@as UnitID?
end

local function pairCritterNearCommander(unitID, radius, teamID)
	local x, _, z = GetUnitPosition(unitID)
	if not x then
		return
	end
	local commanderID = getNearestCommander(x, z, radius, teamID)
	if commanderID then
		pairCompanion(unitID, commanderID)
	end
end

local function updateCompanions()
	local leash = companionPatrolRadius * 1.1
	for commanderID, companions in pairs(companionCritters) do
		local x, _, z = GetUnitPosition(commanderID)
		if x then
			for companionID in pairs(companions) do
				local cx, _, cz = GetUnitPosition(companionID)
				if cx and cz and (abs(x - cx) > leash or abs(z - cz) > leash) then
					givePatrolOrders(companionID, { x = x, z = z, radius = companionPatrolRadius })
				end
			end
		end
	end
	for unitID in pairs(mapCritters) do
		pairCritterNearCommander(unitID, companionRadiusAfterStart)
	end
end

function gadget:Initialize()
	if amountMultiplier == 0.0 then
		Spring.Echo("[Gaia Critters] Critters disabled via ModOption")
		gadgetHandler:RemoveGadget(self)
		return
	end
	amountMultiplier = max(minMultiplier, min(maxMultiplier, amountMultiplier))

	gadgetHandler:RegisterAllowCommand(CMD_ATTACK) -- isn't this blocked already?

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = GetUnitDefID(unitID)
		if isCommander[unitDefID] then
			commanders[unitID] = true
		elseif isCritter[unitDefID] and GetUnitTeam(unitID) == GaiaTeamID then
			mapCritters[unitID] = UnitDefs[unitDefID].name
		end
	end

	local mapName = Game.mapName:lower()
	for name, config in pairs(critterConfig) do
		if mapName:find(name, 1, true) then
			mapConfig = config
			break
		end
	end
	if not mapConfig then
		Spring.Echo("[Gaia Critters] No critter config for map " .. Game.mapName)
		-- Else the gadget stays loaded so any critters given by other means still patrol:
		if not (BAR.Utilities.IsDevMode() or BAR.Utilities.Gametype.IsSinglePlayer()) then
			gadgetHandler:RemoveGadget()
		end
	end
end

function gadget:GameFrame(gameFrame)
	if gameFrame == 1 and mapConfig then
		spawnMapCritters(mapConfig)
	end
	if gameFrame % updateFramesCompanions == 1 then
		updateCompanions()
	end
	if gameFrame % updateFramesPopulation == 0 then
		adjustMapCritterPopulation()
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if isCommander[unitDefID] then
		commanders[unitID] = true
	elseif isCritter[unitDefID] then
		if not spawningMapCritters then
			patrolAround(unitID, isFlyingCritter[unitDefID] and flyingPatrolRadiusCreated or patrolRadiusCreated)
		end
		if unitTeam == GaiaTeamID then
			setGaiaCritterSpecifics(unitID, unitDefID)
			mapCritters[unitID] = UnitDefs[unitDefID].name
			pairCritterNearCommander(unitID, companionRadiusStart)
		else
			pairCritterNearCommander(unitID, companionRadiusStart, unitTeam)
		end
	end
end

function gadget:UnitIdle(unitID, unitDefID)
	if isCritter[unitDefID] then
		patrolAround(unitID, isFlyingCritter[unitDefID] and flyingPatrolRadiusIdle or patrolRadiusIdle)
	end
end

function gadget:UnitDestroyed(unitID)
	mapCritters[unitID] = nil
	local data = companionData[unitID]
	if data then
		removeCompanion(unitID, data)
	end
	if not commanders[unitID] then
		return
	end
	commanders[unitID] = nil

	local companions = companionCritters[unitID]
	if not companions then
		return
	end
	companionCritters[unitID] = nil
	-- Evolution destroys the old commander _after_ creating the new unit.
	local evolvedID = GetUnitRulesParam(unitID, "unit_evolved")
	for companionID in pairs(companions) do
		local companion = companionData[companionID]
		if companion then
			if evolvedID and commanders[evolvedID] then
				addCompanion(companionID, companion, evolvedID)
			else
				revertCompanion(companionID, companion)
			end
		end
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams)
	return #cmdParams ~= 1 or not (mapCritters[cmdParams[1]] or companionData[cmdParams[1]])
end
