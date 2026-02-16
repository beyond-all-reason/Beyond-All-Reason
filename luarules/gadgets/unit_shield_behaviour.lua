local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Shield Behaviour",
		desc = "Overrides default shield engine behavior.",
		author = "SethDGamre",
		layer = -10, -- provides GG.Shields interface for scripted weapon types
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

---@alias ShieldPreDamagedCallback fun(projectileID:integer, attackerID:integer, shieldWeaponIndex:integer, shieldUnitID:integer, bounceProjectile:boolean, beamWeaponIndex:integer?, beamUnitID:integer?, startX:number?, startY:number?, startZ:number?, hitX:number, hitY:number, hitZ:number): boolean? (default := `false`)

local mathMax = math.max

local spGetUnitShieldState = Spring.GetUnitShieldState
local spSetUnitShieldState = Spring.SetUnitShieldState

local SHIELDSTATE_DISABLED = 0
local SHIELDSTATE_ENABLED = 1

local armorTypeShields = Game.armorTypes.shields

local originalShieldDamages = table.new(#WeaponDefs, 1) -- [0] goes into hash part
local scriptedShieldDamages = {}

-- Some modoptions require engine shield behaviors (namely their bounce/repulsion effects):

if Spring.GetModOptions().experimentalshields:find("bounce") then
	for weaponDefID = 0, #WeaponDefs do
		local weaponDef = WeaponDefs[weaponDefID]
		originalShieldDamages[weaponDefID] = weaponDef.damages and weaponDef.damages[armorTypeShields] or 0
	end

	---Pass a `weaponDefID` instead of a `damage` for shield damage to be determined for you.
	---@return boolean exhausted The damage was mitigated, in full, by the shield.
	---@return number damageDone The amount of damage done to the targeted shield.
	local function addEngineShieldDamage(shieldUnitID, damage, weaponDefID)
		local state, power = spGetUnitShieldState(shieldUnitID)

		if state == SHIELDSTATE_ENABLED and power > 0 then
			if not damage then
				damage = originalShieldDamages[weaponDefID] or 0 -- to handle envDamageTypes
			end

			spSetUnitShieldState(shieldUnitID, mathMax(0, power - damage))

			if power >= damage then
				return true, damage
			else
				return false, power
			end
		else
			return false, 0
		end
	end

	local function doShieldPreDamaged(self, projectileID, attackerID, shieldWeaponIndex, shieldUnitID, bounceProjectile, beamWeaponIndex, beamUnitID, startX, startY, startZ, hitX, hitY, hitZ)
		for lookup, callback in pairs(scriptedShieldDamages) do
			if lookup[projectileID] then
				if callback(projectileID, attackerID, shieldWeaponIndex, shieldUnitID, bounceProjectile, beamWeaponIndex, beamUnitID, startX, startY, startZ, hitX, hitY, hitZ) then
					return true
				end
			end
		end
	end

	---Add a scripted weapon type to be handled by the shield behaviour gadget.
	---@param projectileTbl table [projectileID] := true
	---@param callback ShieldPreDamagedCallback accepting the ShieldPreDamaged args (excluding self-ref), returning `true` when consuming the event
	local function registerShieldPreDamaged(projectileTbl, callback)
		if not next(scriptedShieldDamages) then
			gadget.ShieldPreDamaged = doShieldPreDamaged
			gadgetHandler:UpdateCallIn("ShieldPreDamaged")
		end
		scriptedShieldDamages[projectileTbl] = callback
	end

	function gadget:Initialize()
		GG.Shields = {}
		GG.Shields.AddShieldDamage = addEngineShieldDamage
		GG.Shields.DamageToShields = originalShieldDamages
		GG.Shields.GetUnitShieldPosition = function() end -- TODO: parts of the api are not usable (nor needed)
		GG.Shields.GetShieldUnitsInSphere = function() end -- TODO: parts of the api are not usable (nor needed)
		GG.Shields.GetUnitShieldState = spGetUnitShieldState
		GG.Shields.RegisterShieldPreDamaged = registerShieldPreDamaged
	end

	return -- do not load custom shields gadget
end

-- Otherwise, this gadget overrides all shield behaviors with game-side shields:

---- Optional unit customParams ----
-- shield_aoe_penetration = bool, if true then AOE damage will hurt units within the shield radius

-- this defines what amount of the total damage a unit deals qualifies as a direct hit for units that are in the vague areas between covered and not covered by shields (typically on edges or sticking out partially)
local directHitQualifyingMultiplier = 0.95

-- the minimum number of frames before the shield is allowed to turn back on. Extra regenerated shield charge is applied to the shield when it comes back online.
local minDownTime					= 1 * Game.gameSpeed

-- The maximum number of frames a shield is allowed to be offline from overkill. This is to handle very, very high single-attack damage which would otherwise cripple the shield for multiple minutes.
local maxDownTime					= 20 * Game.gameSpeed

local shieldOnUnitRulesParamIndex   = 531313
local INLOS                         = { inlos = true }

local mathCeil                      = math.ceil
local mathSqrt                      = math.sqrt
local mathPi                        = math.pi

local spGetUnitShieldState          = Spring.GetUnitShieldState
local spSetUnitShieldState          = Spring.SetUnitShieldState
local spSetUnitShieldRechargeDelay  = Spring.SetUnitShieldRechargeDelay
local spDeleteProjectile            = Spring.DeleteProjectile
local spGetProjectileDefID          = Spring.GetProjectileDefID
local spGetUnitPosition             = Spring.GetUnitPosition
local spGetUnitWeaponVectors        = Spring.GetUnitWeaponVectors
local spGetUnitsInSphere            = Spring.GetUnitsInSphere
local spGetProjectilesInRectangle   = Spring.GetProjectilesInRectangle
local spGetProjectilesInSphere   	= Spring.GetProjectilesInSphere
local spAreTeamsAllied              = Spring.AreTeamsAllied
local spGetUnitIsActive             = Spring.GetUnitIsActive
local spGetUnitIsDead               = Spring.GetUnitIsDead
local spUseUnitResource             = Spring.UseUnitResource
local spSetUnitRulesParam           = Spring.SetUnitRulesParam
local spGetUnitArmored              = Spring.GetUnitArmored

local shieldUnitDefs                = {}
local shieldUnitsData               = {}
local beamEmitterWeapons            = {}
local forceDeleteWeapons            = {}
local unitDefIDCache                = {}
local projectileDefIDCache          = {}
local shieldedUnits                 = {}
local AOEWeaponDefIDs               = {}
local projectileShieldHitCache      = {}
local highestWeapDefDamages         = {}
local armoredUnitDefs               = {}
local destroyedUnitData             = {}

local gameFrame 					= 0

for weaponDefID, weaponDef in ipairs(WeaponDefs) do

	if weaponDef.type == 'Flame' then -- flame projectiles aren't deleted when striking the shield. For compatibility with shield blocking type overrides.
		forceDeleteWeapons[weaponDefID] = weaponDef
	end

	if not weaponDef.customParams.shield_aoe_penetration then
		AOEWeaponDefIDs[weaponDefID] = true
	end

	if weaponDef.customParams.beamtime_damage_reduction_multiplier then
		local base = weaponDef.customParams.shield_damage or 0
		local multiplier = weaponDef.customParams.beamtime_damage_reduction_multiplier
		originalShieldDamages[weaponDefID] = mathCeil(base * multiplier)
	else
		originalShieldDamages[weaponDefID] = tonumber(weaponDef.customParams.shield_damage or 0) or 0
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
		minIntensity = mathMax(minIntensity, minimumMinIntensity)
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
		minIntensity = mathMax(minimumMinIntensity, weaponDef.minIntensity)
	end

	highestWeapDefDamages[weaponDefID] = highestDamage * beamtimeReductionMultiplier * minIntensity *
	directHitQualifyingMultiplier
end

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

----local functions----

local function getUnitShieldWeaponPosition(shieldUnitID, unitData)
	if unitData.x then
		return unitData.x, unitData.y, unitData.z, unitData.radius -- from dead unit
	elseif unitData.shieldWeaponNumber then
		local x, y, z = spGetUnitWeaponVectors(shieldUnitID, unitData.shieldWeaponNumber)
		return x, y, z, unitData.radius
	else
		-- The unit may have died without ever receiving shield damage, so has no weapon number.
		-- TODO: But why is that even a thing? This is not a significant obstacle to overcome.
		local x, y, z = spGetUnitPosition(shieldUnitID, true)
		return x, y, z, unitData.radius
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

----main logic----

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
		destroyedUnitData[unitID] = nil -- Handle (maybe) units being recreated and reusing their original ID
		setCoveredUnits(unitID)
	end

	-- Increases performance by reducing global unitDefID lookups
	unitDefIDCache[unitID] = unitDefID
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local unitData = shieldUnitsData[unitID]
	if unitData then
		shieldUnitsData[unitID] = nil
		-- Keep shield data for one frame, since the shieldsrework delays updates until then.
		destroyedUnitData[unitID] = unitData
		unitData.x, unitData.y, unitData.z = getUnitShieldWeaponPosition(unitID, unitData)
		-- ! Prevent a possible error here, it seems shields are cleaned up faster than unit weapons:
		local success, state, power = pcall(spGetUnitShieldState, unitID, unitData.shieldWeaponNumber)
		unitData.power = (success and state == 1 and power) or unitData.power or 0
	end
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
		local radiusSquared = radius * mathSqrt(mathPi) / 2
		local xmin = x - radiusSquared
		local xmax = x + radiusSquared
		local zmin = z - radiusSquared
		local zmax = z + radiusSquared
		projectiles = spGetProjectilesInRectangle(xmin, zmin, xmax, zmax)
	end
	for i = 1, #projectiles do
		projectileShieldHitCache[projectiles[i]] = true
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

local shieldUnitsTotalCount = 0
local shieldUnitIndex = {}
local shieldCheckFlags = {}
local lastShieldCheckedIndex = 1
local shieldCheckChunkSize = 10
local shieldCheckEndIndex = 1

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

	if frame % 30 == 0 then
		for shieldUnitID, shieldData in pairs(shieldUnitsData) do
			local shieldActive = spGetUnitIsActive(shieldUnitID)

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

	local dud = destroyedUnitData
	for unitID in pairs(dud) do
		dud[unitID] = nil
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

	if shieldWeaponNum and not shieldData.shieldWeaponNumber then
		shieldData.shieldWeaponNumber = shieldWeaponNum
	end

	-- Process scripted weapon types first (dgun, cluster, overpen, area timed). These can override any behaviors, potentially.
	for lookup, callback in pairs(scriptedShieldDamages) do
		if lookup[proID] then -- TODO: filtering for beam weapons (projectileID == -1) is not especially effective here.
			if callback(proID, proOwnerID, shieldWeaponNum, shieldUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ) then
				return true
			end
		end
	end

	-- proID isn't nil if hitscan weapons are used, it's actually -1.
	if proID > -1 then
		weaponDefID = projectileDefIDCache[proID] or spGetProjectileDefID(proID)
		local newShieldDamage = originalShieldDamages[weaponDefID] or 0
		shieldData.shieldDamage = shieldData.shieldDamage + newShieldDamage
		if forceDeleteWeapons[weaponDefID] then
			-- Flame projectiles aren't destroyed when they hit shields, so need to delete manually
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

-- Gadget interface methods ----------------------------------------------------

---@return integer state 0 := DISABLED, 1 := ENABLED
---@return number shieldHealthRemaining including the (hidden) damage done this frame so far
local function getUnitShieldState(shieldUnitID)
	local unitData = shieldUnitsData[shieldUnitID] or destroyedUnitData[shieldUnitID]
	if unitData and unitData.shieldEnabled then
		local power
		if spGetUnitIsDead(shieldUnitID) == false then
			_, power = spGetUnitShieldState(shieldUnitID, unitData.shieldWeaponNumber)
		else
			power = unitData.power
		end
		-- Damage is applied late in the rework, effectively giving infinite HP for one frame.
		-- Still, we report that the shield is enabled (1), and its "actual" power remaining.
		return SHIELDSTATE_ENABLED, power and mathMax(power - unitData.shieldDamage, 0) or -1
	else
		return SHIELDSTATE_DISABLED, 0
	end
end

---Pass a `weaponDefID` instead of a `damage` for shield damage to be determined for you.
---@return boolean exhausted The damage was mitigated, in full, by the shield.
---@return number damageDone The amount of damage done to the targeted shield.
local function addCustomShieldDamage(shieldUnitID, damage, weaponDefID)
	local state, power = getUnitShieldState(shieldUnitID) -- because the unit can be dead

	if state == SHIELDSTATE_ENABLED and power > 0 then
		local shieldData = shieldUnitsData[shieldUnitID] or destroyedUnitData[shieldUnitID]

		if not damage then
			damage = originalShieldDamages[weaponDefID] or 0
		end

		shieldData.shieldDamage = shieldData.shieldDamage + damage
		shieldCheckFlags[shieldUnitID] = true

		-- NB: The decision to delete the projectile is left up to the calling gadget.
		if power >= damage then
			return true, damage
		else
			return false, power
		end
	end

	return false, 0
end

---@return number? x xyz, emitter point of the shield weapon
---@return number? y
---@return number? z
---@return number? shieldRadius though the shield may be inactive
local function getUnitShieldPosition(shieldUnitID)
	local unitData = shieldUnitsData[shieldUnitID] or destroyedUnitData[shieldUnitID]
	if unitData then
		return getUnitShieldWeaponPosition(shieldUnitID, unitData)
	end
end

local function isBallShellIntersection(dx, dy, dz, ballRadius, shellRadius)
	local distanceSq = dx * dx + dy * dy + dz * dz
	return distanceSq >= (shellRadius - ballRadius) * (shellRadius - ballRadius)
		and distanceSq <= (shellRadius + ballRadius) * (shellRadius + ballRadius)
end

---@param x number
---@param y number
---@param z number
---@param radius number? Additive with the radius of the target shield (default := `0`)
---@param onlyAlive boolean? Navigate the rework's one-frame delay on shield effects by excluding recently-dead units (default := `false`)
---@return integer[] shieldUnits
---@return integer count
local function getShieldUnitsInSphere(x, y, z, radius, onlyAlive)
	radius = mathMax(radius or 0, 0.001)

	local units, count = {}, 0
	local position, intersect = getUnitShieldWeaponPosition, isBallShellIntersection

	-- Find intersections of the solid search sphere and thin-shelled shield spheres.
	for unitID, unitData in pairs(shieldUnitsData) do
		if unitData.shieldEnabled then
			local sx, sy, sz, shieldRadius = position(unitID, unitData)
			if intersect(x - sx, y - sy, z - sz, radius, shieldRadius) then
				count = count + 1
				units[count] = unitID
			end
		end
	end

	if onlyAlive then
		return units, count
	end

	for unitID, unitData in pairs(destroyedUnitData) do
		if unitData.shieldEnabled then
			local sx, sy, sz, shieldRadius = position(unitID, unitData)
			if intersect(x - sx, y - sy, z - sz, radius, shieldRadius) then
				count = count + 1
				units[count] = unitID
			end
		end
	end

	return units, count
end

---Add a scripted weapon type to be handled by the shield behaviour gadget.
---@param projectileTbl table [projectileID] := true
---@param callback ShieldPreDamagedCallback accepting the ShieldPreDamaged args (excluding self-ref), returning `true` when consuming the event
local function registerShieldPreDamaged(projectileTbl, callback)
	scriptedShieldDamages[projectileTbl] = callback
end

function gadget:Initialize()
	GG.Shields = {}
	GG.Shields.AddShieldDamage = addCustomShieldDamage
	GG.Shields.DamageToShields = originalShieldDamages
	GG.Shields.GetUnitShieldPosition = getUnitShieldPosition
	GG.Shields.GetShieldUnitsInSphere = getShieldUnitsInSphere
	GG.Shields.GetUnitShieldState = getUnitShieldState
	GG.Shields.RegisterShieldPreDamaged = registerShieldPreDamaged

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitTeam = Spring.GetUnitTeam(unitID)
		gadget:UnitFinished(unitID, unitDefID, unitTeam)
	end
end

function gadget:Shutdown()
	GG.Shields = nil
end
