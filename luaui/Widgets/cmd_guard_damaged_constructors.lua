local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name = "Guard damaged constructors",
    desc = "Replace repair command with guard command when right click targeting damaged constructors and factories",
    license = "GNU GPL, v2 or later",
    layer = 0,
    enabled = true
  }
end

local guardConstructors = true
local guardFactories = true

local isConstructor, isFactory = {}, {}
for unitDefID, unitDef in pairs(UnitDefs) do
  if unitDef.isMobileBuilder then
    isConstructor[unitDefID] = true
  end
  if unitDef.isFactory then
    isFactory[unitDefID] = true
  end
end

function widget:DefaultCommand(targetType, targetID, engineCmd)
  if targetType ~= "unit" then
    return
  end

  if engineCmd == CMD.REPAIR then
    if Spring.GetUnitIsBeingBuilt(targetID) then
      return
    end

    local unitDefID = Spring.GetUnitDefID(targetID)
    if (isConstructor[unitDefID] and guardConstructors) or (isFactory[unitDefID] and guardFactories)
    then
      return CMD.GUARD
    end
  end
end
