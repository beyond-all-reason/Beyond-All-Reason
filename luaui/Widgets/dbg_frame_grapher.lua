-- reading on VAO vs VBO: http://webcache.googleusercontent.com/search?q=cache:-6vWVN6Rur8J:wiki.lwjgl.org/wiki/The_Quad_with_DrawArrays.html+&cd=4&hl=en&ct=clnk&gl=hu&client=firefox-b-d
-- reading on LuaVAO: https://github.com/beyond-all-reason/spring/blob/BAR/rts/Lua/LuaVAOImpl.cpp
-- reading on LuaVBO: https://github.com/beyond-all-reason/spring/blob/BAR/rts/Lua/LuaVBOImpl.cpp
-- Quick video on what VAO/VBO are: https://www.youtube.com/watch?v=WMiggUPst-Q



local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Frame Grapher",
		desc = "Draw frame time graph in bottom right, bar height is time elapsed between frames, blue bars are estimated sim frames, purple bars are CTO errors, and bars are shaded black if their CTO error differs from ideal",
		author = "Beherith",
		date = "2021.mar.29",
		license = "GNU GPL, v2 or later",
		layer = -200001,
    
		enabled = false,
	}
end


-- Localized functions for performance
local mathAbs = math.abs
local mathMin = math.min

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spEcho = Spring.Echo

---------------------------Speedups-----------------------------
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
---------------------------Internal vars---------------------------
local timerstart = nil
----------------------------GL4 vars----------------------------

local rectShader = nil

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local pushElementInstance = InstanceVBOTable.pushElementInstance
local drawInstanceVBO     = InstanceVBOTable.drawInstanceVBO

local maxframes = 2500

local rectInstanceTable = nil
local rectInstancePtr = 0

local vsSrc = [[
#version 420

layout (location = 0) in vec4 coords; // a set of coords coming from vertex buffer
layout (location = 1) in vec4 time_duration_wasgf; // a 'time' for the frame, in milliseconds, and a duration also in ms, w = frametimeoffset

uniform vec4 shaderparams; // .y contains the current actual time

//__ENGINEUNIFORMBUFFERDEFS__

out DataVS {
  vec4 v_time_duration_wasgf;
};

void main() {
	// current time will be equal to full right, e.g an x coord of 1

  float rect_width_pixels  = time_duration_wasgf.y / viewGeometry.x - 1 / viewGeometry.x;
  float rect_height_pixels = 8 * time_duration_wasgf.y / viewGeometry.y;
  float rect_bottom_right  = 1.0 -  (shaderparams.x * 1.0 - time_duration_wasgf.x  ) / viewGeometry.x;

  if (time_duration_wasgf.z > 0.5) {
	//rect_width_pixels = rect_width_pixels + 1 / viewGeometry.x;
	//rect_height_pixels = rect_height_pixels + 60 / viewGeometry.y;
  }


  gl_Position = vec4(
    rect_bottom_right - coords.x*rect_width_pixels,
    -1.0 + coords.y * (rect_height_pixels ) ,
    0.5 + 0.1*time_duration_wasgf.z + time_duration_wasgf.w * 0.1,
    1.0
  );

  if (rect_bottom_right < 0 ) gl_Position.xy = vec2(-1.0);
  if (time_duration_wasgf.y > 200.0 ) gl_Position.xy = vec2(-1.0);

  //gl_Position = vec4(coords.x , coords.y, 0.5, 1.0); // easy debugging

  v_time_duration_wasgf = time_duration_wasgf ;
}
]]

local fsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__

uniform vec4 shaderparams;

in DataVS {
  vec4 v_time_duration_wasgf;
};

out vec4 fragColor;

void main() {
  float green = clamp(v_time_duration_wasgf.y/16.6, 0.5, 1.0);
  float red = clamp((v_time_duration_wasgf.y-16.6)/16.6, 0.0, 1.0);
  if (v_time_duration_wasgf.y > 16.6) green = clamp(1.0-(v_time_duration_wasgf.y-16.6)/16.6, 0.0, 1.0);
	fragColor = vec4(red,green,0,0.75 );
  fragColor.a = 1.0;
  if (v_time_duration_wasgf.z > 0.5 ) fragColor = vec4(0.0, 0.0, 1.0, 1.0);
  if (v_time_duration_wasgf.w > 2.0 ) fragColor = vec4(1.0, 0.0, 1.0, 1.1);
  else fragColor.rgb = mix(fragColor.rgb, vec3(0.0), v_time_duration_wasgf.w);
  
  if (abs(v_time_duration_wasgf.z - 1.0) < 0.01){ // SIM
    fragColor = vec4(1.0, 0.0, 0.0, 1.0);
  }
  else if (abs(v_time_duration_wasgf.z - 2.0) < 0.01){ // update
    fragColor = vec4(1.0, 1.0, 0.0, 1.0);
  }  
  else if (abs(v_time_duration_wasgf.z - 3.0) < 0.01){ // draw
    fragColor = vec4(0.0, 1.0, 0.0, 1.0);
  }
  else if (abs(v_time_duration_wasgf.z - 4.0) < 0.01){ // swap
    fragColor = vec4(0.0, 0.0, 1.0, 1.0);
  }
  else{
    fragColor = vec4(1.0, 0.0, 1.0, 1.0);
  }
}
]]
--------------------------------------------------------------------------------


function widget:Initialize()
  local rectvbo, numVertices = InstanceVBOTable.makeRectVBO(0,0,1,1,0,0,1,1)
  rectInstanceTable = InstanceVBOTable.makeInstanceVBOTable( {{id = 1,  name = "instances",size = 4}}, maxframes+100, "framegraphervbotable")
  rectInstanceTable.VAO = InstanceVBOTable.makeVAOandAttach(rectvbo,rectInstanceTable.instanceVBO)
  rectInstanceTable.numVertices = numVertices

  local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
  rectShader = LuaShader({
      vertex = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs) ,
      fragment = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
      uniformInt = {}, --  usually textures go here
      uniformFloat = {  shaderparams = {alpha, 0.5, 0.5, 0.5},} -- other uniform params
      })

  local shaderCompiled = rectShader:Initialize()
  if not shaderCompiled then
   spEcho("Failed to compile shaders for: frame grapher v2")
   widgetHandler:RemoveWidget(self)
  end
  timerstart = Spring.GetTimerMicros()
  timerold = Spring.GetTimerMicros()
end

function widget:Shutdown()
	if rectShader then rectShader:Finalize() end
end

local wasgameframe = 0
local prevframems = 0
local gameFrameHappened = false
local drawspergameframe = 0


local eventBuffer = {} 
-- This is a table of events that get pushed on every :DrawScreen 
-- Even types are : "sim","update", "draw", "swap", params are start, duration, type

local lastCallin = 'DrawGenesis'
local lastTime = Spring.GetTimerMicros()

local frametypeidx = {
  sim = 1, -- 
  update = 2, -- 
  draw = 3, -- 
  swap = 4, -- 
  error = 5, -- error
}

local nowToPrevToFrameType = {
  GameFramePost = {
    GameFramePost = "error",
    GameFrame = "sim",
    DrawGenesis = "error",
    DrawScreenPost = "error",
    Update = "error",
  },
  GameFrame = {
    GameFramePost = "none",
    GameFrame = "error",
    DrawGenesis = "error",
    DrawScreenPost = "swap",
    Update = "error",
  },
  DrawGenesis = {
    GameFramePost = "error",
    GameFrame = "error",
    DrawGenesis = "error",
    DrawScreenPost = "error",
    Update = "update",
  },
  DrawScreenPost = {
    GameFramePost = "error",
    GameFrame = "error",
    DrawGenesis = "draw",
    DrawScreenPost = "error",
    Update = "error",
  },
  Update = {
    GameFramePost = "none",
    GameFrame = "error",
    DrawGenesis = "error",
    DrawScreenPost = "swap",
    Update = "error",
  },

}
local function nowEvent(e)
    local frameType = nowToPrevToFrameType[e][lastCallin]
      local nowTime = Spring.GetTimerMicros()
    if frameType ~= "error" then
      local lastframetime = spDiffTimers(nowTime, timerstart, nil, true) * 1000 -- in MILLISECONDS
      local lastframeduration = spDiffTimers(nowTime, lastTime, nil, true) * 1000 -- in MILLISECONDS

      eventBuffer[#eventBuffer+1] = {frameType, lastframetime, lastframeduration}
      --spEcho("Event", frameType, "from", e,  "duration", lastframeduration, "ms")
    end
    lastTime = nowTime
    lastCallin = e
end


function widget:GameFramePost() 
  nowEvent("GameFramePost")
  --spEcho("GameFramePost", spGetGameFrame())
end

function widget:GameFrame(n)
  nowEvent("GameFrame")
  wasgameframe =  wasgameframe + 1
  gameFrameHappened = true
  if drawspergameframe ~= 2 then
	--spEcho(drawspergameframe, "draws instead of 2", n)
  end
  drawspergameframe = 0
end

function widget:DrawGenesis()
  nowEvent("DrawGenesis")
end

function widget:DrawScreenPost()
  nowEvent("DrawScreenPost")
end

function widget:Update() 
  nowEvent("Update")
end

function widget:DrawScreen()
--[[
  drawspergameframe = drawspergameframe + 1
	local drawpersimframe = math.floor(Spring.GetFPS()/30.0 +0.5 )

	local timernew = spGetTimer()
	local lastframeduration = spDiffTimers(timernew, timerold)*1000 -- in MILLISECONDS
	timerold = timernew
  local lastframetime = spDiffTimers(timernew, timerstart) * 1000 -- in MILLISECONDS
  local fto = Spring.GetFrameTimeOffset()

  local CTOError = 0

  if drawpersimframe == 2 then
	CTOError = 4 * mathMin(mathAbs(fto-0.5), mathAbs(fto))
  elseif drawpersimframe ==3 then
	CTOError = 6 * mathMin(mathMin(mathAbs(fto-0.33), mathAbs(fto -0.66)), mathAbs(fto))
  elseif drawpersimframe ==4 then
	CTOError = 8 * mathMin(mathMin(mathAbs(fto-0.25), mathAbs(fto -0.5)), mathMin(mathAbs(fto), mathAbs(fto-0.75)))
  end
  --spEcho(spGetGameFrame(), fto, CTOError)

  rectInstancePtr = rectInstancePtr+1
  if rectInstancePtr >= maxframes then rectInstancePtr = 0 end
  pushElementInstance(rectInstanceTable, {lastframetime, lastframeduration, 0, CTOError}, rectInstancePtr, true)
  if wasgameframe>0 then

    rectInstancePtr = rectInstancePtr+1
    if rectInstancePtr >= maxframes then rectInstancePtr = 0 end
    pushElementInstance(rectInstanceTable, {lastframetime, lastframeduration-prevframems, 1, CTOError}, rectInstancePtr, true)
  end

  if fto > 0.99 then

    rectInstancePtr = rectInstancePtr+1
    if rectInstancePtr >= maxframes then rectInstancePtr = 0 end
    pushElementInstance(rectInstanceTable, {lastframetime, lastframeduration, 1, 3}, rectInstancePtr, true)
  end

]]--#region

  for i = 1, #eventBuffer do
    local event = eventBuffer[i]
    local frametype = event[1]
    local lastframetime = event[2]
    local lastframeduration = event[3] 

    rectInstancePtr = rectInstancePtr+1
    if rectInstancePtr >= maxframes then rectInstancePtr = 0 end
    local frameColor = frametypeidx[frametype]
    --spEcho("Event", frametype, "frameColor", frameColor, lastframeduration, "ms", lastframetime)
    pushElementInstance(rectInstanceTable, {lastframetime, lastframeduration, frameColor, 0 }, rectInstancePtr, true)
  end
  eventBuffer = {} -- clear the event buffer

  rectShader:Activate()
   -- We should be setting individual uniforms AFTER activate
  local shadertime = spDiffTimers(Spring.GetTimerMicros(), timerstart, nil, true) * 1000 -- in MILLISECONDS
  rectShader:SetUniform("shaderparams", shadertime,0,0,0)
  drawInstanceVBO(rectInstanceTable)
  rectShader:Deactivate()
  wasgameframe = 0
  prevframems = lastframeduration
  gameFrameHappened = false
end
