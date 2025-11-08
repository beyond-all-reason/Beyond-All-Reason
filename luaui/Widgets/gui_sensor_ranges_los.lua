local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Sensor Ranges LOS",
		desc = "Shows LOS ranges of all ally units. (GL4)",
		author = "Beherith GL4, Borg_King",
		date = "2021.06.18",
		license = "GPLv2, (c) Beherith (mysterme@gmail.com)",
		layer = 20,
		enabled = true
	}
end


-- Localized functions for performance

-- Localized Spring API for performance
local spEcho = Spring.Echo
local spGetViewGeometry = Spring.GetViewGeometry

-------   Configurables: -------------------
local debugmode = false
---
local rangeColor = { 0.9, 0.9, 0.9, 0.24 } -- default range color
local opacity = 0.08
local useteamcolors = false
local rangeLineWidth = 4.5 -- (note: will end up larger for larger vertical screen resolution size)
local lineScale = 1 -- this is a multiplier for the line width, to make it look better on high res screens

local circleSegments = 62 -- To ensure its only 2 warps per instance
local rangecorrectionelmos = debugmode and -16 or 16 -- how much smaller they are drawn than truth due to LOS mipping
--------- End configurables ------

local minSightDistance = 100
local gaiaTeamID = Spring.GetGaiaTeamID()

------- GL4 NOTES -----
-- TODO: draw ally ranges in diff color!
-- 172 vs 123 preopt
-- TODO 2023.07.06:
	-- X Use drawpos
	-- X Stencil outlines too
	-- X remove debug code
	-- X validate options!
	-- X The only actual param needed per unit is its los range :D
	-- X refactor the opacity

-- TODO: 2025.07.02:
	-- [x] rangecorrectionelmos = 16 
	-- [ ] DO NOT DELETE BRANCH ON MERGE! 
	-- [x] Fix screen resize
	-- [-] Engine Version Check for baseVertex offset 
	-- [x] Teamcolor no worky
	-- [x] override master 
	-- [x] profile
	-- [x] Correctly reset GL state for build ETA 
	-- [ ] Try to use only one stencil clear op, use a mask that is unique
	-- [x] Put SDscreenSphere into LuaShader.lua
	-- [-] Draw los in minimap, add config optios for it.  



local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local popElementInstance  = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

local losStencilShader = nil
local losCircleShader = nil
local circleInstanceVBO = nil

local losStencilTexture 
local resolution = 4
local vsx, vsy  = spGetViewGeometry()

local circleShaderSourceCache = {
	shaderName = 'LOS Ranges Circles GL4',
	vssrcpath = "LuaUI/Shaders/sensor_ranges_los.vert.glsl",
	fssrcpath = "LuaUI/Shaders/sensor_ranges_los.frag.glsl",
	shaderConfig = {
		VSX = vsx,
		VSY = vsy,
		RESOLUTION = resolution,
		PADDING = 1,
		USE_TEAMCOLOR = 1,
		VISIBILITYCULLING = 1,
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

	losStencilShader = LuaShader.CheckShaderUpdates(stencilShaderSourceCache,0)	

	if not losStencilShader then
  		return goodbye("Failed to compile losrange stencil shader GL4 ")
 	end
	losCircleShader = LuaShader.CheckShaderUpdates(circleShaderSourceCache,0)
	if not losCircleShader then
		return goodbye("Failed to compile losrange shader GL4 ")
	end

	local GL_R8 = 0x8229
    vsx, vsy = spGetViewGeometry()
	lineScale = (vsy + 500)/ 1300
    if losStencilTexture then gl.DeleteTexture(losStencilTexture) end
    losStencilTexture = gl.CreateTexture(vsx/resolution, vsy/resolution, {
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
	local circleVBO, numVertices = InstanceVBOTable.makeCircleVBO(circleSegments, nil, true, "LOSRangeCircles")
	local circleInstanceVBOLayout = {
		{ id = 1, name = 'radius_params', size = 4 }, -- radius, gameframe, 2 unused floats
		{ id = 2, name = 'instData', size = 4, type = GL.UNSIGNED_INT}, -- instData
	}

	circleInstanceVBO = InstanceVBOTable.makeInstanceVBOTable(circleInstanceVBOLayout, 128, "losrangeVBO", 2)
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
		losStencilShader:Activate()
		circleInstanceVBO.VAO:DrawArrays(GL.TRIANGLE_FAN, circleInstanceVBO.numVertices, 0, circleInstanceVBO.usedElements, 0)
		losStencilShader:Deactivate()
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		gl.BlendEquation(GL.FUNC_ADD)
	end
end

function widget:DrawGenesis()
    gl.RenderToTexture(losStencilTexture, DrawLOSStencil)
end

-- This shows the debug stencil texture in the bottom left corner of the screen
if debugmode then 
	function widget:DrawScreen()	
		losCircleShader = LuaShader.CheckShaderUpdates(circleShaderSourceCache,0) or losCircleShader
		losStencilShader = LuaShader.CheckShaderUpdates(stencilShaderSourceCache,0) or losStencilShader
		gl.Color(1,1,1,1)
		gl.Blending(GL.ONE, GL.ZERO)
		gl.Texture(losStencilTexture)
		gl.TexRect(0, 0, vsx/resolution, vsy/resolution, 0, 0, 1, 1)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
end  

-- Functions shortcuts
local spGetSpectatingState = Spring.GetSpectatingState
local spIsUnitAllied = Spring.IsUnitAllied
local spGetUnitTeam = Spring.GetUnitTeam
local GL_NOTEQUAL = GL.NOTEQUAL
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_KEEP = 0x1E00 --GL.KEEP
local GL_REPLACE = GL.REPLACE

-- Globals
local spec, fullview = spGetSpectatingState()
local allyTeamID = Spring.GetMyAllyTeamID()

-- find all unit types with radar in the game and place ranges into unitRange table
local unitRange = {} -- table of unit types with their radar ranges

for unitDefID, unitDef in pairs(UnitDefs) do
	-- save perf by excluding low los range units
	if unitDef.sightDistance and unitDef.sightDistance > minSightDistance then
		unitRange[unitDefID] = unitDef.sightDistance - rangecorrectionelmos
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

	WG.losrange = {
		getOpacity = function() return opacity end,
		setOpacity = function(value) opacity = value end,
		getUseTeamColors = function() return useteamcolors	end,
		setUseTeamColors = function(value) useteamcolors = value end,
	}

	initgl4()	

	InitializeUnits()
end

function widget:Shutdown()
	if losStencilTexture then gl.DeleteTexture(losStencilTexture) end
	WG.losrange = nil
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
	if reason == "UnitFinished" then
		instanceCache[2] = Spring.GetGameFrame()
	else
		instanceCache[2] = 0 -- start from full size
	end
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
end

function widget:DrawWorld()
	--if spec and fullview then return end
	if Spring.IsGUIHidden() or 
		(circleInstanceVBO.usedElements == 0) or
		(opacity <= 0.01)
	then return end
    
	--gl.Clear(GL.STENCIL_BUFFER_BIT) -- Preemtively clear the stencil buffer
	gl.StencilTest(true) -- Enable stencil testing
	gl.StencilFunc(GL_NOTEQUAL, 1, 1) -- Always Passes, 0 Bit Plane, 0 As Mask
	gl.StencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon
	gl.StencilMask(15) -- Only check the first bit of the stencil buffer
  
	losCircleShader:Activate()
	gl.Texture(0, "$heightmap") -- Bind the heightmap texture
	gl.Texture(1, losStencilTexture) -- Bind the heightmap texture

	losCircleShader:SetUniform("rangeColor", rangeColor[1], rangeColor[2], rangeColor[3], opacity * (useteamcolors and 2 or 1 ))
	--spEcho("rangeColor", rangeColor[1], rangeColor[2], rangeColor[3], opacity * (useteamcolors and 2 or 1 ))
	losCircleShader:SetUniform("teamColorMix", useteamcolors and 1 or 0)

	gl.LineWidth(rangeLineWidth * lineScale * 1.0)

	gl.DepthTest(true)
	-- Note that we are skipping the first and last vertex, as those are the center of the circle : 
	circleInstanceVBO.VAO:DrawArrays(GL_LINE_LOOP, circleInstanceVBO.numVertices -0, 0, circleInstanceVBO.usedElements) 
	-- TODO: In the future, when BASE VERTEX works, use the following line instead:
	--circleInstanceVBO.VAO:DrawArrays(GL_LINE_LOOP, circleInstanceVBO.numVertices -2, 1, circleInstanceVBO.usedElements) 
	
	losCircleShader:Deactivate()
	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.DepthTest(true)
	gl.StencilTest(false) -- Disable stencil testing

	gl.LineWidth(1.0) 
	--gl.Clear(GL.STENCIL_BUFFER_BIT)
end


function widget:GetConfigData(data)
	return {
		opacity = opacity,
		useteamcolors = useteamcolors,
	}
end

function widget:SetConfigData(data)
	if data.opacity ~= nil then
		opacity = data.opacity
	end
	if data.useteamcolors ~= nil then
		useteamcolors = data.useteamcolors
	end
end
