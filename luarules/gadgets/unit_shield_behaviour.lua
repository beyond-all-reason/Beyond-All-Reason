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

local shieldUnitDefs = {}
local shieldUnitsData = {}
local originalShieldDamages = {}


for id, data in pairs(UnitDefs) do
	if data.customParams.shield_radius then
        shieldUnitDefs[id] = data
        shieldUnitDefs[id]["defDowntime"] = tonumber(data.customParams.shield_downtime)
	end
    if data.weapons then
        Spring.Echo("Weapons:", data.weapon)
    end
end

for weaponDefID, weaponDef in ipairs(WeaponDefs) do
	originalShieldDamages[weaponDefID] = weaponDef.customParams.shield_damage
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

function gadget:GameFrame(frame)
--need to prevent extra extra damage from happening to shields from multiple collisions handed down from weapons with staying power
	end

function gadget:ShieldPreDamaged(proID, proOwnerID, shieldWeaponNum, shieldUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)
    if shieldUnitsData[shieldUnitID] then
		local shieldEnabledState, shieldPower = spGetUnitShieldState(shieldUnitID)
        local proDefID
        local beamEmitterUnitDefID
        local damage

        if 0 < hitX and -1 < proID then
            proDefID = spGetProjectileDefID(proID)
            damage = originalShieldDamages[proDefID]
        elseif 0 < hitX and beamEmitterUnitID  then
            beamEmitterUnitDefID = spGetUnitDefID(beamEmitterUnitID)
            damage = originalShieldDamages[UnitDefs[beamEmitterUnitDefID].weapons[beamEmitterWeaponNum].weaponDef]
            Spring.Echo("originalShieldDamages", originalShieldDamages[UnitDefs[beamEmitterUnitDefID].weapons[beamEmitterWeaponNum].weaponDef])
        end

        Spring.Echo("Damage received!",damage)
        if damage then
            shieldPower = math.max(shieldPower - damage, 0)
            spSetUnitShieldState(shieldUnitID, shieldWeaponNum, shieldEnabledState, shieldPower)
        end
 
        if  shieldUnitsData[shieldUnitID].downtime and shieldPower < 1 then
            local maxHealth = select(2, spGetUnitHealth(shieldUnitID))
            local paralyzeTime = maxHealth + ((maxHealth/30)*shieldUnitsData[shieldUnitID].downtime)
            spSetUnitHealth(shieldUnitID, {paralyze = paralyzeTime })
        end
        return false
    end
end
