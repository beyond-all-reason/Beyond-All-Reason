--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_enemy_spotter.lua
--  brief:   Draws transparant smoothed donuts under enemy units
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
      desc      = "Draws transparant smoothed donuts under enemy units (with teamcolors or predefined colors, depending on situation)",
      author    = "TradeMark  (Floris: added multiple ally color support)",
      date      = "17.03.2013",
      license   = "GNU GPL, v2 or later",
      layer     = 5,
      enabled   = false  --  loaded by default?
   }
end



--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local drawWithHiddenGUI                 = true    -- keep widget enabled when graphical user interface is hidden (when pressing F5)
local skipOwnAllyTeam                   = true    -- keep this 'true' if you dont want circles rendered under your own units

local circleSize                        = 1
local circleDivs                        = 12      -- how precise circle? octagon by default
local innercircleOpacity                = 0.35
local outercircleOpacity                = 0.3
local innerSize                         = 0.8    -- circle scale compared to unit radius
local outerSize                         = 1.35    -- outer fade size compared to circle scale (1 = no outer fade)
                                        
local defaultColorsForAllyTeams         = 0       -- (number of teams)   if number <= of total numebr of allyTeams then dont use teamcoloring but default colors
local keepTeamColorsForSmallAllyTeam    = 3       -- (number of teams)   use teamcolors if number or teams (inside allyTeam)  <=  this value
local spotterColor = {                            -- default color values
   {0,0,1} , {1,0,1} , {0,1,1} , {0,1,0} , {1,0.5,0} , {0,1,1} , {1,1,0} , {1,1,1} , {0.5,0.5,0.5} , {0,0,0} , {0.5,0,0} , {0,0.5,0} , {0,0,0.5} , {0.5,0.5,0} , {0.5,0,0.5} , {0,0.5,0.5} , {1,0.5,0.5} , {0.5,0.5,0.1} , {0.5,0.1,0.5},
}
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Automatically generated local definitions

local GL_ONE                  = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA  = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA            = GL.SRC_ALPHA
local glBlending              = gl.Blending
local glBeginEnd              = gl.BeginEnd
local glColor                 = gl.Color
local glCreateList            = gl.CreateList
local glDeleteList            = gl.DeleteList
local glDepthTest             = gl.DepthTest
local glDrawListAtUnit        = gl.DrawListAtUnit
local glPolygonOffset         = gl.PolygonOffset
local glVertex                = gl.Vertex
local spGetTeamColor          = Spring.GetTeamColor
local spGetUnitDefDimensions  = Spring.GetUnitDefDimensions
local spGetUnitDefID          = Spring.GetUnitDefID
local spIsUnitSelected        = Spring.IsUnitSelected
local spGetAllyTeamList       = Spring.GetAllyTeamList 
local spGetTeamList           = Spring.GetTeamList
local spGetVisibleUnits       = Spring.GetVisibleUnits
local spIsGUIHidden           = Spring.IsGUIHidden
local spGetUnitAllyTeam       = Spring.GetUnitAllyTeam
                              
local myTeamID                = Spring.GetLocalTeamID()
local myAllyID                = Spring.GetMyAllyTeamID()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local realRadii               = {}
local circlePolys             = {}
local allyToSpotterColor      = {}
local allyToSpotterColorCount = 0
local pickTeamColor           = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


-- Creating polygons:
function widget:Initialize()
   local allyTeamList = spGetAllyTeamList()
   local numberOfAllyTeams = #allyTeamList
   for allyTeamListIndex = 1, numberOfAllyTeams do
      local allyID                = allyTeamList[allyTeamListIndex]
      if not skipOwnAllyTeam  or  (skipOwnAllyTeam  and  not (allyID == myAllyID))  then
         allyToSpotterColorCount     = allyToSpotterColorCount+1
         allyToSpotterColor[allyID]  = allyToSpotterColorCount
         local usedSpotterColor      = spotterColor[allyToSpotterColorCount]
         if defaultColorsForAllyTeams < numberOfAllyTeams-1 then
            local teamList              = spGetTeamList(allyID)
            for teamListIndex = 1, #teamList do
               local teamID = teamList[teamListIndex]
               if (teamListIndex == 1  and  #teamList <= keepTeamColorsForSmallAllyTeam) then     -- only check for the first allyTeam  (to be consistent with picking a teamcolor or default color, inconsistency could happen with different teamsizes)
                  pickTeamColor = true
               end
               if pickTeamColor then
                  -- pick the first team in the allyTeam and take the color from that one
                  if (teamListIndex == 1) then
                     local r,g,b,a       = spGetTeamColor(teamID)
                     usedSpotterColor[1] = r
                     usedSpotterColor[2] = g
                     usedSpotterColor[3] = b
                  end
               end
            end
         end
         
         
         circlePolys[allyID] = glCreateList(function()
         
            glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)      -- disable layer blending
            
            -- colored inner circle:
            glBeginEnd(GL.TRIANGLES, function()
               local radstep = (2.0 * math.pi) / circleDivs
               for i = 1, circleDivs do
                  local a1 = (i * radstep)
                  local a2 = ((i+1) * radstep)
                  --(fadefrom)
                  glColor(usedSpotterColor[1], usedSpotterColor[2], usedSpotterColor[3], 0)
                  glVertex(0, 0, 0)
                  --(colorSet)
                  glColor(usedSpotterColor[1], usedSpotterColor[2], usedSpotterColor[3], innercircleOpacity)
                  glVertex(math.sin(a1), 0, math.cos(a1))
                  glVertex(math.sin(a2), 0, math.cos(a2))
               end
            end)
            
            if (outerSize ~= 1) then
               -- colored outer circle:
               glBeginEnd(GL.QUADS, function()
                  local radstep = (2.0 * math.pi) / circleDivs
                  for i = 1, circleDivs do
                     local a1 = (i * radstep)
                     local a2 = ((i+1) * radstep)
                     --(colorSet)
                     glColor(usedSpotterColor[1], usedSpotterColor[2], usedSpotterColor[3], outercircleOpacity)
                     glVertex(math.sin(a1), 0, math.cos(a1))
                     glVertex(math.sin(a2), 0, math.cos(a2))
                     --(fadeto)
                     glColor(usedSpotterColor[1], usedSpotterColor[2], usedSpotterColor[3], 0)
                     glVertex(math.sin(a2)*outerSize, 0, math.cos(a2)*outerSize)
                     glVertex(math.sin(a1)*outerSize, 0, math.cos(a1)*outerSize)
                  end
               end)
            end
         end)
      end
   end
end

function widget:Shutdown()
   --glDeleteList(circlePolys)
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
   realRadii[udid] = radius*circleSize
   return radius
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


-- Drawing:
function widget:DrawWorldPreUnit()
   if not drawWithHiddenGUI then
      if spIsGUIHidden() then return end
   end
   glDepthTest(true)
   glPolygonOffset(-100, -2)
   local visibleUnits = spGetVisibleUnits()
   if #visibleUnits then
      for i=1, #visibleUnits do
         unitID = visibleUnits[i]
         local allyID = spGetUnitAllyTeam(unitID)
         if circlePolys[allyID] ~= nil then
            if not skipOwnAllyTeam  or  (skipOwnAllyTeam  and  not (allyID == myAllyID))  then
               local unitDefIDValue = spGetUnitDefID(unitID)
               if (unitDefIDValue) then
                  local radius = GetUnitDefRealRadius(unitDefIDValue) * circleSize
                  if (radius) then
                     glDrawListAtUnit(unitID, circlePolys[allyID], false, radius, 1.0, radius)
                  end
               end
            end
         end
      end
   end
end
             

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------