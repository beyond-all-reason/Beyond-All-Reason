function widget:GetInfo()
  return {
   name     = "Dynamic Blob Shadows",
   desc     = "Creates shadow projections from the sun position that wrap around the unit size",
   author   = "user, speedups by Argh",
   date     = "March 3, 2008",
   license   = "GNU GPL, v2",
   layer    = -1,
   enabled   = false 
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local side = 0
local xmul = 0
local zmu = 0
local ShadowList = {}
local sunx,suny,sunz = gl.GetSun()
local shadowdens = gl.GetSun("shadowdensity","unit")
local SR, SG, SB = gl.GetSun("ambient","unit")
local noshadow = 0
local shadowsareon = 0
local sundist = 0
local realdist = 0
local greater  = 0
local sunscale = 0   
local sunangle = 0 
local cangle = 0
                            
local ShadowsOn         = Spring.HaveShadows
local list   
local UnitIDList
local height, diff, fx, fy, x, y, z, cx, cy, cz, id
local ShadowTex = 'LuaUI/Images/shadow.tga'


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- sun calculations,for projection----------------------------------------------
--------------------------------------------------------------------------------
sunangle = Spring.GetHeadingFromVector(sunx,sunz)/182.0444445 --exact number to convert a short integer to a 0 to 360 number. 
sunangle = sunangle + (360+90)                        --when it is 65536, divide it by 182,0444445 you get 360. 
if (sunangle > 360) then
   sunangle = sunangle - 360
end
if (suny < 0 )then
   noshadow = 1
else
   sunscale = math.abs(suny + 0.1)* 200
   sunscale = math.abs(sunscale - 200) * 100
end
sundist = math.pow(sunx,2) + math.pow(sunz,2)
sundist = math.sqrt(sundist)
realdist = sundist * 50
sunscale = sunscale / 1876

local glTexture = gl.Texture
local glDepthMask = gl.DepthMask
local glDepthTest = gl.DepthTest
local glColor = gl.Color
local SpringGetUnitDefID = Spring.GetUnitDefID
local SpringGetUnitViewPosition = Spring.GetUnitViewPosition
local SpringGetGroundHeight = Spring.GetGroundHeight
local glPushMatrix = gl.PushMatrix
local glDrawListAtUnit = gl.DrawListAtUnit
local glPopMatrix = gl.PopMatrix
local glCreateList = gl.CreateList
local  glBeginEnd =  gl.BeginEnd
local GLQUAD_STRIP = GL.QUAD_STRIP
local glTexCoord = gl.TexCoord
local glVertex = gl.Vertex
local SpringGetCameraPosition = Spring.GetCameraPosition
local SpringGetVisibleUnits = Spring.GetVisibleUnits
local cx,cy,cz = 0,0,0

if SR > 1.0 then SR = 0.5 end
if SG > 1.0 then SG = 0.5 end
if SB > 1.0 then SB = 0.5 end
if shadowdens == nil or shadowdens > 1.0 then shadowdens = 0.5 end

function widget:DrawWorldPreUnit()
   cx,cy,cz = SpringGetCameraPosition()

   glTexture(ShadowTex)
   glDepthMask(false)
   glDepthTest(false)
   glColor(SR,SG,SB,shadowdens)

   unitIDList = SpringGetVisibleUnits(-1,3000,false)

   if unitIDList[1] == nil then
      return false
   else
      if (ShadowsOn()) then
         return false
      else
         if cy < 25 or cy > 4000 then
            return false
         else         
            for _,unitID in ipairs(unitIDList) do
               id = SpringGetUnitDefID(unitID)
               x,y,z = SpringGetUnitViewPosition(unitID)
               height = SpringGetGroundHeight(x,z)
               diff = height-y+5
               if ShadowList[id] then
                  fx = UnitDefs[id].xsize
                  fy = UnitDefs[id].zsize
                  glPushMatrix()
                  glDrawListAtUnit(unitID,list,false,fx,1.0,fy,sunangle,0,1.0,0)
                  glPopMatrix()				
               end                                                                                                                                                      
            end
         end
      end
   end
   glDepthMask(true)
   glDepthTest(true)
   glColor(1,1,1,1)   
end

function widget:Initialize()

   for ud,_ in pairs(UnitDefs) do
   -- customParam dependencies removed
   --   if UnitDefs[ud].customParams.draw_shadow == 'yes' then 
         table.insert(ShadowList,ud,1)
     --end
   end

	list = glCreateList(function()
    glBeginEnd(GLQUAD_STRIP,function() 
      --point1
      glTexCoord(0,0)
      glVertex(-4,0,-4)
      --point2                        
      glTexCoord(0,1)                     
      glVertex(4*sunscale,0,-4)               
      --point3
      glTexCoord(1,0)
      glVertex(-4,0,4)
      --point4
      glTexCoord(1,1)
      glVertex(4*sunscale,0,4)
    end)
   end)
end   
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------