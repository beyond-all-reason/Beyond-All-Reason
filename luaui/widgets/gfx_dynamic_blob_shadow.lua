--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Dynamic Blob Shadows",
    desc      = "Creates shadow projections from the sun position that wrap around the unit size",
    author    = "user, revised by Argh",
    date      = "March 3, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = -1,
    enabled   = true  
  }
end

--1.2
--now working in LOS view without deactivating shadows (vbs)
 
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
----------CONTACT USER BEFORE EDITING, PLEASE.----------------------------------
----------CONTACT USER BEFORE EDITING, PLEASE.----------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local side                 = 0
local xmul                 = 0
local zmul                 = 0
local unitList             = {} 
local featureList          = {}  
local sunx,suny,sunz       = gl.GetSun()
local shadowdens           = gl.GetSun("shadowdensity")
local noshadow             = 0 
local shadowsareon         = 0 
local sundist              = 0
local realdist             = 0
local sunheight            = 0
local greater              = 0
local sunscale             = 0   
local sunangle             = 0  
local cangle               = 0                                      
local ShadowsOn            = Spring.HaveShadows
local GetMapDrawMode       = Spring.GetMapDrawMode
local list         

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- sun calculations,for projection----------------------------------------------
--------------------------------------------------------------------------------
sunangle = Spring.GetHeadingFromVector(sunx,sunz)/182,0444445 --exact number to convert a short integer to a 0 to 360 number.  
sunangle = sunangle + (360+90)                                --when it is 65536, divide it by 182,0444445 you get 360.  
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

function widget:DrawWorldPreUnit()

   list = gl.CreateList(function() 
     gl.BeginEnd(GL.QUAD_STRIP,function()  
       --point1
       gl.TexCoord(0,0)
       gl.Vertex(-4,0,-4)
       --point2                                 
       gl.TexCoord(0,1)                           
       gl.Vertex(4*sunscale,0,-4)                   
       --point3
       gl.TexCoord(1,0)
       gl.Vertex(-4,0,4)
       --point4
       gl.TexCoord(1,1)
       gl.Vertex(4*sunscale,0,4)
     end)
   end)

unitList = Spring.GetVisibleUnits(-1,3000,false)

local cx,cy,cz = Spring.GetCameraPosition()

  gl.Texture('LuaUI/Images/shadow.tga')
  gl.DepthMask(false)
  gl.DepthTest(false)
  gl.Color(1,1,1,0.4)

  local x,y,z
  local fx,fy 

if unitList[1] == nil then return false else

if (ShadowsOn() and GetMapDrawMode() ~= "los") then
   return false
else

if cy == nil or cy > 4000 then return false else

	for _,unitID in ipairs(unitList) do
		x,y,z = Spring.GetUnitViewPosition(unitID)
		
		if (x) then
		local id = Spring.GetUnitDefID(unitID) 
		fx = UnitDefs[id].xsize
		fy = UnitDefs[id].zsize
		 
		local height = Spring.GetGroundHeight(x,z)
		local diff = height-y+5
		local x2,z2 = Spring.GetVectorFromHeading(sunangle)  
		
		gl.PushMatrix()
		gl.Translate(0,diff,0)  
		gl.Translate(sunx*diff,0,sunz*diff)
		gl.DrawListAtUnit(unitID,list,false,fx,1.0,fy,sunangle,0,1.0,0)
		gl.PopMatrix()
		end
    
	end


   end
   end
   end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------