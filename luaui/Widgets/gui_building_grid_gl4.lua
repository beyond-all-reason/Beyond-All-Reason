local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Building Grid GL4",
		desc = "Draw a configurable grid to assist build spacing",
		author = "Hobo Joe, Beherith, LSR",
		date = "June 2023",
		license = "GNU GPL, v2 or later",
		version = 0.2,
		layer = -1,
		enabled = false,
		depends = { "gl4" },
	}
end

local opacity = 0.5

local config = {
	gridSize = 3, -- smallest footprint is size 1 (perimeter camera), size 3 is the size of nanos, winds, etc
	strongLineSpacing = 4, -- which interval produces heavy lines
	strongLineOpacity = 0.60, -- opacity of heavy lines
	weakLineOpacity = 0.18, -- opacity of intermediate lines
	gridRadius = 30, -- how far from the cursor the grid should show, in multiples of 16 elmos
	gridRadiusFalloff = 2.5, -- how sharply the grid should get cut off at max distance
	maxViewDistance = 3000.0, -- distance at which the grid no longer renders
	lineColor = { 0.70, 1.0, 0.70 }, -- color of the lines
}

local waterLevel = Spring.GetWaterPlaneLevel and Spring.GetWaterPlaneLevel() or 0

local spGetActiveCommand = Spring.GetActiveCommand
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetCameraPosition = Spring.GetCameraPosition
local glLineWidth = gl.LineWidth
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glTexture = gl.Texture
local glUniform = gl.Uniform
local mathSqrt = math.sqrt
local GL_LINES = GL.LINES
local GL_ALWAYS = GL.ALWAYS

local gridVAO ---@type VAO
local gridVAOObjects = {} -- the VAO and its buffers, deleted on shutdown
local gridShader ---@type LuaShader
local spacing = config.gridSize * 16 -- the repeat rate of the grid

-- Only lines within gridRadius * 16 elmos of the cursor are visible, so the vertex shader builds a patch of
-- grid around the cursor from gl_VertexID instead of drawing every line on the map.
local patchHalf = math.ceil(config.gridRadius * 16 / spacing) + 1 -- +1 absorbs rounding of the cursor cell
local patchLines = 2 * patchHalf + 2 -- lines per direction
local vertexCount = 4 * patchLines * (patchLines - 1) -- 2 directions, patchLines - 1 segments per line, 2 vertices each

local shaderConfig = { -- These will be replaced in the shader using #defines's
	LINECOLOR = "vec3(" .. config.lineColor[1] .. ", " .. config.lineColor[2] .. ", " .. config.lineColor[3] .. ")",
	GRIDRADIUS = config.gridRadius,
	RADIUSFALLOFF = config.gridRadiusFalloff,
	SPACING = spacing,
	STRONG_LINE_SPACING = config.strongLineSpacing,
	PATCH_HALF = patchHalf,
	PATCH_LINES = patchLines,
	-- last line index and last segment start index per axis that lie on the map
	LAST_LINE_X = math.floor(Game.mapSizeX / spacing),
	LAST_LINE_Z = math.floor(Game.mapSizeZ / spacing),
	LAST_SEGMENT_X = math.ceil(Game.mapSizeX / spacing) - 1,
	LAST_SEGMENT_Z = math.ceil(Game.mapSizeZ / spacing) - 1,
}

local LuaShader = gl.LuaShader

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

out vec3 v_worldPos;
flat out float v_alpha;

uniform sampler2D heightmapTex; // the heightmap texture
uniform vec4 mouseFade; // xyz = cursor world position, w = camera distance fade
uniform vec3 lineParams; // x = strong line alpha, y = weak line alpha, z = minimum height (water level or -1e30)

#line 11000
void main(){
	// two vertices per segment, PATCH_LINES - 1 segments per line, x-running lines first
	int segment = gl_VertexID >> 1;
	int segmentsPerDir = PATCH_LINES * (PATCH_LINES - 1);
	bool alongX = segment < segmentsPerDir;
	if (!alongX) {
		segment -= segmentsPerDir;
	}
	int line = segment / (PATCH_LINES - 1);
	int along = segment - line * (PATCH_LINES - 1);

	ivec2 origin = ivec2(floor(mouseFade.xz / float(SPACING))) - PATCH_HALF;
	ivec2 start = origin + (alongX ? ivec2(along, line) : ivec2(line, along));
	ivec2 dir = alongX ? ivec2(1, 0) : ivec2(0, 1);
	ivec2 lastStart = alongX ? ivec2(LAST_SEGMENT_X, LAST_LINE_Z) : ivec2(LAST_LINE_X, LAST_SEGMENT_Z);

	// drop segments off the map and segments that never come within the fade radius of the cursor
	vec2 segStart = vec2(start) * float(SPACING);
	vec2 segEnd = vec2(start + dir) * float(SPACING);
	vec2 toClosest = clamp(mouseFade.xz, segStart, segEnd) - mouseFade.xz;
	float fadeDist = GRIDRADIUS * 16.0;
	if (any(lessThan(start, ivec2(0))) || any(greaterThan(start, lastStart)) || dot(toClosest, toClosest) >= fadeDist * fadeDist) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0); // both ends outside the clip volume
		v_worldPos = vec3(0.0);
		v_alpha = 0.0;
		return;
	}

	int lineIndex = alongX ? start.y : start.x;
	v_alpha = (lineIndex % STRONG_LINE_SPACING == 0) ? lineParams.x : lineParams.y;

	v_worldPos.xz = ((gl_VertexID & 1) == 0) ? segStart : segEnd;
	vec2 uvhm = heightmapUVatWorldPos(v_worldPos.xz); // this function gets the UV coords of the heightmap texture at a world position
	v_worldPos.y = max(lineParams.z, textureLod(heightmapTex, uvhm, 0.0).x);

	gl_Position = cameraViewProj * vec4(v_worldPos, 1.0);  // project it into camera
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in vec3 v_worldPos;
flat in float v_alpha;

out vec4 fragColor; // the output color

uniform vec4 mouseFade;

void main(void) {
	float dist = distance(v_worldPos, mouseFade.xyz);
	float fadeDist = GRIDRADIUS * 16.0;
	float alpha = smoothstep(0.0, 1.0, ((fadeDist / (dist / RADIUSFALLOFF))) - RADIUSFALLOFF);
	fragColor = vec4(LINECOLOR, (alpha - mouseFade.w) * v_alpha);
}
]]

local function goodbye(reason)
	Spring.Echo("Building Grid GL4 widget exiting with reason: " .. reason)
	widgetHandler:RemoveWidget()
end

local mouseFadeUniform ---@type GL
local lineParamsUniform ---@type GL

local function initShader()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs() -- all the camera and other lovely stuff
	local defines = LuaShader.CreateShaderDefinesString(shaderConfig)
	local shader = LuaShader({
		vertex = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs):gsub("//__DEFINES__", defines),
		fragment = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs):gsub("//__DEFINES__", defines),
		uniformInt = {
			heightmapTex = 0, -- the index of the texture uniform sampler2D
		},
		uniformFloat = {
			mouseFade = { 0.0, 0.0, 0.0, 0.0 },
			lineParams = { 0.0, 0.0, 0.0 },
		},
	}, "gridShader")
	if not shader:Initialize() then
		goodbye("Failed to compile gridshader GL4 ")
		return false
	end
	gridShader = shader

	mouseFadeUniform = gl.GetUniformLocation(gridShader.shaderObj, "mouseFade")
	lineParamsUniform = gl.GetUniformLocation(gridShader.shaderObj, "lineParams")
	return true
end

-- the vertices come from gl_VertexID; the unused buffers are attached because engines without the
-- LuaVAO keep-partial fix (RecoilEngine #3446) rebuild a VAO every draw unless it has all three kinds
local function initVAO()
	local vao = gl.GetVAO()
	local vertexVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	local indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	local instanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	if not (vao and vertexVBO and indexVBO and instanceVBO) then
		return false
	end
	vertexVBO:Define(vertexCount, { { id = 0, name = "unused", size = 1 } }) -- DrawArrays checks the count against it
	indexVBO:Define(1)
	indexVBO:Upload({ 0 })
	instanceVBO:Define(1, { { id = 1, name = "unusedInstance", size = 1 } })
	instanceVBO:Upload({ 0 })
	vao:AttachVertexBuffer(vertexVBO)
	vao:AttachIndexBuffer(indexVBO)
	vao:AttachInstanceBuffer(instanceVBO)
	gridVAO = vao
	gridVAOObjects = { vao, vertexVBO, indexVBO, instanceVBO }
	return true
end

---map of reason to unitDefID
---@type table<string, number>
local forceShow = {}

local function getForceShowUnitDefID()
	-- show grid as long as any source wants us to show it (logical OR)
	local reason = next(forceShow, nil)
	return reason and forceShow[reason] or nil
end

-- unitDefID -> whether its grid sits on the water surface; modCategories builds a new table on every access
local surfaceUnitDefs = {}

local function isSurfaceUnitDef(unitDefID)
	local surface = surfaceUnitDefs[unitDefID]
	if surface == nil then
		surface = not UnitDefs[unitDefID].modCategories.underwater
		surfaceUnitDefs[unitDefID] = surface
	end
	return surface
end

function widget:Initialize()
	WG.buildinggrid = {}
	WG.buildinggrid.getOpacity = function()
		return opacity
	end
	WG.buildinggrid.setOpacity = function(value)
		opacity = value
	end
	WG.buildinggrid.setForceShow = function(reason, enabled, unitDefID)
		if enabled then
			forceShow[reason] = unitDefID
		else
			forceShow[reason] = nil
		end
	end

	if initShader() and not initVAO() then
		goodbye("Failed to create grid VAO")
	end
end

function widget:DrawWorldPreUnit()
	local showUnitDefID = getForceShowUnitDefID()
	if not showUnitDefID then
		local _, cmdID = spGetActiveCommand()
		if not cmdID or cmdID >= 0 then
			return
		end
		showUnitDefID = -cmdID
	end

	local waterSurfaceMode = isSurfaceUnitDef(showUnitDefID)

	local mx, my = spGetMouseState()
	local _, mousePos = spTraceScreenRay(mx, my, true, false, false, not waterSurfaceMode)
	if not mousePos then
		return
	end
	---@cast mousePos xyz
	local px, py, pz = mousePos[1], mousePos[2], mousePos[3]

	-- the whole grid fades out as the camera moves away from the cursor
	local cx, cy, cz = spGetCameraPosition()
	local dx, dy, dz = cx - px, cy - py, cz - pz
	local camFade = 1 - config.maxViewDistance / mathSqrt(dx * dx + dy * dy + dz * dz)
	if camFade > 0 then
		if camFade > 1 then
			camFade = 1
		end
		camFade = camFade * camFade * (3 - 2 * camFade) * 1.75
		if camFade >= 1 then
			return -- no line has any alpha left
		end
	else
		camFade = 0
	end

	glLineWidth(1.75)
	glDepthTest(GL_ALWAYS) -- so that it won't be drawn behind terrain
	glDepthMask(false) -- so that we dont write the depth of the drawn pixels
	glTexture(0, "$heightmap") -- bind engine heightmap texture to sampler 0
	gridShader:Activate()
	glUniform(mouseFadeUniform, px, py, pz, camFade)
	glUniform(
		lineParamsUniform,
		config.strongLineOpacity * opacity,
		config.weakLineOpacity * opacity,
		waterSurfaceMode and waterLevel or -1e30
	)
	gridVAO:DrawArrays(GL_LINES, vertexCount)
	gridShader:Deactivate()
	glTexture(0, false)
	glDepthTest(false)
end

function widget:GetConfigData(data)
	return {
		opacity = opacity,
	}
end

function widget:SetConfigData(data)
	opacity = data.opacity or opacity
end

function widget:Shutdown()
	if type(gridShader) == "table" then
		gridShader:Finalize()
	end
	for i = 1, #gridVAOObjects do
		gridVAOObjects[i]:Delete()
	end
	gridVAOObjects = {}
end
