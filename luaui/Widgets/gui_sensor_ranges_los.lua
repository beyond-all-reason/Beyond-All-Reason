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
local usestipple = 0 -- 0 or 1
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

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir .. "LuaShader.lua")
VFS.Include(luaShaderDir .. "instancevbotable.lua")

local circleShader = nil
local circleInstanceVBO = nil

local vsSrc = [[
#version 420
#line 10000

layout (location = 0) in vec4 circlepointposition;
layout (location = 1) in vec4 startposrad;
layout (location = 2) in vec4 endposrad;
layout (location = 3) in vec4 color;
uniform float circleopacity;

uniform sampler2D heightmapTex;

out DataVS {
	//vec4 worldPos; // pos and radius
	vec4 blendedcolor;
	//float worldscale_circumference;
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 11000

float heightAtWorldPos(vec2 w){
	vec2 uvhm =   vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy;
	return textureLod(heightmapTex, uvhm, 0.0).x;
}

void main() {
	// blend start to end on mod gf%10
	float timemix = clamp((mod(timeInfo.x, 10) + timeInfo.w) * (0.1), 0.0, 1.0);
	vec4 circleWorldPos = mix(startposrad, endposrad, timemix);
	bool isclipped = isSphereVisibleXY(vec4(circleWorldPos.xyz,1.0), circleWorldPos.w * 1.1);
	if (isclipped){
		gl_Position = cameraViewProj * vec4(-10000,-1000,-10000,1.0);
		return;
	}

	circleWorldPos.xz = circlepointposition.xy * circleWorldPos.w +  circleWorldPos.xz;
	// get heightmap
	circleWorldPos.y = max(0.0,heightAtWorldPos(circleWorldPos.xz))+16.0;

	// -- MAP OUT OF BOUNDS
	vec2 mymin = min(circleWorldPos.xz,mapSize.xy - circleWorldPos.xz);
	float inboundsness = min(mymin.x, mymin.y);

	// dump to FS
	//worldscale_circumference = startposrad.w * circlepointposition.z * 6.2831853;
	//worldPos = circleWorldPos;
	blendedcolor = color;
	blendedcolor.a = 1.0;
	blendedcolor.a *= 1.0 - clamp(inboundsness*(-0.02),0.0,1.0);
	gl_Position = cameraViewProj * vec4(circleWorldPos.xyz, 1.0);
}
]]

local fsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 20000

uniform float circleopacity;

uniform sampler2D heightmapTex;

//__ENGINEUNIFORMBUFFERDEFS__

//__DEFINES__

in DataVS {
	//vec4 worldPos; // w = range
	vec4 blendedcolor;
	//float worldscale_circumference;
};

out vec4 fragColor;

void main() {
	fragColor.rgba = blendedcolor.rgba;
	fragColor.a *= circleopacity;
	#if USE_STIPPLE > 0
	//	fragColor.a *= 2.0 * sin(worldscale_circumference + timeInfo.x*0.1) * circleopacity; // PERFECT STIPPLING!
	#endif
}
]]

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

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	circleShader = LuaShader(
		{
			vertex = vsSrc:gsub("//__DEFINES__", "#define MYGRAVITY " .. tostring(Game.gravity + 0.1)),
			fragment = fsSrc:gsub("//__DEFINES__", "#define USE_STIPPLE " .. tostring(usestipple)),
			--geometry = gsSrc, no geom shader for now
			uniformInt = {
				heightmapTex = 0,
			},
			uniformFloat = {
				circleopacity = { 1 },
			},
		},
		"losrange shader GL4"
	)
	shaderCompiled = circleShader:Initialize()
	if not shaderCompiled then
		goodbye("Failed to compile losrange shader GL4 ")
	end
	local circleVBO, numVertices = makeCircleVBO(circleSegments)
	local circleInstanceVBOLayout = {
		{ id = 1, name = 'startposrad', size = 4 }, -- the start pos + radius
		{ id = 2, name = 'endposrad', size = 4 }, --  end pos + radius
		{ id = 3, name = 'color', size = 4 }, --- color
	}
	circleInstanceVBO = makeInstanceVBOTable(circleInstanceVBOLayout, 128, "losrangeVBO")
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
local isBuilding = {} -- unitDefID keys
local crashable = {}


for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.losRadius and unitDef.losRadius > minSightDistance then
		-- save perf by excluding low radar range units
		if not unitRange[unitDefID] then
			unitRange[unitDefID] = unitDef.losRadius - rangecorrectionelmos
		end
		if unitDef.isBuilding or unitDef.isFactory or unitDef.speed == 0 then
			isBuilding[unitDefID] = true
		end
	end
end

--crashable aircraft
for _, UnitDef in pairs(UnitDefs) do
	if UnitDef.canFly == true and UnitDef.transportSize == 0 and string.sub(UnitDef.name, 1, 7) ~= "critter" and string.sub(UnitDef.name, 1, 7) ~= "chicken" then
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



function widget:PlayerChanged()
	local prevFullview = fullview
	local myPrevAllyTeamID = allyTeamID
	spec, fullview = spGetSpectatingState()
	allyTeamID = Spring.GetMyAllyTeamID()
	if fullview ~= prevFullview or allyTeamID ~= myPrevAllyTeamID then
		widget:Initialize()
	end
end

function widget:ViewResize(newX, newY)
	vsx, vsy = Spring.GetViewGeometry()
	lineScale = (vsy + 500)/ 1300
end

-- collect data about the unit and store it into unitList
local unitIDtoaddreason = {}
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

	local x, y, z = spGetUnitPosition(unitID)
	local r, g, b
	if useteamcolors then
		r, g, b = Spring.GetTeamColor(teamID)
	else
		r = rangeColor[1]
		g = rangeColor[2]
		b = rangeColor[3]
	end

	unitList[unitID] = unitDefID
	-- shall we jam it straight into the table?
	--if circleInstanceVBO.instanceIDtoIndex[unitID] then S pring.Echo("Duplicate unit added", unitID, caller, unitIDtoaddreason[unitID]) end
	unitIDtoaddreason[unitID] = caller
	pushElementInstance(circleInstanceVBO,
		{
			x, y, z, range, -- start pos
			x, y, z, range, -- end positions
			--math.random(),math.random(),math.random(),1.0, -- color
			r, g, b, 0.1, -- color
		},
		unitID, --key
		true, -- updateExisting
		caller == "Initialize" -- dont upload on init
	)

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
	unitList = {}
	local units = Spring.GetAllUnits()
	for i = 1, #units do
		processUnit(units[i], spGetUnitDefID(units[i]), "Initialize")
	end
	uploadAllElements(circleInstanceVBO) --upload initialized at once

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

function widget:GameFrame(n)
	--if spec and fullview then return end
	if n % 10 == 0 then
		-- this 15 frames is important, as the vertex shader is interpolating at this rate too!
		local instanceData = circleInstanceVBO.instanceData -- ok this is so nasty that it makes all my prev pop-push work obsolete
		local instanceIDtoIndex = circleInstanceVBO.instanceIDtoIndex
		local instanceStep = circleInstanceVBO.instanceStep
		for unitID, unitDefID in pairs(unitList) do
			if not isBuilding[unitDefID] then
				local x, y, z = spGetUnitPosition(unitID)

				local instanceDataOffset = (instanceIDtoIndex[unitID] - 1) * instanceStep

				for i = instanceDataOffset + 1, instanceDataOffset + 4 do
					instanceData[i] = instanceData[i + 4]
				end
				instanceData[instanceDataOffset + 5] = x
				instanceData[instanceDataOffset + 6] = y
				instanceData[instanceDataOffset + 7] = z
				if crashable[unitDefID] then
					instanceData[instanceDataOffset + 8] = spGetUnitSensorRadius(unitID, "los")
				end
			end
		end
		uploadAllElements(circleInstanceVBO)
	end
end

function widget:DrawWorldPreUnit()
	--if spec and fullview then return end
	if Spring.IsGUIHidden() or (WG['topbar'] and WG['topbar'].showingQuit()) then
		return
	end

	if useteamcolors ~= olduseteamcolors then
		olduseteamcolors = useteamcolors
		widget:Initialize()
	end

	if circleInstanceVBO.usedElements == 0 then
		return
	end

	if opacity < 0.01 then
		return
	end

	--if true then return end

	--gl.Clear(GL.STENCIL_BUFFER_BIT) -- clear stencil buffer before starting work
	glColorMask(false, false, false, false) -- disable color drawing
	glStencilTest(true)
	glDepthTest(false)

	gl.Texture(0, "$heightmap")
	circleShader:Activate()
	circleShader:SetUniform("circleopacity", useteamcolors and opacity*2 or opacity)

	-- https://learnopengl.com/Advanced-OpenGL/Stencil-testing
	-- Borg_King: Draw solid circles into masking stencil buffer
	--glStencilFunc(GL_ALWAYS, 1, 1) -- Always Passes, 0 Bit Plane, 0 As Mask
	glStencilFunc(GL_NOTEQUAL, 1, 1) -- Always Passes, 0 Bit Plane, 0 As Mask
	glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon
	glStencilMask(1)

	circleInstanceVBO.VAO:DrawArrays(GL_TRIANGLE_FAN, circleInstanceVBO.numVertices, 0, circleInstanceVBO.usedElements, 0)

	-- Borg_King: Draw thick ring with partial width outside of solid circle, replacing stencil to 0 (draw) where test passes
	glColorMask(true, true, true, true)	-- re-enable color drawing
	glStencilFunc(GL_NOTEQUAL, 1, 1)
	glStencilMask(0)
	glColor(rangeColor[1], rangeColor[2], rangeColor[3], rangeColor[4])
	glLineWidth(rangeLineWidth * lineScale * 1.0)
	--Spring.Echo("glLineWidth",rangeLineWidth * lineScale * 1.0)
	circleInstanceVBO.VAO:DrawArrays(GL_LINE_LOOP, circleInstanceVBO.numVertices, 0, circleInstanceVBO.usedElements, 0)

	glStencilMask(255) -- enable all bits for future drawing
	glStencilFunc(GL_ALWAYS, 1, 1) -- reset gl stencilfunc too

	circleShader:Deactivate()
	gl.Texture(0, false)
	glStencilTest(false)
	glDepthTest(true)
	glColor(1.0, 1.0, 1.0, 1.0) --reset like a nice boi
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


