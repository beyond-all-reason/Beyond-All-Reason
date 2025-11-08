local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Sensor Ranges Jammer",
		desc = "Shows Jammer ranges of all ally units. (GL4)",
		author = "Beherith GL4",
		date = "2021.06.18",
		license = "GPLv2, (c) Beherith (mysterme@gmail.com)",
		layer = 17,
		enabled = true
	}
end


-- Localized functions for performance

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spEcho = Spring.Echo
local spGetViewGeometry = Spring.GetViewGeometry

-------   Configurables: -------------------
local debugmode = false
---
local rangeColor = { 1.0, 0.35, 0.0, 0.35 } -- default range color
local opacity = 0.08
local rangeLineWidth = 4.5 -- (note: will end up larger for larger vertical screen resolution size)
local lineScale = 1 -- this is a multiplier for the line width, to make it look better on high res screens

local circleSegments = 62 -- To ensure its only 2 warps per instance
local rangecorrectionelmos = debugmode and -16 or 16 -- how much smaller they are drawn than truth due to LOS mipping
--------- End configurables ------

local minJammerDistance = 63
local gaiaTeamID = Spring.GetGaiaTeamID()

------- GL4 NOTES -----
-- TODO: 2025.07.02:




local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local popElementInstance  = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

local jammerStencilShader = nil
local jammerCircleShader = nil
local circleInstanceVBO = nil

local jammerStencilTexture 
local resolution = 4
local vsx, vsy  = spGetViewGeometry()

local circleShaderSourceCache = {
	shaderName = 'Jammer Ranges Circles GL4',
	vssrcpath = "LuaUI/Shaders/sensor_ranges_los.vert.glsl",
	fssrcpath = "LuaUI/Shaders/sensor_ranges_los.frag.glsl",
	shaderConfig = {
		VSX = vsx,
		VSY = vsy,
		RESOLUTION = resolution,
		PADDING = 1,
		VISIBILITYCULLING = 1,
		STIPPLE_RATE = 1.0,
	},
	uniformInt = {
		heightmapTex = 0,
		losStencilTexture = 1,
	},
	uniformFloat = {
		teamColorMix = 1.0,
		rangeColor = rangeColor,
	},
	silent = not debugmode, -- do not print shader compile timing
} 
 
local stencilShaderSourceCache = table.copy(circleShaderSourceCache) -- copy the circle shader source cache, and modify it for stencil pass
stencilShaderSourceCache.shaderConfig.STENCILPASS = 1 -- this is a stencil pass
stencilShaderSourceCache.shaderName = 'Jammer Ranges Stencil GL4'

local function goodbye(reason)
	spEcho("Sensor Ranges LOS widget exiting with reason: " .. reason)
	widgetHandler:RemoveWidget()
	return false
end
 
local function CreateStencilShaderAndTexture()
	vsx, vsy = spGetViewGeometry()
	circleShaderSourceCache.shaderConfig.VSX = vsx
	circleShaderSourceCache.shaderConfig.VSY = vsy
	circleShaderSourceCache.forceupdate = true
	stencilShaderSourceCache.shaderConfig.VSX = vsx
	stencilShaderSourceCache.shaderConfig.VSY = vsy
	stencilShaderSourceCache.forceupdate = true

	jammerStencilShader = LuaShader.CheckShaderUpdates(stencilShaderSourceCache,0)	

	if not jammerStencilShader then
  		return goodbye("Failed to compile jammerrange stencil shader GL4 ")
 	end
	jammerCircleShader = LuaShader.CheckShaderUpdates(circleShaderSourceCache,0)
	if not jammerCircleShader then
		return goodbye("Failed to compile jammerrange shader GL4 ")
	end

	local GL_R8 = 0x8229
    vsx, vsy = spGetViewGeometry()
	lineScale = (vsy + 500)/ 1300
    if jammerStencilTexture then gl.DeleteTexture(jammerStencilTexture) end
    jammerStencilTexture = gl.CreateTexture(vsx/resolution, vsy/resolution, {
		--format = GL.RGBA8,
        format = GL_R8,
		fbo = true,
		min_filter = GL.NEAREST,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})
end
local function initgl4()
	-- Due to the view size being part of the shader config, we need to initialize the shaders after the view size is known.

	-- Note that we are createing a special Circle VBO, that starts at the center vertex! This is needed for triangle fans
	local circleVBO, numVertices = InstanceVBOTable.makeCircleVBO(circleSegments, nil, true, "jammerrangeCircles")
	local circleInstanceVBOLayout = {
		{ id = 1, name = 'radius_params', size = 4 }, -- radius, gameframe, 2 unused floats
		{ id = 2, name = 'instData', size = 4, type = GL.UNSIGNED_INT}, -- instData
	}

	circleInstanceVBO = InstanceVBOTable.makeInstanceVBOTable(circleInstanceVBOLayout, 128, "jammerrangeVBO", 2)
	circleInstanceVBO.numVertices = numVertices
	circleInstanceVBO.vertexVBO = circleVBO
	circleInstanceVBO.VAO = InstanceVBOTable.makeVAOandAttach(circleInstanceVBO.vertexVBO, circleInstanceVBO.instanceVBO)

	CreateStencilShaderAndTexture()
end
 
 
local function DrawLOSStencil() -- about 0.025 ms
	if circleInstanceVBO.usedElements > 0 then
        gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
		gl.BlendEquation(GL.MAX)
		gl.Blending(GL.ONE, GL.ONE)
        gl.Culling(false)
		
		gl.Texture(0, "$heightmap") -- Bind the heightmap texture
		jammerStencilShader:Activate()
		circleInstanceVBO.VAO:DrawArrays(GL.TRIANGLE_FAN, circleInstanceVBO.numVertices, 0, circleInstanceVBO.usedElements, 0)
		jammerStencilShader:Deactivate()
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		gl.BlendEquation(GL.FUNC_ADD)
	end
end

function widget:DrawGenesis()
    gl.RenderToTexture(jammerStencilTexture, DrawLOSStencil)
end

-- This shows the debug stencil texture in the bottom left corner of the screen
if debugmode then 
	function widget:DrawScreen()	
		jammerCircleShader = LuaShader.CheckShaderUpdates(circleShaderSourceCache,0) or jammerCircleShader
		jammerStencilShader = LuaShader.CheckShaderUpdates(stencilShaderSourceCache,0) or jammerStencilShader
		gl.Color(1,1,1,1)
		gl.Blending(GL.ONE, GL.ZERO)
		gl.Texture(jammerStencilTexture)
		gl.TexRect(0, 0, vsx/resolution, vsy/resolution, 0, 0, 1, 1)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
end  

-- Functions shortcuts
local spGetSpectatingState = Spring.GetSpectatingState
local spIsUnitAllied = Spring.IsUnitAllied
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitIsActive 	= Spring.GetUnitIsActive
local GL_NOTEQUAL = GL.NOTEQUAL
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_KEEP = 0x1E00 --GL.KEEP
local GL_REPLACE = GL.REPLACE

-- Globals
local spec, fullview = spGetSpectatingState()
local allyTeamID = Spring.GetMyAllyTeamID()

-- find all unit types with radar in the game and place ranges into unitRange table
local unitRange = {} -- table of unit types with their radar ranges

local unitList = {} -- all ally units and their coordinates and radar ranges

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.radarDistanceJam and unitDef.radarDistanceJam > minJammerDistance then	-- save perf by excluding low radar range units
		unitRange[unitDefID] = unitDef.radarDistanceJam
	end
end

function widget:ViewResize(newX, newY)
	CreateStencilShaderAndTexture()
end 

-- a reusable table, since we will literally only modify its first element.
local instanceCache = {0,0,0,0,0,0,0,0}

local function InitializeUnits()
	--spEcho("Sensor Ranges LOS InitializeUnits")
	InstanceVBOTable.clearInstanceTable(circleInstanceVBO)
	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		local visibleUnits =  WG['unittrackerapi'].visibleUnits
		for unitID, unitDefID in pairs(visibleUnits) do
			widget:VisibleUnitAdded(unitID, unitDefID, spGetUnitTeam(unitID), nil, true)
		end
	end
	InstanceVBOTable.uploadAllElements(circleInstanceVBO)
end

function widget:PlayerChanged()
	local prevFullview = fullview
	local myPrevAllyTeamID = allyTeamID
	spec, fullview = spGetSpectatingState()
	allyTeamID = Spring.GetMyAllyTeamID()
	if fullview ~= prevFullview or allyTeamID ~= myPrevAllyTeamID then
		InitializeUnits()
	end
end

function widget:Initialize()
	if not gl.CreateShader or Spring.GetModOptions().disable_fogofwar then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end

	WG.jammerrange = {
		getOpacity = function() return opacity end,
		setOpacity = function(value) opacity = value end,
	}

	initgl4()	

	InitializeUnits()
end

function widget:Shutdown()
	if jammerStencilTexture then gl.DeleteTexture(jammerStencilTexture) end
	WG.jammerrange = nil
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam, reason,  noupload)
	--spEcho("widget:VisibleUnitAdded",unitID, unitDefID, unitTeam, reason, noupload)
	unitTeam = unitTeam or spGetUnitTeam(unitID)
	noupload = noupload == true
	if unitRange[unitDefID] == nil or unitTeam == gaiaTeamID then return end

	if (not (spec and fullview)) and (not spIsUnitAllied(unitID)) then -- given units are still considered allies :/
		return
	end -- display mode for specs

	if Spring.GetUnitIsBeingBuilt(unitID) then return end

	instanceCache[1] =  unitRange[unitDefID]

	
	local active = spGetUnitIsActive(unitID)
	local gameFrame = spGetGameFrame()
	if reason == "UnitFinished" then
		if active then 
			instanceCache[2] = spGetGameFrame()
		else
			instanceCache[2] = -2 -- start from full size
		end
	else
		if active then 
			instanceCache[2] = gameFrame
		else
			instanceCache[2] = -1 * gameFrame 
		end
	end
	unitList[unitID] = active
	pushElementInstance(circleInstanceVBO,
		instanceCache,
		unitID, --key
		true, -- updateExisting
		noupload,
		unitID -- unitID for uniform buffers
	)
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	-- Note that this unit uses its own VisibleUnitsChanged, to handle the case where we go into fullview.
end

function widget:VisibleUnitRemoved(unitID)
	if circleInstanceVBO.instanceIDtoIndex[unitID] then
		popElementInstance(circleInstanceVBO, unitID)
	end
	unitList[unitID] = nil
end

function widget:GameFrame(n)
	if spec and fullview then return end
	if n % 15 == 0 then 
		for unitID, oldActive in pairs(unitList) do
			local active = spGetUnitIsActive(unitID)
			if active ~= oldActive then
				unitList[unitID] = active
				widget:VisibleUnitAdded(unitID, Spring.GetUnitDefID(unitID), spGetUnitTeam(unitID) )
			end
		end
	end
end

function widget:DrawWorld()
	--if spec and fullview then return end
	if Spring.IsGUIHidden() or 
		(circleInstanceVBO.usedElements == 0) or
		(opacity <= 0.01)
	then return end
    
	--gl.Clear(GL.STENCIL_BUFFER_BIT) -- Preemtively clear the stencil buffer
	gl.StencilTest(true) -- Enable stencil testing
	gl.StencilFunc(GL_NOTEQUAL, 8, 8) -- Always Passes, 0 Bit Plane, 0 As Mask
	gl.StencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon
	gl.StencilMask(15) -- Only check the first bit of the stencil buffer
  
	jammerCircleShader:Activate()
	gl.Texture(0, "$heightmap") -- Bind the heightmap texture
	gl.Texture(1, jammerStencilTexture) -- Bind the heightmap texture

	jammerCircleShader:SetUniform("rangeColor", rangeColor[1], rangeColor[2], rangeColor[3], opacity )
	--spEcho("rangeColor", rangeColor[1], rangeColor[2], rangeColor[3], opacity * (useteamcolors and 2 or 1 ))
	jammerCircleShader:SetUniform("teamColorMix", 0)

	gl.LineWidth(rangeLineWidth * lineScale * 1.0)

	gl.DepthTest(true)
	-- Note that we are skipping the first and last vertex, as those are the center of the circle : 
	circleInstanceVBO.VAO:DrawArrays(GL_LINE_LOOP, circleInstanceVBO.numVertices -0, 0, circleInstanceVBO.usedElements) 
	-- TODO: In the future, when BASE VERTEX works, use the following line instead:
	--circleInstanceVBO.VAO:DrawArrays(GL_LINE_LOOP, circleInstanceVBO.numVertices -2, 1, circleInstanceVBO.usedElements) 
	
	jammerCircleShader:Deactivate()
	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.DepthTest(true)
	gl.StencilTest(false) -- Disable stencil testing

	gl.LineWidth(1.0) 
	gl.Clear(GL.STENCIL_BUFFER_BIT)
end


function widget:GetConfigData(data)
	return {
		opacity = opacity,
	}
end

function widget:SetConfigData(data)
	if data.opacity ~= nil then
		opacity = data.opacity
	end
end
