local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Squad Selection Hull",
		desc = "Convex-hull visualization for the Squad Selection widget",
		author = "Baldric, yyyy",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 301, -- after Squad Selection (300); it produces the state this reads
		enabled = true,
	}
end

-------------------------------------------------------------------------------
-- Squad Selection — convex hull visualization
--
-- Companion to unit_squad_selection.lua. The main widget owns all squad state
-- and animation; this widget only reads a snapshot of that state (via
-- WG['squadselection']) and renders the hulls.
--
-- Coupling (all read-only):
--   WG['squadselection'].getConfig()            -> live config table
--   WG['squadselection'].getSquadState()        -> { squads, squadIdleBlend,
--       squadHideIdleAirHull, squadSelCount, squadHighlightBlend,
--       squadControlBlend, teamColor, ... }
--   WG['squadselection'].addSquadChangeListener/removeSquadChangeListener
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Localized Spring/gl API
-------------------------------------------------------------------------------
local spIsGUIHidden = Spring.IsGUIHidden
local spGetUnitPosition = Spring.GetUnitPosition
local spGetGroundHeight = Spring.GetGroundHeight
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local spIsSphereInView = Spring.IsSphereInView
local spGetSpectatingState = Spring.GetSpectatingState
local spIsReplay = Spring.IsReplay
local spGetLocalPlayerID = Spring.GetLocalPlayerID

local glColor = gl.Color
local glDepthTest = gl.DepthTest
local glLineWidth = gl.LineWidth
local glCreateShader = gl.CreateShader
local glDeleteShader = gl.DeleteShader
local glUseShader = gl.UseShader
local glGetUniformLocation = gl.GetUniformLocation
local glUniform = gl.Uniform
local glGetVBO = gl.GetVBO
local glGetVAO = gl.GetVAO

local function log(...)
	Spring.Log("SquadHull", LOG.ERROR, ...)
end

-------------------------------------------------------------------------------
-- Config
--
-- Hull-specific look + animation. Owned and persisted by this widget. The
-- shared cross-visualization options (visualizationMode, showReserveSquads,
-- squadColorMode, squadCustomColor*) live in the main widget and are read via
-- WG['squadselection'].getConfig().
-------------------------------------------------------------------------------

---@class HullConfig
---@field convexHullPadding number
---@field convexHullArcResolution number
---@field convexHullFillOpacity number
---@field convexHullBorderOpacity number
---@field convexHullBorderThickness number
---@field reserveStripePeriod number
---@field reserveStripeAlphaMul number
---@field hullPulseAmplitude number
---@field hullPulseRate number

---@type HullConfig
local hullConfig = {
	convexHullPadding = 60, -- space (in elmos) between the units and the hull boundary
	convexHullArcResolution = 0.4, -- angle that each chord of the arc spans in radians; smaller = smoother but more expensive
	convexHullFillOpacity = 0.25,
	convexHullBorderOpacity = 0.3,
	convexHullBorderThickness = 2,
	-- Animation tuning (no panel control).
	reserveStripePeriod = 64, -- diagonal-stripe period in world elmos for reserve squad fills
	reserveStripeAlphaMul = 0.3, -- opacity of the dim stripe band relative to the bright band
	hullPulseAmplitude = 0.25, -- breathing pulse amplitude on hull alpha
	hullPulseRate = 1.5, -- breathing pulse rate; period ≈ 2π / rate seconds
}

-------------------------------------------------------------------------------
-- State from the main widget (cached references; refreshed on squad changes)
-------------------------------------------------------------------------------
local config = nil ---@type table? live config table from WG['squadselection'].getConfig()
local squadState = nil ---@type table? snapshot from WG['squadselection'].getSquadState()
local registered = false

local function onSquadChange(event)
	-- Only "rebuild" (rebuildTracking) reassigns the squads/blend tables; "add"
	-- and "remove" mutate them in place, so the cached references stay valid for those.
	if event == "rebuild" then
		local api = WG["squadselection"]
		squadState = api and api.getSquadState and api.getSquadState() or nil
	end
end

local function tryRegister()
	local api = WG["squadselection"]
	if not api then
		registered = false
		squadState = nil
		config = nil
		return
	end
	if not registered and api.addSquadChangeListener and api.getSquadState and api.getConfig then
		config = api.getConfig()
		api.addSquadChangeListener(onSquadChange)
		registered = true
	end
end

-------------------------------------------------------------------------------
-- GL4 hull rendering
--
-- One shared VBO (2D world x,z + ground-sampled y) is re-uploaded per squad
-- per frame, then drawn as TRIANGLE_FAN (fill) and LINE_LOOP (border).
-- The 2D hull geometry is convex, so a fan starting from vertex 0 covers it.
-------------------------------------------------------------------------------

local HULL_MAX_VERTICES = 512
local hullShader = nil ---@type integer?
local hullColorLoc = nil ---@type GL?
local hullStripeLoc = nil ---@type GL?
local hullCentroidLoc = nil ---@type GL?
local hullPulseLoc = nil ---@type GL?
local hullVbo = nil ---@type VBO?
local hullVao = nil ---@type VAO?
local hullReady = false
local hullInitFailed = false -- so we don't spam retries after a failure
local hullTimeOrigin = nil ---@type integer? wall-clock origin for stripe/pulse animation

-- Center -> edge alpha gradient: alpha at the centroid as a fraction of the edge.
local HULL_GRADIENT_CENTER = 0.2

local hullVsSrc = [[
#version 330 compatibility

layout(location = 0) in vec3 position;

out vec3 worldPos;

void main() {
	worldPos = position;
	gl_Position = gl_ModelViewProjectionMatrix * vec4(position, 1.0);
}
]]

local hullFsSrc = [[
#version 330 compatibility

uniform vec4 color;
// stripe.x = period in world units (0 disables stripes)
// stripe.y = alpha multiplier for the dim band
// stripe.z = phase offset in world units (per-squad, so overlapping hulls don't align)
uniform vec3 stripe;
// centroidRadius.xy = squad centroid in world XZ
// centroidRadius.z  = max distance from centroid to a perimeter vertex (gradient norm)
uniform vec3 centroidRadius;
// breathing alpha multiplier (per-squad phase, computed CPU-side)
uniform float pulse;
// alpha at the centroid as a fraction of the edge alpha
uniform float gradientCenter;

in vec3 worldPos;

out vec4 fragColor;

void main() {
	float a = color.a;

	if (stripe.x > 0.0) {
		float band = step(0.5, fract((worldPos.x + worldPos.z + stripe.z) / stripe.x));
		a *= mix(stripe.y, 1.0, band);
	}

	// soft center -> edge alpha gradient
	vec2 toCenter = worldPos.xz - centroidRadius.xy;
	float dist = length(toCenter) / max(centroidRadius.z, 1.0);
	a *= mix(gradientCenter, 1.0, smoothstep(0.0, 1.0, dist));

	a *= pulse;

	fragColor = vec4(color.rgb, a);
}
]]

local function initGlHull()
	if hullReady or hullInitFailed then
		return hullReady
	end
	if not glCreateShader or not glGetVBO or not glGetVAO then
		log("GL4 unavailable — convex hull drawing disabled")
		hullInitFailed = true
		return false
	end

	hullShader = glCreateShader({
		vertex = hullVsSrc,
		fragment = hullFsSrc,
	})
	if not hullShader then
		local shaderLog = gl.GetShaderLog and gl.GetShaderLog() or "(no log)"
		log("Failed to compile hull shader: ", shaderLog)
		hullInitFailed = true
		return false
	end
	hullColorLoc = glGetUniformLocation(hullShader, "color")
	hullStripeLoc = glGetUniformLocation(hullShader, "stripe")
	hullCentroidLoc = glGetUniformLocation(hullShader, "centroidRadius")
	hullPulseLoc = glGetUniformLocation(hullShader, "pulse")
	local gradientLoc = glGetUniformLocation(hullShader, "gradientCenter")
	glUseShader(hullShader)
	glUniform(gradientLoc, HULL_GRADIENT_CENTER)
	glUseShader(0)

	hullVbo = glGetVBO(GL.ARRAY_BUFFER, false)
	if not hullVbo then
		glDeleteShader(hullShader)
		hullShader = nil
		log("Failed to create hull VBO")
		hullInitFailed = true
		return false
	end
	hullVbo:Define(HULL_MAX_VERTICES, {
		{
			id = 0,
			name = "position",
			size = 3,
		},
	})

	hullVao = glGetVAO()
	if not hullVao then
		hullVbo:Delete()
		hullVbo = nil
		glDeleteShader(hullShader)
		hullShader = nil
		log("Failed to create hull VAO")
		hullInitFailed = true
		return false
	end
	hullVao:AttachVertexBuffer(hullVbo)

	hullReady = true
	return true
end

local function cleanupGlHull()
	if hullVao then
		hullVao:Delete()
	end
	if hullVbo then
		hullVbo:Delete()
	end
	if hullShader then
		glDeleteShader(hullShader)
	end
	hullVao = nil
	hullVbo = nil
	hullShader = nil
	hullColorLoc = nil
	hullStripeLoc = nil
	hullCentroidLoc = nil
	hullPulseLoc = nil
	hullReady = false
	hullInitFailed = false
end

-------------------------------------------------------------------------------
-- Convex hull
-------------------------------------------------------------------------------

-- Persistent scratch buffers. Tables inside (scratchWorld / scratchPadded
-- entries) are reused across frames. scratchHull / scratchUpper hold refs
-- *into* scratchWorld, not independent tables.
local scratchWorld = {} -- {x=world_x, y=world_z} per unit
local scratchHull = {} -- refs into scratchWorld
local scratchUpper = {} -- internal to convexHull
local scratchPadded = {} -- {x, y} per padded-hull vertex
local scratchFlat = {} -- flat {x, y, z, x, y, z, ...} for VBO upload

local function comparePoints(a, b)
	return a.x < b.x or (a.x == b.x and a.y < b.y)
end

local function cross(o, a, b)
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
end

local function truncate(buf, newLen)
	for i = #buf, newLen + 1, -1 do
		buf[i] = nil
	end
end

-- Writes refs-into-world into out. Sorts `world` in place. Expects #world == n.
local function convexHull(world, n, out, upper)
	table.sort(world, comparePoints)

	local h = 0
	for i = 1, n do
		local p = world[i]
		while h >= 2 and cross(out[h - 1], out[h], p) <= 0 do
			out[h] = nil
			h = h - 1
		end
		h = h + 1
		out[h] = p
	end

	local u = 0
	for i = n, 1, -1 do
		local p = world[i]
		while u >= 2 and cross(upper[u - 1], upper[u], p) <= 0 do
			upper[u] = nil
			u = u - 1
		end
		u = u + 1
		upper[u] = p
	end

	for i = 2, u - 1 do
		h = h + 1
		out[h] = upper[i]
	end

	truncate(upper, 0)
	truncate(out, h)
	return h
end

-- circle for squads with only one unit. Writes into out, reuses its tables.
local function paddedCircle(cx, cy, radius, arcSegmentsAngle, out)
	local segments = math.max(math.ceil(2 * math.pi / arcSegmentsAngle), 3)
	for i = 0, segments - 1 do
		local angle = 2 * math.pi * i / segments
		local p = out[i + 1]
		if not p then
			p = {}
			out[i + 1] = p
		end
		p.x = cx + radius * math.cos(angle)
		p.y = cy + radius * math.sin(angle)
	end
	truncate(out, segments)
	return segments
end

-- rounded padded convex hull for 2+ units. Writes into out, reuses its tables.
local function paddedMoreThanOneUnit(hull, nHull, radius, arcSegmentsAngle, out)
	local n = 0
	for i = 1, nHull do
		local prev = hull[i == 1 and nHull or i - 1]
		local curr = hull[i]
		local nxt = hull[i == nHull and 1 or i + 1]

		local dxPrev = curr.x - prev.x
		local dyPrev = curr.y - prev.y
		local dxNext = nxt.x - curr.x
		local dyNext = nxt.y - curr.y

		-- right normals (outward for CCW): (dy, -dx)
		local anglePrev = math.atan2(-dxPrev, dyPrev)
		local angleNext = math.atan2(-dxNext, dyNext)
		local angleDiff = angleNext - anglePrev
		while angleDiff < 0 do
			angleDiff = angleDiff + 2 * math.pi
		end
		local arcSegments = math.max(math.ceil(angleDiff / arcSegmentsAngle), 1)
		for j = 0, arcSegments do
			local t = j / arcSegments
			local theta = anglePrev + t * angleDiff
			n = n + 1
			local p = out[n]
			if not p then
				p = {}
				out[n] = p
			end
			p.x = curr.x + radius * math.cos(theta)
			p.y = curr.y + radius * math.sin(theta)
		end
	end
	truncate(out, n)
	return n
end

-- Fill scratchPadded from scratchWorld[1..nWorld]. Returns padded count.
local function getPaddedHull(nWorld, radius, arcSegmentsAngle)
	if nWorld == 1 then
		local p = scratchWorld[1]
		return paddedCircle(p.x, p.y, radius, arcSegmentsAngle, scratchPadded)
	elseif nWorld >= 2 then
		local nHull = convexHull(scratchWorld, nWorld, scratchHull, scratchUpper)
		return paddedMoreThanOneUnit(scratchHull, nHull, radius, arcSegmentsAngle, scratchPadded)
	else
		truncate(scratchPadded, 0)
		return 0
	end
end

-------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------

-- Panel-controlled keys exposed to gui_options.lua via WG['squadselectionhull'].
-- The animation-tuning keys have no panel control and stay config-only.
local exposedSettings = {
	"convexHullPadding",
	"convexHullArcResolution",
	"convexHullFillOpacity",
	"convexHullBorderOpacity",
	"convexHullBorderThickness",
}

function widget:Initialize()
	if spGetSpectatingState() or spIsReplay() then
		widgetHandler:RemoveWidget()
		return
	end

	tryRegister()

	-- WG interface for gui_options.lua. Auto-generates get<Key>/set<Key> pairs
	WG["squadselectionhull"] = {}
	for _, key in ipairs(exposedSettings) do
		local cap = key:sub(1, 1):upper() .. key:sub(2)
		WG["squadselectionhull"]["get" .. cap] = function()
			return hullConfig[key]
		end
		WG["squadselectionhull"]["set" .. cap] = function(v)
			hullConfig[key] = v
		end
	end
end

function widget:Update()
	-- Main widget loading after us? Try to register again.
	tryRegister()
end

function widget:PlayerChanged(playerID)
	if playerID ~= spGetLocalPlayerID() then
		return
	end
	if spGetSpectatingState() then
		widgetHandler:RemoveWidget()
	end
end

function widget:Shutdown()
	local api = WG["squadselection"]
	if api and api.removeSquadChangeListener then
		api.removeSquadChangeListener(onSquadChange)
	end
	WG["squadselectionhull"] = nil
	cleanupGlHull()
end

-------------------------------------------------------------------------------
-- Settings persistence
-------------------------------------------------------------------------------

function widget:SetConfigData(data)
	for key, value in pairs(data) do
		if hullConfig[key] ~= nil then
			hullConfig[key] = value
		end
	end
end

function widget:GetConfigData()
	return hullConfig
end

-------------------------------------------------------------------------------
-- Drawing
-------------------------------------------------------------------------------

function widget:DrawWorldPreUnit()
	if spIsGUIHidden() or not config or config.visualizationMode ~= "convexHull" then
		return
	end
	local state = squadState
	if not state then
		return
	end
	local squads = state.squads
	if not squads or #squads == 0 then
		return
	end
	if not hullReady and not initGlHull() then
		return
	end
	if not (hullShader and hullVbo and hullVao and hullColorLoc and hullStripeLoc and hullCentroidLoc and hullPulseLoc) then
		return
	end

	local squadIdleBlend = state.squadIdleBlend
	local squadHideIdleAirHull = state.squadHideIdleAirHull
	local squadSelCount = state.squadSelCount
	local squadHighlightBlend = state.squadHighlightBlend
	local squadControlBlend = state.squadControlBlend
	local teamColor = state.teamColor

	local fillOpacity = hullConfig.convexHullFillOpacity
	local borderOpacity = hullConfig.convexHullBorderOpacity
	local borderThickness = hullConfig.convexHullBorderThickness
	local padding = hullConfig.convexHullPadding
	local arcRes = hullConfig.convexHullArcResolution
	local showReserves = config.showReserveSquads
	local colorMode = config.squadColorMode

	if not hullTimeOrigin then
		hullTimeOrigin = spGetTimer()
	end
	local now = spDiffTimers(spGetTimer(), hullTimeOrigin)

	glDepthTest(false)
	glUseShader(hullShader)
	glLineWidth(borderThickness)

	for _, squad in ipairs(squads) do
		if not squad.isReserve or showReserves then
			local size = #squad
			if size > 0 then
				local idleBlend = squadIdleBlend[squad] or 0
				local alphaScale = 1 ---@type number
				if squadHideIdleAirHull[squad] then
					alphaScale = 1 - idleBlend
				end

				if alphaScale <= 0.001 then
					-- Fully hidden for idle flying-air squads.
				else
					local cr, cg, cb
					local fullySelected = (squadSelCount[squad] or 0) >= size
					if fullySelected then
						cr, cg, cb = 1, 1, 1
					elseif colorMode == "custom" then
						cr, cg, cb = config.squadCustomColorR, config.squadCustomColorG, config.squadCustomColorB
					elseif colorMode == "squad" and squad.color then
						cr, cg, cb = squad.color[1], squad.color[2], squad.color[3]
					else
						cr = teamColor[1]
						cg = teamColor[2]
						cb = teamColor[3]
					end
					local hb = squadHighlightBlend[squad] or 0
					local ctb = squadControlBlend[squad] or 0
					local effIdle = idleBlend * (1 - hb)
					if effIdle > 0 and not fullySelected then
						local ir = cr * 0.3
						local ig = cg * 0.3
						local ib = cb * 0.3
						cr = cr + (ir - cr) * effIdle
						cg = cg + (ig - cg) * effIdle
						cb = cb + (ib - cb) * effIdle
					end
					if squad.isReserve then
						alphaScale = alphaScale * 0.6
						cr, cg, cb = cr * 1.5, cg * 1.5, cb * 1.5
					end

					-- Highlight tiers faded in by their blends. The commanded squad
					-- always has hb fading in alongside ctb, so control
					-- stacks on top of hover (extra brightness + border width).
					local effFill, effBorder = fillOpacity, borderOpacity
					local effPadding = padding
					if hb > 0 or ctb > 0 then
						effFill = math.min(1, fillOpacity + 0.2 * hb + 0.2 * ctb)
						effBorder = math.min(1, borderOpacity + 0.2 * hb + 0.2 * ctb)
						effPadding = padding + 5 * hb + 5 * ctb
						local bright = 0.4 * ctb
						cr = cr + (1 - cr) * bright
						cg = cg + (1 - cg) * bright
						cb = cb + (1 - cb) * bright
					end

					-- fill scratchWorld in place (reuse {x,y} tables) and track
					-- the bbox in the same pass, so we can frustum-cull without a
					-- second iteration.
					local nWorld = 0
					local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
					for i = 1, size do
						local x, _, z = spGetUnitPosition(squad[i])
						if x and z then
							nWorld = nWorld + 1
							local p = scratchWorld[nWorld]
							if not p then
								p = {}
								scratchWorld[nWorld] = p
							end
							p.x = x
							p.y = z
							if x < minX then
								minX = x
							end
							if x > maxX then
								maxX = x
							end
							if z < minZ then
								minZ = z
							end
							if z > maxZ then
								maxZ = z
							end
						end
					end
					truncate(scratchWorld, nWorld)

					if nWorld > 0 then
						-- Frustum cull: enclose the squad + padding in one sphere
						-- around the bbox centre. Vertical slop (256) covers
						-- terrain variation under the ground-projected hull.
						local cx = (minX + maxX) * 0.5
						local cz = (minZ + maxZ) * 0.5
						local hx = (maxX - minX) * 0.5
						local hz = (maxZ - minZ) * 0.5
						local cy = spGetGroundHeight(cx, cz)
						local radius = math.sqrt(hx * hx + hz * hz) + effPadding + 256
						local visible = (not spIsSphereInView) or spIsSphereInView(cx, cy, cz, radius)

						if visible then
							local n = getPaddedHull(nWorld, effPadding, arcRes)
							if n >= 3 and n <= HULL_MAX_VERTICES then
								local seed = squad.tagSeed or 0

								-- Centroid (average of padded vertices) and max radius
								-- are uploaded as a uniform to drive the fragment-shader
								-- center -> edge alpha gradient. The hull stays convex so
								-- TRIANGLE_FAN can still pivot on vertex 0.
								local pcx, pcy = 0, 0 ---@type number, number
								local fi = 0
								for i = 1, n do
									local p = scratchPadded[i]
									pcx = pcx + p.x
									pcy = pcy + p.y
									scratchFlat[fi + 1] = p.x
									scratchFlat[fi + 2] = spGetGroundHeight(p.x, p.y)
									scratchFlat[fi + 3] = p.y
									fi = fi + 3
								end
								pcx = pcx / n
								pcy = pcy / n

								local maxR2 = 0 ---@type number
								for i = 1, n do
									local p = scratchPadded[i]
									local rdx = p.x - pcx
									local rdy = p.y - pcy
									local r2 = rdx * rdx + rdy * rdy
									if r2 > maxR2 then
										maxR2 = r2
									end
								end
								local hullRadiusNorm = math.sqrt(maxR2)

								hullVbo:Upload(scratchFlat, nil, nil, 1, fi)

								local pulseVal = 1 + hullConfig.hullPulseAmplitude * math.sin(now * hullConfig.hullPulseRate + seed * 6.2831853)
								glUniform(hullCentroidLoc, pcx, pcy, hullRadiusNorm)
								glUniform(hullPulseLoc, pulseVal)

								if squad.isReserve then
									glUniform(hullStripeLoc, hullConfig.reserveStripePeriod, hullConfig.reserveStripeAlphaMul, seed * hullConfig.reserveStripePeriod)
								else
									glUniform(hullStripeLoc, 0, 1, 0)
								end
								glUniform(hullColorLoc, cr, cg, cb, effFill * alphaScale)
								hullVao:DrawArrays(GL.TRIANGLE_FAN, n)
								if squad.isReserve then
									glUniform(hullStripeLoc, 0, 1, 0)
								end
								glUniform(hullColorLoc, cr, cg, cb, effBorder * alphaScale)
								if ctb > 0 then
									glLineWidth(borderThickness + 2 * ctb)
									hullVao:DrawArrays(GL.LINE_LOOP, n)
									glLineWidth(borderThickness)
								else
									hullVao:DrawArrays(GL.LINE_LOOP, n)
								end
							end
						end
					end
				end
			end
		end
	end

	glUseShader(0)
	glLineWidth(1)
	glDepthTest(true)
	glColor(1, 1, 1, 1)
end
