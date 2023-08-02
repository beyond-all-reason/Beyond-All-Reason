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

local debugmode = false
--------- End configurables ------

local minSightDistance = 100
local gaiaTeamID = Spring.GetGaiaTeamID()
local olduseteamcolors = false -- needs re-init when teamcolor prefs are changed

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

local luaShaderDir = "LuaUI/Widgets/Include/"
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
	vssrcpath = "LuaUI/Widgets/Shaders/sensor_ranges_los.vert.glsl",
	fssrcpath = "LuaUI/Widgets/Shaders/sensor_ranges_los.frag.glsl",
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
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitSensorRadius = Spring.GetUnitSensorRadius
local spIsUnitAllied = Spring.IsUnitAllied
local glColor = gl.Color
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
local vsx, vsy = Spring.GetViewGeometry()
local lineScale = 1
local unitList = {} -- all ally units and their coordinates and radar ranges
local spec, fullview = spGetSpectatingState()
local allyTeamID = Spring.GetMyAllyTeamID()

-- find all unit types with radar in the game and place ranges into unitRange table
local unitRange = {} -- table of unit types with their radar ranges
local crashable = {}


for unitDefID, unitDef in pairs(UnitDefs) do
	-- save perf by excluding low los range units
	if unitDef.losRadius and unitDef.losRadius > minSightDistance then
		unitRange[unitDefID] = unitDef.losRadius - rangecorrectionelmos
	end
end

--crashable aircraft
for _, UnitDef in pairs(UnitDefs) do
	if UnitDef.canFly == true and UnitDef.transportSize == 0 and string.sub(UnitDef.name, 1, 7) ~= "critter" and string.sub(UnitDef.name, 1, 7) ~= "raptor" then
		crashable[UnitDef.id] = true
	end
end

--local nonCrashable = {'armpeep', 'corfink', 'corbw', 'armfig', 'armsfig', 'armhawk', 'corveng', 'corsfig', 'corvamp'}
local nonCrashable = { 'armpeep', 'corfink', 'corbw' }
for udid, ud in pairs(UnitDefs) do
	for _, unitname in pairs(nonCrashable) do
		if string.find(ud.name, unitname) then
			crashable[udid] = nil
		end
	end
end

function widget:ViewResize(newX, newY)
	vsx, vsy = Spring.GetViewGeometry()
	lineScale = (vsy + 500)/ 1300
end

-- collect data about the unit and store it into unitList
local unitIDtoaddreason = {}
local instanceCache = {0,0,0,0,0,0,0,0}
local function processUnit(unitID, unitDefID, caller, teamID)
	if debugmode then
		Spring.Echo("processunit", unitID, unitDefID, caller, teamID)
		Spring.Echo('allied:',spIsUnitAllied(unitID),'spec',spec,'fullview',fullview, 'getteam', Spring.GetUnitTeam(unitID)  )
	end
	-- units given to the enemy get called for some reason?
	teamID = teamID or Spring.GetUnitTeam(unitID)

	if (not (spec and fullview)) and (not spIsUnitAllied(unitID)) then -- given units are still considered allies :/
		return
	end -- display mode for specs

	if teamID == gaiaTeamID then
		return
	end -- no gaia units

	local range = unitRange[unitDefID]
	if range == nil then
		return
	end -- not enough LOS to be drawn

	local _, _, _, _, buildProgress = Spring.GetUnitHealth(unitID)
	if buildProgress < 0.99 then
		return
	end

	unitList[unitID] = unitDefID
	-- shall we jam it straight into the table?
	--if circleInstanceVBO.instanceIDtoIndex[unitID] then S pring.Echo("Duplicate unit added", unitID, caller, unitIDtoaddreason[unitID]) end
	unitIDtoaddreason[unitID] = caller
	instanceCache[1] = range
	pushElementInstance(circleInstanceVBO,
		instanceCache,
		unitID, --key
		true, -- updateExisting
		caller == "Initialize", -- dont upload on init, 
		unitID -- new unitID stuff
	)

end

local function InitializeUnits()
	unitList = {}
	clearInstanceTable(circleInstanceVBO)
	local units = Spring.GetAllUnits()
	for i = 1, #units do
		processUnit(units[i], spGetUnitDefID(units[i]), "Initialize")
	end
	uploadAllElements(circleInstanceVBO) --upload initialized at once
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

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if unitList[unitID] then
		unitList[unitID] = nil
		popElementInstance(circleInstanceVBO, unitID)
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	widget:UnitDestroyed(unitID)
	if (spec and fullview) or Spring.AreTeamsAllied(unitTeam, newTeam) == true then
		processUnit(unitID, unitDefID, "UnitTaken", newTeam)
	end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	widget:UnitDestroyed(unitID)
	if (spec and fullview) or Spring.AreTeamsAllied(unitTeam, oldTeam) == true then
		processUnit(unitID, unitDefID, "UnitGiven", unitTeam)
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	processUnit(unitID, unitDefID, "UnitFinished", unitTeam)
end

function widget:DrawWorldPreUnit()
	--if spec and fullview then return end
	if Spring.IsGUIHidden() or (WG['topbar'] and WG['topbar'].showingQuit()) then
		return
	end

	if circleInstanceVBO.usedElements == 0 then
		return
	end

	if opacity < 0.01 then
		return
	end

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
