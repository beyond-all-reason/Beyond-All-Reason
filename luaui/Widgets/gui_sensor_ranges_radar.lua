local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Sensor Ranges Radar",
		desc = "Shows Radar ranges of all ally units. (GL4)",
		author = "Beherith GL4",
		date = "2021.06.18",
		license = "GPLv2, (c) Beherith (mysterme@gmail.com)",
		layer = 19,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spEcho = Spring.Echo
local spGetViewGeometry = Spring.GetViewGeometry

-------   Configurables: -------------------
local debugmode = false
---
local rangeColor = { 0.0, 1.0, 0.0, 0.16 } -- default range color
local opacity = 0.16
local rangeLineWidth = 4.5 -- (note: will end up larger for larger vertical screen resolution size)
local lineScale = 1 -- this is a multiplier for the line width, to make it look better on high res screens

local circleSegments = 126 -- To ensure its only 2 warps per instance
local lineInset = 4 -- elmos inside the coverage edge: about one dash, so the visible (outer) half of the line stays within it
-- radar ranges are large and still readable zoomed out, so they fade later than the LOS and sonar lines
local fadeStart = 600000 -- elmos from the camera where the lines start fading out
local fadeEnd = 1100000 -- elmos from the camera where they are gone
-- players outside the LOS view (L) see their coverage only through these lines, so those don't fade for them
local noFadeWithoutLosView = true
--------- End configurables ------

-- the engine rounds radar ranges down to whole radar cells (ILosType::GetRadius) and its disk ends half a cell past
-- the last cell center, where gui_sensor_ranges_radar_preview ends the coverage; the line goes just inside
local radarMipLevel = 2 -- modrules sensors.los.radarMipLevel
do
	local modrules = VFS.LoadFile("gamedata/modrules.lua")
	local mip = modrules and modrules:match("radarMipLevel%s*=%s*(%d+)")
	if mip then
		radarMipLevel = tonumber(mip)
	end
end
local radarCell = 8 * 2 ^ radarMipLevel

local minRadarDistance = 500
local gaiaTeamID = Spring.GetGaiaTeamID()

------- GL4 NOTES -----
-- TODO: 2025.07.02:

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local popElementInstance = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

local radarCircleShader ---@type LuaShader
---@type InstanceVBOTable?
local circleInstanceVBO = nil

local vsx, vsy = spGetViewGeometry()

-- The fragment shader clips each line where it enters another circle, testing every circle exactly: the shader
-- storage copy of the instance buffer (its instData is filled on the GPU) is bound here before drawing. The radar
-- preview uses this binding as well and binds its own buffers before its passes.
local CIRCLE_SSBO_BINDING = 5
local circleSSBO = nil ---@type VBO?
local circleSSBOCapacity = 0

local circleShaderSourceCache = {
	shaderName = "Radar Ranges Circles GL4",
	vssrcpath = "LuaUI/Shaders/sensor_ranges_los.vert.glsl",
	fssrcpath = "LuaUI/Shaders/sensor_ranges_los.frag.glsl",
	shaderConfig = {
		VSX = vsx,
		VSY = vsy,
		PADDING = 1,
		EXACT_CIRCLES = 1,
		CIRCLE_SEGMENTS = circleSegments - 1, -- makeCircleVBO repeats its first vertex
		CIRCLE_SSBO_BINDING = CIRCLE_SSBO_BINDING,
		--VISIBILITYCULLING = 1,
		STIPPLE_RATE = 1.0,
		FADE_START = fadeStart,
		FADE_END = fadeEnd,
	},
	uniformInt = {
		heightmapTex = 0,
	},
	uniformFloat = {
		teamColorMix = 1.0,
		rangeColor = rangeColor,
	},
	silent = not debugmode, -- do not print shader compile timing
}

local function goodbye(reason)
	spEcho("Sensor Ranges LOS widget exiting with reason: " .. reason)
	widgetHandler:RemoveWidget()
	return false
end

local builtVsx, builtVsy = -1, -1 -- view size the shader (VSX/VSY defines) was made for

local function finalizeShader(shader)
	if shader then
		shader:Finalize()
	end
end

local function CreateCircleShader()
	vsx, vsy = spGetViewGeometry()
	if vsx == builtVsx and vsy == builtVsy then
		return -- e.g. the handler's first ViewResize after load, at the size Initialize built for
	end
	circleShaderSourceCache.shaderConfig.VSX = vsx
	circleShaderSourceCache.shaderConfig.VSY = vsy
	circleShaderSourceCache.forceupdate = true

	local oldCircleShader = radarCircleShader
	radarCircleShader = LuaShader.CheckShaderUpdates(circleShaderSourceCache, 0)
	if not radarCircleShader then
		return goodbye("Failed to compile radarrange shader GL4 ")
	end
	finalizeShader(oldCircleShader)

	lineScale = (vsy + 500) / 1300
	builtVsx, builtVsy = vsx, vsy
end

local function initgl4()
	-- Due to the view size being part of the shader config, we need to initialize the shaders after the view size is known.

	-- Note that we are creating a special Circle VBO, that starts at the center vertex! This is needed for triangle fans
	local circleVBO, numVertices = InstanceVBOTable.makeCircleVBO(circleSegments, nil, true, "radarrangeCircles")
	local circleInstanceVBOLayout = {
		{ id = 1, name = "radius_params", size = 4 }, -- radius, gameframe, 2 unused floats
		{ id = 2, name = "instData", size = 4, type = GL.UNSIGNED_INT }, -- instData
	}

	circleInstanceVBO = InstanceVBOTable.makeInstanceVBOTable(circleInstanceVBOLayout, 128, "radarrangeVBO", 2)
	circleInstanceVBO.numVertices = numVertices
	circleInstanceVBO.vertexVBO = circleVBO
	circleInstanceVBO.VAO = InstanceVBOTable.fillVAOSlots(
		InstanceVBOTable.makeVAOandAttach(circleInstanceVBO.vertexVBO, circleInstanceVBO.instanceVBO),
		false,
		true
	)

	CreateCircleShader()
end

-- copies the instance buffer into the shader storage buffer the fragment shader reads, and binds it
local function UpdateCircleSSBO()
	local instances = circleInstanceVBO
	if not instances then
		return false
	end
	local ssbo = circleSSBO
	if not ssbo or circleSSBOCapacity < instances.maxElements then
		if ssbo then
			ssbo:Delete()
		end
		ssbo = gl.GetVBO(GL.SHADER_STORAGE_BUFFER, false)
		circleSSBO, circleSSBOCapacity = ssbo, 0
		if not ssbo then
			return false
		end
		ssbo:Define(instances.maxElements, { { id = 0, name = "circle", size = 2 } }) -- two vec4: radius_params, instData
		circleSSBOCapacity = instances.maxElements
	end
	instances.instanceVBO:CopyTo(ssbo, instances.usedElements * 32)
	ssbo:BindBufferRange(CIRCLE_SSBO_BINDING)
	return true
end

-- Functions shortcuts
local spGetSpectatingState = Spring.GetSpectatingState
local spIsUnitAllied = Spring.IsUnitAllied
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitIsActive = Spring.GetUnitIsActive
local spGetCameraPosition = Spring.GetCameraPosition
local spGetGroundExtremes = Spring.GetGroundExtremes
local spGetMapDrawMode = Spring.GetMapDrawMode
local GL_NOTEQUAL = GL.NOTEQUAL
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_KEEP = GL.KEEP
local GL_REPLACE = GL.REPLACE

-- Globals
local spec, fullview = spGetSpectatingState()
local allyTeamID = Spring.GetLocalAllyTeamID()

-- find all unit types with radar in the game and place ranges into unitRange table
local unitRange = {} -- table of unit types with their radar ranges
local unitMid = {} -- unit type -> model mid offset x, z: the radar sits at the unit's midPos

-- fetched once a unit of the type is seen (GetUnitDefDimensions loads the model)
local function getUnitMid(unitDefID)
	local mid = unitMid[unitDefID]
	if not mid then
		local dims = Spring.GetUnitDefDimensions(unitDefID)
		mid = { dims and dims.midx or 0, dims and dims.midz or 0 }
		unitMid[unitDefID] = mid
	end
	return mid
end

local unitList = {} -- all ally units and their coordinates and radar ranges

-- 1 when the lines fade out with the camera distance, 0 when they don't
local function getFadeStrength()
	if noFadeWithoutLosView and not spec and spGetMapDrawMode() ~= "los" then
		return 0
	end
	return 1
end

-- true when the camera is so far above the ground that every line (they sit at max(0, ground)) has faded out
local function fadedOut(fadeStrength)
	if fadeStrength <= 0 then
		return false
	end
	local _, camY = spGetCameraPosition()
	local _, _, _, maxHeight = spGetGroundExtremes()
	return camY - math.max(maxHeight, 0) >= fadeEnd
end

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.radarDistance and unitDef.radarDistance > minRadarDistance then -- save perf by excluding low radar range units
		unitRange[unitDefID] = (math.floor(math.floor(unitDef.radarDistance / 8) / 2 ^ radarMipLevel) + 0.5) * radarCell
			- lineInset
	end
end

function widget:ViewResize(newX, newY)
	CreateCircleShader()
end

-- a reusable table, since we will literally only modify its first element.
local instanceCache = { 0, 0, 0, 0, 0, 0, 0, 0 }

local function InitializeUnits()
	--spEcho("Sensor Ranges LOS InitializeUnits")
	InstanceVBOTable.clearInstanceTable(circleInstanceVBO)
	if WG.unittrackerapi and WG.unittrackerapi.visibleUnits then
		local visibleUnits = WG.unittrackerapi.visibleUnits
		for unitID, unitDefID in pairs(visibleUnits) do
			widget:VisibleUnitAdded(unitID, unitDefID, spGetUnitTeam(unitID), nil, true)
		end
	end
	InstanceVBOTable.uploadAllElements(circleInstanceVBO)
end

function widget:PlayerChanged()
	local wasFullview = spec and fullview
	local myPrevAllyTeamID = allyTeamID
	spec, fullview = spGetSpectatingState()
	allyTeamID = Spring.GetLocalAllyTeamID()
	local isFullview = spec and fullview
	if isFullview ~= wasFullview or ((not isFullview) and allyTeamID ~= myPrevAllyTeamID) then
		InitializeUnits()
	end
end

function widget:Initialize()
	if not gl.CreateShader or Spring.GetModOptions().disable_fogofwar then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end

	WG.radarrange = {
		getOpacity = function()
			return opacity
		end,
		setOpacity = function(value)
			opacity = value
		end,
	}

	initgl4()

	InitializeUnits()
end

function widget:Shutdown()
	if circleSSBO then
		circleSSBO:Delete()
	end
	finalizeShader(radarCircleShader)
	WG.radarrange = nil
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam, reason, noupload)
	--spEcho("widget:VisibleUnitAdded",unitID, unitDefID, unitTeam, reason, noupload)
	unitTeam = unitTeam or spGetUnitTeam(unitID)
	noupload = noupload == true
	if unitRange[unitDefID] == nil or unitTeam == gaiaTeamID then
		return
	end

	if (not (spec and fullview)) and (not spIsUnitAllied(unitID)) then -- given units are still considered allies :/
		return
	end -- display mode for specs

	if Spring.GetUnitIsBeingBuilt(unitID) then
		return
	end

	instanceCache[1] = unitRange[unitDefID]
	local mid = getUnitMid(unitDefID)
	instanceCache[3], instanceCache[4] = mid[1], mid[2]

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
	pushElementInstance(
		circleInstanceVBO,
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
	if spec and fullview then
		return
	end
	if n % 15 == 2 then
		for unitID, oldActive in pairs(unitList) do
			local active = spGetUnitIsActive(unitID)
			if active ~= oldActive then
				unitList[unitID] = active
				widget:VisibleUnitAdded(unitID, Spring.GetUnitDefID(unitID), spGetUnitTeam(unitID))
			end
		end
	end
end

function widget:DrawWorld()
	--if spec and fullview then return end
	local fadeStrength = getFadeStrength()
	if Spring.IsGUIHidden() or (circleInstanceVBO.usedElements == 0) or (opacity <= 0.01) or fadedOut(fadeStrength) then
		return
	end
	if not UpdateCircleSSBO() then
		return
	end

	--gl.Clear(GL.STENCIL_BUFFER_BIT) -- Preemtively clear the stencil buffer
	gl.StencilTest(true) -- Enable stencil testing
	gl.StencilFunc(GL_NOTEQUAL, 4, 4) -- Always Passes, 0 Bit Plane, 0 As Mask
	gl.StencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon
	gl.StencilMask(15) -- Only check the first bit of the stencil buffer

	radarCircleShader:Activate()
	gl.Texture(0, "$heightmap") -- Bind the heightmap texture

	radarCircleShader:SetUniform("rangeColor", rangeColor[1], rangeColor[2], rangeColor[3], opacity)
	--spEcho("rangeColor", rangeColor[1], rangeColor[2], rangeColor[3], opacity * (useteamcolors and 2 or 1 ))
	radarCircleShader:SetUniform("teamColorMix", 0)
	radarCircleShader:SetUniformInt("circleCount", circleInstanceVBO.usedElements)
	radarCircleShader:SetUniform("fadeStrength", fadeStrength)

	gl.LineWidth(rangeLineWidth * lineScale * 1.0)

	gl.DepthTest(true)
	-- Note that we are skipping the first and last vertex, as those are the center of the circle :
	circleInstanceVBO.VAO:DrawArrays(GL_LINE_LOOP, circleInstanceVBO.numVertices - 0, 0, circleInstanceVBO.usedElements)
	-- TODO: In the future, when BASE VERTEX works, use the following line instead:
	--circleInstanceVBO.VAO:DrawArrays(GL_LINE_LOOP, circleInstanceVBO.numVertices -2, 1, circleInstanceVBO.usedElements)

	radarCircleShader:Deactivate()
	gl.Texture(0, false)
	gl.DepthTest(true)
	gl.StencilTest(false) -- Disable stencil testing

	gl.LineWidth(1.0)
	--gl.Clear(GL.STENCIL_BUFFER_BIT)
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
