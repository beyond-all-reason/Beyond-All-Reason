local gadget = gadget ---@type Gadget

if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
	return {
		name = "Collateral Target Priority",
		desc = "Target priority for large-area weapons based on nearby units.",
		author = "efrec",
		version = "0.0",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1000, -- process after allow/disallow checks
		enabled = true, -- auto-disables
	}
end

---Anti-collateral weighting should not quash more meaningful power, damage, and positioning.
---We are trying to add a crutch to high-area weapons, not to give them player-intelligence.
local PRIORITY_ANTI_COLLATERAL = 6.5

---Discourage targeting spam mixed with allied units using high-area weapons more strongly.
local PRIORITY_ANTICOLLAT_SPAM = PRIORITY_ANTI_COLLATERAL * 3.0

---The purpose of this gadget is to avoid friendly-fire but not quite to select clean hits.
---I used a weak modifier (close to 1.0) to avoid over-targeting and easy baiting, instead.
local PRIORITY_CLEAN_SHOT = 0.875

---Give friendly units the advantage in power comparisons to spread out target avoidance.
local friendPowerRatio = 1.15

local spamPowerMax = 50.0
local spamRatioMin = 0.2
local allowBadSpamTarget = false ---@type boolean

local unknownRadius = 20.0
local unknownSpeed = 54

local searchRadiusMin = 64.0
local searchDamageMin = 100.0
local effectTarget = 0.20

-- Each update clears half of the unit targeting cache.
local updateInterval = math.round(Game.gameSpeed * 0.5, 0)

-- Lua env globals -------------------------------------------------------------

local math_clamp = math.clamp
local CallAsTeam = CallAsTeam
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local getDamagePerBurst = require("common/weapons").GetDamagePerBurst

-- Initialization --------------------------------------------------------------

-- The positive indices go to radii to avoid. Negative go to radii to prefer.
-- An avoided radius contains allied units. A preferred one is a clean shot.
local targetCache, targetCacheLast = {}, {} ---@type table<AllyTeamID, table>, table<AllyTeamID, table>
do
	local allyTeamList = Spring.GetAllyTeamList()
	for _, allyTeam in pairs(allyTeamList) do
		targetCache[allyTeam] = {}
		targetCacheLast[allyTeam] = targetCache[allyTeam]
	end
end

local updateAllyTeams = table.new(updateInterval, 0)
local frameReset = updateInterval
local frameIndex = frameReset
do
	local allyTeamList = Spring.GetAllyTeamList()
	for _, allyTeam in pairs(allyTeamList) do
		local index = ((allyTeam + 1) % frameReset) + 1
		local group = table.ensureTable(updateAllyTeams, index)
		group[#group + 1] = allyTeam
	end
end

local unitDefValue = table.new(#UnitDefs, 0)
local unitDefRadius = table.new(#UnitDefs, 0)
local unitDefRadiusAverage = 0.0 -- TODO: median or something
local unitDefIsSpam = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	unitDefValue[unitDefID] = unitDef.metalCost + unitDef.energyCost / 70 + unitDef.buildTime / 1000
	unitDefRadiusAverage = unitDefRadiusAverage + unitDef.radius
	unitDefIsSpam[unitDefID] = unitDefValue[unitDefID] <= spamPowerMax
end
unitDefRadiusAverage = unitDefRadiusAverage / #UnitDefs

for unitDefID, unitDef in ipairs(UnitDefs) do
	unitDefRadius[unitDefID] = math.max(unitDef.radius - unitDefRadiusAverage * 0.5, 0)
end

local unitTeam = {} ---@type integer[]
local unitAllyTeam = {} ---@type integer[]
local unitPower = {}
local unitRadius = {}
local unitIsSpam = {}
local readAs = { read = -1 }

local function ignoreWeaponDef(weaponDef)
	return weaponDef.customParams.bogus == "1"
		or weaponDef.manualFire
		or getDamagePerBurst(weaponDef, weaponDef.damages[0]) <= 50
end

local function getWeaponTargetingParent(weapons, weaponNum)
	local parent = weapons[weaponNum]
	while weapons[parent.slavedTo] do
		weaponNum = parent.slavedTo
		parent = weapons[weaponNum]
	end
	return weaponNum, parent
end

-- - We want to aggregate weapons together into piles of stats and modify priority once.
-- - Keep multiple copies of the same weaponDef and check against `testDamageMin` later.
-- - An "ignored" weapon may be used for targeting a non-ignored weapon, e.g. "aimhull".
local function getWeaponGroups(unitDef)
	local groups = {} -- TODO: We are not supporting alternate weapon sets fully, then.

	local weapons = unitDef.weapons
	for weaponNum, weapon in ipairs(weapons) do
		local parentNum = getWeaponTargetingParent(weapons, weaponNum)
		local parentGroup = table.ensureTable(groups, parentNum)
		parentGroup[#parentGroup + 1] = {
			weaponDef = weapon.weaponDef,
			weaponNum = weaponNum,
		}

		-- This skips drone counts for now, so our `testDamageMin` case needs validating.
		local weaponDef = WeaponDefs[weapon.weaponDef] ---@as table
		for _, droneName in ipairs((weaponDef.customParams.carried_unit or ""):split()) do
			if UnitDefNames[droneName] then
				for _, entries in ipairs(getWeaponGroups(UnitDefNames[droneName])) do
					for _, entry in ipairs(entries) do
						parentGroup[#parentGroup + 1] = entry
					end
				end
			end
		end
	end

	return groups
end

local weaponTypesExplosion = {
	Cannon = true,
	BeamLaser = true,
	LaserCannon = true,
	LightningCannon = true,
	MissileLauncher = true,
	TorpedoLauncher = true,
	StarburstLauncher = true,
	AircraftBomb = true,
	-- TODO: Melee?
}

local function getExplosionRadiusEffective(groups, weaponNum, weaponDef)
	local radius, damage = 0.0, 0.0

	if weaponTypesExplosion[weaponDef.type] and not ignoreWeaponDef(weaponDef) then
		-- Start with stats that are based on firing: aiming, accuracy, burst size, etc.
		local scatter = weaponDef.range
			* (
				math.max(weaponDef.accuracy, weaponDef.movingAccuracy * 0.5)
				+ weaponDef.sprayAngle
				+ 0.25 * weaponDef.targetMoveError
			)
		local projectiles = weaponDef.projectiles * weaponDef.salvoSize

		if weaponDef.customParams.speceffect == "sector_fire" then
			local sectorScatter = weaponDef.range * (tonumber(weaponDef.customParams.spread_angle or 0) or 0) * 0.5
			scatter = math.max(scatter, sectorScatter)
		end

		-- Some effects then can replace the delivered payload:
		local isBaseWeapon = weaponDef.customParams.speceffect ~= "split"
			or not WeaponDefNames[weaponDef.customParams.speceffect_def]
		if not isBaseWeapon then
			if WeaponDefNames[weaponDef.customParams.speceffect_def] then
				weaponDef = WeaponDefNames[weaponDef.customParams.speceffect_def]
				scatter = scatter + 32 -- there is no good formula
			end
		end

		local damageMin, damageMax = getDamagePerBurst(weaponDef, weaponDef.damages[0])
		local aoe = weaponDef.damageAreaOfEffect

		-- expMod = (expRadius + 0.001f - expDist) / (expRadius + 0.001f - expDist * expEdgeEffect)
		-- dist@mod (approx) = expRadius * (1 - expMod) / (1 - expEdgeEffect * expMod)
		local effectAtEdge = weaponDef.edgeEffectiveness
		if effectAtEdge < effectTarget then
			aoe = aoe * (1 - effectTarget) / (1 - effectAtEdge * effectTarget)
		end

		local miss = (1 - weaponDef.predictBoost) * unknownSpeed
		if weaponDef.leadLimit > 0 then
			miss = math.min(weaponDef.leadLimit, miss)
		end

		-- Spatial search is via midpoint so add unit radius:
		radius = aoe + scatter + miss + unitDefRadiusAverage
		damage = (damageMin + damageMax) * 0.5 * (isBaseWeapon and 1 or projectiles)

		if weaponDef.customParams.cluster_def then
			local clusterDef = WeaponDefNames[weaponDef.customParams.cluster_def] ---@as table?
			if clusterDef then
				radius = radius + math.max(clusterDef.range - aoe, 0) + clusterDef.damageAreaOfEffect * 0.5
				damage = damage
					+ clusterDef.damages[0]
						* (tonumber(weaponDef.customParams.cluster_number) or 0.0)
						* projectiles
						* 0.5
			end
		elseif weaponDef.customParams.spark_range then
			radius = math.max(radius, (tonumber(weaponDef.customParams.spark_range) or 0.0), 0.0)
			damage = damage * (1 + (tonumber(weaponDef.customParams.spark_forkdamage or 0.0) or 0.0))
		elseif weaponDef.customParams.area_onhit_range then
			radius = radius + math.max((tonumber(weaponDef.customParams.area_onhit_range) or 0.0) - aoe, 0.0)
			damage = damage + (tonumber(weaponDef.customParams.area_onhit_damage) or 0.0) * projectiles
		end

		if weaponDef.paralyzer then
			radius = radius * 0.5
			damage = damage * 0.5
		end
	end

	local subordinates = table.map(groups[weaponNum] or {}, function(w, i)
		return w.weaponNum ~= weaponNum and w or nil, i
	end)
	if next(subordinates) then
		for _, subEntry in pairs(subordinates) do
			local subWeaponDef = WeaponDefs[subEntry.weaponDef]
			local subRadius, subDamage = getExplosionRadiusEffective(groups, subEntry.weaponNum, subWeaponDef)
			radius = math.max(radius, subRadius)
			damage = damage + subDamage
		end
	end

	return radius, damage
end

local weaponSearchRadius = {} ---@type number[]

local function addWeaponCollateral(unitDef)
	local groups = getWeaponGroups(unitDef)
	for weaponNum in pairs(groups) do
		local weapon = unitDef.weapons[weaponNum]
		local weaponDefID = weapon.weaponDef
		local weaponDef = WeaponDefs[weaponDefID]

		local radius, damage = getExplosionRadiusEffective(groups, weaponNum, weaponDef)
		---@cast radius number
		---@cast damage number

		if radius >= searchRadiusMin and damage >= searchDamageMin then
			local searchRadius = weaponSearchRadius[weaponDefID]
			if not searchRadius then
				gadgetHandler:RegisterWeaponTarget(weaponDefID)
				weaponSearchRadius[weaponDefID] = radius
			else
				-- Games that use weaponDefs as shared components likely need to add handling here.
				weaponSearchRadius[weaponDefID] = math.max(searchRadius, radius)
			end
		end
	end
end

-- Local functions -------------------------------------------------------------

local function getUnitCollateral(unitID, allyTeam, radius, targetID)
	local friendPower, enemyPower = 0.0, 0.0

	local _, _, _, tx, ty, tz = spGetUnitPosition(targetID, true)
	---@cast tx -nil
	---@cast ty -nil
	---@cast tz -nil
	local units = spGetUnitsInSphere(tx, ty, tz, radius + (unitRadius[targetID] or unknownRadius))

	for _, foundID in next, units do
		if foundID == unitID then
			--
		elseif unitAllyTeam[foundID] == allyTeam then
			friendPower = friendPower + (unitPower[foundID] or 0.0)
		else
			enemyPower = enemyPower + (unitPower[foundID] or 0.0)
		end
	end

	return friendPower, enemyPower
end

-- Engine callins --------------------------------------------------------------

---@return boolean allow
---@return number? priority
function gadget:AllowWeaponTarget(unitID, targetID, weaponNum, weaponDefID, priority)
	if not priority then
		if allowBadSpamTarget then
			return true
		end
		-- When priority is nil, the value is useless, but we still try to block attacks
		-- against spam units that would cause considerable collateral damage to allies.
		priority = 0.0
	end

	local allyTeam = unitAllyTeam[unitID]
	if not allyTeam then
		return true, priority
	end

	local cache, cacheLast = targetCache[allyTeam], targetCacheLast[allyTeam]
	local searchRadius = weaponSearchRadius[weaponDefID]

	-- Avoid collaterals of a similar scale to our own explosion radius.
	local avoidRadius = cache[targetID] or cacheLast[targetID] ---@as number?
	if avoidRadius and avoidRadius == math_clamp(avoidRadius, searchRadius * 0.5, searchRadius + 10) then
		return allowBadSpamTarget or not unitIsSpam[targetID], priority * PRIORITY_ANTI_COLLATERAL
	end

	-- Prefer targets that are clean hits or bombarded by larger weapons.
	local preferRadius = cache[-targetID] or cacheLast[-targetID]
	if preferRadius and preferRadius >= searchRadius - 10 then
		return true, priority -- No priority bonus. Focus on bad targets.
	end

	-- This search was not cached yet to within our search radius +/- 10.
	readAs.read = unitTeam[unitID]
	local friendPower, enemyPower = CallAsTeam(readAs, getUnitCollateral, unitID, allyTeam, searchRadius, targetID)
	---@cast friendPower number
	---@cast enemyPower number

	local allowed = true

	if enemyPower <= friendPower * friendPowerRatio then
		-- The avoid radius shrinks because a smaller attack region can eliminate
		-- specific targets trivially without causing any friendly-fire damages.
		if not avoidRadius or avoidRadius > searchRadius then
			cache[targetID] = searchRadius
		end
		if enemyPower <= spamPowerMax or enemyPower / friendPower <= spamRatioMin then
			allowed = allowBadSpamTarget
			priority = priority * PRIORITY_ANTICOLLAT_SPAM
		else
			priority = priority * PRIORITY_ANTI_COLLATERAL
		end
	else
		-- The preferred target radius grows since it represents the net region
		-- of incoming attacks that will be (probably) directed at that unit.
		if not preferRadius or preferRadius < searchRadius then
			cache[-targetID] = searchRadius
		end
		if friendPower <= spamPowerMax then
			priority = priority * PRIORITY_CLEAN_SHOT
		end
	end

	return allowed, priority
end

function gadget:GameFramePost(frame)
	frameIndex = frameIndex == 1 and frameReset or frameIndex - 1
	if updateAllyTeams[frameIndex] then
		-- Evicts half the allyTeam targeting cache per update:
		for _, allyTeam in next, updateAllyTeams[frameIndex] do
			local cache = targetCache[allyTeam]
			targetCacheLast[allyTeam] = cache
			if next(cache) ~= nil then
				targetCache[allyTeam] = {}
			end
		end
	end
end

local function callinCacheUnitStats(self, unitID, unitDefID, unitTeamID)
	unitTeam[unitID] = unitTeamID
	unitAllyTeam[unitID] = spGetUnitAllyTeam(unitID)
	unitPower[unitID] = unitDefValue[unitDefID]
	unitIsSpam[unitID] = unitDefIsSpam[unitDefID]
	unitRadius[unitID] = unitDefRadius[unitDefID]
end

local function callinRemoveUnitStats(self, unitID)
	unitTeam[unitID] = nil
	unitAllyTeam[unitID] = nil
	unitPower[unitID] = nil
	unitIsSpam[unitID] = nil
	unitRadius[unitID] = nil
end

gadget.UnitCreated = callinCacheUnitStats
gadget.UnitGiven = callinCacheUnitStats
gadget.UnitDestroyed = callinRemoveUnitStats

function gadget:Initialize()
	for unitDefID, unitDef in ipairs(UnitDefs) do
		addWeaponCollateral(unitDef)
	end

	if not next(weaponSearchRadius) then
		gadgetHandler:RemoveGadget()
		return
	end

	for _, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end
end
