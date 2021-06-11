-- reading on VAO vs VBO: http://webcache.googleusercontent.com/search?q=cache:-6vWVN6Rur8J:wiki.lwjgl.org/wiki/The_Quad_with_DrawArrays.html+&cd=4&hl=en&ct=clnk&gl=hu&client=firefox-b-d
-- reading on LuaVAO: https://github.com/beyond-all-reason/spring/blob/BAR/rts/Lua/LuaVAOImpl.cpp
-- reading on LuaVBO: https://github.com/beyond-all-reason/spring/blob/BAR/rts/Lua/LuaVBOImpl.cpp
-- Quick video on what VAO/VBO are: https://www.youtube.com/watch?v=WMiggUPst-Q

local function D(a) -- nasty-ass debug function to wrap anything into
  local called_from = "Called from: " .. tostring(debug.getinfo(2).name) .. " args:"
  Spring.Echo(called_from)
  --for i,v in ipairs(arg) do
  if type(a) == "table" then
    Spring.Echo( Spring.Utilities.TableToString(a))
  else
    Spring.Echo(tostring(a))
  end
  return a
end

function widget:GetInfo()
	return {
		name = "Frame Grapher V2",
		desc = "Draw frame time graph in bottom right",
		author = "Beherith",
		date = "2021.mar.29",
		layer = -10000000000000000000,
		enabled = false, --  loaded by default
	}
end

---------------------------Speedups-----------------------------
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers 
---------------------------Config vars--------------------------
local yPixelPerMS = 4
local graphDurationMS = 2000
local viewSizeX, viewSizeY = 0, 0
---------------------------Internal vars---------------------------
local deltats = nil
local deltatsGf = nil
local numdeltats = 0
local timerold = nil
local startframe, oldframe
local xPixelPerMS = nil
----------------------------OpenGL vars----------------------------
local rectVAO = nil
local rectVertexVBO = nil
local rectVertexVBOSize = 4000
local rectVertexVBOTable = {} -- this will mirror our shit, and hopefully work well. 
local rectVertexVBOPTR = 0 -- 0 based cause im scum
local rectInstanceVBO = nil
local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
local rectShader = nil

local vsSrc = [[
#version 330

in vec2 coords;
//layout (location = 0) in vec2 aPos;
//layout (location = 1) in vec4 aMirrorParams;

out DataVS {
	vec4 rectColor;
  vec2 rectPos;
};

void main() {
	gl_Position = vec4(coords.xy, 0.0, 1.0);
	rectColor = vec4(1.0,0.0,1.0,0.0);
  rectPos = vec2(coords.xy);
}
]]

local fsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

layout(std140, binding = 1) uniform UniformParamsBuffer {
	vec3 rndVec3; //new every draw frame.
	uint renderCaps; //various render booleans

	vec4 timeInfo; //gameFrame, gameSeconds, drawFrame, frameTimeOffset
	vec4 viewGeometry; //vsx, vsy, vpx, vpy
	vec4 mapSize; //xz, xzPO2

	vec4 fogColor; //fog color
	vec4 fogParams; //fog {start, end, 0.0, scale}
};

uniform vec4 shaderParams;

in DataVS {
	vec4 rectColor;
  vec2 rectPos;
};

out vec4 fragColor;

void main() {
	fragColor = vec4(1.0,1.0,1.0,0.5);// vec4(rectColor.r, fract(rectPos.x*10000),0.0,1.0);
}
]]
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
  deltats = {}
  deltatsGf = {}
  
	startframe = Spring.GetGameFrame()
	oldframe = startframe
	viewSizeX, viewSizeY = gl.GetViewSizes()
  
  rectVAO = gl.GetVAO()
  rectVertexVBO = gl.GetVBO()
  rectInstanceVBO = gl.GetVBO()
  
  if rectVAO == nil  or rectVertexVBO == nil or rectInstanceVBO == nil then 
      Spring.Echo("LuaVAO not supported, disabling frame grapher v2")
      widgetHandler:RemoveWidget(self)
  end
  
  rectVertexVBO:Define(
    rectVertexVBOSize, -- this is the MAX number of vertices we are pushing
    { --second param is an an array of tables, one for each attribute? Or does the ID here refer to the VAO attribute index?
      {id = 0, -- which attribute we should be attaching to, number consecutively from 0, max 15
      name = "pos", -- im hoping this is just a helper name
      size = 2, -- the number of floats in this array that constitute 1 element. So for an xyz pos, its 3 floats
      },
    }
  )
  
  for i = 1, rectVertexVBOSize do
    rectVertexVBOTable [i] = 0.0
  end
  
  rectInstanceVBO:Define( -- we are only going to define 1 for now, this should be done in init if static
    -- Instances: use 0 (or nothing) it forces non instanced
     1, -- number of instances
     {
       {id = 1,
         name = "instances",
         size = 1, -- number of elements per instance
         }
       }
     )
  rectInstanceVBO:Upload({1},0) -- First param is our data, second is the index
  
  rectVAO:AttachVertexBuffer(rectVertexVBO) -- Attach the vertex data to the VAO, only attach once!
  rectVAO:AttachInstanceBuffer(rectInstanceVBO) -- Attach the instance data to the VAO
  
  rectShader = LuaShader({
      vertex = vsSrc,
      fragment = fsSrc,
      uniformInt = {}, --  usually textures go here
      uniformFloat = { -- other static params
        alpha = 1, 
        }
      })
  local shaderCompiled = rectShader:Initialize()
  if not shaderCompiled then
   Spring.Echo("Failed to compile shaders for: frame grapher v2")
   widgetHandler:RemoveWidget(self)
  end

  xPixelPerMS = (viewSizeX / 2.0) / 2000.0
  timerold = Spring.GetTimer()
end 

function widget:Shutdown()
	if rectShader then rectShader:Finalize() end
  if rectVAO then
    rectVAO:Delete()
    rectVAO = nil
  end
  if rectVertexVBO then 
    rectVertexVBO:Delete()
    rectVertexVBO = nil
  end
end

function widget:ViewResize(vsx, vsy)
	widget:Shutdown()
	widget:Initialize()
end

local function AddVertexToArray( x,y,z)
  rectVertexVBOPTR = rectVertexVBOPTR + 1
  rectVertexVBOTable[rectVertexVBOPTR] = x / viewSizeX
  
  rectVertexVBOPTR = rectVertexVBOPTR + 1
  rectVertexVBOTable[rectVertexVBOPTR] = y / viewSizeY
  
  
  
  --[[verts[#verts+1] = x / viewSizeX
  verts[#verts+1] = 
  verts[#verts+1] = z]]--
end

local function AddRectXYtoArray(left, bottom, right, top)
  -- Top left triangle
  AddVertexToArray( left  ,bottom)
  AddVertexToArray( left  ,top   )
  AddVertexToArray( right ,top   )
  -- bottom right triangle
  AddVertexToArray( left   ,bottom)
  AddVertexToArray( right  ,top   )
  AddVertexToArray( right  ,bottom )
end

function widget:DrawScreen()
	local timernew = Spring.GetTimer()
  numdeltats = numdeltats+1
	deltats[numdeltats] = Spring.DiffTimers(timernew, timerold)*1000
	timerold = timernew
  
  -- do the vao magic:
  --rectVAO:AttachVertexBuffer(rectVertexVBO) -- attach it to first attribute of VAO
  local tricoords = {} -- we will store triangle coords here
  
  local rectangles = {} -- for now we will do this the slow way, storing an array of rectangle {left, bototm, right, top}
  
  local leftpos = viewSizeX
  local timeindex = numdeltats
  
  rectVertexVBOPTR = 0
  
  while leftpos > (viewSizeX/2) and timeindex > 1 do
      local deltat_ms = deltats[timeindex]
      
      --[[rectangles[#rectangles+1] = {
        leftpos - 1, 
        0,
        leftpos - deltat_ms * xPixelPerMS, 
        deltat_ms * yPixelPerMS
      }]]--
      
      AddRectXYtoArray( leftpos - 1, 
        0,
        leftpos - deltat_ms * xPixelPerMS, 
        deltat_ms * yPixelPerMS )
      leftpos = leftpos - deltat_ms * xPixelPerMS
      timeindex = timeindex - 1
  end
  
  
  while deltats[timeindex] do -- keep our table neat
    deltats[timeindex] = nil
    timeindex = timeindex - 1
  end
  
  for i, rect in ipairs(rectangles) do
    AddRectXYtoArray(rect[1],rect[2],rect[3],rect[4])
  end
  
  --Upload vertices to VBO:
  --Spring.Echo("We have N rectangles:",#rectangles, " tricoords:",#tricoords,leftpos,timeindex)
  if rectVertexVBOPTR <1 then return end -- bail out, empty VBOS do not like being defined or uploaded or drawn!
  
 
   if numdeltats % 600 ==0 then
    rectVertexVBO:Upload(rectVertexVBOTable,0) -- The second param is probably an offset into the VBO
  end
   
   -- We should be setting uniforms before activate, but I think I have none yet
   rectShader:Activate()
   
   rectVAO:DrawArrays(
     GL.TRIANGLES,  -- primitive type, GL.TRIANGLES for vertex shaders, GL.POINTS for geometry shaders
     rectVertexVBOPTR, -- the number of elements for one array
     0, -- probably an offset into the array
     1 -- instance count, if you have instances, you also need an instance VBO attached to VAO
    ) 
  
   rectShader:Deactivate()

end
