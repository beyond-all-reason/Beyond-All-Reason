-- P0 spike: proves Spring.SetMapShader activation (tileset terrain pipeline groundwork).
-- Expected result with the patched engine: terrain turns green with diagonal dark stripes.
-- On a stock engine with TEST_DEFERRED=false this silently does nothing (the forward-activation bug).

function widget:GetInfo()
	return {
		name    = "Map Shader Smoke Test",
		desc    = "Trivial Lua map shader via Spring.SetMapShader (tileset pipeline P0)",
		author  = "PtaQ",
		date    = "2026-07-14",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = false,
	}
end

-- false = forward-only (the pure engine-bugfix test), true = also install a deferred G-buffer shader
local TEST_DEFERRED = true

local fwdShader = nil
local dfrShader = nil
local echoedFwd = false
local echoedDfr = false

local vertSrc = [[
#version 130
in vec3 vertexPos;

uniform ivec2 texSquare;      // set by the engine per big square, must be ivec2
uniform vec2 specularTexGen;  // 1/mapSize in elmos, set from Lua
uniform sampler2D heightMapTex;

out vec4 vertexWorldPos;
out vec2 diffuseTexCoords;
out float fogFactor;

const float SMF_TEXSQR_SIZE = 1024.0;

float HeightAtWorldPos(vec2 wxz) {
	// texel alignment magic copied from engine SMFVertProg.glsl
	const vec2 HM_TEXEL = vec2(8.0, 8.0);
	vec2 mapSize = vec2(1.0) / specularTexGen;
	wxz += -HM_TEXEL * (wxz * specularTexGen) + 0.5 * HM_TEXEL;
	vec2 uvhm = clamp(wxz, HM_TEXEL, mapSize - HM_TEXEL);
	uvhm *= specularTexGen;
	return textureLod(heightMapTex, uvhm, 0.0).x;
}

void main() {
	vertexWorldPos = vec4(vertexPos, 1.0);
	vertexWorldPos.xz += vec2(texSquare) * SMF_TEXSQR_SIZE;
	vertexWorldPos.y = HeightAtWorldPos(vertexWorldPos.xz);

	diffuseTexCoords = (vertexWorldPos.xz / SMF_TEXSQR_SIZE) - vec2(texSquare);

	gl_Position = gl_ModelViewProjectionMatrix * vertexWorldPos;
	gl_ClipVertex = gl_ModelViewMatrix * vertexWorldPos;

	float fogCoord = length(gl_ClipVertex.xyz);
	fogFactor = clamp((gl_Fog.end - fogCoord) * gl_Fog.scale, 0.0, 1.0);
}
]]

local fragSrcForward = [[
#version 130
uniform sampler2D diffuseTex; // TU0, engine-bound SMT tile

in vec4 vertexWorldPos;
in vec2 diffuseTexCoords;
in float fogFactor;

out vec4 fragColor;

void main() {
	vec4 diffuse = texture(diffuseTex, diffuseTexCoords);
	// unmistakable: green tint + world-space diagonal stripes
	float stripe = step(0.5, fract((vertexWorldPos.x + vertexWorldPos.z) / 256.0));
	vec3 tinted = mix(diffuse.rgb * vec3(0.3, 1.2, 0.3), diffuse.rgb * 0.25, stripe * 0.5);
	fragColor = vec4(mix(gl_Fog.color.rgb, tinted, fogFactor), 1.0);
}
]]

local fragSrcDeferred = [[
#version 130
uniform sampler2D diffuseTex;

in vec4 vertexWorldPos;
in vec2 diffuseTexCoords;
in float fogFactor;

out vec4 fragData[5];

void main() {
	vec4 diffuse = texture(diffuseTex, diffuseTexCoords);
	// magenta-tinted diffuse in the G-buffer so deferred output is distinguishable
	fragData[0] = vec4(0.5, 1.0, 0.5, 1.0);            // NORMTEX: flat up, encoded (n+1)*0.5
	fragData[1] = vec4(diffuse.rgb * vec3(1.2, 0.3, 1.2), 1.0); // DIFFTEX
	fragData[2] = vec4(0.0);                            // SPECTEX
	fragData[3] = vec4(0.0);                            // EMITTEX
	fragData[4] = vec4(0.0);                            // MISCTEX
}
]]

local function makeShader(fragSrc, label)
	local shader = gl.CreateShader({
		vertex   = vertSrc,
		fragment = fragSrc,
		uniformInt = {
			diffuseTex   = 0,
			heightMapTex = 1,
		},
		uniformFloat = {
			specularTexGen = { 1.0 / Game.mapSizeX, 1.0 / Game.mapSizeZ },
		},
	})
	if not shader then
		Spring.Echo("[MapShaderSmoke] " .. label .. " shader compile FAILED:")
		Spring.Echo(gl.GetShaderLog())
	end
	return shader
end

function widget:Initialize()
	if not gl.CreateShader then
		Spring.Echo("[MapShaderSmoke] GLSL not supported, removing")
		widgetHandler:RemoveWidget(self)
		return
	end

	local advMapShading = Spring.GetConfigInt("AdvMapShading", 1)
	local allowDeferred = Spring.GetConfigInt("AllowDeferredMapRendering", 0)
	Spring.Echo("[MapShaderSmoke] AdvMapShading=" .. advMapShading .. " AllowDeferredMapRendering=" .. allowDeferred)
	if advMapShading == 0 then
		Spring.Echo("[MapShaderSmoke] WARNING: AdvMapShading=0 blocks Lua map shaders entirely (needs restart after change)")
	end
	if TEST_DEFERRED and allowDeferred == 0 then
		Spring.Echo("[MapShaderSmoke] WARNING: deferred test requested but AllowDeferredMapRendering=0 (needs restart after change)")
	end

	fwdShader = makeShader(fragSrcForward, "forward")
	if TEST_DEFERRED then
		dfrShader = makeShader(fragSrcDeferred, "deferred")
	end

	if not fwdShader then
		widgetHandler:RemoveWidget(self)
		return
	end

	Spring.SetMapShader(fwdShader, dfrShader or 0)
	Spring.Echo("[MapShaderSmoke] map shader installed (fwd=" .. tostring(fwdShader) .. " dfr=" .. tostring(dfrShader) .. ")")
	Spring.Echo("[MapShaderSmoke] expected: green striped terrain. If unchanged, forward activation failed.")
end

function widget:DrawGroundPreForward()
	if not echoedFwd then
		echoedFwd = true
		Spring.Echo("[MapShaderSmoke] DrawGroundPreForward fired -> forward Lua render state IS active")
	end
	gl.Texture(1, "$heightmap")
end

function widget:DrawGroundPostForward()
	gl.Texture(1, false)
end

function widget:DrawGroundPreDeferred()
	if not echoedDfr then
		echoedDfr = true
		Spring.Echo("[MapShaderSmoke] DrawGroundPreDeferred fired -> deferred Lua render state IS active")
	end
	gl.Texture(1, "$heightmap")
end

function widget:DrawGroundPostDeferred()
	gl.Texture(1, false)
end

function widget:Shutdown()
	-- must reset before LuaShaders programs are destroyed, else the engine render
	-- state keeps dangling GL program ids after /luaui reload
	Spring.SetMapShader(0, 0)
	if fwdShader then gl.DeleteShader(fwdShader) end
	if dfrShader then gl.DeleteShader(dfrShader) end
	Spring.Echo("[MapShaderSmoke] map shader reset to engine default")
end
