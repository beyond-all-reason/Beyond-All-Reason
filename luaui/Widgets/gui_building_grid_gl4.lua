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
        depends = {'gl4'},
    }
end

local opacity = 0.5

local config = {
	gridSize = 3, -- smallest footprint is size 1 (perimeter camera), size 3 is the size of nanos, winds, etc
	strongLineSpacing = 4, -- which interval produces heavy lines
	strongLineOpacity = 0.60, -- opacity of heavy lines
	weakLineOpacity = 0.18, -- opacity of intermediate lines
	gridRadius = 30, -- how far from the cursor the grid should show. Same units as gridSize
	gridRadiusFalloff = 2.5, -- how sharply the grid should get cut off at max distance
	maxViewDistance = 3000.0, -- distance at which the grid no longer renders
	lineColor = { 0.70, 1.0, 0.70 }, -- color of the lines
}

local waterLevel = Spring.GetWaterPlaneLevel and Spring.GetWaterPlaneLevel() or 0

local cmdShowForUnitDefID
local isPregame = Spring.GetGameFrame() == 0 and not isSpec

local gridVBO = nil -- the vertex buffer object, an array of vec2 coords
local gridVAO = nil -- the vertex array object, a way of collecting buffer objects for submission to opengl
local gridShader = nil -- the shader itself
local spacing = config.gridSize * 16 -- the repeat rate of the grid

local shaderConfig = { -- These will be replaced in the shader using #defines's
	LINECOLOR = "vec3(" .. config.lineColor[1] .. ", " .. config.lineColor[2] .. ", " .. config.lineColor[3] .. ")",
	GRIDRADIUS = config.gridRadius,
	RADIUSFALLOFF = config.gridRadiusFalloff,
	MAXVIEWDIST = config.maxViewDistance,
}


local LuaShader = gl.LuaShader


local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

layout (location = 0) in vec3 position; // xz world position, 3rd value is opacity

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

out vec4 v_worldPos;
out vec4 v_color; // this is unused, but you can pass some stuff to fragment shader from here

uniform sampler2D heightmapTex; // the heightmap texture
uniform float waterLevel;
uniform int waterSurfaceMode;

#line 11000
void main(){
	v_worldPos.xz = position.xy;
	float alpha = position.z; // sneaking in an alpha value on the position input
	vec2 uvhm = heightmapUVatWorldPos(v_worldPos.xz); // this function gets the UV coords of the heightmap texture at a world position
	v_worldPos.y = textureLod(heightmapTex, uvhm, 0.0).x;
	if (waterSurfaceMode > 0) {
		v_worldPos.y = max(waterLevel, v_worldPos.y);
	}

	v_color = vec4(LINECOLOR, alpha);
	gl_Position = cameraViewProj * vec4(v_worldPos.xyz, 1.0);  // project it into camera
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in vec4 v_worldPos;
in vec4 v_color;

out vec4 fragColor; // the output color

uniform vec3 mousePos;

void main(void) {
	float maxDist = MAXVIEWDIST;
	vec3 camPos = cameraViewInv[3].xyz;
    float dist = distance(v_worldPos.xyz, mousePos.xyz);
	// Specifiy the color of the output line
	float fadeDist = GRIDRADIUS * 16.0;
    float alpha = smoothstep(0.0, 1.0, ((fadeDist / (dist / RADIUSFALLOFF))) - RADIUSFALLOFF);
    float camDist = distance(camPos, mousePos.xyz);
    float distAlpha = smoothstep(0.0, 1.0, 1.0 - (maxDist / camDist));
	fragColor.rgba = vec4(v_color.rgb, (alpha - (distAlpha * 1.75)) * (v_color.a));
}
]]

local function goodbye(reason)
    Spring.Echo("Building Grid GL4 widget exiting with reason: " .. reason)
    widgetHandler:RemoveWidget()
end

local mousePosUniform
local waterSurfaceModeUniform

function initShader()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs() -- all the camera and other lovely stuff
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	gridShader = LuaShader({
		vertex = vsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
		fragment = fsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
		uniformInt = {
			heightmapTex = 0, -- the index of the texture uniform sampler2D
			waterSurfaceMode = 0,
		},
		uniformFloat = {
			waterLevel = waterLevel,
			mousePos = {0.0, 0.0, 0.0},
		}
	}, "gridShader")
	local shaderCompiled = gridShader:Initialize()
	if not shaderCompiled then
		goodbye("Failed to compile gridshader GL4 ")
		return
	end

	mousePosUniform = gl.GetUniformLocation(gridShader.shaderObj, "mousePos")
	waterSurfaceModeUniform = gl.GetUniformLocation(gridShader.shaderObj, "waterSurfaceMode")
end

---map of reason to unitDefID
---@type table<string, number>
local forceShow = {}

local function getForceShowUnitDefID()
	-- show grid as long as any source wants us to show it (logical OR)
	local reason = next(forceShow, nil)
	return reason and forceShow[reason] or nil
end

function widget:Initialize()
    WG['buildinggrid'] = {}
    WG['buildinggrid'].getOpacity = function()
        return opacity
    end
    WG['buildinggrid'].setOpacity = function(value)
        opacity = value
        -- widget needs reloading wholly
    end
    WG['buildinggrid'].setForceShow = function(reason, enabled, unitDefID)
        if enabled then
            forceShow[reason] = unitDefID
        else
            forceShow[reason] = nil
        end
    end

    initShader()

	if gridVBO then return end

    local VBOData = {} -- the lua array that will be uploaded to the GPU
    for row = 0, Game.mapSizeX, spacing do
        for col = 0, Game.mapSizeZ, spacing do
            if row ~= Game.mapSizeX then -- skip last

				local strength = ((col/spacing) % config.strongLineSpacing == 0 and config.strongLineOpacity or config.weakLineOpacity) * opacity
                -- vertical lines
                VBOData[#VBOData + 1] = row
                VBOData[#VBOData + 1] = col
				VBOData[#VBOData + 1] = strength
                VBOData[#VBOData + 1] = row + spacing
                VBOData[#VBOData + 1] = col
				VBOData[#VBOData + 1] = strength
            end

            if col ~= Game.mapSizeZ then -- skip last
				local strength = ((row/spacing) % config.strongLineSpacing == 0 and config.strongLineOpacity or config.weakLineOpacity) * opacity
                -- horizonal lines
                VBOData[#VBOData + 1] = row
                VBOData[#VBOData + 1] = col
				VBOData[#VBOData + 1] = strength
                VBOData[#VBOData + 1] = row
                VBOData[#VBOData + 1] = col + spacing
				VBOData[#VBOData + 1] = strength
            end
        end
    end

    gridVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	-- this is 2d position + opacity
    gridVBO:Define(#VBOData / 3, {{
        id = 0,
        name = "position",
        size = 3
    }}) -- number of elements (vertices), size is 2 for the vec2 position
    gridVBO:Upload(VBOData)
    gridVAO = gl.GetVAO()
    gridVAO:AttachVertexBuffer(gridVBO)
end


function widget:Update()
	local _, cmdID = Spring.GetActiveCommand()

	cmdShowForUnitDefID = cmdID ~= nil and cmdID < 0 and -cmdID or nil
end

function widget:DrawWorldPreUnit()
	local showUnitDefID = getForceShowUnitDefID() or cmdShowForUnitDefID
	if not showUnitDefID then
		return
	end

	local waterSurfaceMode = not UnitDefs[showUnitDefID].modCategories.underwater

	local mx, my, _ = Spring.GetMouseState()
	local _, mousePos = Spring.TraceScreenRay(mx, my, true, false, false, not waterSurfaceMode)

	if not mousePos then
		return
	end

	gl.LineWidth(1.75)
    gl.Culling(GL.BACK) -- not needed really, only for triangles
    gl.DepthTest(GL.ALWAYS) -- so that it wont be drawn behind terrain
    gl.DepthMask(false) -- so that we dont write the depth of the drawn pixels
    gl.Texture(0, "$heightmap") -- bind engine heightmap texture to sampler 0
    gridShader:Activate()
	gl.UniformInt(waterSurfaceModeUniform, waterSurfaceMode and 1 or 0)
	gl.Uniform(mousePosUniform, unpack(mousePos, 1, 3))
    gridVAO:DrawArrays(GL.LINES) -- draw the lines
    gridShader:Deactivate()
    gl.Texture(0, false)
    gl.DepthTest(false)
end

function widget:GameStart()
	isPregame = false
end

function widget:GetConfigData(data)
    return {
        opacity = opacity,
    }
end

function widget:SetConfigData(data)
    opacity = data.opacity or opacity
end
