local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Outline Shader GL4",
		desc = "Draws unit outlines for other widgets (WG.unitOutlines), and optionally dark outlines around all units",
		author = "Beherith",
		date = "2022.03.05",
		license = "GNU GPL, v2 or later",
		layer = -10, -- below healthbars, above selected units gl4, before the widgets that request outlines
		enabled = true,
	}
end

-- Ported from Zero-K. Needs CUS GL4: its deferred pass marks unit pixels in $model_gbuffer_misctex with green = 1
-- and unitID + 1 in red (low byte) and blue (high byte).
-- Each outlined unit gets a camera facing quad over its model's bounding sphere, padded by the outline's reach.
--
-- WG.unitOutlines.add(owner, unitID, style) outlines a unit until remove(owner, unitID) or clear(owner). The owner is
-- any string; outlines of different owners draw on their own. Units out of view keep their outlines for when they
-- return, dead units lose them. Calling add again changes the style. Style fields, all optional:
--   color = { r, g, b, a } (black), width = solid pixels at 1080p when zoomed in (1), blur = pixels at 1080p over
--   which the outline fades out beyond that (0), scaleWithZoom = false keeps width and blur when zoomed out,
--   pulse = seconds per alpha pulse (0 = steady), fadeTime = seconds to fade in when added and out when removed (0)
-- Widths scale with the screen height, so outlines keep their thickness relative to the units.
-- WG.unitOutlines.setAllUnits(enabled) toggles the Zero-K style dark outline around every unit.

---@class OutlineConfig
---@field allUnits boolean
---@field zoomScale "subtle"|"inverse"|false
local config = {
	allUnits = false, -- dark outline around every unit
	thickness = 1.0, -- all units: outline width multiplier
	scaleRate = 2.2, -- all units: outline width in pixels at 1080p and thickness 1 when zoomed in
	zoomScale = "subtle", -- thinner outlines when zoomed out: "subtle" (cosine falloff), "inverse" (250 / height) or false
	zoomScaleMin = 0.4, -- width multiplier when zoomed out
	zoomScaleExponent = 0.7, -- shape of the "subtle" falloff
	hideWithGui = true,
}

local WIDTH_MIN = 0.1
local WIDTH_MAX = 12
local SUBTLE_MIN = 50
local SUBTLE_MAX = 3500
local OUTLINE_REACH = 1.4241 -- outline reach in pixels per pixel of width
local RADIUS_MARGIN = 1.1 -- room for animated pieces outside the model's bind pose bounds
local DEFAULT_COLOR = { 0, 0, 0, 1 }
local DEFAULT_WIDTH = 1
local REFERENCE_HEIGHT = 1080 -- screen height that widths are given for

local spGetCameraState = Spring.GetCameraState
local spGetDrawSeconds = Spring.GetDrawSeconds
local spGetGroundHeight = Spring.GetGroundHeight
local spIsGUIHidden = Spring.IsGUIHidden

local glBlending = gl.Blending
local glClear = gl.Clear
local glCulling = gl.Culling
local glDepthMask = gl.DepthMask
local glDepthTest = gl.DepthTest
local glStencilFunc = gl.StencilFunc
local glStencilMask = gl.StencilMask
local glStencilOp = gl.StencilOp
local glStencilTest = gl.StencilTest
local glTexture = gl.Texture

local GL_ALWAYS = GL.ALWAYS
local GL_KEEP = GL.KEEP
local GL_NOTEQUAL = GL.NOTEQUAL
local GL_REPLACE = GL.REPLACE
local GL_STENCIL_BUFFER_BIT = GL.STENCIL_BUFFER_BIT
local GL_TRIANGLE_STRIP = GL.TRIANGLE_STRIP

local mathCeil = math.ceil
local mathMax = math.max
local mathMin = math.min

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable
local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance = InstanceVBOTable.popElementInstance

local allUnitsShader ---@type LuaShader
local unitShader ---@type LuaShader
local allUnitsVBO ---@type InstanceVBOTable
local unitVBO ---@type InstanceVBOTable
local cornerVBO ---@type VBO
local glReady ---@type boolean?
local resolutionScale = 1 ---@type number screen height / REFERENCE_HEIGHT

local visibleUnits = {} ---@type table<UnitID, UnitDefID?> the unit tracker's table
local outlines = {} ---@type table<string, table?> instance key -> { unitID, owner, values = color, shape, timing }
local unitOutlineKeys = {} ---@type table<number, table<string, true>?> unitID -> instance keys of its outlines
local fadingOut = {} ---@type table<string, number?> instance key -> draw seconds when its fade out ends
local unitBounds = {} ---@type table<number, number[]?> unitDefID -> instance data: model space bounding sphere, instData
local instanceData = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }

local function Clamp01(x)
	if x < 0 then
		return 0.0
	elseif x > 1 then
		return 1.0
	end
	return x
end

local function GetUnitBounds(unitDefID)
	local bounds = unitBounds[unitDefID]
	if not bounds then
		local unitDef = UnitDefs[unitDefID]
		---@cast unitDef table
		local model = unitDef.model -- loads the model, which drawing the unit already did
		local hx = (model.maxx - model.minx) * 0.5
		local hy = (model.maxy - model.miny) * 0.5
		local hz = (model.maxz - model.minz) * 0.5
		bounds = {
			model.minx + hx,
			model.miny + hy,
			model.minz + hz,
			math.sqrt(hx * hx + hy * hy + hz * hz) * RADIUS_MARGIN,
			0,
			0,
			0,
			0,
		}
		unitBounds[unitDefID] = bounds
	end
	return bounds
end

local function GetCameraHeight()
	local cs = spGetCameraState()
	---@cast cs table
	local groundHeight = spGetGroundHeight(cs.px, cs.pz)
	if cs.name == "ta" or cs.name == "spring" then
		return mathMax(1, (cs.height or cs.dist) - groundHeight)
	end
	return mathMax(1, cs.py - groundHeight)
end

local function GetZoomScale()
	if not config.zoomScale then
		return 1
	end
	local height = GetCameraHeight()
	local minScale = config.zoomScaleMin
	if config.zoomScale == "subtle" then
		if height < SUBTLE_MIN then
			return 1
		elseif height > SUBTLE_MAX then
			return minScale
		end
		local t = ((height - SUBTLE_MIN) / (SUBTLE_MAX - SUBTLE_MIN)) ^ config.zoomScaleExponent
		return (math.cos(math.pi * t) + 1) * 0.5 * (1 - minScale) + minScale
	end
	return mathMin(mathMax(minScale, 250 / height), 1)
end

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack : require

#line 5000

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__
//__QUATERNIONDEFS__

layout (location = 0) in vec2 corner;
layout (location = 1) in vec4 bounds; // model space bounding sphere: center, radius
#if PER_UNIT == 1
	layout (location = 2) in vec4 color;
	layout (location = 3) in vec4 shape; // width and blur in pixels at 1080p, 1 = scale with zoom, unitID + 1
	layout (location = 4) in vec4 timing; // shown since, hidden since (-1 = shown) in draw seconds, fade seconds, pulse seconds
	layout (location = 5) in uvec4 instData;
#else
	layout (location = 2) in uvec4 instData;
#endif

struct SUniformsBuffer {
	uint composite; // u8 drawFlag; u8 unused1; u16 id;

	uint unused2;
	uint unused3;
	uint unused4;

	float maxHealth;
	float health;
	float unused5;
	float unused6;

	vec4 speed;
	vec4[5] userDefined; // can't use float[20] because float in arrays occupies 4 * float space
};

layout(std140, binding = 1) readonly buffer UniformsBuffer {
	SUniformsBuffer uni[];
};

#if USEQUATERNIONS == 0
	layout(std140, binding = 0) readonly buffer MatrixBuffer {
		mat4 UnitPieces[];
	};
#endif

#line 10000

#if PER_UNIT == 1
	uniform float zoomScale;
	uniform float resolutionScale; // screen height / 1080

	out DataVS {
		flat vec4 v_color; // alpha includes fade and pulse
		flat float v_width; // pixels
		flat float v_blur; // pixels
		flat uint v_id; // unitID + 1
	};
#else
	uniform float quadPadding; // pixels added on each side
#endif

void main()
{
	#if USEQUATERNIONS == 0
		mat4 modelMatrix = UnitPieces[instData.x];
	#else
		mat4 modelMatrix = TransformToMatrix(GetModelWorldTransform(instData.x));
	#endif

	#if PER_UNIT == 1
		float sizeScale = resolutionScale * mix(1.0, zoomScale, shape.z);
		float width = clamp(shape.x * sizeScale, 0.0, float(WIDTH_MAX));
		float blur = clamp(shape.y * sizeScale, 0.0, float(WIDTH_MAX));
		float alpha = color.a;
		if (timing.z > 0.0) {
			alpha *= clamp((timeInfo.y - timing.x) / timing.z, 0.0, 1.0);
			if (timing.y >= 0.0) {
				alpha *= 1.0 - clamp((timeInfo.y - timing.y) / timing.z, 0.0, 1.0);
			}
		}
		if (timing.w > 0.0) {
			alpha *= 0.6 + 0.4 * cos(timeInfo.y * 6.2831853 / timing.w);
		}
		v_color = vec4(color.rgb, alpha);
		v_width = width;
		v_blur = blur;
		v_id = uint(shape.w + 0.5);
		float padding = ceil(width + blur + 1.0) + 1.0; // the fragment shader's reach, plus one
	#else
		float alpha = 1.0;
		float padding = quadPadding;
	#endif

	// drawFlag bits 0-1: drawn as a model, not as an icon. A zero position means the unit entered LOS but has
	// not been drawn yet, so its matrix is not uploaded.
	if (alpha <= 0.0 || (uni[instData.y].composite & 3u) == 0u || dot(modelMatrix[3].xyz, modelMatrix[3].xyz) < 1.0) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0); // all four corners here: a degenerate quad outside the view
		return;
	}

	vec3 center = (modelMatrix * vec4(bounds.xyz, 1.0)).xyz;
	vec3 worldPos = center + (cameraViewInv[0].xyz * corner.x + cameraViewInv[1].xyz * corner.y) * bounds.w;
	gl_Position = cameraViewProj * vec4(worldPos, 1.0);
	gl_Position.xy += corner * (2.0 * padding / viewGeometry.xy) * gl_Position.w;
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack : require

#line 20000

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D modelMisc; // units: green = 1, unitID + 1 in red (low byte) and blue (high byte)

#if PER_UNIT == 1
	in DataVS {
		flat vec4 v_color;
		flat float v_width;
		flat float v_blur;
		flat uint v_id;
	};
	#define OUTLINE_WIDTH v_width
#else
	uniform float outlineWidth;
	#define OUTLINE_WIDTH outlineWidth
#endif

out vec4 fragColor;

const vec2 NEIGHBOURS[4] = vec2[4](vec2(-1.0, 0.0), vec2(1.0, 0.0), vec2(0.0, -1.0), vec2(0.0, 1.0));

bvec4 and4(bvec4 a, bvec4 b) {
	return bvec4(a.x && b.x, a.y && b.y, a.z && b.z, a.w && b.w);
}

// The pixels the outline goes around: this unit's, or any unit's, and how the outline fades with the distance
#if PER_UNIT == 1
	// solid for `width` pixels around the member pixels, then fading out over `blur` more; the last pixel antialiases
	float Reach(float width) {
		return width + v_blur + 1.0;
	}

	int SearchRadius(float width, float reach) {
		return int(ceil(reach));
	}

	float EdgeAlpha(float width) {
		return clamp(width - 1.0, 0.0, 1.0);
	}

	float OuterAlpha(float dist, float width, float reach) {
		float t = clamp((reach - dist) / (v_blur + 1.0), 0.0, 1.0);
		return v_blur > 0.0 ? t * t * (3.0 - 2.0 * t) : t;
	}

	bool IsMember(vec4 misc) {
		return all(equal(uvec2(misc.rb * 255.0 + 0.5), uvec2(v_id & 255u, v_id >> 8u)));
	}

	bvec4 GatherMembers(vec2 uv) {
		bvec4 members = equal(uvec4(textureGather(modelMisc, uv, 0) * 255.0 + 0.5), uvec4(v_id & 255u));
		if (any(members)) {
			members = and4(members, equal(uvec4(textureGather(modelMisc, uv, 2) * 255.0 + 0.5), uvec4(v_id >> 8u)));
		}
		return members;
	}
#else
	// Zero-K's falloff
	float Reach(float width) {
		return width * OUTLINE_REACH;
	}

	int SearchRadius(float width, float reach) {
		return min(int(ceil(reach)), int(ceil(width)) + 3);
	}

	float EdgeAlpha(float width) {
		return 1.0 - 1.5 / width;
	}

	float OuterAlpha(float dist, float width, float reach) {
		return 1.0 - pow(dist / reach, float(1 + int(width / 2.0)));
	}

	bool IsMember(vec4 misc) {
		return misc.g > 0.5;
	}

	bvec4 GatherMembers(vec2 uv) {
		return greaterThan(textureGather(modelMisc, uv, 1), vec4(0.5));
	}
#endif

// A member pixel counts as visible where the unit is in front of the terrain.
void main(void)
{
	float width = OUTLINE_WIDTH;
	vec2 texelSize = 1.0 / viewGeometry.xy;
	vec2 texel = floor(gl_FragCoord.xy - viewGeometry.zw);
	ivec2 itexel = ivec2(texel);

	float alpha;
	if (IsMember(texelFetch(modelMisc, itexel, 0)) && texelFetch(mapDepths, itexel, 0).x > texelFetch(modelDepths, itexel, 0).x) {
		// Visible member pixel: outline it where a neighbouring member pixel is behind the terrain
		float edge = 0.0;
		for (int i = 0; i < 4; i++) {
			vec2 uv = (texel + 0.5 + NEIGHBOURS[i]) * texelSize;
			if (IsMember(textureLod(modelMisc, uv, 0.0)) && textureLod(mapDepths, uv, 0.0).x <= textureLod(modelDepths, uv, 0.0).x) {
				edge = 1.0;
			}
		}
		alpha = edge * EdgeAlpha(width);
	} else {
		// Anything else: fade with the distance to the nearest visible member pixel within reach
		float reach = Reach(width);
		float reachSq = reach * reach;
		int radius = SearchRadius(width, reach);
		float nearestSq = reachSq; // no hit: alpha 0

		// textureGather reads a 2x2 block per tap, in the order (0, 1) (1, 1) (1, 0) (0, 0).
		// Blocks overhang the window by one texel on the high side: push those out of reach.
		for (int y = -radius; y <= radius; y += 2) {
			for (int x = -radius; x <= radius; x += 2) {
				vec4 dx = vec4(x, x + 1, x + 1, x);
				vec4 dy = vec4(y + 1, y + 1, y, y);
				vec4 distSq = mix(dx * dx + dy * dy, vec4(1e9), greaterThan(max(dx, dy), vec4(radius)));
				if (!any(lessThan(distSq, vec4(reachSq)))) continue;

				vec2 uv = (texel + vec2(x, y) + 1.0) * texelSize;
				bvec4 isMember = GatherMembers(uv);
				if (!any(isMember)) continue;

				bvec4 inFront = greaterThan(textureGather(mapDepths, uv, 0), textureGather(modelDepths, uv, 0));
				vec4 hitSq = mix(vec4(nearestSq), distSq, and4(isMember, inFront));
				nearestSq = min(nearestSq, min(min(hitSq.x, hitSq.y), min(hitSq.z, hitSq.w)));
			}
		}
		// Hits at or beyond reach give alpha <= 0, same as no hit
		alpha = OuterAlpha(sqrt(nearestSq), width, reach);
	}

	#if PER_UNIT == 1
		alpha = max(alpha, 0.0) * v_color.a;
		if (alpha <= 0.0) discard;
		fragColor = vec4(v_color.rgb, alpha);
	#else
		fragColor = vec4(0.0, 0.0, 0.0, alpha);
	#endif
}
]]

local function CreateShader(perUnit)
	local defines = LuaShader.CreateShaderDefinesString({
		USEQUATERNIONS = Engine.FeatureSupport.transformsInGL4 and "1" or "0",
		PER_UNIT = perUnit and 1 or 0,
		OUTLINE_REACH = OUTLINE_REACH,
		WIDTH_MIN = WIDTH_MIN,
		WIDTH_MAX = WIDTH_MAX,
	})
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	local shader = LuaShader({
		vertex = vsSrc
			:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
			:gsub("//__DEFINES__", defines)
			:gsub("//__QUATERNIONDEFS__", LuaShader.GetQuaternionDefs()),
		fragment = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs):gsub("//__DEFINES__", defines),
		uniformInt = {
			mapDepths = 0,
			modelDepths = 1,
			modelMisc = 2,
		},
		uniformFloat = perUnit and { zoomScale = 1, resolutionScale = 1 } or { outlineWidth = 1, quadPadding = 1 },
	}, perUnit and "Outline Shader GL4 units" or "Outline Shader GL4 all units")
	if shader:Initialize() then
		return shader
	end
end

local function CreateInstanceTable(layout, name, corners)
	local instances = InstanceVBOTable.makeInstanceVBOTable(layout, 64, name, #layout)
	if instances then
		instances:makeVAOandAttach(corners, instances.instanceVBO)
		instances.VAO = InstanceVBOTable.fillVAOSlots(instances.VAO, false, true)
	end
	return instances
end

local function InitGL()
	local allShader = CreateShader(false)
	local perUnitShader = CreateShader(true)
	local corners = gl.GetVBO(GL.ARRAY_BUFFER, false)
	if not allShader or not perUnitShader or not corners then
		return false
	end
	corners:Define(4, { { id = 0, name = "corner", size = 2 } })
	corners:Upload({ -1, -1, 1, -1, -1, 1, 1, 1 })

	local allTable = CreateInstanceTable({
		{ id = 1, name = "bounds", size = 4 },
		{ id = 2, name = "instData", size = 4, type = GL.UNSIGNED_INT },
	}, "Outline Shader GL4 all units", corners)
	local unitTable = CreateInstanceTable({
		{ id = 1, name = "bounds", size = 4 },
		{ id = 2, name = "color", size = 4 },
		{ id = 3, name = "shape", size = 4 },
		{ id = 4, name = "timing", size = 4 },
		{ id = 5, name = "instData", size = 4, type = GL.UNSIGNED_INT },
	}, "Outline Shader GL4 units", corners)
	if not allTable or not unitTable then
		return false
	end

	allUnitsShader, unitShader = allShader, perUnitShader
	allUnitsVBO, unitVBO, cornerVBO = allTable, unitTable, corners
	glReady = true
	return true
end

local function PopInstance(instances, key)
	local index = instances.instanceIDtoIndex[key] ---@type integer?
	if index then
		popElementInstance(instances, key)
	end
end

local function RebuildAllUnits()
	InstanceVBOTable.clearInstanceTable(allUnitsVBO)
	if config.allUnits then
		for unitID, unitDefID in pairs(visibleUnits) do
			pushElementInstance(allUnitsVBO, GetUnitBounds(unitDefID), unitID, true, true, unitID)
		end
		InstanceVBOTable.uploadAllElements(allUnitsVBO)
	end
end

local function PushOutline(key, entry, unitDefID, noUpload)
	local bounds = GetUnitBounds(unitDefID)
	local values = entry.values
	for i = 1, 4 do
		instanceData[i] = bounds[i]
	end
	for i = 1, 12 do
		instanceData[4 + i] = values[i]
	end
	pushElementInstance(unitVBO, instanceData, key, true, noUpload, entry.unitID)
end

local function DropOutline(key)
	local entry = outlines[key]
	if not entry then
		return
	end
	PopInstance(unitVBO, key)
	outlines[key] = nil
	fadingOut[key] = nil
	local keys = unitOutlineKeys[entry.unitID]
	keys[key] = nil
	if next(keys) == nil then
		unitOutlineKeys[entry.unitID] = nil
	end
end

local function AddOutline(owner, unitID, style)
	style = style or {}
	local key = unitID .. ":" .. owner
	local fade = style.fadeTime or 0
	local entry = outlines[key]
	local shownSince = spGetDrawSeconds() ---@type number
	if entry then
		local values = entry.values
		if fadingOut[key] then
			-- back before its fade out ended: fade in from the current alpha
			fadingOut[key] = nil
			local alpha = 1 - Clamp01((shownSince - values[10]) / values[11])
			shownSince = shownSince - alpha * fade
		else
			shownSince = values[9]
		end
	else
		entry = { unitID = unitID, owner = owner, values = {} }
		outlines[key] = entry
		local keys = unitOutlineKeys[unitID]
		if not keys then
			keys = {}
			unitOutlineKeys[unitID] = keys
		end
		keys[key] = true
	end
	local color = style.color or DEFAULT_COLOR
	local values = entry.values
	values[1], values[2], values[3], values[4] = color[1], color[2], color[3], color[4] or 1
	values[5], values[6] = style.width or DEFAULT_WIDTH, style.blur or 0
	values[7], values[8] = style.scaleWithZoom == false and 0 or 1, unitID + 1
	values[9], values[10], values[11], values[12] = shownSince, -1, fade, style.pulse or 0
	local unitDefID = visibleUnits[unitID]
	if unitDefID then
		PushOutline(key, entry, unitDefID)
	end
end

local function RemoveOutline(owner, unitID)
	local key = unitID .. ":" .. owner
	local entry = outlines[key]
	if not entry or fadingOut[key] then
		return
	end
	local values = entry.values
	local fade = values[11]
	local unitDefID = visibleUnits[unitID]
	if fade > 0 and unitDefID then
		local now = spGetDrawSeconds() ---@type number
		local alpha = Clamp01((now - values[9]) / fade)
		values[9] = now - fade -- faded in fully, so the fade out alone sets the alpha
		values[10] = mathMax(now - (1 - alpha) * fade, 0) -- >= 0 marks the fade out
		fadingOut[key] = values[10] + fade
		PushOutline(key, entry, unitDefID)
	else
		DropOutline(key)
	end
end

local function ClearOwner(owner)
	for _, entry in pairs(outlines) do
		if entry.owner == owner then
			RemoveOutline(owner, entry.unitID)
		end
	end
end

local function SetAllUnits(enabled)
	config.allUnits = enabled == true
	RebuildAllUnits()
end

function widget:VisibleUnitAdded(unitID, unitDefID)
	if config.allUnits then
		pushElementInstance(allUnitsVBO, GetUnitBounds(unitDefID), unitID, true, nil, unitID)
	end
	local keys = unitOutlineKeys[unitID]
	if keys then
		local now = spGetDrawSeconds() ---@type number
		for key in pairs(keys) do
			local entry = outlines[key]
			if entry and not fadingOut[key] then
				entry.values[9] = now -- fade in again
				PushOutline(key, entry, unitDefID)
			else
				DropOutline(key)
			end
		end
	end
end

function widget:VisibleUnitRemoved(unitID)
	if config.allUnits then
		PopInstance(allUnitsVBO, unitID)
	end
	local keys = unitOutlineKeys[unitID]
	if keys then
		for key in pairs(keys) do
			if fadingOut[key] then
				DropOutline(key)
			else
				PopInstance(unitVBO, key)
			end
		end
	end
end

function widget:VisibleUnitsChanged(extVisibleUnits)
	visibleUnits = extVisibleUnits
	RebuildAllUnits()
	InstanceVBOTable.clearInstanceTable(unitVBO)
	for key in pairs(fadingOut) do
		DropOutline(key)
	end
	for key, entry in pairs(outlines) do
		local unitDefID = visibleUnits[entry.unitID]
		if unitDefID then
			PushOutline(key, entry, unitDefID, true)
		end
	end
	InstanceVBOTable.uploadAllElements(unitVBO)
end

function widget:UnitDestroyed(unitID)
	local keys = unitOutlineKeys[unitID]
	if keys then
		for key in pairs(keys) do
			DropOutline(key)
		end
	end
end

function widget:DrawWorld()
	if next(fadingOut) then
		local now = spGetDrawSeconds() ---@type number
		for key, fadeEnd in pairs(fadingOut) do
			if now >= fadeEnd then
				DropOutline(key)
			end
		end
	end
	local allUnitsVAO, unitVAO = allUnitsVBO.VAO, unitVBO.VAO
	local allUnitsCount = config.allUnits and allUnitsVBO.usedElements or 0
	local unitCount = unitVBO.usedElements
	if
		not allUnitsVAO
		or not unitVAO
		or (allUnitsCount == 0 and unitCount == 0)
		or (config.hideWithGui and spIsGUIHidden())
	then
		return
	end
	local zoomScale = GetZoomScale()

	glTexture(0, "$map_gbuffer_zvaltex")
	glTexture(1, "$model_gbuffer_zvaltex")
	glTexture(2, "$model_gbuffer_misctex")
	glDepthTest(false)
	glDepthMask(false)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	glCulling(false)

	if allUnitsCount > 0 then
		local width = config.thickness * zoomScale * config.scaleRate * resolutionScale
		width = mathMax(WIDTH_MIN, mathMin(WIDTH_MAX, width))
		allUnitsShader:Activate()
		allUnitsShader:SetUniform("outlineWidth", width)
		allUnitsShader:SetUniform("quadPadding", mathCeil(width * OUTLINE_REACH) + 1)
		-- Quads overlap and every quad computes the same color for a pixel: only the first fragment per pixel draws
		glStencilTest(true)
		glStencilMask(1)
		glStencilFunc(GL_NOTEQUAL, 1, 1)
		glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
		allUnitsVAO:DrawArrays(GL_TRIANGLE_STRIP, 4, 0, allUnitsCount, 0)
		glClear(GL_STENCIL_BUFFER_BIT, 0)
		glStencilMask(255)
		glStencilFunc(GL_ALWAYS, 0, 255)
		glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)
		glStencilTest(false)
		allUnitsShader:Deactivate()
	end

	if unitCount > 0 then
		unitShader:Activate()
		unitShader:SetUniform("zoomScale", zoomScale)
		unitShader:SetUniform("resolutionScale", resolutionScale)
		unitVAO:DrawArrays(GL_TRIANGLE_STRIP, 4, 0, unitCount, 0)
		unitShader:Deactivate()
	end

	glTexture(0, false)
	glTexture(1, false)
	glTexture(2, false)
end

function widget:ViewResize(_, viewSizeY)
	resolutionScale = viewSizeY / REFERENCE_HEIGHT
end

function widget:GetConfigData()
	return { allUnits = config.allUnits }
end

function widget:SetConfigData(data)
	if data.allUnits ~= nil then
		config.allUnits = data.allUnits == true
	end
end

function widget:Initialize()
	if not (Platform.glHaveGL4 and LuaShader.isDeferredShadingEnabled and LuaShader.GetAdvShadingActive()) then
		Spring.Echo("Outline Shader GL4: needs GL4 and deferred rendering, removing")
		widgetHandler:RemoveWidget()
		return
	end
	if not InitGL() then
		Spring.Echo("Outline Shader GL4: failed to create the shaders or buffers, removing")
		widgetHandler:RemoveWidget()
		return
	end
	local _, viewSizeY = Spring.GetViewGeometry()
	resolutionScale = viewSizeY / REFERENCE_HEIGHT
	WG.unitOutlines = {
		add = AddOutline,
		remove = RemoveOutline,
		clear = ClearOwner,
		setAllUnits = SetAllUnits,
		getAllUnits = function()
			return config.allUnits
		end,
	}
	local unitTracker = WG.unittrackerapi ---@type table?
	if unitTracker then
		widget:VisibleUnitsChanged(unitTracker.visibleUnits)
	end
end

function widget:Shutdown()
	WG.unitOutlines = nil
	if glReady ~= nil then
		allUnitsShader:Finalize()
		unitShader:Finalize()
		allUnitsVBO:Delete()
		unitVBO:Delete()
		cornerVBO:Delete()
	end
end
