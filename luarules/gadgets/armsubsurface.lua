function gadget:GetInfo()
	return {
		name = "armsubsurface",
		desc = "Handles Sea Platforms behaviours",
		author = "[Fx]Doo",
		date = "25 of June 2017",
		license = "Free",
		layer = 0,
		enabled = true
	}
end


if (gadgetHandler:IsSyncedCode()) then
UW = {}
SURF = {}
function gadget:UnitFinished(unitID)
unitDefID = Spring.GetUnitDefID(unitID)
unitName = UnitDefs[unitDefID].name
if unitName == "armsub" then
UW[unitID] = true
end
if unitName == "armsubsurface" then
SURF[unitID] = true
end
end

function gadget:GameFrame(f)
for unitID, under in pairs(UW) do
if not Spring.GetUnitIsActive(unitID) == true then

local x,y,z = Spring.GetUnitPosition(unitID)
local rx, ry, rz = Spring.GetUnitRotation(unitID)
local team = Spring.GetUnitTeam(unitID)
local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth(unitID)
local expert = Spring.GetUnitExperience(unitID)
local vx, vy, vz = Spring.GetUnitVelocity(unitID)
Spring.DestroyUnit(unitID, false, true)
UW[unitID] = nil
newID = Spring.CreateUnit("armsubsurface", x,y,z, "n", team)
Spring.SetUnitRotation(newID, rx,ry,rz)
Spring.SetUnitHealth(newID, health, captureProgress, paralyzeDamage, buildProgress)
Spring.SetUnitExperience(newID, expert)
Spring.SetUnitVelocity(newID, vx, vy, vz)
Spring.AddUnitDamage(newID, 835*1.05, 835*1.05, -1, -2)
Spring.Echo("added damages")
SURF[newID] = true
end
end
for unitID, under in pairs(SURF) do
if not Spring.GetUnitIsActive(unitID) == false then
local x,y,z = Spring.GetUnitPosition(unitID)
local rx, ry, rz = Spring.GetUnitRotation(unitID)
local team = Spring.GetUnitTeam(unitID)
local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth(unitID)
local expert = Spring.GetUnitExperience(unitID)
local vx, vy, vz = Spring.GetUnitVelocity(unitID)
Spring.DestroyUnit(unitID, false, true)
SURF[unitID] = nil
newID = Spring.CreateUnit("armsub", x,y,z, "n", team)
Spring.SetUnitRotation(newID, rx,ry,rz)
Spring.SetUnitHealth(newID, health, captureProgress, paralyzeDamage, buildProgress)
Spring.SetUnitExperience(newID, expert)
Spring.SetUnitVelocity(newID, vx, vy, vz)
Spring.AddUnitDamage(newID, 835*1.05, 835*1.05, -1, -2)
Spring.Echo("added damages")
UW[newID] = true
end
end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
Spring.Echo(damage)
Spring.Echo(paralyzer)
end

function gadget:UnitDestroyed(unitID)
if UW[unitID] then
UW[unitID] = nil
end
if SURF[unitID] then
UW[unitID] = nil
end
end
end