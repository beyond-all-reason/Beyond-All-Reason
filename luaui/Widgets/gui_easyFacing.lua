include("keysym.h.lua")
local versionNumber = "1.6"

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Easy Facing",
		desc = "[v"
			.. string.format("%s", versionNumber)
			.. "] Enables changing building facing by holding left mouse button. Hold the right mouse button to change facing while queueing.",
		author = "very_bad_soldier",
		date = "2009.08.10",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame

-- 1.1 Tweaks by Pako, big thx!

-- CONFIGURATION
local updateInt = 1 -- seconds for the ::update loop
local sens = 40 -- rotate mouse sensitivity - length of mouse movement vector
local drawForAll = false -- draw facing direction also for other buildings than labs

-- Arrow style (matches the buildsquare footprint look: soft fill, pale outline, rounded corners)
local ARROW_FILL_COLOR = { 0.05, 1.0, 0.35, 0.42 }
local ARROW_OUTLINE_COLOR = { 0.72, 1.0, 0.72, 0.62 }
local ARROW_CORNER_RADIUS = 2.6 -- elmos
local ARROW_OUTLINE_WIDTH = 1.0 -- elmos
local ARROW_CHEVRON_DEPTH = 0.45 -- inner chevron position, 0 = at the tip edges, 1 = at the base centre
local ARROW_CHEVRON_WIDTH = 1.5 -- elmos
local ARROW_CHEVRON_BASE_GAP = 5 -- elmos the chevron legs stop short of the flat side
local ARROW_GAP = 2 -- elmos between the building footprint and the arrow's flat side

--------------------------------------------------------------------------------

local inDrag = false
local mouseDeltaX = 0
local mouseDeltaY = 0
local mouseXStartRotate = 0
local mouseYStartRotate = 0
local mouseXStartDrag = 0
local mouseYStartDrag = 0
local ineffect = false
local gameStarted, lastTimeUpdate

-------------------------------------------------------------------------------

local isntFactory = {}
local unitZsize = {}
for udefID, def in ipairs(UnitDefs) do
	if def.isFactory == false or #def.buildOptions == 0 then
		isntFactory[udefID] = true
	end
	unitZsize[udefID] = def.zsize
end

local spGetModKeyState = Spring.GetModKeyState
local spGetGameSeconds = Spring.GetGameSeconds
local spGetActiveCommand = Spring.GetActiveCommand
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetCameraVectors = Spring.GetCameraVectors
local spWarpMouse = Spring.WarpMouse
local spGetBuildFacing = Spring.GetBuildFacing
local spSetBuildFacing = Spring.SetBuildFacing
local spPos2BuildPos = Spring.Pos2BuildPos
local spSetActiveCommand = Spring.SetActiveCommand
local spGetCmdDescIndex = Spring.GetCmdDescIndex
local spTestBuildOrder = Spring.TestBuildOrder
local spGiveOrder = Spring.GiveOrder
local spGetInvertQueueKey = Spring.GetInvertQueueKey

local CMDTYPE_ICON_BUILDING = CMDTYPE.ICON_BUILDING

local floor = math.floor
local atan2 = math.atan2
local pi = math.pi
local sqrt = math.sqrt

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate
local glVertex = gl.Vertex
local glRotate = gl.Rotate
local glBeginEnd = gl.BeginEnd
local glScale = gl.Scale
local glUseShader = gl.UseShader
local glUniform = gl.Uniform
local GL_TRIANGLES = GL.TRIANGLES
local GL_QUADS = GL.QUADS

-- Arrow geometry in local units (before the per-building scale): base along x = 0 from z = -32 to 32, tip at x = 24.
local ARROW_BASE_HALF = 32
local ARROW_TIP = 24
local ARROW_QUAD_PADDING = 6 -- keeps the antialiased edge inside the quad

local arrowShader
local arrowUniforms = {}

local arrowVertexShader = [[
#version 150 compatibility
varying vec2 vLocal;
void main() {
	vLocal = gl_Vertex.xz;
	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
]]

local arrowFragmentShader = [[
#version 150 compatibility
uniform float worldScale; // local units -> elmos
uniform float cornerRadius; // elmos
uniform float outlineWidth; // elmos
uniform float chevronDepth; // 0..1 along the leading-edge distance
uniform float chevronWidth; // elmos
uniform float chevronBaseGap; // elmos the chevron legs stop short of the base
uniform vec4 fillColor;
uniform vec4 outlineColor;
varying vec2 vLocal;

const vec2 A = vec2(0.0, -32.0);
const vec2 B = vec2(0.0, 32.0);
const vec2 C = vec2(24.0, 0.0);
// Incenter and inradius of the triangle; the incircle touches the base so the incenter is at (inradius, 0).
const float INRADIUS = 32.0 / 3.0;
const vec2 INCENTER = vec2(INRADIUS, 0.0);
// Inward normals of the two leading edges (A->C and B->C).
const vec2 N_AC = vec2(-0.8, 0.6);
const vec2 N_BC = vec2(-0.8, -0.6);

float sdTriangle(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
	vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
	vec2 v0 = p - p0, v1 = p - p1, v2 = p - p2;
	vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float s = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
	                 vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
	                 vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
	return -sqrt(d.x) * sign(d.y);
}

void main() {
	vec2 p = vLocal;
	// Round the corners without changing the outer extent: shrink the triangle towards its incenter by the
	// radius, then grow the distance field back out by the same amount.
	float radiusLocal = min(cornerRadius / worldScale, INRADIUS * 0.9);
	float shrink = 1.0 - radiusLocal / INRADIUS;
	vec2 a = INCENTER + (A - INCENTER) * shrink;
	vec2 b = INCENTER + (B - INCENTER) * shrink;
	vec2 c = INCENTER + (C - INCENTER) * shrink;
	float edgeDistance = (sdTriangle(p, a, b, c) - radiusLocal) * worldScale; // elmos, negative inside
	float antialias = fwidth(edgeDistance);
	float coverage = 1.0 - smoothstep(0.0, antialias, edgeDistance);
	float outline = smoothstep(-outlineWidth - antialias, -outlineWidth + antialias, edgeDistance);

	// Inner chevron: a band parallel to the two leading edges, measured in local units so it scales with the arrow.
	float leadingDistance = min(dot(p - A, N_AC), dot(p - B, N_BC));
	float maxLeadingDistance = dot(-A, N_AC); // at the base centre
	float chevronCentre = chevronDepth * maxLeadingDistance;
	float chevronDistance = abs(leadingDistance - chevronCentre) * worldScale;
	float chevronAntialias = fwidth(chevronDistance);
	float chevron = 1.0 - smoothstep(chevronWidth * 0.5 - chevronAntialias, chevronWidth * 0.5 + chevronAntialias, chevronDistance);
	// Keep the chevron clear of the outline band so they don't merge into a blob at the base corners.
	chevron *= 1.0 - smoothstep(-outlineWidth * 2.0 - antialias, -outlineWidth * 2.0 + antialias, edgeDistance);
	// ...and stop its legs short of the flat side so the arrow keeps a clean base.
	float baseDistance = p.x * worldScale;
	float baseAntialias = fwidth(baseDistance);
	chevron *= smoothstep(chevronBaseGap - baseAntialias, chevronBaseGap + baseAntialias, baseDistance);

	// The fill gets a touch denser towards the tip so the direction reads even without the outline.
	float tipMix = clamp(p.x / C.x, 0.0, 1.0);
	float fillAlpha = fillColor.a * mix(0.85, 1.15, tipMix);

	float detail = max(outline, chevron * 0.85);
	vec3 color = mix(fillColor.rgb, outlineColor.rgb, detail);
	float alpha = mix(fillAlpha, outlineColor.a, detail);
	gl_FragColor = vec4(color, alpha * coverage);
}
]]

local function initArrowShader()
	if not gl.CreateShader then
		return
	end
	arrowShader = gl.CreateShader({
		vertex = arrowVertexShader,
		fragment = arrowFragmentShader,
		uniformFloat = {
			worldScale = 1.0,
			cornerRadius = ARROW_CORNER_RADIUS,
			outlineWidth = ARROW_OUTLINE_WIDTH,
			chevronDepth = ARROW_CHEVRON_DEPTH,
			chevronWidth = ARROW_CHEVRON_WIDTH,
			chevronBaseGap = ARROW_CHEVRON_BASE_GAP,
			fillColor = ARROW_FILL_COLOR,
			outlineColor = ARROW_OUTLINE_COLOR,
		},
	})
	if not arrowShader then
		Spring.Echo("Easy Facing: arrow shader failed to compile, using the plain triangle: " .. tostring(gl.GetShaderLog()))
		return
	end
	arrowUniforms.worldScale = gl.GetUniformLocation(arrowShader, "worldScale")
end

local function deleteArrowShader()
	if arrowShader then
		gl.DeleteShader(arrowShader)
		arrowShader = nil
	end
end

local function drawArrowTriangle()
	glVertex(0, 0, -ARROW_BASE_HALF)
	glVertex(0, 0, ARROW_BASE_HALF)
	glVertex(ARROW_TIP, 0, 0)
end

local function drawArrowQuad()
	local x0, x1 = -ARROW_QUAD_PADDING, ARROW_TIP + ARROW_QUAD_PADDING
	local z0, z1 = -ARROW_BASE_HALF - ARROW_QUAD_PADDING, ARROW_BASE_HALF + ARROW_QUAD_PADDING
	glVertex(x0, 0, z0)
	glVertex(x0, 0, z1)
	glVertex(x1, 0, z1)
	glVertex(x1, 0, z0)
end

local function maybeRemoveSelf()
	if Spring.GetSpectatingState() and (spGetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
	end
end

---map of reason to unitDefID
---@type table<string, number>
local forceShow = {}

local function getForceShowUnitDefID()
	-- show facing arrow as long as any source wants us to show it (logical OR)
	local reason = next(forceShow, nil)
	return reason and forceShow[reason] or nil
end

local function getVector2dLen(vector)
	return sqrt((vector[1] * vector[1]) + (vector[2] * vector[2]))
end

local function normalizeVector2d(vector)
	local len = getVector2dLen(vector)
	local normVec = { 0.0, 0.0 }
	normVec[1] = vector[1] / len
	normVec[2] = vector[2] / len
	return normVec
end

-- I currently get all degrees in a range from 0 to 270 and 0 to -90
-- this is a hack to correct this
-- also corrects values > 360
local function normalizeDegreeRange(degree)
	if degree < 0 then
		degree = 360.0 + degree
	elseif degree > 360 then
		degree = degree - 360
	end
	return degree
end

local function getRotationVectors2d(vectorA, vectorB)
	vectorA = normalizeVector2d(vectorA)
	vectorB = normalizeVector2d(vectorB)
	local radian = atan2(vectorA[2], vectorA[1]) - atan2(vectorB[2], vectorB[1])
	local val = (360 * radian) / (2 * pi)
	return normalizeDegreeRange(val)
end

-- returns the rotation degrees between mouse move vector and defined forward vector
local function getMouseFacingDegree(mouseVec)
	local forwVec = { 0.0, 1.0 }
	return getRotationVectors2d(forwVec, mouseVec)
end

local function getFacingByMouseDelta(mouseDeltaX, mouseDeltaY)
	local camVecs = spGetCameraVectors() -- would be cool to update this only on a callin like "onCameraMoved()"

	local mouseMovVec = { mouseDeltaX, mouseDeltaY }
	local mMovVecLen = getVector2dLen(mouseMovVec)

	if mMovVecLen < sens then
		return nil
	end

	local mouseDegree = getMouseFacingDegree(mouseMovVec)

	-- calculate the camera angle
	local camRight2d = { camVecs.right[1], -camVecs.right[3] }
	local camDegree = getMouseFacingDegree(camRight2d) - 90
	camDegree = normalizeDegreeRange(camDegree)

	-- take the camera angle into account here
	mouseDegree = mouseDegree + camDegree
	mouseDegree = normalizeDegreeRange(mouseDegree)

	local newFacing = nil
	if mouseDegree >= 280.0 or mouseDegree < 45.0 then
		newFacing = 2
	elseif mouseDegree >= 45.0 and mouseDegree < 135.0 then
		newFacing = 1
	elseif mouseDegree >= 135.0 and mouseDegree < 225.0 then
		newFacing = 0
	elseif mouseDegree >= 225.0 and mouseDegree < 280.0 then
		newFacing = 3
	else
		newFacing = 0 -- should not happen
	end

	return newFacing
end

--------------------------------------------------------------------------------
-- Left+right chord placement
--
-- With the left button held on a build command the engine's GuiHandler owns the mouse, so it also receives the
-- right button press/release used to rotate the facing. Releasing the right button while the left one is still
-- held makes the engine cancel the build command and drop its pending left click, so the eventual left release
-- places nothing. We can't intercept those events (the engine never asks Lua), so watch the button state instead:
-- restore the build command when the right button comes up mid-chord and issue the placement ourselves when the
-- left button is finally released.

local chordCmdID -- build command active while both buttons were held
local pendingCmdID -- build command to place when the left button is released
local prevLmb = false

local function placePendingBuild(mx, my)
	local _, cmdID, cmdType = spGetActiveCommand()
	if cmdID ~= pendingCmdID or cmdType ~= CMDTYPE_ICON_BUILDING then
		return -- the player switched command in the meantime
	end

	local _, coords = spTraceScreenRay(mx, my, true, true)
	if not coords then
		return
	end

	local unitDefID = -cmdID
	local facing = spGetBuildFacing()
	local bx, by, bz = spPos2BuildPos(unitDefID, coords[1], coords[2], coords[3], facing)
	if spTestBuildOrder(unitDefID, bx, by, bz, facing) == 0 then
		return -- blocked: keep the command active, like the engine does on a failed click
	end

	local alt, ctrl, meta, shift = spGetModKeyState()
	local opts = {}
	if alt then
		opts[#opts + 1] = "alt"
	end
	if ctrl then
		opts[#opts + 1] = "ctrl"
	end
	if meta then
		opts[#opts + 1] = "meta"
	end
	if shift then
		opts[#opts + 1] = "shift"
	end
	spGiveOrder(cmdID, { bx, by, bz, facing }, opts)

	-- mirror the engine: the command stays active only while queueing
	if not shift and not spGetInvertQueueKey() then
		spSetActiveCommand(nil)
	end
end

local function trackChordPlacement()
	local mx, my, lmb, _, rmb = spGetMouseState()
	local _, cmdID, cmdType = spGetActiveCommand()
	local buildCmdActive = (cmdType == CMDTYPE_ICON_BUILDING)

	if lmb and rmb then
		if buildCmdActive then
			chordCmdID = cmdID
		end
		-- a right press re-arms the engine's pending click, so it handles a left release during this chord itself
		pendingCmdID = nil
	elseif lmb then
		if chordCmdID then
			-- right button released mid-chord: the engine just cancelled the build command
			if not buildCmdActive then
				local cmdIndex = spGetCmdDescIndex(chordCmdID)
				if cmdIndex and cmdIndex >= 0 then
					spSetActiveCommand(cmdIndex)
				end
			end
			pendingCmdID = chordCmdID
			chordCmdID = nil
		end
	else
		if pendingCmdID and prevLmb and not rmb then
			placePendingBuild(mx, my)
		end
		pendingCmdID = nil
		chordCmdID = nil
	end
	prevLmb = lmb
end

local function manipulateFacing()
	ineffect = false

	-- check if valid command
	local _, cmd_id, cmd_type = spGetActiveCommand()
	if not cmd_id then
		return
	end

	-- check if build command
	if cmd_type ~= 20 then
		return -- quit here if not a build command
	end

	local mx, my, lmb, mmb, rmb = spGetMouseState()
	if lmb and rmb then
		if not inDrag then
			mouseDeltaX = 0
			mouseDeltaY = 0
			mouseXStartRotate = mx
			mouseYStartRotate = my
			mouseXStartDrag = mx
			mouseYStartDrag = my
		end
		inDrag = true
	else
		inDrag = false
	end

	if inDrag then
		local curDeltaX = mx - mouseXStartRotate
		mouseDeltaX = mouseDeltaX + curDeltaX
		local curDeltaY = my - mouseYStartRotate
		mouseDeltaY = mouseDeltaY + curDeltaY

		local newFacing = getFacingByMouseDelta(mouseDeltaX, mouseDeltaY)
		if newFacing ~= nil then
			mouseDeltaX = 0
			mouseDeltaY = 0

			if newFacing ~= spGetBuildFacing() then
				spSetBuildFacing(newFacing)
			end
		end

		if mouseXStartRotate ~= mx or mouseYStartRotate ~= my then
			spWarpMouse(mouseXStartRotate, mouseYStartRotate) -- set old mouse coords to prevent mouse movement
		end
	end
	ineffect = true
end

local function drawOrientation()
	local forceShowUnitDefID = getForceShowUnitDefID()
	if not ineffect and not forceShowUnitDefID then
		return
	end

	local _, cmd_id, cmd_type = spGetActiveCommand()
	if cmd_type ~= 20 and not forceShowUnitDefID then
		return -- quit here if not a build command
	end

	local unitDefID = forceShowUnitDefID or -cmd_id
	if drawForAll == false and isntFactory[unitDefID] then
		return
	end

	local mx, my = spGetMouseState()
	local _, _, _, shift = spGetModKeyState()
	if shift and inDrag then
		mx = mouseXStartDrag
		my = mouseYStartDrag
	end

	local _, coords = spTraceScreenRay(mx, my, true, true)
	if not coords then
		return
	end

	local facing = spGetBuildFacing()
	local centerX, centerY, centerZ = spPos2BuildPos(unitDefID, coords[1], coords[2], coords[3], facing)
	local transSpace = unitZsize[unitDefID] * 4 --should be ysize but its not there?!?
	local transDistance = transSpace + ARROW_GAP -- footprint edge plus a gap so the arrow doesn't touch the building
	local transX, transZ = 0, 0
	if facing == 0 then
		transZ = transDistance
	elseif facing == 1 then
		transX = transDistance
	elseif facing == 2 then
		transZ = -transDistance
	elseif facing == 3 then
		transX = -transDistance
	end

	local worldScale = (transSpace or 70) / 70

	glLineWidth(1)
	glColor(0.0, 1.0, 0.0, 0.45)

	glPushMatrix()
	gl.DepthTest(false)
	glTranslate(centerX + transX, centerY, centerZ + transZ)
	glRotate((3 + facing) * 90, 0, 1, 0)
	glScale(worldScale, 1.0, worldScale)
	if arrowShader then
		glUseShader(arrowShader)
		glUniform(arrowUniforms.worldScale, worldScale)
		glBeginEnd(GL_QUADS, drawArrowQuad)
		glUseShader(0)
	else
		glBeginEnd(GL_TRIANGLES, drawArrowTriangle)
	end
	gl.DepthTest(true)
	glPopMatrix()
	glColor(1.0, 1.0, 1.0, 1.0)
end

function widget:GameStart()
	gameStarted = true
	maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
	maybeRemoveSelf()
end

function widget:Initialize()
	if Spring.IsReplay() or spGetGameFrame() > 0 then
		maybeRemoveSelf()
	end

	initArrowShader()

	WG.easyfacing = {}
	WG.easyfacing.setForceShow = function(reason, enabled, unitDefID)
		if enabled then
			forceShow[reason] = unitDefID
		else
			forceShow[reason] = nil
		end
	end
end

function widget:Shutdown()
	deleteArrowShader()
	WG.easyfacing = nil
end

function widget:Update()
	trackChordPlacement()

	local time = floor(spGetGameSeconds())

	-- update timers once every <updateInt> seconds
	if time % updateInt == 0 and time ~= lastTimeUpdate then
		lastTimeUpdate = time
	else
		manipulateFacing()
	end
end

function widget:DrawWorld()
	drawOrientation()
end
