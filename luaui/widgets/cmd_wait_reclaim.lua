
function widget:GetInfo()
  return {
    name      = "Wait reclaim",
    desc      = "Enables pausing a reclaim with wait",
    author    = "Pako",
    date      = "25.04.2011 -26.05.2011",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

function widget:Initialize()
  if Spring.GetSpectatingState() or Spring.IsReplay() then
    widgetHandler:RemoveWidget()
    return false
  end
end

function widget:PlayerChanged()
  if Spring.GetSpectatingState() or Spring.IsReplay() then
    widgetHandler:RemoveWidget()
  end
end


function widget:UnitCommand(unitId, unitDefId, unitTeam, cmdId, cmdOpts, cmdParams)
  if (cmdId == CMD.WAIT) then
      local cQueue = Spring.GetCommandQueue(unitId)
	if(cQueue~=nil and (#cQueue)>=1 and cQueue[1].id == CMD.RECLAIM)then
	  Spring.GiveOrderToUnit(unitId, CMD.REMOVE, {cQueue[1].tag},{""})
	  Spring.GiveOrderToUnit(unitId, CMD.INSERT, {1, CMD.RECLAIM, CMD.OPT_SHIFT, unpack(cQueue[1].params)}, {"alt"})
	  return false
	end
   end
end
