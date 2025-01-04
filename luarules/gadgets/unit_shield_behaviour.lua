function gadget:GetInfo()
	return {
		name = "Shield Behaviour",
		desc = "Overrides default shield engine behavior. Defines downtime.",
		author = "SethDGamre",
		layer = 1,
		enabled = true
	}
end

if not Spring.GetModOptions().shieldsrework then return false end
if not gadgetHandler:IsSyncedCode() then return end

---- Optional unit customParams ----
-- shield_downtime = <number in seconds>, if not set defaults to defaultDowntime
-- shield_aoe_penetration = bool, if true then AOE damage will hurt units within the shield radius

local defaultDowntime = 1

-- To save on performance, do not perform AoE damage mitigation checks below this threshold, value chosen empirically to negate laser AoE from a Mammoth
local aoeIgnoreThreshold = 11

-- Units half-in/half-out of a shield should not be protected, so need a buffer of non-coverage near the edge, value chosen empirically through testing to avoid having to look up collision volumes
local radiusExclusionBuffer = 10

-- If a unit doesn't have a defined shield damage or default damage, fallbackShieldDamage will be used as a fallback.
local fallbackShieldDamage = 0

local spGetUnitShieldState = Spring.GetUnitShieldState
local spSetUnitShieldState = Spring.SetUnitShieldState
local spGetGameSeconds = Spring.GetGameSeconds
local spSetUnitShieldRechargeDelay = Spring.SetUnitShieldRechargeDelay
local spDeleteProjectile = Spring.DeleteProjectile
local spGetProjectileDefID = Spring.GetProjectileDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spGetProjectilesInRectangle = Spring.GetProjectilesInRectangle
local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitIsActive = Spring.GetUnitIsActive

local shieldUnitDefs = {}
local shieldUnitsData = {}
local originalShieldDamages = {}
local beamEmitterWeapons = {}
local forceDeleteWeapons = {}
local unitDefIDCache = {}
local projectileDefIDCache = {}
local shieldedUnits = {}
local AOEWeaponDefIDs = {}
local projectileShieldHitCache = {}
local gameSeconds = 0

for weaponDefID, weaponDef in ipairs(WeaponDefs) do
	if weaponDef.damageAreaOfEffect > aoeIgnoreThreshold and not weaponDef.customParams.shield_aoe_penetration then
		AOEWeaponDefIDs[weaponDefID] = true
	end

	if weaponDef.customParams.beamtime_damage_reduction_multiplier then
		local base = weaponDef.customParams.shield_damage or fallbackShieldDamage
		local multiplier = weaponDef.customParams.beamtime_damage_reduction_multiplier
		originalShieldDamages[weaponDefID] = math.ceil(base * multiplier)
	else
		originalShieldDamages[weaponDefID] = weaponDef.customParams.shield_damage or fallbackShieldDamage
	end

	if weaponDef.type == 'Flame' or weaponDef.customParams.overpenetrate then
		forceDeleteWeapons[weaponDefID] = weaponDef
	end
end

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.shield_radius then
		shieldUnitDefs[unitDefID] = unitDef
	end

	if unitDef.weapons then
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if weaponDef.type == 'BeamLaser' or weaponDef.type == 'LightningCannon' then
				beamEmitterWeapons[weaponDef.id] = { unitDefID, index }
			end
		end
	end
end

local function removeCoveredUnits(shieldUnitID)
	for unitID, shieldList in pairs(shieldedUnits) do
		if shieldList[shieldUnitID] then
			shieldList[shieldUnitID] = nil
		end
	end
end

local function setCoveredUnits(shieldUnitID)
	local shieldData = shieldUnitsData[shieldUnitID]
	removeCoveredUnits(shieldUnitID)
	local x, y, z = spGetUnitPosition(shieldUnitID, true)
	if not shieldData or not x then
		return
	else
		local unitsTable = spGetUnitsInSphere(x, y, z, (shieldData.radius - radiusExclusionBuffer))

		for _, unitID in ipairs(unitsTable) do
			shieldedUnits[unitID] = shieldedUnits[unitID] or {}
			shieldedUnits[unitID][shieldUnitID] = true
		end

		shieldData.shieldCoverageChecked = true
	end
end

function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
	if shieldUnitsData[unitID] then
		shieldUnitsData[unitID].team = unitTeam
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if shieldUnitDefs[unitDefID] then
		shieldUnitsData[unitID] = {
			shieldEnabled = true,			-- Virtualized enabled/disabled state until engine equivalent is changed
			shieldDamage = 0,				-- This stores the value of damages populated in ShieldPreDamaged(), then applied in GameFrame() all at once
			shieldWeaponNumber = -1,		-- This is replaced with the real shieldWeaponNumber as soon as the shield is damaged
			downtime = shieldUnitDefs[unitDefID].customParams.shield_downtime or defaultDowntime, -- Defined in unitdef.customparams with a default fallback value
			downtimeReset = 0,
			shieldCoverageChecked = false,	-- Used to prevent expensive unit coverage checks being performed more than once per cycle
			radius = shieldUnitDefs[unitDefID].customParams.shield_radius
		}
	setCoveredUnits(unitID)
	end

	-- Increases performance by reducing global unitDefID lookups
	unitDefIDCache[unitID] = unitDefID
end

function gadget:UnitDestroyed(unitID)
	shieldUnitsData[unitID] = nil
	unitDefIDCache[unitID] = nil
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	-- Increases performance by reducing global projectileDefID lookups
	projectileDefIDCache[proID] = weaponDefID
end

function gadget:ProjectileDestroyed(proID)
	projectileDefIDCache[proID] = nil
	projectileShieldHitCache[proID] = nil
end

local function triggerDowntime(unitID, weaponNum)
	local shieldData = shieldUnitsData[unitID]

	-- Dummy disable recharge delay, as engine does not support downtime
	-- Arbitrary large value used to ensure shield does not reactivate before we want it to,
	-- but using math.huge causes shield to instantly reactivate
	spSetUnitShieldRechargeDelay(unitID, weaponNum, 3600)

	spSetUnitShieldState(unitID, weaponNum, false)
	shieldData.downtimeReset = gameSeconds + shieldData.downtime
	shieldData.shieldEnabled = false
end

local function shieldNegatesDamageCheck(unitID, unitTeam, attackerID, attackerTeam)
	-- It is possible for attackerID to be nil, e.g. damage from death explosion
	if shieldedUnits[unitID] and next(shieldedUnits[unitID]) and attackerID and not spAreTeamsAllied(unitTeam, attackerTeam) then
		if not shieldedUnits[attackerID] or (not next(shieldedUnits[attackerID]) and next(shieldedUnits[unitID])) then
			return true
		end

		for shieldUnitID, _ in pairs(shieldedUnits[unitID]) do
			if shieldedUnits[attackerID][shieldUnitID] then
				break
			else
				--The units have to share all of the same shield spaces. As soon as a mismatch is found, that means they don't occupy the same shield space and the shot should be blocked.
				return true
			end
		end
	end

	return false
end

local shieldUnitsTotalCount = 0
local shieldUnitIndex = {}
local shieldCheckFlags = {}
local lastShieldCheckedIndex = 1
local shieldCheckChunkSize = 10
local shieldCheckEndIndex = 1

function gadget:GameFrame(frame)
	gameSeconds = spGetGameSeconds()

	for shieldUnitID, _ in pairs(shieldCheckFlags) do
		local shieldData = shieldUnitsData[shieldUnitID]

		if shieldData then
			if shieldData.shieldDamage > 0 and shieldData.shieldWeaponNumber > -1 then
				local enabledState, shieldPower = spGetUnitShieldState(shieldUnitID)
				shieldPower = shieldPower - shieldData.shieldDamage

				if shieldPower < 0 then
					shieldPower = 0
				end

				spSetUnitShieldState(shieldUnitID, shieldData.shieldWeaponNumber, shieldPower)
				shieldData.shieldDamage = 0

				if shieldData.downtimeReset < gameSeconds and shieldPower <= 0 then
					triggerDowntime(shieldUnitID, shieldData.shieldWeaponNumber)
					removeCoveredUnits(shieldUnitID)
				end
			else
				shieldData.shieldDamage = 0
			end

			shieldCheckFlags[shieldUnitID] = nil
		end

	end
	for shieldUnitID, shieldData in pairs(shieldUnitsData) do
		if frame % Game.gameSpeed == 0 then
			if select(2, spGetUnitIsStunned(shieldUnitID)) and shieldData.downtimeReset ~= 0 then
				shieldData.downtimeReset = shieldData.downtimeReset + 1
			end
		end

		if frame % 10 == 0 then
			if not spGetUnitIsActive(shieldUnitID) then
				spSetUnitShieldState(shieldUnitID, shieldData.shieldWeaponNumber, 0)
			end
			if not shieldData.shieldEnabled and shieldData.downtimeReset ~= 0 and shieldData.downtimeReset <= gameSeconds then
				shieldData.downtimeReset = 0
				shieldData.shieldEnabled = true
				spSetUnitShieldRechargeDelay(shieldUnitID, shieldData.shieldWeaponNumber, 0)

				-- This section is to allow slower moving projectiles already inside the shield when it comes back online to damage units within the radius.
				local x, y, z = spGetUnitPosition(shieldUnitID)
				-- Engine has GetProjectilesInRectangle, but not GetProjectilesInCircle, so we have to square the circle
				-- TODO: Change to GetProjectilesInCircle once it is added
				local radius = shieldData.radius * math.sqrt(math.pi) / 2
				local xmin = x - radius
				local xmax = x + radius
				local zmin = z - radius
				local zmax = z + radius
				local projectiles = spGetProjectilesInRectangle(xmin, zmin, xmax, zmax)
				for _, projectileID in ipairs(projectiles) do
					projectileShieldHitCache[projectileID] = true
				end
			end
		end
	end

	if frame % 90 == 0 then
		shieldUnitsTotalCount = 0
		shieldUnitIndex = {}

		for shieldUnitID, shieldData in pairs(shieldUnitsData) do
			shieldUnitsTotalCount = shieldUnitsTotalCount + 1
			shieldUnitIndex[shieldUnitsTotalCount] = shieldUnitID
		end

		shieldCheckChunkSize = math.max(math.ceil(shieldUnitsTotalCount / 4), 1)
	end
	if frame % 11 == 7 then
		for i = lastShieldCheckedIndex, shieldCheckEndIndex do
			local shieldUnitID = shieldUnitIndex[i]
			local shieldData = shieldUnitsData[shieldUnitID]

			if shieldData then
				if not shieldData.shieldCoverageChecked then
					if shieldData.shieldEnabled then
						setCoveredUnits(shieldUnitID)
					else
						removeCoveredUnits(shieldUnitID)
					end
				end

				shieldData.shieldCoverageChecked = false
			end
		end

		lastShieldCheckedIndex = shieldCheckEndIndex + 1

		if lastShieldCheckedIndex > #shieldUnitIndex then
			lastShieldCheckedIndex = 1
		end
		shieldCheckEndIndex = math.min(lastShieldCheckedIndex + shieldCheckChunkSize - 1, #shieldUnitIndex)
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if not AOEWeaponDefIDs[weaponDefID] or projectileShieldHitCache[projectileID] then
		return damage
	end

	if shieldNegatesDamageCheck(unitID, unitTeam, attackerID, attackerTeam) then
		return 0, 0
	else
		return damage
	end
end

function gadget:ShieldPreDamaged(proID, proOwnerID, shieldWeaponNum, shieldUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)
	local shieldData = shieldUnitsData[shieldUnitID]
	local weaponDefID

	if not shieldData or not shieldData.shieldEnabled then
		return true
	end

	shieldData.shieldWeaponNumber = shieldWeaponNum

	-- proID isn't nil if hitscan weapons are used, it's actually -1.
	if proID > -1 then
		weaponDefID = projectileDefIDCache[proID] or spGetProjectileDefID(proID)
		local newShieldDamage = originalShieldDamages[weaponDefID] or fallbackShieldDamage
		shieldData.shieldDamage = shieldData.shieldDamage + newShieldDamage

		if forceDeleteWeapons[weaponDefID] then
			-- Flames aren't destroyed when they hit shields, so need to delete manually
			spDeleteProjectile(proID)
		end
	elseif beamEmitterUnitID then
		local beamEmitterUnitDefID = unitDefIDCache[beamEmitterUnitID]

		if not beamEmitterUnitDefID then
			return false
		end

		weaponDefID = UnitDefs[beamEmitterUnitDefID].weapons[beamEmitterWeaponNum].weaponDef
		shieldData.shieldDamage = (shieldData.shieldDamage + originalShieldDamages[weaponDefID])
	end

	shieldCheckFlags[shieldUnitID] = true

	if shieldData.shieldEnabled then
		if not shieldData.shieldCoverageChecked and AOEWeaponDefIDs[weaponDefID] then
			setCoveredUnits(shieldUnitID)
		end
	else
		removeCoveredUnits(shieldUnitID)
	end
end

do
	---Shield controller API for other gadgets to generate and process their own shield damage events.
	local function addShieldDamage(shieldUnitID, shieldWeaponNumber, damage, weaponDefID, projectileID, beamEmitterWeaponNum, beamEmitterUnitID)
		local projectileDestroyed, damageMitigated = false, 0
		if not beamEmitterUnitID and beamEmitterWeapons[weaponDefID] then
			beamEmitterUnitID, beamEmitterWeaponNum = unpack(beamEmitterWeapons[weaponDefID])
		end
		local shieldData = shieldUnitsData[shieldUnitID]
		if shieldData and shieldData.shieldEnabled then
			if shieldData.shieldWeaponNumber == -1 and not shieldWeaponNumber then
				return
			end
			local shieldDamage = shieldData.shieldDamage
			local result = gadget:ShieldPreDamaged(projectileID, nil, shieldWeaponNumber, shieldUnitID, nil, beamEmitterWeaponNum, beamEmitterUnitID)
			if result == nil then
				projectileDestroyed = true
				if damage then
					shieldData.shieldDamage = shieldDamage + damage
					damageMitigated = damage
				else
					damageMitigated = shieldData.shieldDamage - shieldDamage
				end
			end
		end
		return projectileDestroyed, damageMitigated
	end

	function gadget:Initialize()
		GG.AddShieldDamage = addShieldDamage

		for _, unitID in ipairs(Spring.GetAllUnits()) do
			local unitDefID = Spring.GetUnitDefID(unitID)
			local unitTeam = Spring.GetUnitTeam(unitID)
			gadget:UnitFinished(unitID, unitDefID, unitTeam)
		end
	end
end

function gadget:ShutDown()
	GG.AddShieldDamage = nil
end
