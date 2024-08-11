function gadget:GetInfo()
	return {
		name = "Shield Behaviour",
		desc = "Overrides default shield engine behavior. Defines downtime.",
		author = "SethDGamre",
		layer = 1,
		enabled = true
	}
end

local modOptions = Spring.GetModOptions()
if modOptions.shieldsrework == false then return false end
if not gadgetHandler:IsSyncedCode() then return end

----Optional unit customParams----
--customParams shield_downtime = <number in seconds>, if not set defaults to 5 seconds
--customParams shield_aoe_penetration = bool, if true then the AOE will hurt units within the shield radius.

local spGetUnitShieldState = Spring.GetUnitShieldState
local spSetUnitShieldState = Spring.SetUnitShieldState
local spGetGameSeconds = Spring.GetGameSeconds
local spSetUnitShieldRechargeDelay = Spring.SetUnitShieldRechargeDelay
local spDeleteProjectile = Spring.DeleteProjectile
local spGetProjectileDefID = Spring.GetProjectileDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spGetProjectilesInRectangle = Spring.GetProjectilesInRectangle

local shieldUnitDefs = {}
local shieldUnitsData = {}
local originalShieldDamages = {}
local flameWeapons = {}
local unitDefIDCache = {}
local projectileDefIDCache = {}
local shieldedUnits = {}
local AOEWeaponDefIDs = {}
local projectileShieldHitCache = {}
local gameSeconds = 0

for weaponDefID, weaponDef in ipairs(WeaponDefs) do
	local areaOfEffect = weaponDef.damageAreaOfEffect
	local interceptedByShieldType = weaponDef.interceptedByShieldType
	if areaOfEffect > 11 and not weaponDef.customParams.shield_aoe_penetration and weaponDef.interceptedByShieldType == 1 then -- 11 because the the benchmark cortex sumo has a AOE of 12
		AOEWeaponDefIDs[weaponDefID] = true
	end
	if weaponDef.customParams.beamtime_damage_reduction_multiplier then
		local base = weaponDef.customParams.shield_damage
		local multiplier = weaponDef.customParams.beamtime_damage_reduction_multiplier
		local damage = math.max(base * multiplier)
		originalShieldDamages[weaponDefID] = math.floor(damage)
	else
		originalShieldDamages[weaponDefID] = tonumber(weaponDef.customParams.shield_damage)
	end
	if weaponDef.type == 'Flame' then
		flameWeapons[weaponDefID] = weaponDef
	end
end

for id, data in pairs(UnitDefs) do
	if data.customParams.shield_radius then
		shieldUnitDefs[id] = data
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
			isStatic = shieldUnitDefs[unitDefID].isStatic or false,        --used to prefer paralyze disable method for shields that don't move.
			team = unitTeam,                                               --for future AOE damage mitigation
			location = { 0, 0, 0 },                                        --for future AOE damage mitigation
			shieldEnabled = true,                                          --virtualized enabled/disabled state until engine equivalent is changed
			shieldDamage = 0,                                              --this stores the value of damages populated in ShieldPreDamaged(), then applied in GameFrame() all at once.
			shieldWeaponNumber = -1,                                       --this is replaced with the real shieldWeaponNumber as soon as the shield is damaged.
			downtime = shieldUnitDefs[unitDefID].customParams.shield_downtime or 8, --defined in unitdef.customparams with a default fallback value.
			downtimeReset = 0,
			shieldCoverageChecked = false,									--this is to prevent expensive unit coverage checks aren't performed more than once per cycle.
			radius = shieldUnitDefs[unitDefID].customParams.shield_radius
		}
	end
	unitDefIDCache[unitID] = unitDefID --increases performance by reducing unitDefID lookups
end

function gadget:UnitDestroyed(unitID)
	shieldUnitsData[unitID] = nil
	unitDefIDCache[unitID] = nil
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID) --increases performance by reducing projectileDefID lookups
	projectileDefIDCache[proID] = weaponDefID
end

function gadget:ProjectileDestroyed(proID)
	projectileDefIDCache[proID] = nil
	projectileShieldHitCache[proID] = nil
end

local function triggerDowntime(unitID, weaponNum)
	local shieldData = shieldUnitsData[unitID]
	spSetUnitShieldRechargeDelay(unitID, weaponNum, 120) --this method is used for mobile units with shields such as evocom cortex commander. This is far less efficient, but for smaller unit counts is OK.
	spSetUnitShieldState(unitID, weaponNum, false)
	shieldData.downtimeReset = gameSeconds + shieldData.downtime
	shieldData.shieldEnabled = false
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
	if not shieldData then
		return
	else
		removeCoveredUnits(shieldUnitID)
		local x, y, z = spGetUnitPosition(shieldUnitID, true)
		local unitsTable = spGetUnitsInSphere(x, y, z, (shieldData.radius - 10))
		for _, unitID in ipairs(unitsTable) do
			if shieldedUnits[unitID] then
				shieldedUnits[unitID][shieldUnitID] = true
			else
				shieldedUnits[unitID] = {}
				shieldedUnits[unitID][shieldUnitID] = true
			end
		end
		shieldData.shieldCoverageChecked = true
	end
end

local function shieldNegatesDamageCheck(unitID, unitTeam, attackerID, attackerTeam)
	if unitTeam ~= attackerTeam and shieldedUnits[unitID] and next(shieldedUnits[unitID]) then --if same team, collision doesn't happen so no point in checking. If unit ID doesn't have any shields protecting it, skip it.
		if not shieldedUnits[attackerID] or (not next(shieldedUnits[attackerID]) and next(shieldedUnits[unitID])) then
			return true
		end
		for subKey in pairs(shieldedUnits[unitID]) do
			if shieldedUnits[attackerID][subKey] then
				break
			else
				return true --the units have to share all of the same shield spaces. As soon as a mismatch is found, that means they don't occupy the same shield space and the shot should be blocked.
			end
		end
	end
	return false
end

local shieldUnitsTotalCount = 0
local shieldUnitIndex = {}
local shieldCheckFlags = {}
local lastShieldCheckChunkNumber = 1 -- Initialize this to your desired starting index
local shieldCheckChunkSize = 10      -- Define the chunk size
local shieldCheckEndIndex = 1
function gadget:GameFrame(frame)
	gameSeconds = spGetGameSeconds()

	for shieldUnitID in pairs(shieldCheckFlags) do
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
		if frame % 10 == 0 then
			if shieldData.shieldEnabled == false and shieldData.downtimeReset ~= 0 and shieldData.downtimeReset <= gameSeconds then
				shieldData.downtimeReset = 0
				shieldData.shieldEnabled = true
				spSetUnitShieldRechargeDelay(shieldUnitID, shieldData.shieldWeaponNumber, 0)
				    --this section is to allow slower moving projectiles already inside the shield when it comes back online to damage units within the radius.
					local x, y, z = spGetUnitPosition(shieldUnitID)
					local radius = shieldData.radius-25
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
		shieldCheckChunkSize = math.max(math.ceil(shieldUnitsTotalCount / 10), 1)
		if lastShieldCheckChunkNumber > #shieldUnitIndex then
			lastShieldCheckChunkNumber = 1
		end
		shieldCheckEndIndex = math.min(lastShieldCheckChunkNumber + shieldCheckChunkSize - 1, #shieldUnitIndex)
	end
	for i = lastShieldCheckChunkNumber, shieldCheckEndIndex do
		local shieldUnitID = shieldUnitIndex[i]
		local shieldData = shieldUnitsData[shieldUnitID]
		if shieldData then
			if shieldData.shieldCoverageChecked == false then
				if shieldData.shieldEnabled == true then
					setCoveredUnits(shieldUnitID)
				else
					removeCoveredUnits(shieldUnitID)
				end
			end
			shieldData.shieldCoverageChecked = false
		end
	end

	lastShieldCheckChunkNumber = shieldCheckEndIndex + 1
	if lastShieldCheckChunkNumber > #shieldUnitIndex then
		lastShieldCheckChunkNumber = 1
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if not AOEWeaponDefIDs[weaponDefID] or projectileShieldHitCache[projectileID] then return damage end
	if shieldNegatesDamageCheck(unitID, unitTeam, attackerID, attackerTeam) then
		return 0
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
	if proID > -1 then -- proID isn't nil if hitscan weapons are used, it's actually -1.
		weaponDefID = projectileDefIDCache[proID]
		if not weaponDefID then
			weaponDefID = spGetProjectileDefID(proID) -- because flame projectiles for some reason don't live long enough to reference from the cache table
		end
		shieldData.shieldDamage = (shieldData.shieldDamage + originalShieldDamages[weaponDefID])
		if flameWeapons[weaponDefID] then
			spDeleteProjectile(proID) --flames aren't destroyed when they hit shields. This fixes that.
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
	if shieldData.shieldEnabled == true then
		if shieldData.shieldCoverageChecked == false and AOEWeaponDefIDs[weaponDefID] then
			setCoveredUnits(shieldUnitID)
		end
	else
		removeCoveredUnits(shieldUnitID)
	end
end
