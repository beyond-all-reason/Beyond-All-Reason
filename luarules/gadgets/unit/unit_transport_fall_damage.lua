function gadget:GetInfo()
	return {
		name = "Fall Damage from Transports",
		desc = "All units that fall from transports except Commandos receive height and mass proportional damage",
		author = "Beherith",
		date = "2023.06.22",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false  --  loaded by default?
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local commandoUnitDefID = UnitDefNames["cormando"].id
local masses = {}
local droppedunits = {}
local heightThreshold = 32 -- if unit is at least 32 elmos up consider it falling
local damageMult = 0.02 -- damage is 2% of mass * height

for unitDefID, unitDef in ipairs(UnitDefs) do
	masses[unitDefID] = unitDef.mass
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
	if unitDefID == commandoUnitDefID then return end
	
	local unitHeight = GetUnitHeightAboveGroundAndWater(unitID)
	if unitHeight and unitHeight > heightThreshold then 
		droppedunits[unitID] = unitHeight * masses[unitDefID] * damageMult
	end
end

function gadget:GameFrame()
	if next(droppedunits) then 
		for unitID, falldamage in pairs(droppedunits) do 
			local unitHeight = GetUnitHeightAboveGroundAndWater(unitID)
			if unitHeight then 
				if unitHeight < heightThreshold then 
					Spring.AddUnitDamage(unitID, falldamage)
					droppedunits[unitID] = nil
				end
			else -- dead
				droppedunits[unitID] = nil
			end
		end
	end
end
