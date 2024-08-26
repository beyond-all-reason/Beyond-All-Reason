function gadget:GetInfo()
	return {
		name = "Fall Damage from Transports",
		desc = "All units that fall from transports except Commandos receive height and mass proportional damage",
		author = "Beherith, SethDGamre",
		date = "2023.06.22",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end
--this gadget is enabled as a bandaid fix for commander effigies. Units cannot be moved when released from transports using Spring.SetUnitPosition until it lands, meaning effigy transposition cannot occur until commander lands. This gadget is pending approval from the GDT for mainline use.

--use customparams.fall_damage_multiplier = <number> to overwrite default damage multiplier as defined below.
local fallDamageMultipliers = {}
local masses = {}
local droppedunits = {}
local heightThreshold = 32 -- if unit is at least 32 elmos up consider it falling
local landedThreshold = 0 -- once the unit's height is equal or below ground height, take damage.
local defaultDamageMult = 0.03 -- damage is 3% of mass * dropHeight if not defined in customParam.fall_damage_multiplier

for unitDefID, unitDef in ipairs(UnitDefs) do
	masses[unitDefID] = unitDef.mass
	if unitDef.customParams.fall_damage_multiplier then
		fallDamageMultipliers[unitDefID] = unitDef.customParams.fall_damage_multiplier
	end
end

local function GetUnitHeightAboveGroundAndWater(unitID) -- returns nil for invalid units
	if (Spring.GetUnitIsDead(unitID) ~= false) or (Spring.ValidUnitID(unitID) ~= true) then return nil end

	local px, py, pz = Spring.GetUnitPosition(unitID)
	if px and py and pz  then
		local groundHeight = math.max(0, Spring.GetGroundHeight( px, pz ))
		return py - groundHeight
	else
		return nil
	end
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	local deadTransport = Spring.GetUnitIsDead(transportID)
	if deadTransport then
		local unitDropDistance = GetUnitHeightAboveGroundAndWater(unitID)
		if unitDropDistance and unitDropDistance > heightThreshold then
			local damageMult = fallDamageMultipliers[unitDefID] or defaultDamageMult
			droppedunits[unitID] = unitDropDistance * masses[unitDefID] * damageMult
		end
	end
end

function gadget:GameFrame()
	if next(droppedunits) then
		for unitID, dropDamage in pairs(droppedunits) do
			local unitHeight = GetUnitHeightAboveGroundAndWater(unitID)
			if unitHeight then
				if unitHeight <= landedThreshold then
					Spring.AddUnitDamage(unitID, dropDamage, 0, Spring.GetGaiaTeamID(), 1)
					droppedunits[unitID] = nil
				end
			else -- dead
				droppedunits[unitID] = nil
			end
		end
	end
end
