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
local spGetProjectileDefID = Spring.GetProjectileDefID
local spSetUnitShieldState = Spring.SetUnitShieldState
local spGetUnitDefID = Spring.GetUnitDefID
local spGetGameSeconds = Spring.GetGameSeconds
local spSetUnitShieldRechargeDelay = Spring.SetUnitShieldRechargeDelay
local spDeleteProjectile =  Spring.DeleteProjectile

local shieldUnitDefs = {}
local shieldUnitsData = {}
local originalShieldDamages = {}
local flameWeapons = {}

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
			shieldEnabled = true,
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
	if frame % 10 == 0 then
		for shieldUnitID, shieldData in pairs (shieldUnitsData) do
			if shieldData.downtimeReset and shieldData.downtimeReset ~= 0 and shieldData.downtimeReset <= seconds then
				spSetUnitShieldRechargeDelay(shieldUnitID, shieldData.shieldWeaponNumber, 0)
				shieldData.downtimeReset = 0
				shieldData.shieldEnabled = true
			end
		end
	end
end

local function triggerDowntime(unitID, weaponNum)
	local shieldData = shieldUnitsData[unitID]
	spSetUnitShieldRechargeDelay(unitID, weaponNum, 10000)
	spSetUnitShieldState(unitID, weaponNum, false)
	shieldData.downtimeReset = seconds+shieldData.downtime
	shieldData.shieldEnabled = false
end

function gadget:ShieldPreDamaged(proID, _, shieldWeaponNum, shieldUnitID, _, beamEmitterWeaponNum, beamEmitterUnitID)
    local shieldData = shieldUnitsData[shieldUnitID]
    
	if not shieldData or not shieldData.shieldEnabled then
        return true
    end

    local enabledState, shieldPower = spGetUnitShieldState(shieldUnitID)
    shieldData.shieldWeaponNumber = shieldWeaponNum
    local damage = 0

    if proID > -1 then
        local proDefID = spGetProjectileDefID(proID)
        damage = originalShieldDamages[proDefID] or 0
        shieldPower = shieldPower - damage
		if shieldPower < 0 then
			shieldPower = 0
		end
        spSetUnitShieldState(shieldUnitID, shieldWeaponNum, shieldPower)
        if flameWeapons[proDefID] then
            spDeleteProjectile(proID)
        end
    elseif beamEmitterUnitID then
        local beamEmitterUnitDefID = spGetUnitDefID(beamEmitterUnitID)
        local weaponDef = UnitDefs[beamEmitterUnitDefID].weapons[beamEmitterWeaponNum].weaponDef
        damage = originalShieldDamages[weaponDef] or 0
		shieldPower = shieldPower - damage
		if shieldPower < 0 then
			shieldPower = 0
		end
        spSetUnitShieldState(shieldUnitID, shieldWeaponNum, shieldPower)
    end

    if shieldData.downtimeReset < seconds and shieldPower <= 0 then
        triggerDowntime(shieldUnitID, shieldWeaponNum)
    end

    return false
end