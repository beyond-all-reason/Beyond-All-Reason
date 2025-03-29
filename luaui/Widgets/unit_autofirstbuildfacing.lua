
local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "Auto First Build Facing",
    desc      = "Set buildfacing toward map center on the first building placed",
    author    = "zwzsg with lotsa help from #lua channel",
    date      = "October 26, 2008",
    license   = "Free",
    layer     = 0,
    enabled   = true
  }
end


local facing=0
local x=0
local z=0
local n=0

-- Count all units and calculate their barycenter
function widget:GameFrame(f)
  if f==3 then
    if Spring.GetTeamUnitCount(Spring.GetMyTeamID()) and Spring.GetTeamUnitCount(Spring.GetMyTeamID())>0 then
      local units = Spring.GetTeamUnits(Spring.GetMyTeamID())
      for i=1,#units do
        local ux=0
        local uz=0
        ux,_,uz=Spring.GetUnitPosition(units[i])
        if ux and uz then
          x=x+ux
          z=z+uz
          n=n+1
        end
      end
    end
    x=x/n
    z=z/n
    widget.widgetHandler.RemoveCallIn(widget.widget,"GameFrame")
  end
end

-- Set buildfacing the first time a building is about to be built
function widget:Update()
  local _,cmd=Spring.GetActiveCommand()
  if cmd and cmd<0 then
    if math.abs(Game.mapSizeX - 2*x) > math.abs(Game.mapSizeZ - 2*z) then
      if (2*x>Game.mapSizeX) then
        facing="west"
      else
        facing="east"
      end
    else
      if (2*z>Game.mapSizeZ) then
        facing="north"
      else
        facing="south"
      end
    end
    Spring.SendCommands({"buildfacing "..facing})
    widget.widgetHandler.RemoveCallIn(widget.widget,"Update")
  end
end
