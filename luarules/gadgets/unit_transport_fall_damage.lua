function gadget:GetInfo()
	return {
		name = "Fall Damage from Transports",
		desc = "All units that fall from transports except Commandos receive height and mass proportional damage",
		author = "Beherith",
		date = "2023.06.22",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

--use customparams.fall_damage_multiplier = <number> to overwrite default damage multiplier as defined below.

local fallDamageMultipliers = {}
local masses = {}
local droppedunits = {}
local heightThreshold = 32 -- if unit is at least 32 elmos up consider it falling
local defaultDamageMult = 0.02 -- damage is 2% of mass * height if not defined in customParam.fall_damage_multiplier

for unitDefID, unitDef in ipairs(UnitDefs) do
	masses[unitDefID] = unitDef.mass
	if unitDef.customParams.fall_damage_multiplier then
		fallDamageMultipliers[unitDefID] = unitDef.customParams.fall_damage_multiplier
	end
end

local function GetUnitHeightAboveGroundAndWater(unitID) -- returns nil for invalid units
	if (Spring.GetUnitIsDead(unitID) ~= false) or (Spring.ValidUnitID(unitID) ~= true) then return nil end
	
	local px, py, pz = Spring.GetUnitBasePosition(unitID)
	if px and py and pz  then 	
		local gh = math.max(0, Spring.GetGroundHeight( px, pz ))
		return py - gh
	else
		return nil
	end
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	local unitHeight = GetUnitHeightAboveGroundAndWater(unitID)
	if unitHeight and unitHeight > heightThreshold then
		local damageMult = fallDamageMultipliers[unitDefID] or defaultDamageMult
		droppedunits[unitID] = unitHeight * masses[unitDefID] * damageMult
	end
end

function gadget:GameFrame()
	if next(droppedunits) then 
		for unitID, falldamage in pairs(droppedunits) do 
			local unitHeight = GetUnitHeightAboveGroundAndWater(unitID)
			if unitHeight then 
				if unitHeight < heightThreshold then 
					Spring.AddUnitDamage(unitID, falldamage, 0, Spring.GetGaiaTeamID(), 1)
					droppedunits[unitID] = nil
				end
			else -- dead
				droppedunits[unitID] = nil
			end
		end
	end
end
