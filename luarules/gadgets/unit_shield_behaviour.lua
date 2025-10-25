local gadget = gadget ---@type Gadget

local reworkEnabled = Spring.GetModOptions().shieldsrework --remove when shield rework is permanent

function gadget:GetInfo()
	return {
		name = "Shield Behaviour",
		desc = "Overrides default shield engine behavior.",
		author = "SethDGamre",
		layer = 1,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then return false end

---- Optional unit customParams ----
-- shield_aoe_penetration = bool, if true then AOE damage will hurt units within the shield radius

-- If a unit doesn't have a defined shield damage or default damage, fallbackShieldDamage will be used as a fallback.
local fallbackShieldDamage          = 0

-- this defines what amount of the total damage a unit deals qualifies as a direct hit for units that are in the vague areas between covered and not covered by shields (typically on edges or sticking out partially)
local directHitQualifyingMultiplier = 0.95

-- the minimum number of frames before the shield is allowed to turn back on. Extra regenerated shield charge is applied to the shield when it comes back online.
local minDownTime					= 1 * Game.gameSpeed

-- The maximum number of frames a shield is allowed to be offline from overkill. This is to handle very, very high single-attack damage which would otherwise cripple the shield for multiple minutes.
local maxDownTime					= 20 * Game.gameSpeed

local shieldModulo                  = Game.gameSpeed
local shieldOnUnitRulesParamIndex   = 531313
local INLOS                         = { inlos = true }

local spGetUnitShieldState          = Spring.GetUnitShieldState
local spSetUnitShieldState          = Spring.SetUnitShieldState
local spSetUnitShieldRechargeDelay  = Spring.SetUnitShieldRechargeDelay
local spDeleteProjectile            = Spring.DeleteProjectile
local spGetProjectileDefID          = Spring.GetProjectileDefID
local spGetUnitPosition             = Spring.GetUnitPosition
local spGetUnitsInSphere            = Spring.GetUnitsInSphere
local spGetProjectilesInRectangle   = Spring.GetProjectilesInRectangle
local spGetProjectilesInSphere   	= Spring.GetProjectilesInSphere
local spAreTeamsAllied              = Spring.AreTeamsAllied
local spGetUnitIsActive             = Spring.GetUnitIsActive
local spUseUnitResource             = Spring.UseUnitResource
local spSetUnitRulesParam           = Spring.SetUnitRulesParam
local spGetUnitArmored              = Spring.GetUnitArmored
local mathMax                       = math.max
local mathCeil                      = math.ceil

local shieldUnitDefs                = {}
local shieldUnitsData               = {}
local originalShieldDamages         = {}
local beamEmitterWeapons            = {}
local forceDeleteWeapons            = {}
local unitDefIDCache                = {}
local projectileDefIDCache          = {}
local shieldedUnits                 = {}
local AOEWeaponDefIDs               = {}
local projectileShieldHitCache      = {}
local highestWeapDefDamages         = {}
local armoredUnitDefs               = {}

local gameFrame 					= 0

for weaponDefID, weaponDef in ipairs(WeaponDefs) do
	if weaponDef.noExplode then
		-- Volumetric projectiles deal damage per-frame while inside of the shield.
		-- We only delete certain types; e.g., ignoring Commander and other DGun's.
		if weaponDef.type == "Flame" or weaponDef.customParams.overpenetrate then
			forceDeleteWeapons[weaponDefID] = weaponDef
		end
	end

	if reworkEnabled then  --remove this if when shield rework is permanent
		if not weaponDef.customParams.shield_aoe_penetration then
			AOEWeaponDefIDs[weaponDefID] = true
		end

		if weaponDef.customParams.beamtime_damage_reduction_multiplier then
			local base = weaponDef.customParams.shield_damage or fallbackShieldDamage
			local multiplier = weaponDef.customParams.beamtime_damage_reduction_multiplier
			originalShieldDamages[weaponDefID] = mathCeil(base * multiplier)
		else
			originalShieldDamages[weaponDefID] = weaponDef.customParams.shield_damage or fallbackShieldDamage
		end

		local highestDamage = 0
		if weaponDef.damages then
			for type, damage in ipairs(weaponDef.damages) do
				if damage > highestDamage then
					highestDamage = damage
				end
			end
		end

		--this section calculates the rough amount of damage required to be considered a "direct hit", which assumes it didn't happen from AOE reaching inside shield.
		local beamtimeReductionMultiplier = 1
		local minIntensity = 1
		if weaponDef.beamtime and weaponDef.beamtime < 1 then
			local minimumMinIntensity = 0.5
			local minIntensity = weaponDef.minIntensity or minimumMinIntensity
			minIntensity = math.max(minIntensity, minimumMinIntensity)
			-- This splits up the damage of hitscan weapons over the duration of beamtime, as each frame counts as a hit in ShieldPreDamaged() callin
			-- Math.floor is used to sheer off the extra digits of the number of frames that the hits occur
			beamtimeReductionMultiplier = 1 / math.floor(weaponDef.beamtime * Game.gameSpeed)
		end

		local minimumMinIntensity = 0.65 --impirically tested to work the majority of the time with normal damage falloff.
		local hasDamageFalloff = false
		local damageFalloffUnitTypes = {
			BeamLaser = true,
			Flame = true,
			LaserCannon = true,
			LightningCannon = true,
		}
		if damageFalloffUnitTypes[weaponDef.type] then
			hasDamageFalloff = true
		end

		if weaponDef.minIntensity and hasDamageFalloff then
			minIntensity = math.max(minimumMinIntensity, weaponDef.minIntensity)
		end

		highestWeapDefDamages[weaponDefID] = highestDamage * beamtimeReductionMultiplier * minIntensity *
		directHitQualifyingMultiplier
	end
end

-- Shared shield logic

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	projectileDefIDCache[proID] = weaponDefID
end

-- Pre-rework shield logic

if not reworkEnabled then
	function gadget:ShieldPreDamaged(proID, proOwnerID, shieldWeaponNum, shieldUnitID, bounceProjectile, beamEmitterWeaponNum,
									 beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)
		if proID > -1 then
			if forceDeleteWeapons[projectileDefIDCache[proID] or spGetProjectileDefID(proID)] then
				spDeleteProjectile(proID)
			end
		end
	end

	function gadget:ProjectileDestroyed(proID)
		projectileDefIDCache[proID] = nil
	end

	return
end

-- Shield Rework

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.shield_radius then
		local data = {}
		data.shieldRadius = tonumber(unitDef.customParams.shield_radius)

		for i, weaponsData in pairs(unitDef.weapons) do
			local wDefData = WeaponDefs[weaponsData.weaponDef]
			if wDefData.shieldPowerRegen and wDefData.shieldPowerRegen > 0 then
				data.shieldWeaponNumber = i
				data.shieldPowerRegen = wDefData.shieldPowerRegen
				data.shieldPowerRegenEnergy = wDefData.shieldPowerRegenEnergy
			end
		end
		shieldUnitDefs[unitDefID] = data
	end

	if unitDef.weapons then
		for index, weapon in ipairs(unitDef.weapons) do
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if weaponDef.type == 'BeamLaser' or weaponDef.type == 'LightningCannon' then
				beamEmitterWeapons[weaponDef.id] = { unitDefID, index }
			end
		end
	end

	if unitDef.armoredMultiple and unitDef.armoredMultiple < 1 and unitDef.armoredMultiple > 0 then
		armoredUnitDefs[unitDefID] = unitDef.armoredMultiple
	end
end

local shieldUnitsTotalCount = 0
local shieldUnitIndex = {}
local shieldCheckFlags = {}
local lastShieldCheckedIndex = 1
local shieldCheckChunkSize = 10
local shieldCheckEndIndex = 1

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
		local unitsTable = spGetUnitsInSphere(x, y, z, shieldData.radius)

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
	local data = shieldUnitDefs[unitDefID]
	if data then
		shieldUnitsData[unitID] = {
			shieldPowerRegen = data.shieldPowerRegen,
			shieldPowerRegenEnergy = data.shieldPowerRegenEnergy,
			shieldWeaponNumber = data.shieldWeaponNumber, -- This is replaced with the real shieldWeaponNumber as soon as the shield is damaged
			radius = data.shieldRadius,
			shieldEnabled = false,               -- Virtualized enabled/disabled state until engine equivalent is changed
			shieldDamage = 0,                    -- This stores the value of damages populated in ShieldPreDamaged(), then applied in GameFrame() all at once
			shieldCoverageChecked = false,       -- Used to prevent expensive unit coverage checks being performed more than once per cycle
			overKillDamage = 0,
			shieldDownTime = 0,
			maxDownTime = 0
		}
		setCoveredUnits(unitID)
	end

	-- Increases performance by reducing global unitDefID lookups
	unitDefIDCache[unitID] = unitDefID
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	shieldUnitsData[unitID] = nil
	unitDefIDCache[unitID] = nil
end

local function setProjectilesAlreadyInsideShield(shieldUnitID, radius)
	-- This section is to allow slower moving projectiles already inside the shield when it comes back online to damage units within the radius.
	local x, y, z = spGetUnitPosition(shieldUnitID)
	if not x then
		return -- Unit doesn't exist or is invalid
	end
	local projectiles
	if spGetProjectilesInSphere then
		projectiles = spGetProjectilesInSphere(x, y, z, radius)
	else
		-- Engine has GetProjectilesInRectangle, but not GetProjectilesInCircle, so we have to square the circle
		-- TODO: Change to GetProjectilesInCircle once it is added
		local radius = radius * math.sqrt(math.pi) / 2
		local xmin = x - radius
		local xmax = x + radius
		local zmin = z - radius
		local zmax = z + radius
		projectiles = spGetProjectilesInRectangle(xmin, zmin, xmax, zmax)
	end
	for _, projectileID in ipairs(projectiles) do
		projectileShieldHitCache[projectileID] = true
	end
end

local function suspendShield(unitID)
	local shieldData = shieldUnitsData[unitID]

	-- Dummy disable recharge delay, as engine does not support downtime
	-- Arbitrary large value used to ensure shield does not reactivate before we want it to,
	-- but using math.huge causes shield to instantly reactivate
	spSetUnitShieldRechargeDelay(unitID, shieldData.shieldWeaponNumber, 3600)

	spSetUnitShieldState(unitID, shieldData.shieldWeaponNumber, false)
	shieldData.shieldEnabled = false
	shieldData.shieldDownTime = gameFrame + minDownTime
	shieldData.maxDownTime = gameFrame + maxDownTime
	spSetUnitRulesParam(unitID, shieldOnUnitRulesParamIndex, 0, INLOS)
end

local function activateShield(unitID)
	local shieldData = shieldUnitsData[unitID]
	if not shieldData then
		return -- Shield unit no longer exists
	end
	shieldData.shieldEnabled = true
	spSetUnitRulesParam(unitID, shieldOnUnitRulesParamIndex, 1, INLOS)
	spSetUnitShieldRechargeDelay(unitID, shieldData.shieldWeaponNumber, 0)

	setProjectilesAlreadyInsideShield(unitID, shieldData.radius)
end

local function shieldNegatesDamageCheck(unitID, unitTeam, attackerID, attackerTeam)
	-- It is possible for attackerID to be nil, e.g. damage from death explosion
	local unitShields = shieldedUnits[unitID]
	if unitShields and next(unitShields) and attackerID and not spAreTeamsAllied(unitTeam, attackerTeam) then
		local attackerShields = shieldedUnits[attackerID]
		if not attackerShields or not next(attackerShields) then
			return true
		end

		for shieldUnitID, _ in pairs(unitShields) do
			if attackerShields[shieldUnitID] then
				break
			else
				--The units have to share all of the same shield spaces. As soon as a mismatch is found, that means they don't occupy the same shield space and the shot should be blocked.
				return true
			end
		end
	end

	return false
end

function gadget:ProjectileDestroyed(proID)
	projectileDefIDCache[proID] = nil
	projectileShieldHitCache[proID] = nil
end

function gadget:GameFrame(frame)
	gameFrame = frame

	for shieldUnitID, _ in pairs(shieldCheckFlags) do
		local shieldData = shieldUnitsData[shieldUnitID] --zzz for some reason the shield orb isn't disappearing sometimes when big damage

		--apply shield damages
		if shieldData then
			if shieldData.shieldDamage > 0 then
				local enabledState, shieldPower = spGetUnitShieldState(shieldUnitID)
				shieldPower = shieldPower - shieldData.shieldDamage

				if shieldPower < 0 then
					shieldData.overKillDamage = shieldPower --stored as a negative value
					shieldPower = 0
				end

				spSetUnitShieldState(shieldUnitID, shieldData.shieldWeaponNumber, shieldPower)
				shieldData.shieldDamage = 0

				if shieldPower <= 0 then
					suspendShield(shieldUnitID)
					removeCoveredUnits(shieldUnitID)
				end
			else
				shieldData.shieldDamage = 0
			end
			shieldCheckFlags[shieldUnitID] = nil
		end
	end

	for shieldUnitID, shieldData in pairs(shieldUnitsData) do
		local shieldActive = spGetUnitIsActive(shieldUnitID)

		if frame % shieldModulo == 0 then
			if shieldActive then
				if shieldData.overKillDamage ~= 0 then
					local usedEnergy = spUseUnitResource(shieldUnitID, "e", shieldData.shieldPowerRegenEnergy)
					if usedEnergy then
						shieldData.overKillDamage = shieldData.overKillDamage + shieldData.shieldPowerRegen
					end
				end
			else
				--if shield is manually turned off, set shield charge to 0
				spSetUnitShieldState(shieldUnitID, shieldData.shieldWeaponNumber, 0)
			end

			if not shieldData.shieldEnabled and shieldData.shieldDownTime < frame and shieldData.overKillDamage >= 0 then
				if shieldData.overKillDamage > 0 then
					spSetUnitShieldState(shieldUnitID, shieldData.shieldWeaponNumber, shieldData.overKillDamage)
					shieldData.overKillDamage = 0
				end
				activateShield(shieldUnitID)

			elseif shieldData.maxDownTime < frame then
				activateShield(shieldUnitID)
				shieldData.overKillDamage = 0
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

		shieldCheckChunkSize = mathMax(mathCeil(shieldUnitsTotalCount / 4), 1)
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

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID,
							   attackerDefID, attackerTeam)
	if not AOEWeaponDefIDs[weaponDefID] or projectileShieldHitCache[projectileID] then
		return damage
	end

	local directHitThreshold = highestWeapDefDamages[weaponDefID]
	if directHitThreshold then
		local armoredMultiple = armoredUnitDefs[unitDefID]
		if armoredMultiple then
			local isArmored = spGetUnitArmored(unitID)
			if isArmored and damage >= directHitThreshold * armoredMultiple then
				return damage
			end
		end
		if damage >= directHitThreshold then
			return damage
		end
	end

	if shieldNegatesDamageCheck(unitID, unitTeam, attackerID, attackerTeam) then
		return 0, 0
	else
		return damage
	end
end

function gadget:ShieldPreDamaged(proID, proOwnerID, shieldWeaponNum, shieldUnitID, bounceProjectile, beamEmitterWeaponNum,
								 beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)
	local weaponDefID
	local shieldData = shieldUnitsData[shieldUnitID]
	if not shieldData or not shieldData.shieldEnabled then
		return true
	end

	-- proID isn't nil if hitscan weapons are used, it's actually -1.
	if proID > -1 then
		weaponDefID = projectileDefIDCache[proID] or spGetProjectileDefID(proID)
		local newShieldDamage = originalShieldDamages[weaponDefID] or fallbackShieldDamage
		shieldData.shieldDamage = shieldData.shieldDamage + newShieldDamage
		if forceDeleteWeapons[weaponDefID] then
			-- Flames and penetrating projectiles aren't destroyed when they hit shields, so need to delete manually
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

---Shield controller API for other gadgets to generate and process their own shield damage events.
local function addShieldDamage(shieldUnitID, damage, weaponDefID, projectileID, beamEmitterWeaponNum, beamEmitterUnitID)
	local projectileDestroyed, damageMitigated = false, 0
	if not beamEmitterUnitID and beamEmitterWeapons[weaponDefID] then
		beamEmitterUnitID, beamEmitterWeaponNum = unpack(beamEmitterWeapons[weaponDefID])
	end
	local shieldData = shieldUnitsData[shieldUnitID]
	if shieldData and shieldData.shieldEnabled then
		local shieldDamage = shieldData.shieldDamage
		local result = gadget:ShieldPreDamaged(projectileID, nil, shieldData.shieldWeaponNumber, shieldUnitID, nil, beamEmitterWeaponNum, beamEmitterUnitID)
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

function gadget:ShutDown()
	GG.AddShieldDamage = nil
end
