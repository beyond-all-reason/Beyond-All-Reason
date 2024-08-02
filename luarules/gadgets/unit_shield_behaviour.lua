function gadget:GetInfo()
	return {
		name = "Shield Behaviour",
		desc = "Overrides default shield engine behavior. Defines downtime.",
		author = "SethDGamre",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end
--customParams shieldDowntime = def [number in seconds] or 5 seconds
--customParams shieldDowntimeThreshold = def [number] or 1% shield_power


local spSetProjectilePosition = Spring.SetProjectilePosition
local spSetProjectileVelocity = Spring.SetProjectileVelocity
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileDefID = Spring.GetProjectileDefID
local spGetUnitShieldState = Spring.GetUnitShieldState
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spSetUnitShieldState = Spring.SetUnitShieldState
local spGetGroundHeight = Spring.GetGroundHeight
local spDeleteProjectile = Spring.DeleteProjectile
local spGetProjectileOwnerID = Spring.GetProjectileOwnerID
local spSpawnExplosion = Spring.SpawnExplosion
local spGetUnitPosition = Spring.GetUnitPosition
local spSpawnCEG = Spring.SpawnCEG
local spGetGameSeconds = Spring.GetGameSeconds

local shieldUnitDefs = {}

for id, data in pairs(UnitDefs) do
	if data.customParams.shield_radius then
        shieldUnitDefs[id] = data
        shieldUnitDefs[id]["defDowntime"] = tonumber(data.customParams.shield_downtime) or 5
        shieldUnitDefs[id]["defDowntimeThreshold"] = tonumber(data.customParams.shield_downtime_threshold) or math.ceil(data.customParams.shield_power/100)
	end
end

local shieldUnitsData = {}

function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
    Spring.Echo("Unit Added!", UnitDefs[unitDefID].name)
    if  shieldUnitsData[unitID] then
        shieldUnitsData[unitID].team = unitTeam
        Spring.Echo("Team Changed!", UnitDefs[unitDefID].name, shieldUnitsData[unitID].team)
    elseif shieldUnitDefs[unitDefID] then
        Spring.Echo("Shield Unit Added!", UnitDefs[unitDefID].name)
        shieldUnitsData[unitID] = {
            team = unitTeam,
            unitDefID = unitDefID,
            location = {0, 0, 0},
            shieldEnabled = select(1,spGetUnitShieldState(unitID)),
            downtime = shieldUnitDefs[unitDefID].defDowntime,
            downtimeThreshold = shieldUnitDefs[unitDefID].defDowntimeThreshold,
            downtimeExpiration = 0,
            downtimeTriggered = false,
        }
    end
end

function gadget:UnitDestroyed(unitID)
    shieldUnitsData[unitID] = nil
end

-- function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
-- end

-- function gadget:ProjectileDestroyed(proID)
-- end
local secondsCount = 0
function gadget:GameFrame(frame)
    if frame % 30 == 0 then
        secondsCount = spGetGameSeconds()
        for unitID, data in pairs(shieldUnitsData) do
            if data.downtimeTriggered == true and secondsCount < data.downtimeExpiration then
                spSetUnitShieldState(unitID, -1, false)
                Spring.Echo("Suspend Shield")
            elseif data.downtimeTriggered == true then
                spSetUnitShieldState(unitID, -1, data.shieldEnabled)
                data.downtimeTriggered = false
                Spring.Echo("Reactivate Shield")
            end
        end
    end
end

-- function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
-- 	return damage
-- end

function gadget:ShieldPreDamaged(proID, proOwnerID, shieldWeaponNum, shieldUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)
    Spring.Echo("Shield Damaged!")
    if shieldUnitsData[shieldUnitID] then

		local shieldEnabledState, shieldPower = spGetUnitShieldState(shieldUnitID)

        Spring.Echo("ShieldPreDamaged Data", shieldUnitsData[shieldUnitID].downtimeTriggered, shieldUnitsData[shieldUnitID].downtimeThreshold)
        if shieldUnitsData[shieldUnitID].downtimeTriggered == false and shieldPower < shieldUnitsData[shieldUnitID].downtimeThreshold then
            shieldUnitsData[shieldUnitID].shieldEnabled = select(1,spGetUnitShieldState(shieldUnitID))
            shieldUnitsData[shieldUnitID].downtimeExpiration = secondsCount+shieldUnitsData[shieldUnitID].downtime
            shieldUnitsData[shieldUnitID].downtimeTriggered = true
            Spring.Echo("downtime triggered!", shieldUnitsData[shieldUnitID].shieldEnabled, shieldUnitsData[shieldUnitID].downtimeExpiration, shieldUnitsData[shieldUnitID].downtimeTriggered)
        end
    end
    return false
end
