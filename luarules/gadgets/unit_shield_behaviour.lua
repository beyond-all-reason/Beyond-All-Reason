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
	originalShieldDamages[weaponDefID] = tonumber(weaponDef.customParams.shield_damage)
    if weaponDef.customParams.beamtime_damage_reduction_multiplier then
        local base = tonumber(weaponDef.customParams.shield_damage)
        local multiplier = tonumber(weaponDef.customParams.beamtime_damage_reduction_multiplier)
        local damage = math.max(base * multiplier)
        originalShieldDamages[weaponDefID] = damage
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

local hurtMeQueue = {}
function gadget:GameFrame(frame)
    -- Process the hurtMeQueue
    local seconds = spGetGameSeconds()
    for id, idData in pairs(hurtMeQueue) do
        for attackNumber, data in pairs(idData) do
            if data and data.damage then
                shieldUnitsData[data.shieldUnitID].shieldDamage = shieldUnitsData[data.shieldUnitID].shieldDamage+data.damage
            end
        end
        hurtMeQueue[id] = nil
    end
    
    if frame % 3 == 0 then
        for id, data in pairs(shieldUnitsData) do
            local shieldEnabled, shieldPower = spGetUnitShieldState(id)
            data.shieldEnabled = shieldEnabled
            data.shieldPower = shieldPower
            if data.shieldDamage > 0 then
                data.shieldPower = math.max(data.shieldPower - data.shieldDamage, 0)
                local newPower = tonumber(data.shieldPower)
                local shieldEnabled = tonumber(data.shieldEnabled)
                spSetUnitShieldState(id, data.shieldWeaponNumber, true, newPower)
                data.shieldDamage = 0
                shieldEnabled, shieldPower = spGetUnitShieldState(id)
                if data.downtime and data.downtimeReset < seconds and data.shieldPower <= 0 then
                    local maxHealth = select(2, spGetUnitHealth(id))
                    local paralyzeTime = maxHealth + ((maxHealth / 30) * shieldUnitsData[id].downtime)
                    spSetUnitHealth(id, {paralyze = paralyzeTime})
                    data.downtimeReset = seconds+data.downtime+1
                end
            end
        end
    end
end

function gadget:ShieldPreDamaged(proID, proOwnerID, shieldWeaponNum, shieldUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)
    if shieldUnitsData[shieldUnitID] then
        shieldUnitsData[shieldUnitID].shieldWeaponNumber = shieldWeaponNum
        local damage = 0
        if 0 < hitX and -1 < proID then
            local proDefID = spGetProjectileDefID(proID)
            damage = originalShieldDamages[proDefID]
            hurtMeQueue[proOwnerID] = hurtMeQueue[proOwnerID] or {}
            hurtMeQueue[proOwnerID][proID] = {
                damage = damage,
                shieldUnitID = shieldUnitID,
            }
            spSetProjectileCollision(proID)

        elseif beamEmitterUnitID then
            local beamEmitterUnitDefID = spGetUnitDefID(beamEmitterUnitID)
            damage = originalShieldDamages[UnitDefs[beamEmitterUnitDefID].weapons[beamEmitterWeaponNum].weaponDef]
            hurtMeQueue[beamEmitterUnitID] = hurtMeQueue[beamEmitterUnitID] or {}
            hurtMeQueue[beamEmitterUnitID][beamEmitterWeaponNum] = {
                damage = damage,
                shieldUnitID = shieldUnitID,
            }
        end
        return false
    end
end

--gonna need to assign shieldWeaponNum upon initialization of the gadget to shieldUnitsdata[unitid]