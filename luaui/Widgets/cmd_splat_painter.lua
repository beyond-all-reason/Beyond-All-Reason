local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Splat Painter",
		desc = "Paint terrain splat distribution textures (DNTS) as a new mode in the terraform brush panel",
		author = "BARb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Engine API locals
local GetMouseState = Spring.GetMouseState
local TraceScreenRay = Spring.TraceScreenRay
local GetGroundHeight = Spring.GetGroundHeight
local GetGroundNormal = Spring.GetGroundNormal
local Echo = Spring.Echo
local SetMapShadingTexture = Spring.SetMapShadingTexture

local glCreateTexture = gl.CreateTexture
local glDeleteTexture = gl.DeleteTexture
local glTexture = gl.Texture
local glRenderToTexture = gl.RenderToTexture
local glCreateShader = gl.CreateShader
local glDeleteShader = gl.DeleteShader
local glUseShader = gl.UseShader
local glUniform = gl.Uniform
local glUniformInt = gl.UniformInt
local glGetUniformLocation = gl.GetUniformLocation
local glTexRect = gl.TexRect
local glColor = gl.Color
local glBlending = gl.Blending
local glSaveImage = gl.SaveImage
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glLineWidth = gl.LineWidth
local glDrawGroundCircle = gl.DrawGroundCircle
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glPolygonOffset = gl.PolygonOffset
local glDepthTest    = gl.DepthTest
local glTexCoord     = gl.TexCoord
local GL_TRIANGLES   = GL.TRIANGLES
local GL_LINE_LOOP   = GL.LINE_LOOP
local GL_LINES       = GL.LINES

local floor = math.floor
local max = math.max
local min = math.min
local cos = math.cos
local sin = math.sin
local abs = math.abs
local pi = math.pi
local sqrt = math.sqrt

-- Constants
local SPLAT_TEX_NAME = "$ssmf_splat_distr"
local CIRCLE_SEGMENTS = 64
local MIN_RADIUS = 8
local MAX_RADIUS = 2000
local RADIUS_STEP = 8
local MIN_STRENGTH = 0.01
local MAX_STRENGTH = 1.0
local STRENGTH_STEP = 0.01
local DEFAULT_STRENGTH = 0.15
local DEFAULT_RADIUS = 100
local DEFAULT_CURVE = 1.0
local MIN_CURVE = 0.1
local MAX_CURVE = 5.0
local CURVE_STEP = 0.1
local DEFAULT_INTENSITY = 1.0
local MIN_INTENSITY = 0.1
local MAX_INTENSITY = 10.0
local INTENSITY_STEP = 0.1
local FALLOFF_DISPLAY_HEIGHT = 60
local GRID_STEP = 24 -- elmos between smart-filter sample points

-- Shapes (reuse from terraform brush)
local SHAPES = { "circle", "square", "triangle", "hexagon", "octagon" }

-- State
local active = false
local activeChannel = 1 -- 1=R, 2=G, 3=B, 4=A
local activeStrength = DEFAULT_STRENGTH
local activeIntensity = DEFAULT_INTENSITY
local activeRadius = DEFAULT_RADIUS
local activeShape = "circle"
local activeRotation = 0
local activeCurve = DEFAULT_CURVE
local eraseMode = false

-- Export format state
local EXPORT_FORMATS = { "png", "tga", "bmp" }
local exportFormatIndex = 1

-- Geo decal state
local geoDecalMode = false
local GEO_DECAL_TEX_PATH = "unittextures/decals/armageo_aoplane.dds"
local GEO_DECAL_SIZE = 176 -- 11 footprint * 16 elmos
local placedGeoDecals = {} -- array of {x=, z=, rot=, size=}

-- Smart filter state
local smartFilterEnabled = false
local smartFilter = {
	avoidWater = false,
	avoidCliffs = false,
	slopeMax = 45,
	preferSlopes = false,
	slopeMin = 10,
	altMinEnable = false,
	altMin = 0,
	altMaxEnable = false,
	altMax = 200,
}

-- Texture state
local splatTexWidth = 0
local splatTexHeight = 0
local fboTex = nil
local texApplied = false

-- Paint shader
local paintShader = nil
local uLocBrushPos = nil
local uLocBrushRadius = nil
local uLocBrushStrength = nil
local uLocBrushChannel = nil
local uLocBrushErase = nil
local uLocTexSize = nil
local uLocMapSize = nil
local uLocBrushCurve = nil
local uLocBrushShape = nil
local uLocBrushRotation = nil

-- Copy shader (blit existing texture into FBO)
local copyShader = nil

-- Splatmap overlay shader (channel-colorized world overlay)
local overlayShader = nil

-- Overlay state
local showSplatOverlay = false

-- Drawing
local drawCacheList = nil
local leftMouseHeld = false
local lastPaintX = nil
local lastPaintZ = nil

-- Deferred init: GL calls can only happen inside Draw call-ins
local pendingInit = false
local pendingPaintStrokes = {}
local pendingSave = false

-- Undo/redo history (texture snapshots per drag)
local MAX_UNDO_SPLAT = 20
local undoStack = {}
local redoStack = {}
local pendingSnapshot = false  -- set on MousePress, consumed before first stroke
local pendingUndoCount = 0
local pendingRedoCount = 0

-- Shape index mapping for shader
local SHAPE_INDEX = {
	circle = 0,
	square = 1,
	triangle = 2,
	hexagon = 3,
	octagon = 4,
}

local function invalidateDrawCache()
	if drawCacheList then
		glDeleteList(drawCacheList)
		drawCacheList = nil
	end
end

local function getWorldMousePosition()
	local mx, my = GetMouseState()
	local _, pos = TraceScreenRay(mx, my, true)
	if pos then
		return pos[1], pos[3]
	end
	return nil, nil
end

-- Smart filter: check if a world position is valid for painting
local function isPointValid(px, pz)
	if not smartFilterEnabled then return true end
	local sf = smartFilter

	local groundHeight = GetGroundHeight(px, pz)

	-- Avoid water
	if sf.avoidWater and groundHeight < 0 then
		return false
	end

	-- Slope checks
	local nx, ny, nz = GetGroundNormal(px, pz)
	if nx then
		if sf.avoidCliffs then
			local cosMax = cos(sf.slopeMax * pi / 180)
			if ny < cosMax then return false end
		end
		if sf.preferSlopes then
			local cosMin = cos(sf.slopeMin * pi / 180)
			if ny > cosMin then return false end
		end
	end

	-- Altitude checks
	if sf.altMinEnable and groundHeight < sf.altMin then
		return false
	end
	if sf.altMaxEnable and groundHeight > sf.altMax then
		return false
	end

	return true
end

-- ============ SHADER CODE ============

local PAINT_VERT_SRC = [[
	#version 130
	void main() {
		gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
		gl_TexCoord[0] = gl_MultiTexCoord0;
	}
]]

local PAINT_FRAG_SRC = [[
	#version 130
	uniform sampler2D tex0;       // current splat distribution
	uniform sampler2D heightMap;  // engine heightmap ($heightmap)
	uniform vec2 brushPos;        // brush center in map world coords
	uniform float brushRadius;    // brush radius in world coords
	uniform float brushStrength;  // paint strength 0..1
	uniform int brushChannel;     // 0=R, 1=G, 2=B, 3=A
	uniform int brushErase;       // 1 = erase mode
	uniform vec2 texSize;         // splat texture dimensions
	uniform vec2 mapSize;         // map world size
	uniform float brushCurve;     // falloff exponent
	uniform int brushShape;       // 0=circle, 1=square, 2=triangle, 3=hexagon, 4=octagon
	uniform float brushRotation;  // rotation in radians

	// Smart-filter uniforms
	uniform int sfEnabled;
	uniform int sfAvoidWater;
	uniform int sfAvoidCliffs;
	uniform float sfSlopeMax;     // degrees
	uniform int sfPreferSlopes;
	uniform float sfSlopeMin;     // degrees
	uniform int sfAltMinEnable;
	uniform float sfAltMin;
	uniform int sfAltMaxEnable;
	uniform float sfAltMax;

	// ------ smart-filter helpers ------
	float sampleHeight(vec2 uv) {
		return texture2D(heightMap, uv).x;
	}

	bool passesSmartFilter(vec2 uv) {
		if (sfEnabled == 0) return true;

		float h = sampleHeight(uv);

		// Water
		if (sfAvoidWater == 1 && h < 0.0) return false;

		// Altitude caps
		if (sfAltMinEnable == 1 && h < sfAltMin) return false;
		if (sfAltMaxEnable == 1 && h > sfAltMax) return false;

		// Slope (compute normal from heightmap finite-differences)
		if (sfAvoidCliffs == 1 || sfPreferSlopes == 1) {
			// One heightmap texel in UV space
			vec2 hmTexel = 1.0 / vec2(textureSize(heightMap, 0));
			float hL = sampleHeight(uv + vec2(-hmTexel.x, 0.0));
			float hR = sampleHeight(uv + vec2( hmTexel.x, 0.0));
			float hD = sampleHeight(uv + vec2(0.0, -hmTexel.y));
			float hU = sampleHeight(uv + vec2(0.0,  hmTexel.y));

			// World distance between adjacent heightmap samples
			vec2 cellSize = mapSize * hmTexel;
			vec3 normal = normalize(vec3(hL - hR, 2.0 * cellSize.x, hD - hU));
			float ny = normal.y;

			if (sfAvoidCliffs == 1) {
				float cosMax = cos(sfSlopeMax * 3.14159265 / 180.0);
				if (ny < cosMax) return false;
			}
			if (sfPreferSlopes == 1) {
				float cosMin = cos(sfSlopeMin * 3.14159265 / 180.0);
				if (ny > cosMin) return false;
			}
		}

		return true;
	}

	void main() {
		vec2 uv = gl_TexCoord[0].st;
		vec4 current = texture2D(tex0, uv);

		// Convert UV to world position
		vec2 worldPos = uv * mapSize;

		// Vector from brush center to this pixel
		vec2 delta = worldPos - brushPos;

		// Apply rotation
		float cr = cos(-brushRotation);
		float sr = sin(-brushRotation);
		vec2 rotDelta = vec2(
			delta.x * cr - delta.y * sr,
			delta.x * sr + delta.y * cr
		);

		// Compute distance based on shape
		float dist = 0.0;
		if (brushShape == 0) {
			// Circle
			dist = length(rotDelta) / brushRadius;
		} else if (brushShape == 1) {
			// Square
			dist = max(abs(rotDelta.x), abs(rotDelta.y)) / brushRadius;
		} else if (brushShape == 2) {
			// Triangle (equilateral, apex at -Z = north, matches outline)
			vec2 p = rotDelta / brushRadius;
			// Negate p.y so apex points toward -Z (north) matching the visual outline
			float py = -p.y - 0.333333;
			// Half-plane distances for equilateral triangle
			float d1 = -py - 0.5;                              // south edge
			float d2 =  0.866025 * p.x + 0.5 * py - 0.5;      // lower-right edge
			float d3 = -0.866025 * p.x + 0.5 * py - 0.5;      // lower-left edge
			dist = max(max(d1, d2), d3) + 1.0;
		} else if (brushShape == 3) {
			// Hexagon
			vec2 a = abs(rotDelta) / brushRadius;
			dist = max(a.x * 0.866025 + a.y * 0.5, a.y);
		} else if (brushShape == 4) {
			// Octagon
			vec2 a = abs(rotDelta) / brushRadius;
			float oct = 0.4142136 * (a.x + a.y);
			dist = max(max(a.x, a.y), oct);
		}

		if (dist >= 1.0) {
			gl_FragColor = current;
			return;
		}

		// Smart filter: reject pixels that fail terrain checks
		if (!passesSmartFilter(uv)) {
			gl_FragColor = current;
			return;
		}

		// Falloff
		float falloff = 1.0 - pow(dist, brushCurve);
		float amount = brushStrength * falloff;

		vec4 result = current;
		if (brushErase == 1) {
			// Erase: reduce selected channel
			result[brushChannel] = max(0.0, result[brushChannel] - amount);
		} else {
			// Paint: increase selected channel, optionally reduce others
			result[brushChannel] = min(1.0, result[brushChannel] + amount);
			// Normalize so channels sum to ~1 (keeps weights balanced)
			float total = result.r + result.g + result.b + result.a;
			if (total > 1.0) {
				float excess = total - 1.0;
				// Reduce other channels proportionally
				for (int i = 0; i < 4; i++) {
					if (i != brushChannel) {
						float share = result[i] / (total - result[brushChannel]);
						result[i] = max(0.0, result[i] - excess * share);
					}
				}
			}
		}

		gl_FragColor = result;
	}
]]

local COPY_FRAG_SRC = [[
	#version 130
	uniform sampler2D tex0;
	void main() {
		gl_FragColor = texture2D(tex0, gl_TexCoord[0].st);
	}
]]

-- Overlay fragment shader: maps R/G/B/A splatmap channels to distinct indicator colors
local OVERLAY_FRAG_SRC = [[
	#version 130
	uniform sampler2D tex0;  // splatmap RGBA (ch1=R, ch2=G, ch3=B, ch4=A)
	void main() {
		vec4 sp = texture2D(tex0, gl_TexCoord[0].st);
		vec3 c = sp.r * vec3(1.0,  0.15, 0.15)   // ch1 = red
		       + sp.g * vec3(0.15, 1.0,  0.15)   // ch2 = green
		       + sp.b * vec3(0.2,  0.45, 1.0)    // ch3 = blue
		       + sp.a * vec3(1.0,  0.85, 0.1);   // ch4 = yellow
		float alpha = clamp(sp.r + sp.g + sp.b + sp.a, 0.0, 1.0) * 0.55;
		gl_FragColor = vec4(c, alpha);
	}
]]

local function createShaders()
	paintShader = glCreateShader({
		vertex = PAINT_VERT_SRC,
		fragment = PAINT_FRAG_SRC,
		uniformInt = {
			tex0 = 0,
			heightMap = 1,
		},
	})
	if not paintShader then
		Echo("[Splat Painter] Failed to create paint shader: " .. tostring(gl.GetShaderLog()))
		return false
	end

	uLocBrushPos = glGetUniformLocation(paintShader, "brushPos")
	uLocBrushRadius = glGetUniformLocation(paintShader, "brushRadius")
	uLocBrushStrength = glGetUniformLocation(paintShader, "brushStrength")
	uLocBrushChannel = glGetUniformLocation(paintShader, "brushChannel")
	uLocBrushErase = glGetUniformLocation(paintShader, "brushErase")
	uLocTexSize = glGetUniformLocation(paintShader, "texSize")
	uLocMapSize = glGetUniformLocation(paintShader, "mapSize")
	uLocBrushCurve = glGetUniformLocation(paintShader, "brushCurve")
	uLocBrushShape = glGetUniformLocation(paintShader, "brushShape")
	uLocBrushRotation = glGetUniformLocation(paintShader, "brushRotation")
	-- Smart filter uniform locations
	uLocSfEnabled     = glGetUniformLocation(paintShader, "sfEnabled")
	uLocSfAvoidWater  = glGetUniformLocation(paintShader, "sfAvoidWater")
	uLocSfAvoidCliffs = glGetUniformLocation(paintShader, "sfAvoidCliffs")
	uLocSfSlopeMax    = glGetUniformLocation(paintShader, "sfSlopeMax")
	uLocSfPreferSlopes = glGetUniformLocation(paintShader, "sfPreferSlopes")
	uLocSfSlopeMin    = glGetUniformLocation(paintShader, "sfSlopeMin")
	uLocSfAltMinEnable = glGetUniformLocation(paintShader, "sfAltMinEnable")
	uLocSfAltMin      = glGetUniformLocation(paintShader, "sfAltMin")
	uLocSfAltMaxEnable = glGetUniformLocation(paintShader, "sfAltMaxEnable")
	uLocSfAltMax      = glGetUniformLocation(paintShader, "sfAltMax")

	copyShader = glCreateShader({
		vertex = PAINT_VERT_SRC,
		fragment = COPY_FRAG_SRC,
		uniformInt = {
			tex0 = 0,
		},
	})
	if not copyShader then
		Echo("[Splat Painter] Failed to create copy shader: " .. tostring(gl.GetShaderLog()))
		return false
	end

	overlayShader = glCreateShader({
		vertex = PAINT_VERT_SRC,
		fragment = OVERLAY_FRAG_SRC,
		uniformInt = {
			tex0 = 0,
		},
	})
	if not overlayShader then
		Echo("[Splat Painter] Failed to create overlay shader: " .. tostring(gl.GetShaderLog()))
		return false
	end

	return true
end

local function destroyShaders()
	if paintShader then
		glDeleteShader(paintShader)
		paintShader = nil
	end
	if copyShader then
		glDeleteShader(copyShader)
		copyShader = nil
	end
	if overlayShader then
		glDeleteShader(overlayShader)
		overlayShader = nil
	end
end

-- ============ TEXTURE MANAGEMENT ============

local function initSplatTexture()
	-- Get dimensions of existing splat distribution texture
	local texInfo = gl.TextureInfo(SPLAT_TEX_NAME)
	if not texInfo or texInfo.xsize <= 0 or texInfo.ysize <= 0 then
		Echo("[Splat Painter] Could not query splat distribution texture dimensions. Map may not have SSMF splat textures.")
		return false
	end

	splatTexWidth = texInfo.xsize
	splatTexHeight = texInfo.ysize

	Echo("[Splat Painter] Splat texture size: " .. splatTexWidth .. "x" .. splatTexHeight)

	-- Create FBO texture at matching size
	fboTex = glCreateTexture(splatTexWidth, splatTexHeight, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL.RGBA8,
	})

	if not fboTex then
		Echo("[Splat Painter] Failed to create FBO texture")
		return false
	end

	-- Copy existing splat distribution into our FBO
	glRenderToTexture(fboTex, function()
		glBlending(false)

		glUseShader(copyShader)
		glTexture(0, SPLAT_TEX_NAME)
		glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		glTexture(0, false)
		glUseShader(0)

		glBlending(true)
	end)

	-- Apply our FBO as the new splat distribution
	local ok = SetMapShadingTexture(SPLAT_TEX_NAME, fboTex)
	if not ok then
		Echo("[Splat Painter] Warning: SetMapShadingTexture failed. Splat painting may not be visible.")
	end
	texApplied = true

	return true
end

local function destroySplatTexture()
	if texApplied then
		-- Restore original by passing empty string
		SetMapShadingTexture(SPLAT_TEX_NAME, "")
		texApplied = false
	end
	if fboTex then
		glDeleteTexture(fboTex)
		fboTex = nil
	end
end

-- ============ PAINT OPERATION ============

local function paintBrushStroke(worldX, worldZ, rotDeg)
	if not paintShader then return end

	-- Queue stroke for execution in DrawWorld where GL context is available
	pendingPaintStrokes[#pendingPaintStrokes + 1] = { worldX, worldZ, rotDeg or activeRotation }
end

-- Paint at a world point, integrating TerraformBrush grid-snap, angle-snap,
-- and symmetric-position fan-out when those instruments are active.
local function paintAtSymmetric(worldX, worldZ)
	local tb = WG.TerraformBrush
	local rot = activeRotation
	if tb and tb.getState then
		local st = tb.getState()
		-- Protractor: use shared snap angle if active
		if st.angleSnap then
			rot = st.rotationDeg or rot
		end
		-- Grid snap
		if st.gridSnap and tb.snapWorld then
			worldX, worldZ = tb.snapWorld(worldX, worldZ, rot)
		end
		-- Symmetric fan-out
		if st.symmetryActive and tb.getSymmetricPositions then
			local positions = tb.getSymmetricPositions(worldX, worldZ, rot)
			if positions and #positions > 0 then
				for _, p in ipairs(positions) do
					paintBrushStroke(p.x, p.z, p.rot or rot)
				end
				return
			end
		end
	end
	paintBrushStroke(worldX, worldZ, rot)
end

-- Actually execute a paint stroke (must be called from a Draw call-in)
local function executePaintStroke(worldX, worldZ, rotDeg)
	if not fboTex or not paintShader then return end
	rotDeg = rotDeg or activeRotation

	-- We need a second FBO to ping-pong (read from current, write to new)
	local tempTex = glCreateTexture(splatTexWidth, splatTexHeight, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL.RGBA8,
	})

	if not tempTex then return end

	glRenderToTexture(tempTex, function()
		glBlending(false)

		glUseShader(paintShader)

		-- Bind current splat texture as source
		glTexture(0, fboTex)
		-- Bind engine heightmap for smart-filter slope / altitude checks
		glTexture(1, "$heightmap")

		-- Set uniforms
		glUniform(uLocBrushPos, worldX, worldZ)
		glUniform(uLocBrushRadius, activeRadius)
		glUniform(uLocBrushStrength, activeStrength * activeIntensity)
		glUniformInt(uLocBrushChannel, activeChannel - 1) -- 0-indexed for shader
		glUniformInt(uLocBrushErase, eraseMode and 1 or 0)
		glUniform(uLocTexSize, splatTexWidth, splatTexHeight)
		glUniform(uLocMapSize, Game.mapSizeX, Game.mapSizeZ)
		glUniform(uLocBrushCurve, activeCurve)
		glUniformInt(uLocBrushShape, SHAPE_INDEX[activeShape] or 0)
		glUniform(uLocBrushRotation, rotDeg * pi / 180)

		-- Smart filter uniforms
		local sf = smartFilter
		glUniformInt(uLocSfEnabled, smartFilterEnabled and 1 or 0)
		glUniformInt(uLocSfAvoidWater, sf.avoidWater and 1 or 0)
		glUniformInt(uLocSfAvoidCliffs, sf.avoidCliffs and 1 or 0)
		glUniform(uLocSfSlopeMax, sf.slopeMax)
		glUniformInt(uLocSfPreferSlopes, sf.preferSlopes and 1 or 0)
		glUniform(uLocSfSlopeMin, sf.slopeMin)
		glUniformInt(uLocSfAltMinEnable, sf.altMinEnable and 1 or 0)
		glUniform(uLocSfAltMin, sf.altMin)
		glUniformInt(uLocSfAltMaxEnable, sf.altMaxEnable and 1 or 0)
		glUniform(uLocSfAltMax, sf.altMax)

		-- Draw fullscreen quad
		glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)

		glTexture(1, false)
		glTexture(0, false)
		glUseShader(0)
		glBlending(true)
	end)

	-- Copy result back to main FBO
	glRenderToTexture(fboTex, function()
		glBlending(false)
		glUseShader(copyShader)
		glTexture(0, tempTex)
		glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		glTexture(0, false)
		glUseShader(0)
		glBlending(true)
	end)

	glDeleteTexture(tempTex)

	-- Re-apply to engine
	if texApplied then
		SetMapShadingTexture(SPLAT_TEX_NAME, fboTex)
	end
end

-- ============ SAVE / EXPORT ============

-- Execute the actual save (must be called from a Draw call-in)
local function executeSaveSplats()
	if not fboTex then return end

	local ext = EXPORT_FORMATS[exportFormatIndex] or "png"
	local SPLATS_DIR = "Terraform Brush/Splats/"
	Spring.CreateDir(SPLATS_DIR)
	local filename = SPLATS_DIR .. "splat_export_" .. Game.mapName .. "." .. ext

	glRenderToTexture(fboTex, function()
		glSaveImage(0, 0, splatTexWidth, splatTexHeight, filename, { yflip = false })
	end)

	Echo("[Splat Painter] Saved splat distribution to: " .. filename .. " (" .. splatTexWidth .. "x" .. splatTexHeight .. ")")
end

-- Public API: always defers to DrawWorld
local function requestSaveSplats()
	if not fboTex and not active then
		Echo("[Splat Painter] No splat texture to save")
		return
	end
	pendingSave = true
end

-- ============ GEO DECAL PLACEMENT ============

local function placeGeoDecal(worldX, worldZ)
	local halfSize = GEO_DECAL_SIZE * 0.5
	placedGeoDecals[#placedGeoDecals + 1] = {
		x = worldX,
		z = worldZ,
		rot = activeRotation * pi / 180,
		size = halfSize,
	}
	Echo("[Splat Painter] Placed geo decal #" .. #placedGeoDecals .. " at (" .. floor(worldX) .. ", " .. floor(worldZ) .. ")")
end

local function undoGeoDecal()
	if #placedGeoDecals == 0 then
		Echo("[Splat Painter] No geo decals to undo")
		return
	end
	placedGeoDecals[#placedGeoDecals] = nil
	Echo("[Splat Painter] Undid geo decal, " .. #placedGeoDecals .. " remaining")
end

-- ============ UNDO/REDO ============

-- Must be called from a Draw call-in (uses GL)
local function takeSnapshot()
	if not fboTex then return end
	local snapTex = glCreateTexture(splatTexWidth, splatTexHeight, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL.RGBA8,
	})
	if not snapTex then return end
	glRenderToTexture(snapTex, function()
		glBlending(false)
		glUseShader(copyShader)
		glTexture(0, fboTex)
		glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		glTexture(0, false)
		glUseShader(0)
		glBlending(true)
	end)
	-- Trim oldest entries before pushing
	while #undoStack >= MAX_UNDO_SPLAT do
		glDeleteTexture(table.remove(undoStack, 1))
	end
	undoStack[#undoStack + 1] = snapTex
	-- Clear redo on new paint action
	for _, t in ipairs(redoStack) do glDeleteTexture(t) end
	redoStack = {}
end

local function splatUndo()
	pendingUndoCount = pendingUndoCount + 1
end

local function splatRedo()
	pendingRedoCount = pendingRedoCount + 1
end

local function clearGeoDecals()
	for i = #placedGeoDecals, 1, -1 do
		placedGeoDecals[i] = nil
	end
	Echo("[Splat Painter] Cleared all geo decals")
end

local function setGeoDecalMode(enabled)
	geoDecalMode = enabled
	invalidateDrawCache()
end

local function setGeoDecalSize(size)
	GEO_DECAL_SIZE = max(16, min(512, size))
	invalidateDrawCache()
end

-- ============ STATE / API ============

local function getState()
	return {
		active = active,
		channel = activeChannel,
		strength = activeStrength,
		intensity = activeIntensity,
		radius = activeRadius,
		shape = activeShape,
		rotationDeg = activeRotation,
		curve = activeCurve,
		eraseMode = eraseMode,
		exportFormat = EXPORT_FORMATS[exportFormatIndex],
		smartEnabled = smartFilterEnabled,
		smartFilters = smartFilter,
		splatTexWidth = splatTexWidth,
		splatTexHeight = splatTexHeight,
		geoDecalMode = geoDecalMode,
		geoDecalSize = GEO_DECAL_SIZE,
		geoDecalCount = #placedGeoDecals,
		undoCount = #undoStack,
		redoCount = #redoStack,
		showSplatOverlay = showSplatOverlay,
	}
end

local function setSplatOverlay(enabled)
	showSplatOverlay = enabled and true or false
end

local function activateSplat()
	if active then return end

	-- Shaders can be created outside Draw call-ins
	if not paintShader then
		if not createShaders() then
			Echo("[Splat Painter] Shader creation failed, cannot activate")
			return
		end
	end

	active = true

	-- If FBO not yet created, defer GL init to DrawWorld where GL context is available
	if not fboTex then
		pendingInit = true
	end

	Echo("[Splat Painter] Activated | Channel: " .. activeChannel .. " | Hold left-click to paint, right-click to erase")
end

local function deactivateSplat()
	if not active then return end
	active = false
	leftMouseHeld = false
	lastPaintX = nil
	lastPaintZ = nil
	invalidateDrawCache()
end

local function setChannel(ch)
	ch = max(1, min(4, ch))
	activeChannel = ch
	invalidateDrawCache()
end

local function setStrength(s)
	activeStrength = max(MIN_STRENGTH, min(MAX_STRENGTH, s))
end

local function setIntensity(i)
	activeIntensity = max(MIN_INTENSITY, min(MAX_INTENSITY, i))
end

local function setRadius(r)
	activeRadius = max(MIN_RADIUS, min(MAX_RADIUS, floor(r)))
	invalidateDrawCache()
end

local function setShape(s)
	for _, v in ipairs(SHAPES) do
		if v == s then
			activeShape = s
			invalidateDrawCache()
			return
		end
	end
end

local function setRotation(deg)
	activeRotation = deg % 360
	invalidateDrawCache()
end

local function rotateBy(delta)
	setRotation(activeRotation + delta)
end

local function setCurve(c)
	activeCurve = max(MIN_CURVE, min(MAX_CURVE, c))
	invalidateDrawCache()
end

local function setEraseMode(enabled)
	eraseMode = enabled
end

local function cycleExportFormat()
	exportFormatIndex = (exportFormatIndex % #EXPORT_FORMATS) + 1
end

local function setExportFormat(fmt)
	for i, v in ipairs(EXPORT_FORMATS) do
		if v == fmt then
			exportFormatIndex = i
			return
		end
	end
end

local function setSmartEnabled(enabled)
	smartFilterEnabled = enabled
end

local function setSmartFilter(key, val)
	if smartFilter[key] ~= nil then
		smartFilter[key] = val
	end
end

-- ============ WIDGET CALLBACKS ============

function widget:Initialize()
	widgetHandler:AddAction("splatpaint", function()
		if active then
			deactivateSplat()
		else
			activateSplat()
		end
	end, nil, "t")
	widgetHandler:AddAction("splatpaintoff", deactivateSplat, nil, "t")
	widgetHandler:AddAction("splatexport", requestSaveSplats, nil, "t")

	WG.SplatPainter = {
		getState = getState,
		activate = activateSplat,
		deactivate = deactivateSplat,
		setChannel = setChannel,
		setStrength = setStrength,
		setIntensity = setIntensity,
		setRadius = setRadius,
		setShape = setShape,
		setRotation = setRotation,
		rotate = rotateBy,
		setCurve = setCurve,
		setEraseMode = setEraseMode,
		setSmartEnabled = setSmartEnabled,
		setSmartFilter = setSmartFilter,
		saveSplats = requestSaveSplats,
		cycleExportFormat = cycleExportFormat,
		setExportFormat = setExportFormat,
		setGeoDecalMode = setGeoDecalMode,
		setSplatOverlay = setSplatOverlay,
		setGeoDecalSize = setGeoDecalSize,
		placeGeoDecal = placeGeoDecal,
		undoGeoDecal = undoGeoDecal,
		clearGeoDecals = clearGeoDecals,
		undo = splatUndo,
		redo = splatRedo,
	}
end

function widget:Shutdown()
	invalidateDrawCache()
	destroySplatTexture()
	destroyShaders()
	-- Free undo/redo snapshot textures
	for _, t in ipairs(undoStack) do glDeleteTexture(t) end
	undoStack = {}
	for _, t in ipairs(redoStack) do glDeleteTexture(t) end
	redoStack = {}
	widgetHandler:RemoveAction("splatpaint")
	widgetHandler:RemoveAction("splatpaintoff")
	widgetHandler:RemoveAction("splatexport")
	WG.SplatPainter = nil
end

function widget:MousePress(mx, my, button)
	if not active then return false end

	-- Defer to measure / height-sampler tools when active so splat paint doesn't consume the click
	do
		local tb = WG.TerraformBrush
		local st = tb and tb.getState and tb.getState() or nil
		if st and st.measureActive then return false end
		if st and st.heightSamplingMode then return false end
		if tb and tb.getHeightSamplingMode and tb.getHeightSamplingMode() then return false end
	end

	-- Geo decal mode: left-click places, right-click undoes
	if geoDecalMode then
		if button == 1 then
			local worldX, worldZ = getWorldMousePosition()
			if worldX then
				placeGeoDecal(worldX, worldZ)
			end
			return true
		elseif button == 3 then
			undoGeoDecal()
			return true
		end
		return false
	end

	if button == 1 then
		-- Left click: paint
		leftMouseHeld = true
		eraseMode = false
		pendingSnapshot = true  -- snapshot before first stroke of this drag
		local worldX, worldZ = getWorldMousePosition()
		if worldX then
			paintAtSymmetric(worldX, worldZ)
			lastPaintX = worldX
			lastPaintZ = worldZ
		end
		return true
	elseif button == 3 then
		-- Right click: erase
		leftMouseHeld = true
		eraseMode = true
		pendingSnapshot = true  -- snapshot before first stroke of this drag
		local worldX, worldZ = getWorldMousePosition()
		if worldX then
			paintAtSymmetric(worldX, worldZ)
			lastPaintX = worldX
			lastPaintZ = worldZ
		end
		return true
	end

	return false
end

function widget:MouseRelease(mx, my, button)
	if not active then return false end

	if button == 1 or button == 3 then
		leftMouseHeld = false
		lastPaintX = nil
		lastPaintZ = nil
		return true
	end

	return false
end

function widget:MouseMove(mx, my, dx, dy, button)
	if not active or not leftMouseHeld then return false end

	local worldX, worldZ = getWorldMousePosition()
	if not worldX then return false end

	-- Paint along drag path with spacing to avoid gaps
	local spacing = max(activeRadius * 0.3, 8)
	if lastPaintX and lastPaintZ then
		local ddx = worldX - lastPaintX
		local ddz = worldZ - lastPaintZ
		local dist = sqrt(ddx * ddx + ddz * ddz)
		if dist >= spacing then
			local steps = floor(dist / spacing)
			for i = 1, steps do
				local t = i / steps
				local ix = lastPaintX + ddx * t
				local iz = lastPaintZ + ddz * t
				paintAtSymmetric(ix, iz)
			end
			lastPaintX = worldX
			lastPaintZ = worldZ
		end
	else
		paintAtSymmetric(worldX, worldZ)
		lastPaintX = worldX
		lastPaintZ = worldZ
	end

	return false
end

function widget:MouseWheel(up, value)
	if not active then return false end

	local alt, ctrl, meta, shift = Spring.GetModKeyState()
	local spaceHeld = Spring.GetKeyState(0x020) -- spacebar

	if spaceHeld then
		-- Space+Scroll: change intensity
		local delta = up and INTENSITY_STEP or -INTENSITY_STEP
		setIntensity(activeIntensity + delta)
		return true
	elseif ctrl then
		-- Ctrl+Scroll: change radius
		local delta = up and RADIUS_STEP or -RADIUS_STEP
		setRadius(activeRadius + delta)
		return true
	elseif shift then
		-- Shift+Scroll: change curve
		local delta = up and CURVE_STEP or -CURVE_STEP
		setCurve(activeCurve + delta)
		return true
	elseif alt then
		-- Alt+Scroll: change rotation (snap to TB protractor step when angleSnap on)
		local step = 3
		local tb = WG.TerraformBrush
		local tbs = tb and tb.getState and tb.getState() or nil
		if tbs and tbs.angleSnap and (tbs.angleSnapStep or 0) > 0 then
			step = tbs.angleSnapStep
		end
		rotateBy(up and step or -step)
		return true
	end

	return false
end

function widget:KeyPress(key, mods, isRepeat)
	if not active then return false end

	-- Ctrl+Z = undo, Ctrl+Shift+Z = redo
	if mods.ctrl and key == 122 then -- 'z'
		if mods.shift then
			splatRedo()
		else
			splatUndo()
		end
		return true
	end

	-- Channel selection: 1-4
	if key >= 0x31 and key <= 0x34 then -- '1' through '4'
		setChannel(key - 0x30)
		return true
	end

	return false
end

-- ============ SMART FILTER OVERLAY ============

-- Check if a local-space point is inside the brush shape
local function isInsideBrush(lx, lz, radius, shape)
	if shape == "circle" then
		return (lx * lx + lz * lz) <= radius * radius
	elseif shape == "square" then
		return abs(lx) <= radius and abs(lz) <= radius
	elseif shape == "hexagon" then
		local ax, az = abs(lx), abs(lz)
		local apothem = radius * cos(pi / 6)
		if az > apothem then return false end
		if ax > radius then return false end
		return ax * cos(pi / 6) + az * sin(pi / 6) <= apothem
	elseif shape == "triangle" then
		-- Equilateral triangle, apex at -Z (north) matching visual outline
		local px, pz = lx / radius, lz / radius
		local pz2 = -pz - 0.333333
		local d1 = -pz2 - 0.5
		local d2 =  0.866025 * px + 0.5 * pz2 - 0.5
		local d3 = -0.866025 * px + 0.5 * pz2 - 0.5
		return max(max(d1, d2), d3) < 0.0
	elseif shape == "octagon" then
		local ax, az = abs(lx), abs(lz)
		local cut = radius * sin(pi / 8)
		local side = radius * cos(pi / 8)
		if ax > side or az > side then return false end
		return (ax + az) <= (side + cut)
	end
	return true
end

-- Draw colored terrain-following quads showing valid (green) vs rejected (red) areas
local function drawSmartFilterOverlay(cx, cz, radius, shape, angleDeg)
	local step = GRID_STEP
	local halfStep = step * 0.3
	local rad = angleDeg * pi / 180
	local cosR, sinR = cos(rad), sin(rad)

	glDepthTest(true)
	glBeginEnd(GL_TRIANGLES, function()
		for lx = -radius, radius, step do
			for lz = -radius, radius, step do
				if isInsideBrush(lx, lz, radius, shape) then
					local wx = cx + lx * cosR - lz * sinR
					local wz = cz + lx * sinR + lz * cosR
					local valid = isPointValid(wx, wz)

					if valid then
						glColor(0.2, 0.85, 0.3, 0.08)
					else
						glColor(0.9, 0.15, 0.15, 0.14)
					end

					local x0 = wx - halfStep
					local x1 = wx + halfStep
					local z0 = wz - halfStep
					local z1 = wz + halfStep
					local y00 = GetGroundHeight(x0, z0) + 3
					local y10 = GetGroundHeight(x1, z0) + 3
					local y01 = GetGroundHeight(x0, z1) + 3
					local y11 = GetGroundHeight(x1, z1) + 3

					glVertex(x0, y00, z0)
					glVertex(x1, y10, z0)
					glVertex(x1, y11, z1)

					glVertex(x0, y00, z0)
					glVertex(x1, y11, z1)
					glVertex(x0, y01, z1)
				end
			end
		end
	end)
	glDepthTest(false)
end

-- Get shape corner points for altitude cap prism drawing
local function getShapeCorners(shape, radius, angleDeg)
	local corners = {}
	local rad = angleDeg * pi / 180
	if shape == "circle" then
		for i = 0, 15 do
			local a = i * (2 * pi / 16) + rad
			corners[#corners + 1] = { radius * cos(a), radius * sin(a) }
		end
	elseif shape == "square" then
		local pts = { {-radius,-radius}, {radius,-radius}, {radius,radius}, {-radius,radius} }
		for _, p in ipairs(pts) do
			local rx = p[1] * cos(rad) - p[2] * sin(rad)
			local rz = p[1] * sin(rad) + p[2] * cos(rad)
			corners[#corners + 1] = { rx, rz }
		end
	elseif shape == "hexagon" then
		for i = 0, 5 do
			local a = i * (2 * pi / 6) + rad
			corners[#corners + 1] = { radius * cos(a), radius * sin(a) }
		end
	elseif shape == "triangle" then
		for i = 0, 2 do
			local a = i * (2 * pi / 3) - pi / 2 + rad
			corners[#corners + 1] = { radius * cos(a), radius * sin(a) }
		end
	elseif shape == "octagon" then
		for i = 0, 7 do
			local a = i * (2 * pi / 8) + rad
			corners[#corners + 1] = { radius * cos(a), radius * sin(a) }
		end
	end
	return corners
end

-- Draw altitude cap prism (orange for max, cyan for min, white struts)
local function drawAltitudeCapPrism(cx, cz, radius, shape, angleDeg)
	local sf = smartFilter
	if not sf.altMinEnable and not sf.altMaxEnable then return end

	local corners = getShapeCorners(shape, radius, angleDeg)
	if #corners == 0 then return end

	local botY = sf.altMinEnable and sf.altMin or nil
	local topY = sf.altMaxEnable and sf.altMax or nil

	glDepthTest(true)
	glLineWidth(1.5)

	if topY then
		glColor(1.0, 0.6, 0.1, 0.55)
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 1, #corners do
				glVertex(cx + corners[i][1], topY, cz + corners[i][2])
			end
		end)
	end

	if botY then
		glColor(0.1, 0.6, 1.0, 0.55)
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 1, #corners do
				glVertex(cx + corners[i][1], botY, cz + corners[i][2])
			end
		end)
	end

	local stride = max(1, floor(#corners / 8))
	local strutBot = botY or (topY and topY - 100) or 0
	local strutTop = topY or (botY and botY + 100) or 0
	glColor(1, 1, 1, 0.2)
	glBeginEnd(GL_LINES, function()
		for i = 1, #corners, stride do
			local wx = cx + corners[i][1]
			local wz = cz + corners[i][2]
			glVertex(wx, strutBot, wz)
			glVertex(wx, strutTop, wz)
		end
	end)

	glLineWidth(1)
	glDepthTest(false)
end

-- ============ DRAW ============

local function generateBrushOutline(centerX, centerZ, groundY)
	local rotRad = activeRotation * pi / 180
	local cr = cos(rotRad)
	local sr = sin(rotRad)
	local r = activeRadius
	local segments = CIRCLE_SEGMENTS
	local shape = activeShape

	-- Channel colors: R=red, G=green, B=blue, A=yellow
	local channelColors = {
		{ 1.0, 0.3, 0.3, 0.9 },
		{ 0.3, 1.0, 0.3, 0.9 },
		{ 0.3, 0.3, 1.0, 0.9 },
		{ 1.0, 1.0, 0.3, 0.9 },
	}
	local col = channelColors[activeChannel] or { 1, 1, 1, 0.9 }
	if eraseMode then
		col = { 1.0, 0.5, 0.0, 0.9 } -- orange for erase
	end

	glColor(col[1], col[2], col[3], col[4])
	glLineWidth(2.0)

	if shape == "circle" then
		glDrawGroundCircle(centerX, groundY, centerZ, r, segments)
	else
		local verts = {}
		if shape == "square" then
			verts = {
				{ -r, -r }, { r, -r }, { r, r }, { -r, r },
			}
		elseif shape == "hexagon" then
			for i = 0, 5 do
				local angle = pi / 3 * i + pi / 6
				verts[#verts + 1] = { r * cos(angle), r * sin(angle) }
			end
		elseif shape == "triangle" then
			for i = 0, 2 do
				local angle = (2 * pi / 3) * i - pi / 2
				verts[#verts + 1] = { r * cos(angle), r * sin(angle) }
			end
		elseif shape == "octagon" then
			for i = 0, 7 do
				local angle = pi / 4 * i + pi / 8
				verts[#verts + 1] = { r * cos(angle), r * sin(angle) }
			end
		end

		-- Rotate and project to ground
		glBeginEnd(GL.LINE_LOOP, function()
			for _, v in ipairs(verts) do
				local rx = v[1] * cr - v[2] * sr + centerX
				local rz = v[1] * sr + v[2] * cr + centerZ
				local gy = GetGroundHeight(rx, rz)
				glVertex(rx, gy + 2, rz)
			end
		end)
	end

	-- Draw inner crosshair
	glColor(col[1], col[2], col[3], 0.5)
	glLineWidth(1.0)
	local crossSize = min(r * 0.1, 16)
	glBeginEnd(GL.LINES, function()
		glVertex(centerX - crossSize, groundY + 3, centerZ)
		glVertex(centerX + crossSize, groundY + 3, centerZ)
		glVertex(centerX, groundY + 3, centerZ - crossSize)
		glVertex(centerX, groundY + 3, centerZ + crossSize)
	end)

	-- Draw falloff ring at 50% strength
	if shape == "circle" and activeCurve > 0.1 then
		local halfR = r * (0.5 ^ (1 / activeCurve))
		glColor(col[1], col[2], col[3], 0.3)
		glLineWidth(1.0)
		glDrawGroundCircle(centerX, groundY, centerZ, halfR, segments)
	end
end

function widget:DrawWorld()
	-- Splatmap channel-colorized overlay (shown when chip is toggled, even when tool is inactive)
	if showSplatOverlay and fboTex and overlayShader then
		local GetGH = GetGroundHeight
		local msX = Game.mapSizeX
		local msZ = Game.mapSizeZ
		local GRID_N = 32
		local stepX = msX / GRID_N
		local stepZ = msZ / GRID_N
		glDepthTest(false)
		glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		glUseShader(overlayShader)
		glTexture(0, fboTex)
		glBeginEnd(GL_TRIANGLES, function()
			for gx = 0, GRID_N - 1 do
				for gz = 0, GRID_N - 1 do
					local x1, x2 = gx * stepX, (gx + 1) * stepX
					local z1, z2 = gz * stepZ, (gz + 1) * stepZ
					local u1, u2 = x1 / msX, x2 / msX
					local v1, v2 = z1 / msZ, z2 / msZ
					local y11 = GetGH(x1, z1) + 4
					local y21 = GetGH(x2, z1) + 4
					local y22 = GetGH(x2, z2) + 4
					local y12 = GetGH(x1, z2) + 4
					glTexCoord(u1, v1); glVertex(x1, y11, z1)
					glTexCoord(u2, v1); glVertex(x2, y21, z1)
					glTexCoord(u2, v2); glVertex(x2, y22, z2)
					glTexCoord(u1, v1); glVertex(x1, y11, z1)
					glTexCoord(u2, v2); glVertex(x2, y22, z2)
					glTexCoord(u1, v2); glVertex(x1, y12, z2)
				end
			end
		end)
		glTexture(0, false)
		glUseShader(0)
		glBlending(false)
		glDepthTest(true)
	end

	-- Draw placed geo decals as textured ground quads (always, even when not active)
	if #placedGeoDecals > 0 then
		glDepthTest(true)
		glPolygonOffset(1, 1)
		glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		glTexture(GEO_DECAL_TEX_PATH)
		glColor(0.5, 0.5, 0.5, 0.7)
		for _, d in ipairs(placedGeoDecals) do
			local s = d.size
			local cr, sr = cos(d.rot), sin(d.rot)
			local dy = 1
			local dx1 = -s * cr - (-s) * sr
			local dz1 = -s * sr + (-s) * cr
			local dx2 =  s * cr - (-s) * sr
			local dz2 =  s * sr + (-s) * cr
			local dx3 =  s * cr - s * sr
			local dz3 =  s * sr + s * cr
			local dx4 = -s * cr - s * sr
			local dz4 = -s * sr + s * cr
			glBeginEnd(GL_TRIANGLES, function()
				glTexCoord(0, 0)
				glVertex(d.x + dx1, GetGroundHeight(d.x + dx1, d.z + dz1) + dy, d.z + dz1)
				glTexCoord(1, 0)
				glVertex(d.x + dx2, GetGroundHeight(d.x + dx2, d.z + dz2) + dy, d.z + dz2)
				glTexCoord(1, 1)
				glVertex(d.x + dx3, GetGroundHeight(d.x + dx3, d.z + dz3) + dy, d.z + dz3)
				glTexCoord(0, 0)
				glVertex(d.x + dx1, GetGroundHeight(d.x + dx1, d.z + dz1) + dy, d.z + dz1)
				glTexCoord(1, 1)
				glVertex(d.x + dx3, GetGroundHeight(d.x + dx3, d.z + dz3) + dy, d.z + dz3)
				glTexCoord(0, 1)
				glVertex(d.x + dx4, GetGroundHeight(d.x + dx4, d.z + dz4) + dy, d.z + dz4)
			end)
		end
		glTexture(false)
		glColor(1, 1, 1, 1)
		glPolygonOffset(false)
		glDepthTest(false)
	end

	if not active then return end

	-- Deferred GL initialization (must happen inside a Draw call-in)
	if pendingInit then
		pendingInit = false
		if not initSplatTexture() then
			Echo("[Splat Painter] Texture initialization failed")
			active = false
			destroyShaders()
			return
		end
	end

	-- Handle undo/redo (texture swaps — no GL rendering needed)
	if pendingUndoCount > 0 then
		local changed = false
		for _ = 1, pendingUndoCount do
			if #undoStack == 0 then break end
			local cur = fboTex
			fboTex = table.remove(undoStack)
			redoStack[#redoStack + 1] = cur
			changed = true
		end
		pendingUndoCount = 0
		if changed and texApplied then SetMapShadingTexture(SPLAT_TEX_NAME, fboTex) end
	end
	if pendingRedoCount > 0 then
		local changed = false
		for _ = 1, pendingRedoCount do
			if #redoStack == 0 then break end
			local cur = fboTex
			fboTex = table.remove(redoStack)
			undoStack[#undoStack + 1] = cur
			changed = true
		end
		pendingRedoCount = 0
		if changed and texApplied then SetMapShadingTexture(SPLAT_TEX_NAME, fboTex) end
	end

	-- Snapshot current state before first stroke of a new drag
	if pendingSnapshot and #pendingPaintStrokes > 0 then
		pendingSnapshot = false
		takeSnapshot()
	end

	-- Execute queued paint strokes
	if #pendingPaintStrokes > 0 then
		for _, stroke in ipairs(pendingPaintStrokes) do
			executePaintStroke(stroke[1], stroke[2], stroke[3])
		end
		pendingPaintStrokes = {}
	end

	-- Deferred save
	if pendingSave and fboTex then
		pendingSave = false
		executeSaveSplats()
	end

	local worldX, worldZ = getWorldMousePosition()
	do
		local tb = WG.TerraformBrush
		if tb and tb.animateUnmouse then
			worldX, worldZ = tb.animateUnmouse("splatPainter", worldX, worldZ, activeRadius, 1.0)
		elseif tb and tb.getUnmouseTarget and not worldX then
			worldX, worldZ = tb.getUnmouseTarget(activeRadius, 1.0)
		end
	end
	if not worldX then return end
	local groundY = GetGroundHeight(worldX, worldZ)

	glPolygonOffset(1, 1)
	if geoDecalMode then
		-- Draw geo decal preview: magenta circle at decal size
		local halfSize = GEO_DECAL_SIZE * 0.5
		glColor(0.9, 0.3, 0.9, 0.8)
		glLineWidth(2.0)
		glDrawGroundCircle(worldX, groundY, worldZ, halfSize, CIRCLE_SEGMENTS)
		-- Inner crosshair
		local crossSize = min(halfSize * 0.15, 16)
		glColor(0.9, 0.3, 0.9, 0.5)
		glLineWidth(1.0)
		glBeginEnd(GL.LINES, function()
			glVertex(worldX - crossSize, groundY + 3, worldZ)
			glVertex(worldX + crossSize, groundY + 3, worldZ)
			glVertex(worldX, groundY + 3, worldZ - crossSize)
			glVertex(worldX, groundY + 3, worldZ + crossSize)
		end)
	else
		generateBrushOutline(worldX, worldZ, groundY)
	end
	glPolygonOffset(false)

	-- Smart filter overlay: show valid/rejected terrain areas
	if smartFilterEnabled and not geoDecalMode then
		drawSmartFilterOverlay(worldX, worldZ, activeRadius, activeShape, activeRotation)
		drawAltitudeCapPrism(worldX, worldZ, activeRadius, activeShape, activeRotation)
	end

	-- Reset color
	glColor(1, 1, 1, 1)
	glLineWidth(1.0)
end

function widget:IsAbove(mx, my)
	return false
end

function widget:GetTooltip(mx, my)
	if not active then return nil end
	if geoDecalMode then
		return "Splat Painter | GEO DECAL | Size: " .. GEO_DECAL_SIZE .. " | Placed: " .. #placedGeoDecals .. " | LMB=place, RMB=undo"
	end
	local channelNames = { "Red (Tex 1)", "Green (Tex 2)", "Blue (Tex 3)", "Alpha (Tex 4)" }
	return "Splat Painter | Channel: " .. (channelNames[activeChannel] or "?") .. " | Strength: " .. string.format("%.2f", activeStrength) .. " | Size: " .. activeRadius
end
