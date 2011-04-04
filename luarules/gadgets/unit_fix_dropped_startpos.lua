function gadget:GetInfo()
  return {
    name      = "DroppedStartPos",
    desc      = "fixes start postion for dropped players",
    author    = "SirMaverick",
    date      = "August 3, 2009",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
  }
end

-- SYNCED
if gadgetHandler:IsSyncedCode() then

function gadget:GameFrame(n)

  if (n == 1) then
    -- check if all units are within their start boxes
    local units = Spring.GetAllUnits()
    for i=1,#units do

      repeat -- emulating "continue"

        local unitid = units[i]
        local allyid = Spring.GetUnitAllyTeam(unitid)
        if not allyid then break end
        local xmin, zmin, xmax, zmax = Spring.GetAllyTeamStartBox(allyid)
        if not xmin then break end
        local x, y, z = Spring.GetUnitPosition(unitid)

        if not x then break end
        if (xmin <= x+16 and x-16 <= xmax and zmin <= z+16 and z-16 <= zmax) then
          -- all ok
        else
          -- move into middle of team start box
          Spring.SetUnitPosition(unitid, (xmin+xmax)/2, (zmin+zmax)/2)
          Spring.GiveOrderToUnit(unitid, CMD.STOP, {}, {});
        end
      until true
    end

    gadgetHandler:RemoveGadget()
    return

  end
end

else
-- UNSYNCED

end

