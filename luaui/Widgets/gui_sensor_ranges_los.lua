local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Sensor Ranges LOS",
		desc = "Shows LOS ranges of all ally units. (GL4)",
		author = "Beherith GL4, Borg_King",
		date = "2021.06.18",
		license = "Lua: GPLv2, GLSL: (c) Beherith (mysterme@gmail.com)",
		layer = 0,
		enabled = true
	}
end

-------   Configurables: -------------------
local rangeColor = { 0.9, 0.9, 0.9, 0.24 } -- default range color
local opacity = 0.08
local useteamcolors = false
local rangeLineWidth = 4.5 -- (note: will end up larger for larger vertical screen resolution size)

local circleSegments = 64
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

local luaShaderDir = "LuaUI/Include/"
local LuaShader = VFS.Include(luaShaderDir .. "LuaShader.lua")
VFS.Include(luaShaderDir .. "instancevbotable.lua")

local circleShader = nil
local circleInstanceVBO = nil

local shaderConfig = {
	EXAMPLE_DEFINE = 1.0,
	--USE_STIPPLE = 1.5;
}

local shaderSourceCache = {
	shaderName = 'LOS Ranges GL4',
	vssrcpath = "LuaUI/Shaders/sensor_ranges_los.vert.glsl",
	fssrcpath = "LuaUI/Shaders/sensor_ranges_los.frag.glsl",
	shaderConfig = shaderConfig,
	uniformInt = {
		heightmapTex = 0,
	},
	uniformFloat = {
		teamColorMix = 1.0,
		rangeColor = rangeColor,
	},
}

local function goodbye(reason)
	Spring.Echo("Sensor Ranges LOS widget exiting with reason: " .. reason)
	widgetHandler:RemoveWidget()
end

local function initgl4()
	if circleShader then
		circleShader:Finalize()
	end
	if circleInstanceVBO then
		clearInstanceTable(circleInstanceVBO)
	end
	circleShader = LuaShader.CheckShaderUpdates(shaderSourceCache,0)

	if not circleShader then
		goodbye("Failed to compile losrange shader GL4 ")
	end
	local circleVBO, numVertices = makeCircleVBO(circleSegments)
	local circleInstanceVBOLayout = {
		{ id = 1, name = 'radius_params', size = 4 }, -- radius, + 3 unused floats
		{ id = 2, name = 'instData', size = 4, type = GL.UNSIGNED_INT}, -- instData
	}
	circleInstanceVBO = makeInstanceVBOTable(circleInstanceVBOLayout, 128, "losrangeVBO", 2)
	circleInstanceVBO.numVertices = numVertices
	circleInstanceVBO.vertexVBO = circleVBO
	circleInstanceVBO.VAO = makeVAOandAttach(circleInstanceVBO.vertexVBO, circleInstanceVBO.instanceVBO)
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
	local vsx, vsy = Spring.GetViewGeometry()
	lineScale = (vsy + 500)/ 1300
end

-- a reusable table, since we will literally only modify its first element.
local instanceCache = {0,0,0,0,0,0,0,0}

local function InitializeUnits()
	--Spring.Echo("Sensor Ranges LOS InitializeUnits")
	clearInstanceTable(circleInstanceVBO)
	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		local visibleUnits =  WG['unittrackerapi'].visibleUnits
		for unitID, unitDefID in pairs(visibleUnits) do
			widget:VisibleUnitAdded(unitID, unitDefID, spGetUnitTeam(unitID), true)
		end
	end
	uploadAllElements(circleInstanceVBO)
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

	for index, unitID in ipairs(allcircles) do
		local px,py,pz = Spring.GetUnitPosition(unitID)
		--Spring.Echo(px,py,pz)
		if px then
			local unitDefID = Spring.GetUnitDefID(unitID)
			local losrange = unitRange[unitDefID]
			totalcircles = totalcircles + 1
			-- check for overlap
			local overlaps = False
			for index2, unitID2 in ipairs(allcircles) do
				local unitDefID2 = Spring.GetUnitDefID(unitID2)
				local losrange2 = unitRange[unitDefID2]
				--Spring.Echo(losrange2, losrange)
				if losrange2 > losrange then
					local px2, py2, pz2 = Spring.GetUnitPosition(unitID2)
					--Spring.Echo(px-px2, pz-pz2, losrange2, losrange)
					if px2 and (math.diag(px-px2, pz-pz2) < losrange2 - losrange) then
						overlaps = true
					end
				end
			end



			if Spring.IsSphereInView(px,py,pz,losrange) then
				inviewcircles =inviewcircles + 1
				if overlaps then inviewoverlapping = inviewoverlapping + 1 end
			end
			if overlaps then totaloverlapping = totaloverlapping + 1 end
		end
	end
	return totalcircles, totaloverlapping, inviewcircles, inviewoverlapping
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

	--gl.Clear(GL.STENCIL_BUFFER_BIT) -- clear stencil buffer before starting work
	glColorMask(false, false, false, false) -- disable color drawing
	glStencilTest(true) -- Enable stencil testing
	glDepthTest(false)  -- Dont do depth tests, as we are still pre-unit

	gl.Texture(0, "$heightmap") -- Bind the heightmap texture
	circleShader:Activate()
	circleShader:SetUniform("rangeColor", rangeColor[1], rangeColor[2], rangeColor[3], opacity * (useteamcolors and 2 or 1 ))
	circleShader:SetUniform("teamColorMix", useteamcolors and 1 or 0)

	-- https://learnopengl.com/Advanced-OpenGL/Stencil-testing
	-- Borg_King: Draw solid circles into masking stencil buffer
	--glStencilFunc(GL_ALWAYS, 1, 1) -- Always Passes, 0 Bit Plane, 0 As Mask
	glStencilFunc(GL_NOTEQUAL, 1, 1) -- Always Passes, 0 Bit Plane, 0 As Mask
	glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon
	glStencilMask(1) -- Only check the first bit of the stencil buffer


	circleInstanceVBO.VAO:DrawArrays(GL_TRIANGLE_FAN, circleInstanceVBO.numVertices, 0, circleInstanceVBO.usedElements, 0)

	-- Borg_King: Draw thick ring with partial width outside of solid circle, replacing stencil to 0 (draw) where test passes
	glColorMask(true, true, true, true)	-- re-enable color drawing
	glStencilFunc(GL_NOTEQUAL, 1, 1)
	--glStencilMask(0) -- this is commented out to not double-draw los ring edges
	--glColor(rangeColor[1], rangeColor[2], rangeColor[3], rangeColor[4])
	glLineWidth(rangeLineWidth * lineScale * 1.0)
	--Spring.Echo("glLineWidth",rangeLineWidth * lineScale * 1.0)
	glDepthTest(true)
	circleInstanceVBO.VAO:DrawArrays(GL_LINE_LOOP, circleInstanceVBO.numVertices, 0, circleInstanceVBO.usedElements, 0)

	glStencilMask(255) -- enable all bits for future drawing
	glStencilFunc(GL_ALWAYS, 1, 1) -- reset gl stencilfunc too

	circleShader:Deactivate()
	gl.Texture(0, false)
	glStencilTest(false)
	glDepthTest(true)
	--glColor(1.0, 1.0, 1.0, 1.0) --reset like a nice boi
	glLineWidth(1.0)
	gl.Clear(GL.STENCIL_BUFFER_BIT)

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
