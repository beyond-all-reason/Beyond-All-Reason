local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Cancel orders on share",
        desc      = "Prevents units carrying on with orders once shared/taken and turns on mexes that have been captured",
        author    = "Bluestone, Beherith",
        date      = "Jan 2015",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end


if (not gadgetHandler:IsSyncedCode()) then

  function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
    -- give all shared units a stop command
    Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)

    -- remove their build queue
    local buildQ = Spring.GetFullBuildQueue(unitID) or {}
    for _,buildOrder in pairs(buildQ) do
      for uDID,count in pairs(buildOrder) do
        for i=1,count do
          Spring.GiveOrderToUnit(unitID, -uDID, {}, {"right"})
        end
      end
    end
  end

else -- SYNCED

  local recievedMexes = {}

  function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
    -- if the unit is a metal extractor, turn it on:
    if UnitDefs[unitDefID] and UnitDefs[unitDefID].extractsMetal and UnitDefs[unitDefID].extractsMetal > 0 then
      recievedMexes[#recievedMexes+1] = unitID
    end
  end

  function gadget:GameFrame(n)
    if n%37 == 0 and #recievedMexes > 0 then
      for i, unitID in ipairs(recievedMexes) do
        if Spring.ValidUnitID(unitID) then
          Spring.GiveOrderToUnit( unitID, CMD.ONOFF, { 1 }, 0 )
        end
      end
      recievedMexes = {}
    end
  end

end
