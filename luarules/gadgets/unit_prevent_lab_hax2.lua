local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Prevent Lab Hax2",
        desc      = "Prevents units to keep being built after lab's death",
        author    = "Doo",
        date      = "Sept 2017",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

if (gadgetHandler:IsSyncedCode()) then

  local builder = {}
  local destroyQueue = {}
  local numtodestroy = 0
  
  function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID) -- destroy created unit if builder is dead
    if Spring.ValidUnitID(builderID) and not Spring.GetUnitIsDead(builderID) then
    else
      local HP = Spring.GetUnitHealth(unitID)
      if HP <= 1 then -- avoid killing /give and Spring.CreateUnit()
        destroyQueue[numtodestroy + 1] = unitID
        numtodestroy = numtodestroy + 1 
      end
    end
  end

function gadget:GameFrame()
    if numtodestroy > 0 then 
        for i = numtodestroy, 1, -1 do 
            Spring.DestroyUnit(destroyQueue[i], false, true)
            destroyQueue[i] = nil
        end
        numtodestroy = 0
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
