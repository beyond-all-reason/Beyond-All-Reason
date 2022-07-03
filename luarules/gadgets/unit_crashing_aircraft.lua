function gadget:GetInfo()
	return {
		name      = "Crashing Aircraft",
		desc      = "Make aircraft crash-land instead of exploding",
		author    = "Beherith",
		date      = "aug 2012",
		license   = "PD",
		layer     = 1000,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local random = math.random
local GetUnitHealth = Spring.GetUnitHealth
local SetUnitCOBValue = Spring.SetUnitCOBValue
local SetUnitNoSelect = Spring.SetUnitNoSelect
local SetUnitNoMinimap = Spring.SetUnitNoMinimap
local SetUnitSensorRadius = Spring.SetUnitSensorRadius
local SetUnitWeaponState = Spring.SetUnitWeaponState
local SetUnitStealth = Spring.SetUnitStealth
local SetUnitNeutral = Spring.SetUnitNeutral
local SetUnitAlwaysVisible = Spring.SetUnitAlwaysVisible
local DestroyUnit = Spring.DestroyUnit

local COB_CRASHING = COB.CRASHING
local COM_BLAST = WeaponDefNames['commanderexplosion'].id

local isAircon = {}
local crashable  = {}
local alwaysCrash = {}
for udid,UnitDef in pairs(UnitDefs) do
	if UnitDef.canFly == true and UnitDef.transportSize == 0 and string.sub(UnitDef.name, 1, 7) ~= "critter" and string.sub(UnitDef.name, 1, 7) ~= "chicken" then
		crashable[UnitDef.id] = true
		if UnitDef.buildSpeed > 1 then
			isAircon[udid] = true
		end
	end
	if string.find(UnitDef.name, 'corcrw') or string.find(UnitDef.name, 'armliche') then
		alwaysCrash[UnitDef.id] = true
	end
end
--local nonCrashable = {'armpeep', 'corfink', 'corbw', 'armfig', 'armsfig', 'armhawk', 'corveng', 'corsfig', 'corvamp'}
local nonCrashable = {'armpeep', 'corfink', 'corbw'}
for udid, ud in pairs(UnitDefs) do
	for _, unitname in pairs(nonCrashable) do
		if string.find(ud.name, unitname) then
			crashable[udid] = nil
		end
	end
end

local crashing = {}
local crashingCount = 0

local totalUnitsTime = 0
local percentage = 0.6	-- is reset somewhere else

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if paralyzer then return damage,1 end
	if crashing[unitID] then
		return 0,0
	end

	if crashable[unitDefID] and (damage>GetUnitHealth(unitID)) and weaponDefID ~= COM_BLAST then
		if Spring.GetGameSeconds() - totalUnitsTime > 5 then
			totalUnitsTime = Spring.GetGameSeconds()
			local totalUnits = #Spring.GetAllUnits()
			percentage = (1 - (totalUnits/10000))
			if percentage < 0.6 then
				percentage = 0.6
			end
		end
		if random() < percentage or alwaysCrash[unitDefID] then
			-- increase gravity so it crashes faster
			local moveTypeData = Spring.GetUnitMoveTypeData(unitID)
			if moveTypeData['myGravity'] then
				Spring.MoveCtrl.SetAirMoveTypeData(unitID, 'myGravity', moveTypeData['myGravity'] * 1.7)
			end
			-- make it crash
			crashingCount = crashingCount + 1
			crashing[unitID] = Spring.GetGameFrame() + 230
			SetUnitCOBValue(unitID, COB_CRASHING, 1)
			SetUnitNoSelect(unitID,true)
			SetUnitNoMinimap(unitID,true)
			SetUnitStealth(unitID, true)
			SetUnitAlwaysVisible(unitID, false)
			SetUnitNeutral(unitID, true)
			for weaponID, weapon in pairs(UnitDefs[unitDefID].weapons) do
				SetUnitWeaponState(unitID, weaponID, "reloadState", 0)
				SetUnitWeaponState(unitID, weaponID, "reloadTime", 9999)
				SetUnitWeaponState(unitID, weaponID, "range", 0)
				SetUnitWeaponState(unitID, weaponID, "burst", 0)
				SetUnitWeaponState(unitID, weaponID, "aimReady", 0)
				SetUnitWeaponState(unitID, weaponID, "salvoLeft", 0)
				SetUnitWeaponState(unitID, weaponID, "nextSalvo", 9999)
			end
			-- remove sensors
			SetUnitSensorRadius(unitID, "los", 0)
			SetUnitSensorRadius(unitID, "airLos", 0)
			SetUnitSensorRadius(unitID, "radar", 0)
			SetUnitSensorRadius(unitID, "sonar", 0)

			-- make sure aircons stop building
			if isAircon[unitDefID] then
				Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
			end
		end
	end
	return damage,1
end

function gadget:GameFrame(gf)
	if crashingCount > 0 and gf % 44 == 1 then
		for unitID,deathGameFrame in pairs(crashing) do
			if gf >= deathGameFrame then
				DestroyUnit(unitID, false, true) --dont seld, but also dont leave wreck at all
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if crashing[unitID] then
		crashingCount = crashingCount - 1
		crashing[unitID] = nil
	end
end
