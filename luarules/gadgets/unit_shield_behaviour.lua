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
local projectilePenetrationOverrides = {}
local dgunWeapons = {}

for weaponDefID, weaponDef in ipairs(WeaponDefs) do
	if weaponDef.customParams.beamtime_damage_reduction_multiplier then
		local base = weaponDef.customParams.shield_damage
		local multiplier = weaponDef.customParams.beamtime_damage_reduction_multiplier
		local damage = math.max(base * multiplier)
		originalShieldDamages[weaponDefID] = math.floor(damage)
	else originalShieldDamages[weaponDefID] = tonumber(weaponDef.customParams.shield_damage)
	end
	if weaponDef.type == 'DGun' then
		dgunWeapons[weaponDefID] = weaponDef
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

function gadget:ShieldPreDamaged(proID, proOwnerID, shieldWeaponNum, shieldUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)
	local shieldData = shieldUnitsData[shieldUnitID]
	
	if not shieldData then
		return false
	end
	local _, shieldPower = spGetUnitShieldState(shieldUnitID)

	if shieldData.shieldEnabled == false then
		return true
	elseif shieldUnitsData[shieldUnitID] then
		shieldUnitsData[shieldUnitID].shieldWeaponNumber = shieldWeaponNum
		local damage

		if -1 < proID then
			local proDefID = spGetProjectileDefID(proID)
			if projectilePenetrationOverrides[proDefID] then
				return true
			end
			damage = originalShieldDamages[proDefID] or 0
			shieldPower = math.max(shieldPower - damage, 0)
			spSetUnitShieldState(shieldUnitID, shieldWeaponNum, shieldPower)
			if not dgunWeapons[proDefID] then
				spDeleteProjectile(proID)
			end
		elseif beamEmitterUnitID then
			local beamEmitterUnitDefID = spGetUnitDefID(beamEmitterUnitID)
			if projectilePenetrationOverrides[UnitDefs[beamEmitterUnitDefID].weapons[beamEmitterWeaponNum].weaponDef] then
				return true
			end
			
			damage = originalShieldDamages[UnitDefs[beamEmitterUnitDefID].weapons[beamEmitterWeaponNum].weaponDef] or 0
			shieldPower = math.max(shieldPower - damage, 0)
			spSetUnitShieldState(shieldUnitID, shieldWeaponNum, shieldPower)
		end

		if shieldData.downtime and shieldData.downtimeReset < seconds and shieldPower <= 0 then
			triggerDowntime(shieldUnitID, shieldWeaponNum)
		end

		return false
	end
end