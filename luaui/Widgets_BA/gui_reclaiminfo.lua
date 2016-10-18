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
local nonground = "" --if reclaim order done with right click on a feature or unit 
local rangestart = {}  --counting start center
local rangestartinminimap = false --both start and end need to be equaly checked
local rangeend = {}  --counting radius end point
local b1was = false  -- cursor was outside the map?
local vsx, vsy = widgetHandler:GetViewSizes()
local form = 12 --text format depends on screen size
local xstart,ystart = 0
local cmd,xend,yend,x,y,b1,b2
local inMinimap = false --mouse cursor in minimap
function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY
  form = math.floor(vsx/87)
end

local function InMinimap(x,y)
  local posx,posy,sizex,sizey,minimized,maximized = Spring.GetMiniMapGeometry()
  rx,ry = (x-posx)/sizex,(y-posy)/sizey
  return (not (minimized or maximized)) and
         (rx>=0)and(rx<=1)and
         (ry>=0)and(ry<=1),rx,ry
end
local function MinimapToWorld(rx,ry)
  if (rx>=0)and(rx<=1)and
     (ry>=0)and(ry<=1)
  then
    local mapx,mapz = Game.mapSizeX*rx,Game.mapSizeZ-Game.mapSizeZ*ry
    local mapy = Spring.GetGroundHeight(mapx,mapz)
    return {mapx,mapy,mapz}
  else
    return {-1,-1,-1}
  end
end

function widget:Initialize()
end

function widget:DrawScreen()
  _,cmd,_ = Spring.GetActiveCommand()
  x, y, b1,_,b2 = Spring.GetMouseState() --b1 = left button pressed?
  nonground,_ = Spring.GetMouseCursor()
  x, y = math.floor(x), math.floor(y) --TraceScreenRay needs this
  if ((cmd==CMD.RECLAIM) and (rangestart ~= nil) and (b1) and (b1was == false)) or ((nonground == "Reclaim") and (b1was == false) and (b2) and (rangestart ~= nil)) then
   if(rangestart[1] == 0) and (rangestart[3] == 0) then
     local rx,ry
     inMinimap,rx,ry = InMinimap(x,y)
     if inMinimap then
        rangestart = MinimapToWorld(rx,ry)
        xstart,ystart = x,y
        start = false
        rangestartinminimap = true
     else
      xstart,ystart = x,y
      start = false
      rangestartinminimap = false
      _, rangestart = Spring.TraceScreenRay(x, y, true) --cursor on world pos
     end
   end
  elseif (rangestart == nil) and (b1) then
     b1was = true
    else
     b1was = false
    rangestart = {0, _,0}
  end 
  --bit more precise showing when mouse is moved by 4 pixels (start)
  if (b1 and (rangestart ~= nil) and (cmd==CMD.RECLAIM) and (start==false)) or ((nonground == "Reclaim") and (rangestart ~= nil) and (start==false) and (b2)) then
   xend, yend = x,y
    if (((xend>xstart+4)or(xend<xstart-4))or((yend>ystart+4)or(yend<ystart-4))) then
     start=true
    end
  end
  --
   if (b1 and (rangestart ~= nil) and (cmd==CMD.RECLAIM) and start) or ((nonground == "Reclaim") and start and b2 and (rangestart ~= nil)) then
   
     local rx,ry
     inMinimap,rx,ry = InMinimap(x,y)
     if inMinimap and rangestartinminimap then
        rangeend = MinimapToWorld(rx,ry)
     else
     _, rangeend = Spring.TraceScreenRay(x,y,true)
     end
     
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
    if (nonground=="Reclaim") and (rangestart ~= nil) and ((energy==0) or (metal==0)) and (b1==false) then
      local isunit, unitID = Spring.TraceScreenRay(x, y) --if on unit pos!
      if (isunit == "unit") and (Spring.GetUnitHealth(unitID)) then --Getunithealth just to make sure that it is in los
       local unitDefID = Spring.GetUnitDefID(unitID)
       local _,_,_,_,buildprogress = Spring.GetUnitHealth(unitID)
       metal=math.floor(UnitDefs[unitDefID].metalCost*buildprogress)
       local textwidth = 12*gl.GetTextWidth("   M:"..metal.."\255\255\255\128")
        if(textwidth+x>vsx) then
        x = x - textwidth - 10
        end
        if(12+y>vsy) then
         y = y - form
        end
        local color = "\255\255\255\255"
        if not UnitDefs[Spring.GetUnitDefID(unitID)].reclaimable then
         color = "\255\220\10\10"
        end
        gl.Text(color.."   M:"..metal,x,y,form)
      end
    end
    --
    metal = 0
    energy = 0
end
