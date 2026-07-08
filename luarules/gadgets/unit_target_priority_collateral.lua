local gadget = gadget ---@type Gadget

if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
	return {
		name    = "Collateral Target Priority",
		desc    = "Modifies the target priority based on nearby units.",
		author  = "efrec",
		version = "0.0",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 1000, -- process after allow/disallow checks
		enabled = true, -- auto-disables
	}
end

local PRIORITY_CLEAN_SHOT = 0.875
local PRIORITY_ANTI_COLLATERAL = 5.0
local PRIORITY_ANTI_SPAM = 20.0
local allowBadSpamTarget = false

local friendPowerRatio = 1.5
local spamPowerMax = 50
local unknownPower = spamPowerMax * 2

local searchRadiusMin = 64.0
local searchDamageMin = 100.0
local effectTarget = 0.20

-- Lua env globals -------------------------------------------------------------

local CallAsTeam = CallAsTeam

local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitsInSphere = Spring.GetUnitsInSphere

-- Initialization --------------------------------------------------------------

local weaponSearchRadius = {}

local avoidUnit, preferUnit = {}, {}
do
	local allyTeamList = Spring.GetAllyTeamList()
	for _, allyTeam in pairs(allyTeamList) do
		avoidUnit[allyTeam] = {}
		preferUnit[allyTeam] = {}
	end
end

local readAs = { read = -1 }

local unitPower = { [-1] = unknownPower }
local unitRadius = { [-1] = 10.0 }
local unitDefRadiusAverage = 0.0 -- TODO: median or something

for unitDefID, unitDef in ipairs(UnitDefs) do
	unitPower[unitDefID] = unitDef.metalCost + unitDef.energyCost / 70
	unitDefRadiusAverage = unitDefRadiusAverage + unitDef.radius
end
unitDefRadiusAverage = unitDefRadiusAverage / #UnitDefs

for unitDefID, unitDef in ipairs(UnitDefs) do
	unitRadius[unitDefID] = math.max(unitDef.radius - unitDefRadiusAverage * 0.5, 0)
end

local unitAllyTeam = {}

local function getWeaponDamage(weaponDef)
	local damage = weaponDef.damages[0] -- TODO: other armor type targets
	local salvo = weaponDef.salvoSize * weaponDef.projectiles
	local burstTime = weaponDef.salvoSize * weaponDef.salvoDelay
	if burstTime > 1 then
		salvo = salvo / burstTime
	end
	return damage * salvo
end

local function ignoreWeaponDef(weaponDef)
	return weaponDef.customParams.bogus == "1"
		or weaponDef.manualFire
		or getWeaponDamage(weaponDef) <= 10
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
		local weaponDef = WeaponDefs[weapon.weaponDef]
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
	Cannon            = true,
	BeamLaser         = true,
	LaserCannon       = true,
	LightningCannon   = true,
	MissileLauncher   = true,
	TorpedoLauncher   = true,
	StarburstLauncher = true,
	AircraftBomb      = true,
	-- TODO: Melee?
}

local function getExplosionRadiusEffective(groups, weaponNum, weaponDef)
	local radius, damage = 0.0, 0.0

	if not weaponTypesExplosion[weaponDef.type] then
		return radius, damage
	end

	if not ignoreWeaponDef(weaponDef) then
		local aoe = weaponDef.damageAreaOfEffect

		-- expMod = (expRadius + 0.001f - expDist) / (expRadius + 0.001f - expDist * expEdgeEffect)
		-- dist@mod (approx) = expRadius * (1 - expMod) / (1 - expEdgeEffect * expMod)
		local effectAtEdge = weaponDef.edgeEffectiveness
		if effectAtEdge < effectTarget then
			aoe = aoe * (1 - effectTarget) / (1 - effectAtEdge * effectTarget)
		end

		local scatter = weaponDef.range * (math.max(weaponDef.accuracy, weaponDef.movingAccuracy * 0.5) + weaponDef.sprayAngle + 0.25 * weaponDef.targetMoveError)

		local miss = (1 - weaponDef.predictBoost) * 54
		if weaponDef.leadLimit > 0 then
			miss = math.min(weaponDef.leadLimit, miss)
		end

		-- Spatial search is via midpoint. Just add padding:
		radius = aoe + scatter + miss + unitDefRadiusAverage
		damage = getWeaponDamage(weaponDef)

		if weaponDef.customParams.cluster_def then
			local clusterDef = WeaponDefNames[weaponDef.customParams.cluster_def]
			if clusterDef then
				radius = radius + math.max(clusterDef.range - aoe, 0) + clusterDef.damageAreaOfEffect * 0.5
				damage = damage + clusterDef.damages[0] * tonumber(weaponDef.customParams.cluster_number)
			end
		elseif weaponDef.customParams.spark_range then
			radius = math.max(radius, tonumber(weaponDef.customParams.spark_range), 0)
		elseif weaponDef.customParams.speceffect == "split" then
			radius = radius + 32 -- sure
		elseif weaponDef.customParams.area_onhit_range then
			radius = radius + math.max(tonumber(weaponDef.customParams.area_onhit_range) - aoe, 0)
		end
	end

	local subordinates = table.map(groups[weaponNum] or {}, function(w, i) return w.weaponNum ~= weaponNum and w or nil, i end)
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

local function addWeaponCollateral(unitDef)
	local groups = getWeaponGroups(unitDef)
	for weaponNum in pairs(groups) do
		local weapon = unitDef.weapons[weaponNum]
		local weaponDefID = weapon.weaponDef
		local weaponDef = WeaponDefs[weaponDefID]

		local radius, damage = getExplosionRadiusEffective(groups, weaponNum, weaponDef)

		if radius >= searchRadiusMin and damage >= searchDamageMin then
			if not weaponSearchRadius[weaponDefID] then
				Script.SetWatchAllowTarget(weaponDefID, true)
				weaponSearchRadius[weaponDefID] = radius
			else
				-- Games that use weaponDefs as shared components likely need to add handling here.
				weaponSearchRadius[weaponDefID] = math.max(weaponSearchRadius[weaponDefID], radius)
			end
		end
	end
end

-- Local functions -------------------------------------------------------------

local function getUnitCollateral(unitID, allyTeam, radius, targetID)
	local friendPower, enemyPower = 0.0, 0.0

	local _, _, _, tx, ty, tz = spGetUnitPosition(targetID, true)
	local units = spGetUnitsInSphere(tx, ty, tz, radius + unitRadius[spGetUnitDefID(targetID) or -1])

	for _, foundID in next, units do
		if foundID == unitID then
			--
		elseif spGetUnitAllyTeam(foundID) == allyTeam then
			friendPower = friendPower + unitPower[spGetUnitDefID(foundID)]
		else
			enemyPower = enemyPower + unitPower[spGetUnitDefID(foundID) or -1]
		end
	end

	return friendPower, enemyPower
end

-- Engine callins --------------------------------------------------------------

function gadget:AllowWeaponTarget(unitID, targetID, weaponNum, weaponDefID, priority)
	local searchRadius = weaponSearchRadius[weaponDefID]
	if not searchRadius then
		return true, priority
	end

	-- :Destroyed can occur while unit is alive. But does that unit reach this point in targeting logic?
	local allyTeam = unitAllyTeam[unitID]
	if not allyTeam then
		return true, priority
	end

	-- Check preferred targets first. If it's getting bombarded anyway...
	local preferRadius = preferUnit[allyTeam][targetID]
	if preferRadius and preferRadius + 10 >= searchRadius then
		return true, priority
	end

	-- Avoids are less important and use the reverse logic in comparison.
	local avoidRadius = avoidUnit[allyTeam][targetID]
	if avoidRadius and avoidRadius - 10 <= searchRadius then
		return true, priority * PRIORITY_ANTI_COLLATERAL
	end

	-- We've done the above work to avoid this more expensive spatial search against the target.
	readAs.read = spGetUnitTeam(unitID)
	local friendPower, enemyPower = CallAsTeam(readAs, getUnitCollateral, unitID, allyTeam, searchRadius, targetID)

	local allowed = true

	if enemyPower >= friendPower * friendPowerRatio then
		-- The preferred target radius grows since it represents the net region
		-- of incoming attacks that will be (probably) directed at that unit.
		if not preferRadius or preferRadius < searchRadius then
			preferUnit[allyTeam][targetID] = searchRadius
		end
		if friendPower <= spamPowerMax then
			priority = priority * PRIORITY_CLEAN_SHOT
		end
	else
		-- The avoid radius shrinks because a smaller attack region can eliminate
		-- specific targets trivially without causing any friendly-fire damages.
		if not avoidRadius or avoidRadius > searchRadius then
			avoidUnit[allyTeam][targetID] = searchRadius
		end
		if enemyPower <= spamPowerMax then
			allowed = allowBadSpamTarget
			priority = priority * PRIORITY_ANTI_SPAM
		else
			priority = priority * PRIORITY_ANTI_COLLATERAL
		end
	end

	-- local x, y, z = Spring.GetUnitPosition(targetID)
	-- Spring.MarkerAddPoint(x, y, z, ("allow:%s prio:%.3f"):format(tostring(allowed), priority))
	return allowed, priority
end

local index = 0
local reset = Game.gameSpeed

function gadget:GameFramePost(frame)
	if index == reset then
		for i in pairs(avoidUnit) do
			avoidUnit[i] = {}
			preferUnit[i] = {}
		end
		index = 0
	end
	index = index + 1
end

local function callinSetUnitAllyTeam(self, unitID)
	unitAllyTeam[unitID] = spGetUnitAllyTeam(unitID)
end
gadget.UnitCreated = callinSetUnitAllyTeam
gadget.UnitTaken = callinSetUnitAllyTeam

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	unitAllyTeam[unitID] = nil
end

function gadget:Initialize()
	for unitDefID, unitDef in ipairs(UnitDefs) do
		addWeaponCollateral(unitDef)
	end

	if not next(weaponSearchRadius) then
		gadgetHandler:RemoveGadget()
		return
	end
end
