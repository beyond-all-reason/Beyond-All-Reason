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
--customParams shieldDowntime = <number in seconds>

local spGetUnitShieldState = Spring.GetUnitShieldState
local spSetUnitHealth = Spring.SetUnitHealth
local spGetUnitHealth = Spring.GetUnitHealth
local spGetProjectileDefID = Spring.GetProjectileDefID
local spSetUnitShieldState = Spring.SetUnitShieldState
local spSetProjectileDamages = Spring.SetProjectileDamages
local spGetUnitWeaponDamages = Spring.GetUnitWeaponDamages
local spSetProjectileCollision = Spring.SetProjectileCollision
local spGetUnitDefID = Spring.GetUnitDefID
local spGetGameSeconds = Spring.GetGameSeconds

local shieldUnitDefs = {}
local shieldUnitsData = {}
local originalShieldDamages = {}

for weaponDefID, weaponDef in ipairs(WeaponDefs) do
    if weaponDef.customParams.beamtime_damage_reduction_multiplier then
        local base = weaponDef.customParams.shield_damage
        local multiplier = weaponDef.customParams.beamtime_damage_reduction_multiplier
        local damage = math.max(base * multiplier)
        originalShieldDamages[weaponDefID] = math.floor(damage)
    else originalShieldDamages[weaponDefID] = tonumber(weaponDef.customParams.shield_damage)
    end
end

for id, data in pairs(UnitDefs) do
	if data.customParams.shield_radius then
        shieldUnitDefs[id] = data
        shieldUnitDefs[id]["defDowntime"] = tonumber(data.customParams.shield_downtime)
	end
end

function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
    if  shieldUnitsData[unitID] then
        shieldUnitsData[unitID].team = unitTeam
    elseif shieldUnitDefs[unitDefID] then
        shieldUnitsData[unitID] = {
            team = unitTeam,
            unitDefID = unitDefID,
            location = {0, 0, 0},
            shieldEnabled = false,
            shieldPower = 0,
            shieldDamage = 0,
            shieldWeaponNumber = -1,
            downtime = shieldUnitDefs[unitDefID].defDowntime,
            downtimeReset = 0
        }
    end
end

function gadget:UnitDestroyed(unitID)
    shieldUnitsData[unitID] = nil
end


local seconds
function gadget:GameFrame(frame)
seconds = spGetGameSeconds()
end

local function triggerDowntime(unitID, weaponNum)
    local shieldData = shieldUnitsData[unitID]
    local maxHealth = select(2, spGetUnitHealth(unitID))
    local paralyzeTime = maxHealth + ((maxHealth / 30) * shieldData.downtime)
    spSetUnitHealth(unitID, {paralyze = paralyzeTime})
    shieldData.downtimeReset = seconds+shieldData.downtime+1
end

function gadget:ShieldPreDamaged(proID, proOwnerID, shieldWeaponNum, shieldUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)
    local shieldData = shieldUnitsData[shieldUnitID]
    local shieldEnabled, shieldPower = spGetUnitShieldState(shieldUnitID)

    if shieldUnitsData[shieldUnitID] then
        shieldUnitsData[shieldUnitID].shieldWeaponNumber = shieldWeaponNum
        local damage = 0
        if -1 < proID then
            local proDefID = spGetProjectileDefID(proID)
            damage = originalShieldDamages[proDefID]
            shieldPower = math.max(shieldPower - damage, 0)
            spSetUnitShieldState(shieldUnitID, shieldWeaponNum, shieldPower)
            --spSetProjectileCollision(proID)
            if shieldData.downtime and shieldData.downtimeReset < seconds and shieldPower <= 0 then
                triggerDowntime(shieldUnitID, shieldWeaponNum)
            end
        elseif beamEmitterUnitID then
            local beamEmitterUnitDefID = spGetUnitDefID(beamEmitterUnitID)

            damage = originalShieldDamages[UnitDefs[beamEmitterUnitDefID].weapons[beamEmitterWeaponNum].weaponDef]
            shieldPower = math.max(shieldPower - damage, 0)
            spSetUnitShieldState(shieldUnitID, shieldWeaponNum, shieldPower)
            if shieldData.downtime and shieldData.downtimeReset < seconds and shieldPower <= 0 then
                triggerDowntime(shieldUnitID, shieldWeaponNum)
            end
        end
        Spring.Echo(damage, startX, startY, startZ)
        return false
    end
end

--gonna need to assign shieldWeaponNum upon initialization of the gadget to shieldUnitsdata[unitid]