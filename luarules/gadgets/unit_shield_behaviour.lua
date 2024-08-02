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
--customParams shieldDowntime = <number in seconds> with a default fallback value if not defined.
--customParams shieldDowntimeThreshold = <number> with a default fallback value if not defined.

local spGetUnitShieldState = Spring.GetUnitShieldState
local spSetUnitHealth = Spring.SetUnitHealth
local spGetUnitHealth = Spring.GetUnitHealth
local spGetProjectileDefID = Spring.GetProjectileDefID
local spSetUnitShieldState = Spring.SetUnitShieldState
local spSetProjectileDamages = Spring.SetProjectileDamages
local spGetUnitWeaponDamages = Spring.GetUnitWeaponDamages
local spSetProjectileCollision = Spring.SetProjectileCollision

local shieldUnitDefs = {}
local shieldUnitsData = {}


for id, data in pairs(UnitDefs) do
	if data.customParams.shield_radius then
        shieldUnitDefs[id] = data
        shieldUnitDefs[id]["defDowntime"] = tonumber(data.customParams.shield_downtime) or 5
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
            shieldEnabled = select(1,spGetUnitShieldState(unitID)),
            shieldWeaponNumber = 0,
            downtime = shieldUnitDefs[unitDefID].defDowntime,
        }
    end
end

function gadget:UnitDestroyed(unitID)
    shieldUnitsData[unitID] = nil
end

local overwriteDamagesTable = {}
for i = 1, 40 do
    overwriteDamagesTable[i] = 0
end

function gadget:ShieldPreDamaged(proID, proOwnerID, shieldWeaponNum, shieldUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)
    if shieldUnitsData[shieldUnitID] then
		local shieldEnabledState, shieldPower = spGetUnitShieldState(shieldUnitID)
        local proDefID
        local damage

        if -1 < proID then
            proDefID = spGetProjectileDefID(proID)
            if WeaponDefs[proDefID].type == "DGun" then
                damage = 0 --Because damage is handled more precisely in unit_dgun_behavior.lua
            end
            damage = WeaponDefs[proDefID].damages[11]
        end
        
        if beamEmitterUnitID then
            damage = spGetUnitWeaponDamages(beamEmitterUnitID, beamEmitterWeaponNum, "11")
            spSetProjectileDamages(beamEmitterUnitID, beamEmitterWeaponNum, overwriteDamagesTable)
        end

        if damage and shieldPower < damage then
            shieldPower = 0
            spSetUnitShieldState(shieldUnitID, shieldWeaponNum, shieldEnabledState, shieldPower)
        end
 
        if  shieldPower < 1 then
            local maxHealth = select(2, spGetUnitHealth(shieldUnitID))
            local paralyzeTime = maxHealth + ((maxHealth/30)*shieldUnitsData[shieldUnitID].downtime)
            spSetUnitHealth(shieldUnitID, {paralyze = paralyzeTime })
            if beamEmitterUnitID then
            --space left blank to insert future code related to stopping beamlasers
            elseif proID then
                spSetProjectileCollision(proID)
            end
        end
        return true
    end
end
