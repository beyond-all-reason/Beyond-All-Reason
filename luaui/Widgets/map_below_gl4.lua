local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Map Below",
		desc = "A backdrop under the map: a planet or a cloud deck, seen through holes and past the map edge. Use WG.MapBelow",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -9998,
		enabled = true,
		depends = { "gl4" },
	}
end

-- The backdrop is not geometry: every pixel the ground left open casts a ray at a sphere
-- (planet) or a plane (clouds) at a real distance below the map, so it shifts a little
-- against the map as the camera moves. It is lit by the map's sun.

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable
local Echo = Spring.Echo

local MIN_DEPTH, MAX_DEPTH = 500, 60000
local MIN_SIZE, MAX_SIZE = 1, 30
local MAP_SIDE = math.max(Game.mapSizeX, Game.mapSizeZ)

local KINDS = {
	{ name = "", label = "None" },
	{ name = "planet", label = "Planet" },
	{ name = "clouds", label = "Clouds" },
}

-- sea, low land, high land, haze: rgb. level = share of the surface that is sea,
-- clouds = cloud cover, glow = how much the sea shines by itself, bands = gas giant
local LOOKS = {
	{
		name = "terran",
		label = "Terran",
		sea = { 0.03, 0.12, 0.30 },
		low = { 0.14, 0.28, 0.09 },
		high = { 0.46, 0.40, 0.30 },
		haze = { 0.35, 0.60, 1.00 },
		level = 0.52,
		clouds = 0.55,
		glow = 0,
		bands = 0,
	},
	{
		name = "desert",
		label = "Desert",
		sea = { 0.42, 0.25, 0.13 },
		low = { 0.70, 0.50, 0.30 },
		high = { 0.86, 0.76, 0.60 },
		haze = { 1.00, 0.70, 0.45 },
		level = 0.38,
		clouds = 0.15,
		glow = 0,
		bands = 0,
	},
	{
		name = "ice",
		label = "Ice",
		sea = { 0.08, 0.18, 0.34 },
		low = { 0.72, 0.80, 0.90 },
		high = { 1.00, 1.00, 1.00 },
		haze = { 0.60, 0.80, 1.00 },
		level = 0.44,
		clouds = 0.35,
		glow = 0,
		bands = 0,
	},
	{
		name = "lava",
		label = "Lava",
		sea = { 1.00, 0.32, 0.04 },
		low = { 0.12, 0.09, 0.08 },
		high = { 0.30, 0.25, 0.22 },
		haze = { 1.00, 0.35, 0.10 },
		level = 0.46,
		clouds = 0.10,
		glow = 1,
		bands = 0,
	},
	{
		name = "gas",
		label = "Gas giant",
		sea = { 0.55, 0.36, 0.22 },
		low = { 0.80, 0.66, 0.48 },
		high = { 0.93, 0.87, 0.74 },
		haze = { 0.95, 0.78, 0.55 },
		level = 0.30,
		clouds = 0,
		glow = 0,
		bands = 1,
	},
}
local lookByName = {}
for _, l in ipairs(LOOKS) do
	lookByName[l.name] = l
end

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
layout (location = 0) in vec4 position;
out vec2 v_ndc;
void main() {
	v_ndc = position.xy;
	// on the far plane: anything the map draws stays in front
	gl_Position = vec4(position.xy, 1.0, 1.0);
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000
//__ENGINEUNIFORMBUFFERDEFS__
uniform vec4 body;      // planet: centre xyz, radius. clouds: y of the deck in .y, reach in .w
uniform vec4 params;    // x = turn (radians), y = brightness, z = kind (0 planet, 1 clouds), w = bands
uniform vec4 surface;   // x = sea level, y = cloud cover, z = sea glow
uniform vec3 seaCol;
uniform vec3 lowCol;
uniform vec3 highCol;
uniform vec3 hazeCol;
in vec2 v_ndc;
out vec4 fragColor;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}
float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 6; i++) {
		s += a * noise(p);
		p = p * 2.03 + vec3(17.1, 3.7, 9.2);
		a *= 0.5;
	}
	return s;
}
vec3 turnY(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * v.x + s * v.z, v.y, c * v.z - s * v.x);
}

vec4 planet(vec3 ro, vec3 rd, vec3 sun) {
	vec3 oc = ro - body.xyz;
	float b = dot(oc, rd);
	vec3 perp = oc - b * rd;
	float d2 = dot(perp, perp);
	float r2 = body.w * body.w;
	if (b > 0.0) return vec4(0.0);
	if (d2 > r2) {
		// a thin glow past the limb
		float h = (sqrt(d2) - body.w) / (body.w * 0.02);
		return vec4(hazeCol, 0.55 * exp(-h * 2.5));
	}
	float t = -b - sqrt(r2 - d2);
	vec3 n = normalize(ro + rd * t - body.xyz);
	vec3 s = turnY(n, params.x);

	vec3 albedo;
	float glow = 0.0;
	if (params.w > 0.5) {
		float warp = fbm(s * 3.0) - 0.5;
		float band = fbm(vec3(0.0, s.y * 9.0 + warp * 1.6, 0.0) + s * 0.6) + (fbm(s * 24.0) - 0.5) * 0.05;
		albedo = mix(seaCol, lowCol, smoothstep(0.30, 0.50, band));
		albedo = mix(albedo, highCol, smoothstep(0.50, 0.68, band));
	} else {
		float h = fbm(s * 2.6) + (fbm(s * 21.0) - 0.5) * 0.07;
		float land = smoothstep(surface.x - 0.01, surface.x + 0.01, h);
		float up = clamp((h - surface.x) / max(1.0 - surface.x, 0.01), 0.0, 1.0);
		albedo = mix(seaCol, mix(lowCol, highCol, smoothstep(0.1, 0.55, up)), land);
		glow = surface.z * (1.0 - land);
		vec3 cs = turnY(s, 1.7 + params.x * 0.35);
		float c = fbm(cs * 4.2 + vec3(31.0)) + (fbm(cs * 30.0) - 0.5) * 0.12;
		albedo = mix(albedo, vec3(1.0), smoothstep(0.50, 0.72, c) * surface.y);
		glow *= 1.0 - smoothstep(0.50, 0.72, c) * surface.y;
	}
	float ndl = max(dot(n, sun), 0.0);
	vec3 col = albedo * (0.06 + ndl) + albedo * glow;
	// haze thickens toward the limb
	float rim = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);
	col = mix(col, hazeCol * (0.25 + ndl), rim * 0.75);
	return vec4(col, 1.0);
}

vec4 clouds(vec3 ro, vec3 rd, vec3 sun) {
	if (rd.y > -0.0005) return vec4(0.0);
	float t = (body.y - ro.y) / rd.y;
	vec3 p = ro + rd * t;
	vec2 q = p.xz / body.w;
	float d = fbm(vec3(q * 14.0 + vec2(params.x * 0.6, 0.0), params.x * 0.25));
	d += (fbm(vec3(q * 110.0, params.x * 0.5)) - 0.5) * 0.12;
	float puff = smoothstep(0.32, 0.70, d);
	float light = 0.35 + 0.65 * max(sun.y, 0.0);
	vec3 col = mix(hazeCol * 0.45, vec3(1.0), puff) * light;
	// the deck melts into the sky far away
	float far = clamp(t / (body.w * 6.0), 0.0, 1.0);
	col = mix(col, hazeCol * light, far * 0.6);
	return vec4(col, 1.0 - smoothstep(0.55, 1.0, far));
}

void main() {
	vec4 f = cameraViewProjInv * vec4(v_ndc, 1.0, 1.0);
	vec3 ro = cameraViewInv[3].xyz;
	vec3 rd = normalize(f.xyz / f.w - ro);
	vec3 sun = normalize(sunDir.xyz);
	vec4 c = (params.z < 0.5) ? planet(ro, rd, sun) : clouds(ro, rd, sun);
	if (c.a <= 0.003) discard;
	fragColor = vec4(c.rgb * params.y, c.a);
}
]]

---@type LuaShader?
local shader
local rectVAO
local state = { kind = "", look = "terran", depth = 8000, size = 8, yaw = 0, spin = 2, brightness = 1 }
local listeners = {}
local turn = 0
local lastClock = os.clock()

local function clamp(v, lo, hi, default)
	v = tonumber(v) or default
	return math.max(lo, math.min(hi, v))
end

local function changed()
	for _, fn in pairs(listeners) do
		fn()
	end
end

local MapBelow = {}

---@return { name: string, label: string }[]
function MapBelow.getKinds()
	return KINDS
end

---@return { name: string, label: string }[]
function MapBelow.getLooks()
	return LOOKS
end

---@return table state a copy, plain values only
function MapBelow.getState()
	local out = {}
	for k, v in pairs(state) do
		out[k] = v
	end
	return out
end

---Change some fields; the rest keep their value.
---@param fields table
function MapBelow.set(fields)
	if fields.kind ~= nil then
		state.kind = (fields.kind == "planet" or fields.kind == "clouds") and fields.kind or ""
	end
	if fields.look ~= nil and lookByName[fields.look] then
		state.look = fields.look
	end
	if fields.depth ~= nil then
		state.depth = clamp(fields.depth, MIN_DEPTH, MAX_DEPTH, state.depth)
	end
	if fields.size ~= nil then
		state.size = clamp(fields.size, MIN_SIZE, MAX_SIZE, state.size)
	end
	if fields.yaw ~= nil then
		state.yaw = (tonumber(fields.yaw) or 0) % 360
	end
	if fields.spin ~= nil then
		state.spin = clamp(fields.spin, -60, 60, state.spin)
	end
	if fields.brightness ~= nil then
		state.brightness = clamp(fields.brightness, 0, 3, state.brightness)
	end
	changed()
end

---@param s table? what getState returned; nil turns the backdrop off
function MapBelow.setState(s)
	state.kind = ""
	MapBelow.set(type(s) == "table" and s or {})
end

---@param key any
---@param fn function? called after every change; nil removes
function MapBelow.onChange(key, fn)
	listeners[key] = fn
end

function widget:Initialize()
	if not (LuaShader and InstanceVBOTable and InstanceVBOTable.MakeTexRectVAO) then
		widgetHandler:RemoveWidget()
		return
	end
	local fs = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", LuaShader.GetEngineUniformBufferDefs())
	shader = LuaShader({
		vertex = vsSrc,
		fragment = fs,
		uniformFloat = {
			body = { 0, 0, 0, 1 },
			params = { 0, 1, 0, 0 },
			surface = { 0.5, 0.5, 0, 0 },
			seaCol = { 0, 0, 0 },
			lowCol = { 0, 0, 0 },
			highCol = { 0, 0, 0 },
			hazeCol = { 0, 0, 0 },
		},
	}, "Map Below")
	if shader:Initialize() ~= true then
		Echo("[Map Below] shader compilation failed")
		widgetHandler:RemoveWidget()
		return
	end
	rectVAO = InstanceVBOTable.MakeTexRectVAO()
	WG.MapBelow = MapBelow
	-- an exported map carries its backdrop
	local mapFile = "mapconfig/below.lua"
	if VFS.FileExists(mapFile, VFS.MAP) then
		local ok, cfg = pcall(VFS.Include, mapFile, {}, VFS.MAP)
		if ok and type(cfg) == "table" and (tonumber(cfg.version) or 1) <= 1 then
			MapBelow.setState(cfg)
		else
			Echo("[Map Below] " .. mapFile .. " not applied: " .. tostring(ok and "bad format" or cfg))
		end
	end
end

function widget:Shutdown()
	if shader then
		shader:Finalize()
		shader = nil
	end
	if rectVAO then
		rectVAO:Delete()
		rectVAO = nil
	end
	if WG.MapBelow == MapBelow then
		WG.MapBelow = nil
	end
end

function widget:DrawWorldPreUnit()
	local now = os.clock()
	-- spin is in degrees a minute
	turn = (turn + state.spin * (now - lastClock) / 60) % 360
	lastClock = now
	if state.kind == "" or not shader then
		return
	end
	local look = lookByName[state.look] or LOOKS[1]
	-- never above the lowest ground
	local lowest = Spring.GetGroundExtremes()
	local top = -math.max(state.depth, 200 - (lowest or 0))
	local cx, cz = Game.mapSizeX * 0.5, Game.mapSizeZ * 0.5
	local reach = state.size * MAP_SIDE

	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(false)
	gl.Culling(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	shader:Activate()
	if state.kind == "planet" then
		shader:SetUniformFloat("body", cx, top - reach, cz, reach)
	else
		shader:SetUniformFloat("body", cx, top, cz, reach)
	end
	shader:SetUniformFloat(
		"params",
		math.rad(state.yaw + turn),
		state.brightness,
		state.kind == "planet" and 0 or 1,
		look.bands
	)
	shader:SetUniformFloat("surface", look.level, look.clouds, look.glow, 0)
	shader:SetUniformFloat("seaCol", look.sea[1], look.sea[2], look.sea[3])
	shader:SetUniformFloat("lowCol", look.low[1], look.low[2], look.low[3])
	shader:SetUniformFloat("highCol", look.high[1], look.high[2], look.high[3])
	shader:SetUniformFloat("hazeCol", look.haze[1], look.haze[2], look.haze[3])
	rectVAO:DrawArrays(GL.TRIANGLES)
	shader:Deactivate()
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthMask(true)
	gl.DepthTest(false)
end
