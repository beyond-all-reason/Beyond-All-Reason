function gadget:GetInfo()
  return {
    name      = "Cancel orders on share",
    desc      = "Prevents units carrying on with orders once shared/taken",
    author    = "Bluestone",
    date      = "Jan 2015",
    license   = "SAUSAGE",
    layer     = 0,
    enabled   = true  
  }
end


if (not gadgetHandler:IsSyncedCode()) then
 
function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
  -- give all shared units a stop command
  Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {})

  -- remove their build queue
  local buildQ = Spring.GetFullBuildQueue(unitID) or {}
  for _,buildOrder in pairs(buildQ) do
    for uDID,count in pairs(buildOrder) do
        for i=1,count do
            Spring.GiveOrderToUnit(unitID, -uDID, {}, {"right"}) 
        end
    end
  end
  
  -- self d commands are removed by prevent_share_self_d
end

end