--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_enemy_spotter.lua
--  brief:   Draws blue smoothed octagon under enemy units
--  author:  Dave Rodgers (orig. TeamPlatter edited by TradeMark)
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
   return {
      name      = "EnemySpotter",
      desc      = "Draws blue smoothed octagon under enemy units",
      author    = "TradeMark",
      date      = "03.12.2009",
      license   = "GNU GPL, v2 or later",
      layer     = 5,
      enabled   = false  --  loaded by default?
   }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Automatically generated local definitions

local GL_LINE_LOOP           = GL.LINE_LOOP
local GL_TRIANGLE_FAN        = GL.TRIANGLE_FAN
local glBeginEnd             = gl.BeginEnd
local glColor                = gl.Color
local glCreateList           = gl.CreateList
local glDeleteList           = gl.DeleteList
local glDepthTest            = gl.DepthTest
local glDrawListAtUnit       = gl.DrawListAtUnit
local glLineWidth            = gl.LineWidth
local glPolygonOffset        = gl.PolygonOffset
local glVertex               = gl.Vertex
local spDiffTimers           = Spring.DiffTimers
local spGetAllUnits          = Spring.GetAllUnits
local spGetGroundNormal      = Spring.GetGroundNormal
local spGetSelectedUnits     = Spring.GetSelectedUnits
local spGetTeamColor         = Spring.GetTeamColor
local spGetTimer             = Spring.GetTimer
local spGetUnitBasePosition  = Spring.GetUnitBasePosition
local spGetUnitDefDimensions = Spring.GetUnitDefDimensions
local spGetUnitDefID         = Spring.GetUnitDefID
local spGetUnitRadius        = Spring.GetUnitRadius
local spGetUnitTeam          = Spring.GetUnitTeam
local spGetUnitViewPosition  = Spring.GetUnitViewPosition
local spIsUnitSelected       = Spring.IsUnitSelected
local spIsUnitVisible        = Spring.IsUnitVisible
local spSendCommands         = Spring.SendCommands


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local circlePolys = 0
local myTeamID = Spring.GetLocalTeamID()
local realRadii = {}

local circleDivs = 8 -- how precise circle? octagon by default
local innersize = 1.5 -- circle scale compared to unit radius
local outersize = 1.75 -- outer fade size compared to circle scale (1 = no outer fade)

local fadefrom = { 0, 0, 1, 0 } -- inner color
local colorSet = { 0, 0, 1, 0.23 } -- middle color
local fadeto = { 0, 0, 1, 0 } -- outer color


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


-- Creating polygons:
function widget:Initialize()
   circlePolys = glCreateList(function()
      -- inner:
      glBeginEnd(GL.TRIANGLES, function()
         local radstep = (2.0 * math.pi) / circleDivs
         for i = 1, circleDivs do
            local a1 = (i * radstep)
            local a2 = ((i+1) * radstep)
            glColor(fadefrom)
            glVertex(0, 0, 0)
            glColor(colorSet)
            glVertex(math.sin(a1), 0, math.cos(a1))
            glVertex(math.sin(a2), 0, math.cos(a2))
         end
      end)
      if (outersize ~= 1) then
         -- outer edge:
         glBeginEnd(GL.QUADS, function()
            local radstep = (2.0 * math.pi) / circleDivs
            for i = 1, circleDivs do
               local a1 = (i * radstep)
               local a2 = ((i+1) * radstep)
               glColor(colorSet)
               glVertex(math.sin(a1), 0, math.cos(a1))
               glVertex(math.sin(a2), 0, math.cos(a2))
               glColor(fadeto)
               glVertex(math.sin(a2)*outersize, 0, math.cos(a2)*outersize)
               glVertex(math.sin(a1)*outersize, 0, math.cos(a1)*outersize)
            end
         end)
      end
   end)
end

function widget:Shutdown()
   glDeleteList(circlePolys)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


-- Retrieving radius:
local function GetUnitDefRealRadius(udid)
   local radius = realRadii[udid]
   if (radius) then return radius end
   local ud = UnitDefs[udid]
   if (ud == nil) then return nil end
   local dims = spGetUnitDefDimensions(udid)
   if (dims == nil) then return nil end
   local scale = ud.hitSphereScale -- missing in 0.76b1+
   scale = ((scale == nil) or (scale == 0.0)) and 1.0 or scale
   radius = dims.radius / scale
   realRadii[udid] = radius*innersize
   return radius
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


-- Drawing:
function widget:DrawWorldPreUnit()
   glDepthTest(true)
   glPolygonOffset(-100, -2)
   for _,unitID in ipairs(Spring.GetVisibleUnits()) do
      local teamID = spGetUnitTeam(unitID)
      if (teamID) then
         if ( not Spring.AreTeamsAllied(myTeamID, teamID) ) then
            local radius = GetUnitDefRealRadius(spGetUnitDefID(unitID))
            if (radius) then
               glDrawListAtUnit(unitID, circlePolys, false, radius, 1.0, radius)
            end
         end
      end
   end
end
             

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function CheckSpecState()
	local playerID = spGetMyPlayerID()
	local _, _, spec, _, _, _, _, _ = spGetPlayerInfo(playerID)
		
	if ( spec == true ) then
		spEcho("<EnemySpotter> Spectator mode. Widget removed.")
		widgetHandler:RemoveWidget()
		return false
	end
	
	return true	
end