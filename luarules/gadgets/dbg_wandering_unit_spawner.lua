function gadget:GetInfo()
	return {
		name    = "Wandering Unit Spawner",
		desc    = "Periodically spawns units at a random location, orders them to the opposite map corner, and despawns them once idle",
		author  = "SethDGamre",
		date    = "July 2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local SPAWN_TECH_LEVEL           = "1"
local ALLOWED_NAME_PREFIXES      = { arm = true, cor = true, leg = true }
local SPAWN_INTERVAL_FRAMES      = 10 * Game.gameSpeed
local IDLE_CHECK_INTERVAL_FRAMES = 3 * Game.gameSpeed
local IDLE_GRACE_FRAMES          = Game.gameSpeed
local MIN_SPAWN_COUNT            = 5
local MAX_SPAWN_COUNT            = 25
local SPAWN_SPREAD               = 128
local CORNER_MARGIN              = 64
local EXCLUDED_TEAM_ID           = 0
local MOVE_ORDER_OPTIONS         = 0

local MAP_SIZE_X                 = Game.mapSizeX
local MAP_SIZE_Z                 = Game.mapSizeZ
local MAP_CENTER_X               = MAP_SIZE_X * 0.5
local MAP_CENTER_Z               = MAP_SIZE_Z * 0.5

local CMD_MOVE                   = CMD.MOVE

local spGetTeamList              = Spring.GetTeamList
local spGetTeamInfo              = Spring.GetTeamInfo
local spGetGroundHeight          = Spring.GetGroundHeight
local spCreateUnit               = Spring.CreateUnit
local spGiveOrderToUnit          = Spring.GiveOrderToUnit
local spGetUnitCurrentCommand    = Spring.GetUnitCurrentCommand
local spValidUnitID              = Spring.ValidUnitID
local spGetUnitIsDead            = Spring.GetUnitIsDead
local spDestroyUnit              = Spring.DestroyUnit
local spGetGameFrame             = Spring.GetGameFrame
local random                     = math.random
local clamp                      = math.clamp

local unitDefs                   = UnitDefs

local spawnUnitDefIDs            = {}
local spawnedUnits               = {}

local function getEligibleTeams()
	local teamList = spGetTeamList()
	local eligibleTeams = {}
	for i = 1, #teamList do
		local teamID = teamList[i]
		local isDead = select(3, spGetTeamInfo(teamID, false))
		if teamID ~= EXCLUDED_TEAM_ID and not isDead then
			eligibleTeams[#eligibleTeams + 1] = teamID
		end
	end
	return eligibleTeams
end

local function getOppositeCorner(spawnX, spawnZ)
	local targetX = spawnX < MAP_CENTER_X and (MAP_SIZE_X - CORNER_MARGIN) or CORNER_MARGIN
	local targetZ = spawnZ < MAP_CENTER_Z and (MAP_SIZE_Z - CORNER_MARGIN) or CORNER_MARGIN
	return targetX, targetZ
end

local function spawnWave()
	if #spawnUnitDefIDs == 0 then
		return
	end

	local eligibleTeams = getEligibleTeams()
	if #eligibleTeams == 0 then
		return
	end

	local currentFrame = spGetGameFrame()
	local spawnCenterX = random(0, MAP_SIZE_X)
	local spawnCenterZ = random(0, MAP_SIZE_Z)
	local targetX, targetZ = getOppositeCorner(spawnCenterX, spawnCenterZ)
	local targetY = spGetGroundHeight(targetX, targetZ)
	local spawnCount = random(MIN_SPAWN_COUNT, MAX_SPAWN_COUNT)
	local teamID = eligibleTeams[random(1, #eligibleTeams)]
	local unitDefID = spawnUnitDefIDs[random(1, #spawnUnitDefIDs)]

	for i = 1, spawnCount do
		local spawnX = clamp(spawnCenterX + random(-SPAWN_SPREAD, SPAWN_SPREAD), 0, MAP_SIZE_X)
		local spawnZ = clamp(spawnCenterZ + random(-SPAWN_SPREAD, SPAWN_SPREAD), 0, MAP_SIZE_Z)
		local spawnY = spGetGroundHeight(spawnX, spawnZ)
		local unitID = spCreateUnit(unitDefID, spawnX, spawnY, spawnZ, 0, teamID)
		if unitID then
			spGiveOrderToUnit(unitID, CMD_MOVE, { targetX, targetY, targetZ }, MOVE_ORDER_OPTIONS)
			spawnedUnits[unitID] = currentFrame
		end
	end
end

local function checkIdleUnits(currentFrame)
	for unitID, spawnFrame in pairs(spawnedUnits) do
		if not spValidUnitID(unitID) or spGetUnitIsDead(unitID) then
			spawnedUnits[unitID] = nil
		elseif currentFrame - spawnFrame >= IDLE_GRACE_FRAMES then
			local currentCommand = spGetUnitCurrentCommand(unitID)
			if not currentCommand then
				spDestroyUnit(unitID, false, true)
				spawnedUnits[unitID] = nil
			end
		end
	end
end

function gadget:GameFrame(frame)
	if frame > 0 and frame % SPAWN_INTERVAL_FRAMES == 0 then
		spawnWave()
	end
	if frame > 0 and frame % IDLE_CHECK_INTERVAL_FRAMES == 0 then
		checkIdleUnits(frame)
	end
end

function gadget:UnitDestroyed(unitID)
	spawnedUnits[unitID] = nil
end

function gadget:Initialize()
	for unitDefID, unitDef in pairs(unitDefs) do
		local customParams = unitDef.customParams
		local unitName = unitDef.name
		local isCommander = unitName and string.find(unitName, "com", 1, true) ~= nil
		local hasAllowedPrefix = unitName and ALLOWED_NAME_PREFIXES[string.sub(unitName, 1, 3)]
		if unitDef.speed and unitDef.speed > 0 and customParams and customParams.techlevel == SPAWN_TECH_LEVEL and not isCommander and hasAllowedPrefix then
			spawnUnitDefIDs[#spawnUnitDefIDs + 1] = unitDefID
		end
	end
	if #spawnUnitDefIDs == 0 then
		Spring.Echo("[WanderingUnitSpawner] No mobile tech " .. tostring(SPAWN_TECH_LEVEL) .. " units found")
		gadgetHandler:RemoveGadget(gadget)
		return
	end
end
