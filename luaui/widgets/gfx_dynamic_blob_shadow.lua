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

--1.3
--perfomance optimizid (vbs)

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
local spGetUnitViewPosition 	= Spring.GetUnitViewPosition
local spGetUnitDefID			= Spring.GetUnitDefID
local spGetGroundHeight			= Spring.GetGroundHeight
local spGetVectorFromHeading	= Spring.GetVectorFromHeading

local glPushMatrix				= gl.PushMatrix
local glTranslate				= gl.Translate
local glPopMatrix				= gl.PopMatrix
local glDrawListAtUnit			= gl.DrawListAtUnit
local glBeginEnd				= gl.BeginEnd
local glVertex					= gl.Vertex
local glTexCoord				= gl.TexCoord
local glTexture					= gl.Texture
local glColor					= gl.Color
local glDepthMask				= gl.DepthMask
local glDepthTest				= gl.DepthTest

local udefTab					= UnitDefs

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

list = gl.CreateList(function() 
	glBeginEnd(GL.QUAD_STRIP,function()  
    --point1
    glTexCoord(0,0)
    glTexCoord(-4,0,-4)
    --point2                                 
    glTexCoord(0,1)                           
    glTexCoord(4*sunscale,0,-4)                   
    --point3
    glTexCoord(1,0)
    glTexCoord(-4,0,4)
    --point4
    glTexCoord(1,1)
    glTexCoord(4*sunscale,0,4)
    end)
end)

function widget:DrawWorldPreUnit()
	if (ShadowsOn() and GetMapDrawMode() ~= "los") then
	   return false
	end
	
	unitList = Spring.GetVisibleUnits(-1,3000,false)
	if unitList[1] == nil then 
		return false 
	end

	local _,cy,_ = Spring.GetCameraPosition()
	if cy == nil or cy > 4000 then 
		return false
	end
	
	glTexture('LuaUI/Images/shadow.tga')
	glDepthMask(false)
	glDepthTest(false)
	glColor(1,1,1,0.4)

	local x,y,z
	local fx,fy 

	for i=1, #unitList do
		unitID = unitList[i]
		x,y,z = spGetUnitViewPosition(unitID)
		
		if (x) then
			local id = spGetUnitDefID(unitID) 
			fx = udefTab[id].xsize
			fy = udefTab[id].zsize
			 
			local height = spGetGroundHeight(x,z)
			local diff = height-y+5
			local x2,z2 = spGetVectorFromHeading(sunangle)  
			
			glPushMatrix()
			glTranslate(0,diff,0)  
			glTranslate(sunx*diff,0,sunz*diff)
			glDrawListAtUnit(unitID,list,false,fx,1.0,fy,sunangle,0,1.0,0)
			glPopMatrix()
		end
	end

	--gl.Texture(nil)
	--gl.Color(1.0,1.0,1.0,1.0)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------