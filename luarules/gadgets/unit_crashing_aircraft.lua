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
     
if (not gadgetHandler:IsSyncedCode()) then
  return
end

local random			= math.random 
local GetUnitHealth 	= Spring.GetUnitHealth
local SetUnitCOBValue 	= Spring.SetUnitCOBValue
local SetUnitNoSelect	= Spring.SetUnitNoSelect
local SetUnitNoMinimap	= Spring.SetUnitNoMinimap
local SetUnitSensorRadius = Spring.SetUnitSensorRadius
local SetUnitWeaponState = Spring.SetUnitWeaponState
local DestroyUnit = Spring.DestroyUnit

local COB_CRASHING = COB.CRASHING
local COM_BLAST = WeaponDefNames['commanderexplosion'].id

local crashable  = {}
local crashing = {}
local crashingCount = 0

local totalUnitsTime = 0
local percentage = 0.5	-- is reset somewhere else

function gadget:Initialize()
	--set up table to check against
	for _,UnitDef in pairs(UnitDefs) do
		if UnitDef.canFly == true and UnitDef.transportSize == 0 and string.sub(UnitDef.name, 1, 7) ~= "critter" and string.sub(UnitDef.name, 1, 7) ~= "chicken" then
			crashable[UnitDef.id] = true
		end
	end
	crashable[UnitDefNames['armliche'].id] = false
	crashable[UnitDefNames['armpeep'].id] = false
	crashable[UnitDefNames['corfink'].id] = false

	crashable[UnitDefNames['corbw'].id] = false

	crashable[UnitDefNames['armfig'].id] = false
	crashable[UnitDefNames['armsfig'].id] = false
	crashable[UnitDefNames['armhawk'].id] = false
	crashable[UnitDefNames['corveng'].id] = false
	crashable[UnitDefNames['corsfig'].id] = false
	crashable[UnitDefNames['corvamp'].id] = false
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if paralyzer then return damage,1 end
	if crashing[unitID] then
		return 0,0
	end

	if crashable[unitDefID] and (damage>GetUnitHealth(unitID)) and weaponDefID ~= COM_BLAST then
		if Spring.GetGameSeconds() - totalUnitsTime > 5 then
			totalUnitsTime = Spring.GetGameSeconds()
			local totalUnits = #Spring.GetAllUnits()
			percentage = 0.7 * (1 - (totalUnits/5000))
			if percentage < 0.25 then
				percentage = 0.25
			end
		end
		if random() < percentage then
			-- make it crash
			crashingCount = crashingCount + 1
			crashing[unitID] = Spring.GetGameFrame() + 300
			SetUnitCOBValue(unitID, COB_CRASHING, 1)
			SetUnitNoSelect(unitID,true)
			SetUnitNoMinimap(unitID,true)
			for weaponID, weapon in pairs(UnitDefs[unitDefID].weapons) do
				SetUnitWeaponState(unitID, weaponID, "reloadTime", 9999)
			end
			-- remove sensors
			SetUnitSensorRadius(unitID, "los", 0)
			SetUnitSensorRadius(unitID, "airLos", 0)
			SetUnitSensorRadius(unitID, "radar", 0)
			SetUnitSensorRadius(unitID, "sonar", 0)
		end
	end
	return damage,1
end

function gadget:GameFrame(gf)
	if crashingCount > 0 and gf % 44 == 1 then
		for unitID,deathGameFrame in pairs(crashing) do
			if gf >= deathGameFrame then
				DestroyUnit(unitID, false, false)
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if crashing[unitID] then
		crashingCount = crashingCount - 1
		crashing[unitID]=nil
	end
end
