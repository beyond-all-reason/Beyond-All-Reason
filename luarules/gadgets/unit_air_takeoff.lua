function gadget:GetInfo()
  return {
    name      = "Takeoff Fix",
    desc      = "Hack to prevent airlab waiting for takeoff",
    author    = "Pako",
    date      = "2011.11.26",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
  if UnitDefs[unitDefID].canFly and not UnitDefs[unitDefID].hoverAttack then
    --local x,y,z = Spring.GetUnitPosition(unitID)
    --local h = UnitDefs[unitDefID].wantedHeight
    Spring.MoveCtrl.Enable(unitID)
    --Spring.MoveCtrl.SetPosition(unitID, x,y+h*2,z) --uncomment these lines if doesn't work
    Spring.MoveCtrl.SetProgressState(unitID, "done")
    Spring.MoveCtrl.Disable(unitID)
  end
end