local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Desolation",
		desc = "Cheat command to wipe team 0 down to a power quota",
		author = "SethDGamre",
		date = "2026-05-21",
		layer = 0,
		enabled = false,
	}
end

local DESOLATION_TEAM = 0
local DESOLATION_QUOTA_RATIO = 0.2
local TURRET_RADIUS = 200
local TURRET_RADIUS_SQR = TURRET_RADIUS * TURRET_RADIUS
local FAVORED_PICK_CHANCE = 0.25
local CORPSE_CHANCE = 0.33
local HEAP_OVERKILL_MULTIPLIER = 3
local STAGGER_MAX_SECONDS = 10
local EXTREME_DAMAGE = 999999

local DEATH_CORPSE = 1
local DEATH_HEAP = 2
local DEATH_EXPLODE = 3
local DEATH_NEUTRAL = 4

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitPosition = Spring.GetUnitPosition
local spGetTeamUnits = Spring.GetTeamUnits
local spAddUnitDamage = Spring.AddUnitDamage
local spValidUnitID = Spring.ValidUnitID
local mathRandom = math.random
local mathMax = math.max
local mathFloor = math.floor

local isCommander = {}
local deathQueue = {}
local deathsThisFrame = {}
local turretDefs = {}
local commanderDefs = {}

local function isCommanderUnit(unitDefID)
	return isCommander[unitDefID]
end

local function getUnitPower(unitDefID)
	local unitDef = UnitDefs[unitDefID]
	return unitDef and unitDef.power or 0
end

local function getMaxCommanderPower()
	local maxPower = 0
	for unitDefID in pairs(isCommander) do
		maxPower = mathMax(maxPower, getUnitPower(unitDefID))
	end
	return maxPower
end

local function getCommanderPowerOnTeam(teamID)
	local teamUnits = spGetTeamUnits(teamID)
	for unitIndex = 1, #teamUnits do
		local unitDefID = spGetUnitDefID(teamUnits[unitIndex])
		if isCommanderUnit(unitDefID) then
			return getUnitPower(unitDefID)
		end
	end
	return 0
end

local function getTeamPowerExcludingCommanders(teamID)
	local totalPower = 0
	local teamUnits = spGetTeamUnits(teamID)
	for unitIndex = 1, #teamUnits do
		local unitDefID = spGetUnitDefID(teamUnits[unitIndex])
		if unitDefID and not isCommanderUnit(unitDefID) then
			totalPower = totalPower + getUnitPower(unitDefID)
		end
	end
	return totalPower
end

local function isTurret(unitDef)
	if unitDef.canMove then
		return false
	end
	if not unitDef.weapons or #unitDef.weapons == 0 then
		return false
	end
	if unitDef.buildOptions and #unitDef.buildOptions > 0 then
		return false
	end
	Spring.Echo(unitDef.name, "is turret")
	return true
end

--collect defs
for unitDefID, unitDef in ipairs(UnitDefs) do
	if isTurret(unitDef) then
		turretDefs[unitDefID] = true
	end
	if isCommanderUnit(unitDefID) then
		commanderDefs[unitDefID] = true
	end
end

local function shuffleTable(unitList)
	for index = #unitList, 2, -1 do
		local swapIndex = mathRandom(index)
		unitList[index], unitList[swapIndex] = unitList[swapIndex], unitList[index]
	end
end

local function popRandomUnit(favoredUnits, unfavoredUnits)
	local favoredCount = #favoredUnits
	local unfavoredCount = #unfavoredUnits
	if favoredCount == 0 and unfavoredCount == 0 then
		return nil
	end
	if favoredCount > 0 and (unfavoredCount == 0 or mathRandom() < FAVORED_PICK_CHANCE) then
		return favoredUnits[favoredCount], favoredUnits, favoredCount - 1
	end
	return unfavoredUnits[unfavoredCount], unfavoredUnits, unfavoredCount - 1
end

local function getStaggerFrames()
	return mathFloor(Game.gameSpeed * STAGGER_MAX_SECONDS)
end

local function queueUnitDeath(unitID, deathType, unitDefID)
	if deathQueue[unitID] then
		return
	end
	local staggerFrames = getStaggerFrames()
	deathQueue[unitID] = {
		frame = Spring.GetGameFrame() + mathRandom(0, staggerFrames),
		deathType = deathType,
		unitDefID = unitDefID,
	}
end

local function killUnitAsCorpse(unitID)
	local health = spGetUnitHealth(unitID)
	if health and health > 0 then
		spAddUnitDamage(unitID, health, 0, nil, -1)
	end
end

local function killUnitAsHeap(unitID)
	local health, maxHealth = spGetUnitHealth(unitID)
	if maxHealth and maxHealth > 0 then
		spAddUnitDamage(unitID, maxHealth * HEAP_OVERKILL_MULTIPLIER, 0, nil, -1)
	elseif health and health > 0 then
		spAddUnitDamage(unitID, health, 0, nil, -1)
	end
end

local function killUnitNoWreck(unitID)
	spAddUnitDamage(unitID, EXTREME_DAMAGE, 0, nil, -1)
end

local function neutralizeUnit(unitID, unitDefID)
	Spring.SetUnitNeutral(unitID, true)
	local weaponIndex = 0
	for weaponNum in pairs(UnitDefs[unitDefID].weapons) do
		Spring.UnitWeaponHoldFire(unitID, weaponNum)
		weaponIndex = weaponIndex + 1
	end
	if weaponIndex > 0 then
		Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, 0)
		Spring.SetUnitTarget(unitID, nil)
		if GameCMD and GameCMD.UNIT_CANCEL_TARGET then
			Spring.GiveOrderToUnit(unitID, GameCMD.UNIT_CANCEL_TARGET, {}, {})
		end
	end
end

local function executeQueuedDeath(unitID, deathType, unitDefID)
	if not spValidUnitID(unitID) then
		return
	end
	if deathType == DEATH_CORPSE then
		killUnitAsCorpse(unitID)
	elseif deathType == DEATH_HEAP then
		killUnitAsHeap(unitID)
	elseif deathType == DEATH_EXPLODE then
		killUnitNoWreck(unitID)
	elseif deathType == DEATH_NEUTRAL and unitDefID then
		neutralizeUnit(unitID, unitDefID)
	end
end

local function processDeathQueue(gameFrame)
	local deathCount = 0
	for unitID, queuedDeath in pairs(deathQueue) do
		if gameFrame >= queuedDeath.frame then
			deathCount = deathCount + 1
			deathsThisFrame[deathCount] = unitID
		end
	end
	for deathIndex = 1, deathCount do
		local unitID = deathsThisFrame[deathIndex]
		deathsThisFrame[deathIndex] = nil
		local queuedDeath = deathQueue[unitID]
		deathQueue[unitID] = nil
		if queuedDeath then
			executeQueuedDeath(unitID, queuedDeath.deathType, queuedDeath.unitDefID)
		end
	end
end

local function queueFinishRemainingUnit(unitID, unitDefID)
	if isCommanderUnit(unitDefID) then
		return
	end
	local unitDef = UnitDefs[unitDefID]
	if mathRandom() < CORPSE_CHANCE then
		queueUnitDeath(unitID, DEATH_CORPSE, unitDefID)
	elseif isTurret(unitDef) then
		queueUnitDeath(unitID, DEATH_NEUTRAL, unitDefID)
	else
		queueUnitDeath(unitID, DEATH_HEAP, unitDefID)
	end
end

local function executeDesolation()
	if not GG.PowerLib or not GG.PowerLib.AveragePlayerTeamPower then
		Spring.Echo("Desolation: PowerLib unavailable")
		return
	end

	local averagePower = GG.PowerLib.AveragePlayerTeamPower() or 0
	local commanderPower = getCommanderPowerOnTeam(DESOLATION_TEAM)
	if commanderPower == 0 then
		commanderPower = getMaxCommanderPower()
	end
	local desolationQuota = averagePower * DESOLATION_QUOTA_RATIO
	local remainingPower = getTeamPowerExcludingCommanders(DESOLATION_TEAM)
	local queuedDeaths = 0

	local teamUnits = spGetTeamUnits(DESOLATION_TEAM)
	local turrets = {}
	local remainingUnits = {}

	for unitIndex = 1, #teamUnits do
		local unitID = teamUnits[unitIndex]
		local unitDefID = spGetUnitDefID(unitID)
		if not isCommanderUnit(unitDefID) then
			local unitDef = UnitDefs[unitDefID]
			local unitX, _, unitZ = spGetUnitPosition(unitID)
			remainingUnits[#remainingUnits + 1] = {
				unitID = unitID,
				unitDefID = unitDefID,
				unitDef = unitDef,
				x = unitX,
				z = unitZ,
			}
			if isTurret(unitDef) and unitX and unitZ then
				turrets[#turrets + 1] = { x = unitX, z = unitZ }
			end
		end
	end

	local favoredUnits = {}
	local unfavoredUnits = {}

	for unitIndex = 1, #remainingUnits do
		local unitData = remainingUnits[unitIndex]
		local nearTurret = false
		for turretIndex = 1, #turrets do
			local turretData = turrets[turretIndex]
			local deltaX = unitData.x - turretData.x
			local deltaZ = unitData.z - turretData.z
			if deltaX * deltaX + deltaZ * deltaZ <= TURRET_RADIUS_SQR then
				nearTurret = true
				break
			end
		end
		if nearTurret then
			favoredUnits[#favoredUnits + 1] = unitData.unitID
		else
			unfavoredUnits[#unfavoredUnits + 1] = unitData.unitID
		end
	end

	shuffleTable(favoredUnits)
	shuffleTable(unfavoredUnits)

	while remainingPower > desolationQuota do
		local pickedUnitID, pickTable, newCount = popRandomUnit(favoredUnits, unfavoredUnits)
		if not pickedUnitID then
			break
		end
		pickTable[newCount + 1] = nil
		local pickedUnitDefID = spGetUnitDefID(pickedUnitID)
		if pickedUnitDefID then
			local unitPower = getUnitPower(pickedUnitDefID)
			remainingPower = remainingPower - unitPower
			queueUnitDeath(pickedUnitID, DEATH_EXPLODE)
			queuedDeaths = queuedDeaths + 1
		end
	end

	local finishQueued = 0
	for unitIndex = 1, #remainingUnits do
		local unitData = remainingUnits[unitIndex]
		if not deathQueue[unitData.unitID] then
			queueFinishRemainingUnit(unitData.unitID, unitData.unitDefID)
			finishQueued = finishQueued + 1
		end
	end

	Spring.Echo(string.format(
		"Desolation: team %d keep %.0f non-cmd power (20%% of avg %.0f) + commander %.0f, after cull %.0f, culled %d finished %d over %ds",
		DESOLATION_TEAM,
		desolationQuota,
		averagePower,
		commanderPower,
		remainingPower,
		queuedDeaths,
		finishQueued,
		STAGGER_MAX_SECONDS
	))
end

local function desolationCommand(cmd, line, words, playerID)
	if not Spring.IsCheatingEnabled() then
		return
	end
	executeDesolation()
end

if gadgetHandler:IsSyncedCode() then

	for unitDefID, unitDef in ipairs(UnitDefs) do
		if unitDef.customParams.iscommander or unitDef.customParams.isscavcommander then
			isCommander[unitDefID] = true
		end
	end

	function gadget:GameFrame(gameFrame)
		processDeathQueue(gameFrame)
	end

	function gadget:Initialize()
		gadgetHandler:AddChatAction("desolation", desolationCommand, "Wipes team 0 to 20% of average player power + commander. Requires /cheat")
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("desolation")
	end

end
