local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Sensor Ranges LOS V2",
		desc = "Shows LOS ranges of all ally units. (GL4)",
		author = "Beherith GL4, Borg_King",
		date = "2021.06.18",
		license = "Lua: GPLv2, GLSL: (c) Beherith (mysterme@gmail.com)",
		layer = 0,
		enabled = true
	}
end

-------   Configurables: -------------------
local debugmode = false
---
local rangeColor = { 0.9, 0.9, 0.9, 0.24 } -- default range color
local opacity = 0.08
local useteamcolors = false
local rangeLineWidth = 4.5 -- (note: will end up larger for larger vertical screen resolution size)

local circleSegments = 62 -- To ensure its only 2 warps per instance
local rangecorrectionelmos = 16 -- how much smaller they are drawn than truth due to LOS mipping
--------- End configurables ------

local minSightDistance = 100
local gaiaTeamID = Spring.GetGaiaTeamID()

------- GL4 NOTES -----
--only update every 15th frame, and interpolate pos in shader!
--Each instance has:
-- startposrad
-- endposrad
-- color
-- TODO: draw ally ranges in diff color!
-- 172 vs 123 preopt
-- TODO 2023.07.06:
	-- X Use drawpos
	-- X Stencil outlines too
	-- X remove debug code
	-- X validate options!
	-- X The only actual param needed per unit is its los range :D
	-- X refactor the opacity

-- Compute shader visibility culling:
-- Pass 1. compute :
	-- Inputs: Take SUniformsBuffer and the losrangeVBO
	-- Calculates: Which of the units are in view, and which are not. 
	-- Outputs: a VBO of vec4's of {posx, posz, losrange, index} for each unit that is in view.
		-- note that we cant selectively output stuff we want, because no sorting is possible in compute shaders.
	-- the indices are in the same order as in the losrangeVBO, so we can use them to index into the losrangeVBO.

-- Pass 2. compute :
	-- inputs: Takes the VBO from pass 1, 
	-- Calculates overlappedness of the los ranges. 
	-- Outputs: a new VBO which is #maxunits size indicating overlappedness
	-- in LOSRANGEVBO index order

-- Pass 3. vertex shader:
	-- inputs: Takes the VBO from pass 2, and the losrangeVBO
	-- draws stuff based on the VBO from pass 2, and the losrangeVBO

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local popElementInstance  = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

local stencilShader = nil
local circleShader = nil
local circleInstanceVBO = nil

local circleShaderConfig = {
}  
 
local losStencilTexture 
local resolution = 4
local vsx, vsy  = Spring.GetViewGeometry()

local circleShaderSourceCache = {
	shaderName = 'LOS Ranges Circles GL4',
	vssrcpath = "LuaUI/Shaders/sensor_ranges_los_v2.vert.glsl",
	fssrcpath = "LuaUI/Shaders/sensor_ranges_los_v2.frag.glsl",
	shaderConfig = {
		VSX = vsx,
		VSY = vsy,
		RESOLUTION = resolution,
		PADDING = 1,
	},
	uniformInt = {
		heightmapTex = 0,
		losStencilTexture = 1,
	},
	uniformFloat = {
		teamColorMix = 1.0,
		rangeColor = rangeColor,
	},
} 
 
local stencilShaderSourceCache = {
	shaderName = 'LOS Ranges Stencil GL4',
	vssrcpath = "LuaUI/Shaders/sensor_ranges_los_v2.vert.glsl",
	fssrcpath = "LuaUI/Shaders/sensor_ranges_los_v2.frag.glsl",
	shaderConfig = {
		STENCILPASS = 1,
		VSX = vsx,
		VSY = vsy,
		RESOLUTION = resolution,
		PADDING = 1,
	},
	uniformInt = {
		heightmapTex = 0,
		losStencilTexture = 1,
	},
	uniformFloat = {
		teamColorMix = 1.0,
		rangeColor = rangeColor,
	},
}

local function goodbye(reason)
	Spring.Echo("Sensor Ranges LOS widget exiting with reason: " .. reason)
	widgetHandler:RemoveWidget()
	return false
end
 

local function initgl4()
	circleShader = LuaShader.CheckShaderUpdates(circleShaderSourceCache,0)
	if not circleShader then
		return goodbye("Failed to compile losrange shader GL4 ")
	end

	stencilShader = LuaShader.CheckShaderUpdates(stencilShaderSourceCache,0)
	if not stencilShader then
  		return goodbye("Failed to compile losrange stencil shader GL4 ")
 	end

	local circleVBO, numVertices = InstanceVBOTable.makeCircleVBO(circleSegments, nil, true, "LOSRangeCircles")
	local circleInstanceVBOLayout = {
		{ id = 1, name = 'radius_params', size = 4 }, -- radius, + 3 unused floats
		{ id = 2, name = 'instData', size = 4, type = GL.UNSIGNED_INT}, -- instData
	}
	circleInstanceVBO = InstanceVBOTable.makeInstanceVBOTable(circleInstanceVBOLayout, 128, "losrangeVBO", 2)
	circleInstanceVBO.numVertices = numVertices
	circleInstanceVBO.vertexVBO = circleVBO
	circleInstanceVBO.VAO = InstanceVBOTable.makeVAOandAttach(circleInstanceVBO.vertexVBO, circleInstanceVBO.instanceVBO)
end
 
 
local function DrawMe() -- about 0.025 ms
	if circleInstanceVBO.usedElements > 0 then
        gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
		gl.BlendEquation(GL.MAX)
		gl.Blending(GL.ONE, GL.ONE)
        gl.Culling(false)
		
		gl.Texture(0, "$heightmap") -- Bind the heightmap texture
		stencilShader:Activate()
        stencilShader:SetUniform("stencilColor", 0.5)
		circleInstanceVBO.VAO:DrawArrays(GL.TRIANGLE_FAN, circleInstanceVBO.numVertices, 0, circleInstanceVBO.usedElements, 0)
		stencilShader:Deactivate()
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		gl.BlendEquation(GL.FUNC_ADD)
		
	end
end

function widget:DrawWorldPreUnit()
    --DrawMe()
end

local stencilRequested = false

function widget:DrawWorld()
 
end 
function widget:DrawGenesis()
    gl.RenderToTexture(losStencilTexture, DrawMe)
end

-- This shows the debug stencil texture

if debugmode then 
	function widget:DrawScreen()
		
	circleShader = LuaShader.CheckShaderUpdates(circleShaderSourceCache,0) or circleShader
	stencilShader = LuaShader.CheckShaderUpdates(stencilShaderSourceCache,0) or stencilShader
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
local glColorMask = gl.ColorMask
local glDepthTest = gl.DepthTest
local glLineWidth = gl.LineWidth
local glStencilFunc = gl.StencilFunc
local glStencilOp = gl.StencilOp
local glStencilTest = gl.StencilTest
local glStencilMask = gl.StencilMask
local GL_ALWAYS = GL.ALWAYS
local GL_NOTEQUAL = GL.NOTEQUAL
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_KEEP = 0x1E00 --GL.KEEP
local GL_REPLACE = GL.REPLACE
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN

-- Globals
local lineScale = 1
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
	local GL_R8 = 0x8229
    vsx, vsy = Spring.GetViewGeometry()
	lineScale = (vsy + 500)/ 1300
    if losStencilTexture then gl.DeleteTexture(unitFeatureStencilTex) end
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

-- a reusable table, since we will literally only modify its first element.
local instanceCache = {0,0,0,0,0,0,0,0}

local function InitializeUnits()
	--Spring.Echo("Sensor Ranges LOS InitializeUnits")
	InstanceVBOTable.clearInstanceTable(circleInstanceVBO)
	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		local visibleUnits =  WG['unittrackerapi'].visibleUnits
		for unitID, unitDefID in pairs(visibleUnits) do
			widget:VisibleUnitAdded(unitID, unitDefID, spGetUnitTeam(unitID), true)
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

local function CalculateOverlapping()
	local allcircles = circleInstanceVBO.indextoInstanceID
	local totalcircles = 0
	local totaloverlapping = 0
	local inviewcircles = 0
	local inviewoverlapping = 0
	local inviewoverlapsmalls = 0
	local additionalOverlaps = 0

	local circles = {}
	-- cut it down to visible circles only
	for index, unitID in ipairs(allcircles) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local losrange = unitRange[Spring.GetUnitDefID(unitID)]
		local px,py,pz = Spring.GetUnitPosition(unitID)
		local inview = Spring.IsSphereInView(px,py,pz,losrange)
		if px and unitRange[unitDefID] then
			--circles[index] = {px = px, py = py, pz =  pz, losrange = losrange, inview = Spring.IsSphereInView(px,py,pz,losrange),
			--fullycovered = false, topcovered =  false, bottomcovered =  false, leftcovered =  false, rightcovered = false}
			if inview then 
				circles[#circles + 1] = {px, py,  pz,  losrange, Spring.IsSphereInView(px,py,pz,losrange), false,   false,   false,   false,  false}	
				inviewcircles = inviewcircles + 1
			end
			totalcircles = totalcircles + 1
		end
	end
	local rmult = 0.707
	local omult = 0.5

	rmult = 0.8
	omult = 0.25
	for index, circle in ipairs(circles) do
		local px,  pz, losrange = circle[1], circle[3], circle[4]

		-- check for overlap
		local overlaps = false
		for index2, circle2 in ipairs(circles) do
			for o = 0, 4 do 
				local px2, pz2, losrange2 = circle2[1], circle2[3], circle2[4]
				local testrange = losrange
				local ox = 0
				local oz = 0 
				if o > 0 then 
					testrange = losrange * rmult
				end
				if o == 1 then 
					ox = losrange *omult  -- THIS IS INCORRECT! other way around!
					oz = losrange *omult
				elseif o == 2 then 
					ox = -losrange *omult
					oz = losrange * omult
				elseif o == 3 then
					ox = losrange *omult
					oz = -losrange *omult
				elseif o == 4 then
					ox = -losrange *omult
					oz = -losrange *omult
				end
				if losrange2 > testrange then
					if math.diag(px + ox -px2, pz + oz -pz2) < (losrange2 - testrange) then
						circle[6+o] = true -- covered
					end 
				end
			end
		end
		if circle[7] and circle[8] and circle[9] and circle[10] then
			inviewoverlapsmalls = inviewoverlapsmalls + 1
			if not circle[6] then
				additionalOverlaps = additionalOverlaps + 1
			end
		end	
		if circle[6] then
			inviewoverlapping = inviewoverlapping + 1
		end
	end
	Spring.Echo("Sensor Ranges LOS: ",omult, totalcircles, totaloverlapping, inviewcircles, inviewoverlapping, inviewoverlapsmalls, additionalOverlaps)

	return totalcircles, totaloverlapping, inviewcircles, inviewoverlapping, inviewoverlapsmalls
end

function widget:TextCommand(command)
	if string.find(command, "loscircleoverlap", nil, true) then
		Spring.Echo("CalculateOverlapping", CalculateOverlapping())
	end
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if Spring.GetModOptions().disable_fogofwar then
		widgetHandler:RemoveWidget()
		return
	end
	WG.losrange = {}
	WG.losrange.getOpacity = function()
		return opacity
	end
	WG.losrange.setOpacity = function(value)
		opacity = value
	end
	WG.losrange.getUseTeamColors = function()
		return useteamcolors
	end
	WG.losrange.setUseTeamColors = function(value)
		useteamcolors = value
	end
	initgl4()
	widget:ViewResize()
	InitializeUnits()
end

function widget:Shutdown()
	WG.losrange = nil
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam, noupload)
	--Spring.Echo("widget:VisibleUnitAdded",unitID, unitDefID, unitTeam, noupload)
	unitTeam = unitTeam or spGetUnitTeam(unitID)
	noupload = noupload == true
	if unitRange[unitDefID] == nil or unitTeam == gaiaTeamID then return end

	if (not (spec and fullview)) and (not spIsUnitAllied(unitID)) then -- given units are still considered allies :/
		return
	end -- display mode for specs

	if Spring.GetUnitIsBeingBuilt(unitID) then return end

	instanceCache[1] =  unitRange[unitDefID]
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
	--InitializeUnits()
end

function widget:VisibleUnitRemoved(unitID)
	if circleInstanceVBO.instanceIDtoIndex[unitID] then
		popElementInstance(circleInstanceVBO, unitID)
	end
end

function widget:DrawWorld()
	--if spec and fullview then return end
	if Spring.IsGUIHidden() or (WG['topbar'] and WG['topbar'].showingQuit()) then return end
	if circleInstanceVBO.usedElements == 0 then return end
	if opacity < 0.01 then return end
 
	--[[
	circleShader:Activate()
 
	gl.Texture(0, "$heightmap") -- Bind the heightmap texture
	gl.Texture(1, losStencilTexture) -- Bind the heightmap texture
	circleShader:SetUniform("rangeColor", rangeColor[1], rangeColor[2], rangeColor[3], opacity * (useteamcolors and 2 or 1 ))
	circleShader:SetUniform("teamColorMix", useteamcolors and 1 or 0)

	circleInstanceVBO.VAO:DrawArrays(GL_TRIANGLE_FAN, circleInstanceVBO.numVertices, 0, circleInstanceVBO.usedElements, 0)

	circleShader:Deactivate()
	]]--#region
    
  
	circleShader:Activate()
	
	gl.Texture(0, "$heightmap") -- Bind the heightmap texture
	gl.Texture(1, losStencilTexture) -- Bind the heightmap texture
	glLineWidth(rangeLineWidth * lineScale * 1.0)
	glDepthTest(true)
	circleInstanceVBO.VAO:DrawArrays(GL_LINE_LOOP, circleInstanceVBO.numVertices -0, 1, circleInstanceVBO.usedElements, 0)
 
	
	circleShader:Deactivate()
	gl.Texture(0, false)
	gl.Texture(1, false)
	glDepthTest(true)
	--glColor(1.0, 1.0, 1.0, 1.0) --reset like a nice boi
	glLineWidth(1.0)
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
