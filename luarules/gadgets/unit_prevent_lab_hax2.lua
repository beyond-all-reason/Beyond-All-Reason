function gadget:GetInfo()
  return {
    name      = "Prevent Lab Hax2",
    desc      = "Prevents units to keep being built after lab's death",
    author    = "Doo",
    date      = "Sept 2017",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

if (gadgetHandler:IsSyncedCode()) then
builder = {}
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID) -- destroy created unit if builder is dead
if Spring.ValidUnitID(builderID) and not Spring.GetUnitIsDead(builderID) then
else 
HP = Spring.GetUnitHealth(unitID) 
if HP <= 1 then -- avoid killing /give and Spring.CreateUnit() 
Spring.DestroyUnit(unitID, false, true)
end
end
end

function gadget:AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z, facing) -- do not allow create unit if builder is dead
if Spring.ValidUnitID(builderID) and not Spring.GetUnitIsDead(builderID) then
return true
else 
return false
end
end

end