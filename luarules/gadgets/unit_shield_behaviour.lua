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

local spGetUnitShieldState = Spring.GetUnitShieldState
local spSetUnitShieldState = Spring.SetUnitShieldState
local spGetGameSeconds = Spring.GetGameSeconds
local spSetUnitShieldRechargeDelay = Spring.SetUnitShieldRechargeDelay
local spDeleteProjectile =  Spring.DeleteProjectile
local spGetUnitHealth = Spring.GetUnitHealth
local spSetUnitHealth = Spring.SetUnitHealth
local spGetProjectileDefID = Spring.GetProjectileDefID

local shieldUnitDefs = {}
local shieldUnitsData = {}
local originalShieldDamages = {}
local flameWeapons = {}
local unitDefIDCache = {}
local projectileDefIDCache = {}
local gameSeconds


for weaponDefID, weaponDef in ipairs(WeaponDefs) do
	if weaponDef.customParams.beamtime_damage_reduction_multiplier then
		local base = weaponDef.customParams.shield_damage
		local multiplier = weaponDef.customParams.beamtime_damage_reduction_multiplier
		local damage = math.max(base * multiplier)
		originalShieldDamages[weaponDefID] = math.floor(damage)
	else originalShieldDamages[weaponDefID] = tonumber(weaponDef.customParams.shield_damage)
	end
	if weaponDef.type == 'Flame' then
		flameWeapons[weaponDefID] = weaponDef
	end
end

for id, data in pairs(UnitDefs) do
	if data.customParams.shield_radius then
		shieldUnitDefs[id] = data
		shieldUnitDefs[id]["defDowntime"] = tonumber(data.customParams.shield_downtime) or 5
		if data.speed == 0 then
			shieldUnitDefs[id]["isStatic"] = true
		end
	end
end

function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
	if  shieldUnitsData[unitID] then
		shieldUnitsData[unitID].team = unitTeam
	elseif shieldUnitDefs[unitDefID] then
		shieldUnitsData[unitID] = {
			isStatic = shieldUnitDefs[unitDefID].isStatic or false,
			team = unitTeam,
			unitDefID = unitDefID,
			location = {0, 0, 0},
			shieldEnabled = true,
			shieldPower = 0,
			shieldDamage = 0,
			shieldWeaponNumber = -1,
			downtime = shieldUnitDefs[unitDefID].defDowntime,
			downtimeReset = 0
		}
	end
	unitDefIDCache[unitID] = unitDefID
end

function gadget:UnitDestroyed(unitID)
	shieldUnitsData[unitID] = nil
	unitDefIDCache[unitID] = nil
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	projectileDefIDCache[proID] = weaponDefID
end

function gadget:ProjectileDestroyed(proID)
	projectileDefIDCache[proID] = nil
end

local function triggerDowntime(unitID, weaponNum)
	local shieldData = shieldUnitsData[unitID]
	if shieldData.isStatic then
		local maxHealth = select(2, spGetUnitHealth(unitID))
		local paralyzeTime = maxHealth + ((maxHealth/30)*shieldData.downtime)
		spSetUnitHealth(unitID, {paralyze = paralyzeTime })
	else
		spSetUnitShieldRechargeDelay(unitID, weaponNum, shieldData.downtime)
		spSetUnitShieldState(unitID, weaponNum, false)
		shieldData.downtimeReset = gameSeconds+shieldData.downtime
		shieldData.shieldEnabled = false
	end
end

local shieldCheckFlags = {}
function gadget:GameFrame(frame)
    gameSeconds = spGetGameSeconds()

    if frame % 10 == 0 then
        for shieldUnitID, shieldData in pairs(shieldUnitsData) do
            if shieldData and shieldData.downtimeReset and shieldData.downtimeReset ~= 0 and shieldData.downtimeReset <= gameSeconds then
                spSetUnitShieldRechargeDelay(shieldUnitID, shieldData.shieldWeaponNumber, 0)
                shieldData.downtimeReset = 0
                shieldData.shieldEnabled = true
            end
        end
    end

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
				end
			else
				shieldData.shieldDamage = 0
			end
			shieldCheckFlags[shieldUnitID] = nil
		end
	end
end

function gadget:ShieldPreDamaged(proID, proOwnerID, shieldWeaponNum, shieldUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)
    local shieldData = shieldUnitsData[shieldUnitID]
    
    if not shieldData or not shieldData.shieldEnabled then
        return true
    end
    shieldData.shieldWeaponNumber = shieldWeaponNum
    if proID > -1 then
        local proDefID = projectileDefIDCache[proID]
        if not proDefID then
            proDefID = spGetProjectileDefID(proID) -- because flame projectiles for some reason don't live long enough to reference from the cache table
        end
        shieldData.shieldDamage = (shieldData.shieldDamage + originalShieldDamages[proDefID])
        if flameWeapons[proDefID] then
            spDeleteProjectile(proID)
        end
    elseif beamEmitterUnitID then
        local beamEmitterUnitDefID = unitDefIDCache[beamEmitterUnitID]
        if not beamEmitterUnitDefID then
            return false
        end
        local weaponDef = UnitDefs[beamEmitterUnitDefID].weapons[beamEmitterWeaponNum].weaponDef
        shieldData.shieldDamage = (shieldData.shieldDamage + originalShieldDamages[weaponDef])
    end
	shieldCheckFlags[shieldUnitID] = true
	return false
end