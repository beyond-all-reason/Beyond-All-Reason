--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_ReclaimInfo.lua
--  brief:   Shows the amount of metal/energy when using area reclaim.
--  original author:  Janis Lukss
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
return {
name      = "ReclaimInfo",
desc      = "Shows the amount of metal/energy when using area reclaim.",
author    = "Pendrokar",
date      = "Nov 17, 2007",
license   = "GNU GPL, v2 or later",
layer     = 0,
enabled   = true -- loaded by default?
}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local start = false  --reclaim area cylinder drawing has been started
local metal = 0  --metal count from features in cylinder
local energy = 0  --energy count from features in cylinder
local rangestart = {}  --counting start center
local rangeend = {}  --counting radius end point
local b1was = false  -- cursor was outside the map?
local vsx, vsy = widgetHandler:GetViewSizes()
local form = 12 --text format depends on screen size
local xstart,ystart = 0
function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY
  form = math.floor(vsx/87)
end

function widget:Initialize()
end

function widget:DrawScreen()
  local _,cmd,_ = Spring.GetActiveCommand()
  local xend,yend
  local x, y, b1 = Spring.GetMouseState() --b1 = left button pressed?
  x, y = math.floor(x), math.floor(y) --TraceScreenRay needs this
  if (cmd==CMD.RECLAIM) and (rangestart ~= nil) and (b1) and (b1was == false) then
   if(rangestart[1] == 0) and (rangestart[3] == 0) then
     xstart,ystart = x,y
     start = false
     _, rangestart = Spring.TraceScreenRay(x, y, true) --cursor on world pos
   end
  elseif (rangestart == nil) and (b1) then
     b1was = true
    else
     b1was = false
    rangestart = {0, _,0}
  end 
  --bit more precise showing when mouse is moved by 4 pixels (start)
  if (b1 == true) and (rangestart ~= nil) and (cmd==CMD.RECLAIM) and (start==false) then
   xend, yend = x,y
    if (((xend>xstart+4)or(xend<xstart-4))or((yend>ystart+4)or(yend<ystart-4))) then
     start=true
    end
  end
  --
   if (b1 == true) and (rangestart ~= nil) and (cmd==CMD.RECLAIM) and start then
     _, rangeend = Spring.TraceScreenRay(x,y,true)
      if(rangeend == nil) then
      return 
      end
     metal=0
     energy=0
     local rdx, rdy = (rangestart[1] - rangeend[1]), (rangestart[3]- rangeend[3])
     local dist = math.sqrt((rdx * rdx) + (rdy * rdy))
     --because there is only GetFeaturesInRectangle. Features outside of the circle are needed to be ignored
     local units = Spring.GetFeaturesInRectangle(rangestart[1]-dist,rangestart[3]-dist,rangestart[1]+dist,rangestart[3]+dist)
     for _,unit in ipairs(units) do
        local ux, _, uy = Spring.GetFeaturePosition(unit)
        local udx, udy = (ux - rangestart[1]), (uy - rangestart[3])
        udist = math.sqrt((udx * udx) + (udy * udy))
        if(udist < dist) then
          local fm,_,fe  = Spring.GetFeatureResources(unit) 
          metal = metal + fm
          energy = energy + fe
        end
     end
     metal=math.floor(metal)
     energy=math.floor(energy)
    local textwidth = 12*gl.GetTextWidth("   M:"..metal.."\255\255\255\128".." E:"..energy)
     if(textwidth+x>vsx) then
      x = x - textwidth - 10
     end
      if(12+y>vsy) then
       y = y - form
      end
     gl.Text("   M:"..metal.."\255\255\255\128".." E:"..energy,x,y,form)
    end
    --Unit resource info when mouse on one
    if (cmd==CMD.RECLAIM) and (rangestart ~= nil) and ((energy==0) or (metal==0)) and (b1==false)  and buildprogress then
      local isunit, unitID = Spring.TraceScreenRay(x, y) --if on unit pos!
      if (isunit == "unit") then
       local unitDefID = Spring.GetUnitDefID(unitID)
       local _,_,_,_,buildprogress = Spring.GetUnitHealth(unitID)
       local ud = UnitDefs[unitDefID]
       if ud ~= nil then 
         metal=math.floor(ud.metalCost*buildprogress)
       else 
         metal = 0
       end
       local textwidth = 12*gl.GetTextWidth("   M:"..metal.."\255\255\255\128".." E:"..energy)
        if(textwidth+x>vsx) then
        x = x - textwidth - 10
        end
        if(12+y>vsy) then
         y = y - form
        end
        local color = "\255\255\255\255"
        if (Spring.GetUnitDefID(unitID) and not UnitDefs[Spring.GetUnitDefID(unitID)].reclaimable) then
         color = "\255\220\10\10"
        end
        gl.Text(color.."   M:"..metal,x,y,form)
      end
    end
    --
    metal = 0
    energy = 0
end
