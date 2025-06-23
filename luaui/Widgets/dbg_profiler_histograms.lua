-- reading on VAO vs VBO: http://webcache.googleusercontent.com/search?q=cache:-6vWVN6Rur8J:wiki.lwjgl.org/wiki/The_Quad_with_DrawArrays.html+&cd=4&hl=en&ct=clnk&gl=hu&client=firefox-b-d
-- reading on LuaVAO: https://github.com/beyond-all-reason/spring/blob/BAR/rts/Lua/LuaVAOImpl.cpp
-- reading on LuaVBO: https://github.com/beyond-all-reason/spring/blob/BAR/rts/Lua/LuaVBOImpl.cpp
-- Quick video on what VAO/VBO are: https://www.youtube.com/watch?v=WMiggUPst-Q

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Profiler Histograms",
		desc = "Try to profile stuff, use /histogram Sim::Script",
		author = "Beherith",
		date = "2021.mar.29",
		license = "GNU GPL, v2 or later",
		layer = -100000,
		enabled = false,
	}
end

---------------------------Speedups-----------------------------
local spGetProfilerTimeRecord = Spring.GetProfilerTimeRecord
---------------------------Internal vars---------------------------
local timerstart = nil

local vsx, vsy = Spring.GetViewGeometry()
----------------------------GL4 vars----------------------------

local boundingbox = {vsx/4, vsy/4, 3*vsx/4, 3*vsy/4}

local histShader = nil

local LuaShader = gl.LuaShader

local vsSrc = [[
#version 420

layout (location = 0) in vec2 coords; // a set of coords coming from vertex buffer


uniform vec4 shaderparams; // .y contains the current actual time

//__ENGINEUNIFORMBUFFERDEFS__

uniform vec4 boundingbox; //left, bottom, right, top
uniform vec4 color = vec4(1.0);

out DataVS {
	vec4 v_time_duration_wasgf;
};

void main() {
	// current time will be equal to full right, e.g an x coord of 1
	uint index = uint(coords.x);
	vec2 screenpos = vec2(
		coords.x * (boundingbox.z-boundingbox.x) + boundingbox.x,
		coords.y * (boundingbox.w-boundingbox.y) + boundingbox.y
	);
	screenpos = screenpos / vec2(viewGeometry.x, viewGeometry.y);
	screenpos -= 0.5;
	gl_Position = vec4(screenpos.x , screenpos.y, 0.5, 1.0); // easy debugging
	v_time_duration_wasgf = vec4(0.0);
}
]]

local fsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__

uniform vec4 color = vec4(1.0);

in DataVS {
	vec4 v_time_duration_wasgf;
};

out vec4 fragColor;

void main() {
	fragColor = color;
}
]]


------------------------ HISTOGRAM STUFF -------------------------------
local profilerecords = {}

local bincount = 128
local binrez = 0.05 -- half MS resolutions
local histograms = {} -- key name, value histogram object
local actives = {Sim = true}
--actives['Draw'] = true
actives['Update'] = true
actives['Sim::Script'] = true


local function createhistogram(name)
	local newhist = {
		last = 0,
		name = name,
		binrez = binrez,
		bincount = bincount,
		maxcount = 1,
		data = {},
		numsamples = 0,
		numzeros = 0,
		numtoobig = 0,
		mean = 0,
		linewidth = 2,
		color = {math.random(),math.random(),math.random(),1},
	}
	for i=1,bincount do 
		newhist.data[i] = 0
	end
	
	local histVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	local VBOData = {}

	for i = 1, bincount  do 
		VBOData[#VBOData+1] = i/bincount-- X
		VBOData[#VBOData+1] = i/bincount-- Y
	end	
	
	histVBO:Define(
		bincount, 
		{{id = 0, name = "coords", size = 2}}
	)
	histVBO:Upload(VBOData)
	histVAO = gl.GetVAO()
	histVAO:AttachVertexBuffer(histVBO)
	
	newhist.VBO = histVBO
	newhist.VAO = histVAO
	newhist.VBOData = VBOData
	return newhist
end

local function updatehist(h,newvalue, counter)
	local total, current = spGetProfilerTimeRecord(h.name, false)
	if not current then return end
	counter = current
	if counter then 
		if counter < h.last then 
			newvalue = counter
		else
			newvalue = counter - h.last
		end
		h.last = counter
	else
		h.last = newvalue
	end
	
	if newvalue < h.binrez then 
		h.numzeros = h.numzeros + 1
		return 0,0,0 
	end 
	
	
	local binid = math.floor(math.min((newvalue/h.binrez), h.bincount -1)) + 1
	if binid == h.bincount then 
		h.numtoobig = h.numtoobig + 1 
	end
	
	local oldratio = h.mean * h.numsamples
	h.numsamples = h.numsamples + 1
	h.mean = (oldratio + newvalue) / h.numsamples
	
	local newcount = h.data[binid] + 1
	if newcount > h.maxcount then 
		h.maxcount = newcount
	end
	h.data[binid] = newcount
	return newvalue, newcount, binid
end

local function updateVBO(h)
	if h == nil then return end
	local vboData = h.VBOData
	for i, count  in ipairs(h.data) do 
		vboData[2*i - 1] =     i / bincount
		vboData[2*i    ] = count / h.maxcount
	end
	h.VBO:Upload(vboData)
end

------------------- WIDGET STUFF --------------------------------------

function widget:Initialize()
	lineVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)

	local VBOData = {}

	for i = 1, bincount  do 
		VBOData[#VBOData+1] = i-- X
		VBOData[#VBOData+1] = i-- Y
	end	

	lineVBO:Define(
		bincount, 
		{{id = 0, name = "coords", size = 2}}
	)
	lineVBO:Upload(VBOData)
	--if true then return nil end 
	lineVAO = gl.GetVAO()
	lineVAO:AttachVertexBuffer(lineVBO)
	
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	histShader = LuaShader({
		vertex = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs) ,
		fragment = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
		uniformInt = {}, --	usually textures go here
		uniformFloat = {	
			boundingbox = {0, 0, vsx, vsy},
			color = {1, 1, 1, 1},
			
			} -- left, bottom,right,top
		})

	local shaderCompiled = histShader:Initialize()
	if not shaderCompiled then
	 Spring.Echo("Failed to compile shaders for: frame grapher v2")
	 widgetHandler:RemoveWidget(self)
	end
	timerstart = Spring.GetTimer()
	timerold = Spring.GetTimer()
	
	for k,v in pairs(Spring.GetProfilerRecordNames()) do 
		--Spring.Echo(k,v)
		profilerecords[k] = v
		histograms[v] = createhistogram(v)
	end
end

local function PrintRecord(name)
	local total, current, maxdt, time, peak = Spring.GetProfilerTimeRecord(name,false)
	-- where total is in milliseconds
	-- current gets reset ever 33 frames, and is a running tally
	-- maxdt is the peak value
	-- time is lag?
	-- peak is unknown?
	
	-- so last frame dt === 
	
	local gf = Spring.GetGameFrame()
	Spring.Echo(gf, 'P:', name, total, current, maxdt, time, peak)
end

local function GetRecordCurrent(name)
	local total, current = Spring.GetProfilerTimeRecord(name,false)
	return current
end

function widget:Shutdown()
	if histShader then histShader:Finalize() end
	for name,hist in pairs(histograms) do 
		if hist.VBO then hist.VBO:Delete() end
		if hist.VAO then hist.VAO:Delete() end
	end
end

function widget:GameFrame(n)
	for name, hist in pairs(actives) do
		if histograms[name] then 
			updatehist(histograms[name])
		end
	end
end

function widget:DrawScreen()

	histShader:Activate()
	histShader:SetUniform("boundingbox", boundingbox[1],boundingbox[2],boundingbox[3],boundingbox[4])
	for name, _ in pairs(actives) do 
		local hist = histograms[name]
		if hist then 
			if Spring.GetGameFrame()%30 == 0 then
				updateVBO(hist)
			end
			gl.LineWidth(hist.linewidth)
			histShader:SetUniform("color", hist.color[1], hist.color[2], hist.color[3], hist.color[4])
			hist.VAO:DrawArrays(GL.LINE_STRIP)
		end
	end
	histShader:Deactivate()
end

function widget:DbgTimingInfo(eventname, starttime, endtime)
	--Spring.Echo("DbgTimingInfo",eventname, starttime, endtime)
end

function widget:TextCommand(command)
	if string.find(command, "histogram", nil, true) then
		local name = string.sub(command, string.len("histogram") +2)
		if histograms[name] then 
			if actives[name] then 
				Spring.Echo("Disabling histogram for",name)
				actives[name] = nil 
			else
				Spring.Echo("Enabling histogram for",name)
				actives[name] = true 		
			end
		else
			Spring.Echo("Unknown histogram name:",name)
		end
	end
end

-------------------- AVAILABLE SUBSYSTEMS ----------------------
--[[

 1, AI
 2, AI::{id=1 team=0 name=NullAI version=0.1}
 3, CFeatureDrawer::Draw
 4, CFeatureDrawer::DrawAlphaPass
 5, CFeatureDrawer::DrawOpaquePass
 6, CFeatureDrawer::DrawShadowPass
 7, CFeatureDrawerBase::Update
 8, CUnitDrawer::Draw
 9, CUnitDrawer::DrawAlphaPass
 10, CUnitDrawer::DrawOpaquePass
 11, CUnitDrawer::DrawShadowPass
 12, CUnitDrawerBase::Update
 13, Draw
 14, Draw::DrawGenesis
 15, Draw::Screen
 16, Draw::Screen::DrawScreen
 17, Draw::Screen::InputReceivers
 18, Draw::World
 19, Draw::World::CreateShadows
 20, Draw::World::Decals
 21, Draw::World::DrawWorld
 22, Draw::World::Foliage
 23, Draw::World::Models::Alpha
 24, Draw::World::Models::Opaque
 25, Draw::World::Projectiles
 26, Draw::World::Terrain
 27, Draw::World::Terrain::ROAM::Draw
 28, Draw::World::Terrain::ROAM::Update
 29, Draw::World::UpdateReflTex
 30, Draw::World::UpdateShadingTex
 31, Draw::World::Water
 32, Lua::Callins::Synced
 33, Lua::Callins::Unsynced
 34, Lua::CollectGarbage::Synced
 35, Lua::CollectGarbage::Unsynced
 36, Lua::CopyData
 37, MatrixUploader::Update
 38, Misc::InputHandler::PushEvents
 39, Misc::Profiler::AddTime
 40, Misc::SwapBuffers
 41, ModelsUniformsUploader::Update
 42, Sim
 43, Sim::BasicMapDamage
 44, Sim::Features
 45, Sim::GameFrame
 46, Sim::Los
 47, Sim::Path
 48, Sim::Projectiles
 49, Sim::Projectiles::Collisions
 50, Sim::Projectiles::Update
 51, Sim::Script
 52, Sim::SmoothHeightMesh::UpdateSmoothMesh
 53, Sim::Unit::MoveType
 54, Sim::Unit::MoveType::1::UpdatePreCollisionsMT
 55, Sim::Unit::MoveType::2::UpdatePreCollisionsST
 56, Sim::Unit::MoveType::3::CollisionDetectionMT
 57, Sim::Unit::MoveType::5::UpdateST
 58, Sim::Unit::RequestPath
 59, Sim::Unit::SlowUpdate
 60, Sim::Unit::Update
 61, Sim::Unit::Weapon
 62, ThreadPool::AddTask
 63, ThreadPool::RunTask
 64, ThreadPool::WaitFor
 65, Update
 66, Update::EventHandler
 67, Update::ReadMap::UHM
 68, Update::WorldDrawer
 69, Update::WorldDrawer::{Sky,Water}
 
 ]]--
