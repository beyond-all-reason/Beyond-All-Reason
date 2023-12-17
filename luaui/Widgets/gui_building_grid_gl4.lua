function widget:GetInfo()
    return {
        name = "Building Grid GL4",
        desc = "Draw a configurable grid to assist build spacing",
        author = "Hobo Joe, Beherith, LSR",
        date = "June 2023",
        license = "GNU GPL, v2 or later",
		version = 0.2,
        layer = -1,
        enabled = false
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

local showGrid = true
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


local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir .. "LuaShader.lua")

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

#line 11000
void main(){
	v_worldPos.xz = position.xy;
	float alpha = position.z; // sneaking in an alpha value on the position input
	vec2 uvhm = heighmapUVatWorldPos(v_worldPos.xz); // this function gets the UV coords of the heightmap texture at a world position
	v_worldPos.y  = textureLod(heightmapTex, uvhm, 0.0).x;
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

void main(void) {
	float maxDist = MAXVIEWDIST;
	vec3 camPos = cameraViewInv[3].xyz;
    float dist = distance(v_worldPos.xyz, mouseWorldPos.xyz);
	// Specifiy the color of the output line
	float fadeDist = GRIDRADIUS * 16.0;
    float alpha = smoothstep(0.0, 1.0, ((fadeDist / (dist / RADIUSFALLOFF))) - RADIUSFALLOFF);
    float camDist = distance(camPos, mouseWorldPos.xyz);
    float distAlpha = smoothstep(0.0, 1.0, 1.0 - (maxDist / camDist));
	fragColor.rgba = vec4(v_color.rgb, (alpha - (distAlpha * 1.75)) * (v_color.a));
}
]]

local function goodbye(reason)
    Spring.Echo("DrawPrimitiveAtUnits GL4 widget exiting with reason: " .. reason)
    widgetHandler:RemoveWidget()
end

function initShader()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs() -- all the camera and other lovely stuff
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	gridShader = LuaShader({
		vertex = vsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
		fragment = fsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
		uniformInt = {
			heightmapTex = 0 -- the index of the texture uniform sampler2D
		},
		uniformFloat = {}
	}, "gridShader")
	local shaderCompiled = gridShader:Initialize()
	if not shaderCompiled then
		goodbye("Failed to compile gridshader GL4 ")
	end
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

    initShader()

	if gridVBO then return end

    local VBOData = {} -- the lua array that will be uploaded to the GPU
	Spring.Echo("map size is", Game.mapSizeX, Game.mapSizeZ)
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
	local _, cmdID
	if isPregame and WG['pregame-build'] and WG['pregame-build'].getPreGameDefID then
		cmdID = WG['pregame-build'].getPreGameDefID()
		cmdID = cmdID and -cmdID or 0 --invert to get the correct negative value
	else
		_, cmdID = Spring.GetActiveCommand()
	end

	showGrid = cmdID and cmdID < 0 or false
end

function widget:DrawWorldPreUnit()
	if not showGrid then return end
	gl.LineWidth(1.75)
    gl.Culling(GL.BACK) -- not needed really, only for triangles
    gl.DepthTest(GL.ALWAYS) -- so that it wont be drawn behind terrain
    gl.DepthMask(false) -- so that we dont write the depth of the drawn pixels
    gl.Texture(0, "$heightmap") -- bind engine heightmap texture to sampler 0
    gridShader:Activate()
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
