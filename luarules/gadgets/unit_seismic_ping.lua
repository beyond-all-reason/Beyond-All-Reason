function gadget:GetInfo()
	return {
		name = "Seismic Ping",
		desc = "Draw seismic pings effect",
		author = "Floris",
		date = "2026",
		license = "GNU GPL, v2 or later",
		version = 1,
		layer = 5,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return
end

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMyAllyTeamID = Spring.GetLocalAllyTeamID
local spGetGroundHeight = Spring.GetGroundHeight
local spGetCameraPosition = Spring.GetCameraPosition
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitIsCloaked = Spring.GetUnitIsCloaked
local spIsGUIHidden = Spring.IsGUIHidden
local spIsSphereInView = Spring.IsSphereInView

local glColor = gl.Color
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glRotate = gl.Rotate
local glScale = gl.Scale
local glBlending = gl.Blending
local glDepthTest = gl.DepthTest
local glBillboard = gl.Billboard
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local max = math.max
local min = math.min
local sqrt = math.sqrt
local floor = math.floor

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------
local pingLifetime = 0.95
local baseRadius = 15
local maxRadius = 19
local onlyCloakedUnits = true
local drawFlatOnMap = true
local hideWhenTerrainOccluded = true
local terrainOcclusionSamples = 6
local terrainOcclusionMargin = 8
local pingHeightOffset = drawFlatOnMap and 1.5 or 5

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local pings = {}
local pingCount = 0
local pingPool = {}
local pingPoolCount = 0
local gameTime = 0
local thicknessScale = 1.2

--------------------------------------------------------------------------------
-- Textures
--------------------------------------------------------------------------------
local atlasTexture = "LuaRules/Images/seismic_ping/seismic_atlas.png"
local atlasSprites = {
	outerRing = { 0 / 7, 0, 1 / 7, 1 },
	outerOutline = { 1 / 7, 0, 2 / 7, 1 },
	middleRing = { 2 / 7, 0, 3 / 7, 1 },
	middleOutline = { 3 / 7, 0, 4 / 7, 1 },
	innerRing = { 4 / 7, 0, 5 / 7, 1 },
	innerOutline = { 5 / 7, 0, 6 / 7, 1 },
	centerDot = { 6 / 7, 0, 7 / 7, 1 },
}

-- Texture radius in source image does not fill full quad, so apply scale compensation.
local outerQuadScale = 1.17
local middleQuadScale = 1.18
local innerQuadScale = 1.24
local centerQuadScale = 2.2

--------------------------------------------------------------------------------
-- Draw a textured billboard quad
--------------------------------------------------------------------------------
local function DrawTexturedQuad(sprite, scale, rotation)
	local s1, t1, s2, t2 = sprite[1], sprite[2], sprite[3], sprite[4]
	glPushMatrix()
	if rotation then
		glRotate(rotation, 0, 0, 1)
	end
	glScale(scale, scale, 1)
	glTexRect(-1, -1, 1, 1, s1, t1, s2, t2)
	glPopMatrix()
end

-- Cheap terrain line test: if terrain crosses camera->ping center line, hide full ping.
local function IsTerrainOccluded(camX, camY, camZ, pingX, pingY, pingZ)
	local dx = pingX - camX
	local dy = pingY - camY
	local dz = pingZ - camZ
	local distance = sqrt(dx * dx + dy * dy + dz * dz)
	local samples = terrainOcclusionSamples + min(8, floor(distance / 700))
	local step = 1 / (samples + 1)

	for i = 1, samples do
		local t = i * step
		local sx = camX + dx * t
		local sy = camY + dy * t
		local sz = camZ + dz * t
		if spGetGroundHeight(sx, sz) > sy + terrainOcclusionMargin then
			return true
		end
	end

	return false
end

--------------------------------------------------------------------------------
-- Draw a single seismic ping with rotating textured rings
--------------------------------------------------------------------------------
local function DrawPing(ping, currentTime, cameraDistance)
	local age = currentTime - ping.startTime
	if age > pingLifetime then
		return false
	end

	local progress = age / pingLifetime
	local radius = (baseRadius + (maxRadius - baseRadius) * progress) * thicknessScale
	local wx, wy, wz = ping.x, ping.y, ping.z

	glPushMatrix()
	glTranslate(wx, wy + pingHeightOffset, wz)
	if drawFlatOnMap then
		glRotate(90, 1, 0, 0)
	else
		glBillboard()
	end
	glTexture(atlasTexture)

	-- Calculate all progress/alpha values
	local rotation1 = currentTime * 70
	local outerProgress = min(1, progress * 1.3)
	local outerAlpha = max(0, (1 - outerProgress) * 0.7)
	local outerRadius = radius * 1.15 - (radius * progress * 0.25)

	local rotation2 = -currentTime * 150
	local middleProgress = max(0, min(1, (progress - 0.1) / 0.9))
	local middleAlpha = max(0, (1 - middleProgress) * 0.85)
	local middleRadius = radius + (radius * progress * 0.4)

	local rotation3 = currentTime * 90
	local innerProgress = max(0, min(1, (progress - 0.15) / 0.85))
	local innerAlpha = max(0, (1 - innerProgress))
	local innerRadius = radius - (radius * progress * 0.45)

	-- PASS 1: Draw all dark outlines with normal blending (skip when camera is far away for performance)
	if cameraDistance < 3000 then
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

		-- Outer outlines
		if outerAlpha > 0.001 then
			glColor(0.09, 0, 0, outerAlpha * 0.25)
			DrawTexturedQuad(atlasSprites.outerOutline, outerRadius * outerQuadScale, rotation1)
		end

		-- Middle outlines
		if middleAlpha > 0.001 then
			glColor(0.09, 0, 0, middleAlpha * 0.25)
			DrawTexturedQuad(atlasSprites.middleOutline, middleRadius * middleQuadScale, rotation2)
		end

		-- Inner outlines
		if innerAlpha > 0.001 then
			glColor(0.07, 0, 0, innerAlpha * 0.25)
			DrawTexturedQuad(atlasSprites.innerOutline, innerRadius * innerQuadScale, rotation3)
		end
	end

	-- PASS 2: Draw all bright arcs with additive blending
	glBlending(GL_SRC_ALPHA, GL_ONE)

	-- Outer ring - 4 arcs rotating clockwise
	if outerAlpha > 0.001 then
		glColor(1, 0.1, 0.09, outerAlpha)
		DrawTexturedQuad(atlasSprites.outerRing, outerRadius * outerQuadScale, rotation1)
	end

	-- Middle ring - 3 arcs rotating counter-clockwise
	if middleAlpha > 0.001 then
		glColor(1, 0.22, 0.2, middleAlpha)
		DrawTexturedQuad(atlasSprites.middleRing, middleRadius * middleQuadScale, rotation2)
	end

	-- Inner ring - 2 arcs rotating clockwise
	if innerAlpha > 0.001 then
		glColor(1, 0.37, 0.33, innerAlpha)
		DrawTexturedQuad(atlasSprites.innerRing, innerRadius * innerQuadScale, rotation3)
	end

	-- Center dot (shrinks from large to small with fade in/out)
	local centerProgress = min(1, progress * 1.8)
	local centerScale = baseRadius * 0.82 * (1 - centerProgress) * thicknessScale
	if centerScale > 0.1 then
		local centerAlphaMultiplier
		if centerProgress < 0.2 then
			centerAlphaMultiplier = centerProgress / 0.2
		else
			centerAlphaMultiplier = (1 - centerProgress) / 0.8
		end
		local centerAlpha = max(0, centerAlphaMultiplier * 0.6)
		glColor(1, 0.25, 0.23, centerAlpha)
		DrawTexturedQuad(atlasSprites.centerDot, centerScale * centerQuadScale)
	end

	glTexture(false)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glPopMatrix()

	return true
end

--------------------------------------------------------------------------------
-- callins
--------------------------------------------------------------------------------
function gadget:Initialize() end

function gadget:ViewResize(vsx, vsy) end

function gadget:Shutdown() end

function gadget:UnitSeismicPing(x, y, z, strength, allyTeam, unitID, unitDefID)
	local spec, fullview = spGetSpectatingState()
	local myAllyTeam = spGetMyAllyTeamID()
	local unitAllyTeam = spGetUnitAllyTeam(unitID)

	if (spec or allyTeam == myAllyTeam) and unitAllyTeam ~= allyTeam then
		if spec and not fullview then
			if allyTeam ~= myAllyTeam then
				return
			end
		end
		if onlyCloakedUnits and not spGetUnitIsCloaked(unitID) then
			return
		end

		local ping
		if pingPoolCount > 0 then
			ping = pingPool[pingPoolCount]
			pingPool[pingPoolCount] = nil
			pingPoolCount = pingPoolCount - 1
		else
			ping = {}
		end

		ping.x = x
		ping.y = spGetGroundHeight(x, z) or y
		ping.z = z
		ping.startTime = gameTime

		pingCount = pingCount + 1
		pings[pingCount] = ping

		-- Inform LuaUI with full payload; widgets that only use first args stay compatible.
		Script.LuaUI.UnitSeismicPing(x, y, z, strength, allyTeam, unitID, unitDefID)
	end
end

function gadget:Update(dt)
	gameTime = gameTime + dt
end

function gadget:DrawWorldPreUnit()
	if pingCount == 0 or spIsGUIHidden() then
		return
	end

	glDepthTest(false)

	local cx, cy, cz = spGetCameraPosition()
	local cullRadius = maxRadius * thicknessScale * 2.5

	local currentTime = gameTime
	local i = 1
	while i <= pingCount do
		local ping = pings[i]
		if spIsSphereInView(ping.x, ping.y + pingHeightOffset, ping.z, cullRadius) then
			local isOccluded = false
			if hideWhenTerrainOccluded then
				isOccluded = IsTerrainOccluded(cx, cy, cz, ping.x, ping.y + pingHeightOffset, ping.z)
			end

			if isOccluded then
				if currentTime - ping.startTime > pingLifetime then
					local dead = ping
					pings[i] = pings[pingCount]
					pings[pingCount] = nil
					pingCount = pingCount - 1
					pingPoolCount = pingPoolCount + 1
					pingPool[pingPoolCount] = dead
				else
					i = i + 1
				end
			-- Ping is visible and not terrain-occluded, try to draw it
			elseif not DrawPing(ping, currentTime, cy) then
				local dead = ping
				pings[i] = pings[pingCount]
				pings[pingCount] = nil
				pingCount = pingCount - 1
				pingPoolCount = pingPoolCount + 1
				pingPool[pingPoolCount] = dead
			else
				i = i + 1
			end
		else
			-- Ping is outside frustum, skip drawing but only remove when expired
			if currentTime - ping.startTime > pingLifetime then
				local dead = ping
				pings[i] = pings[pingCount]
				pings[pingCount] = nil
				pingCount = pingCount - 1
				pingPoolCount = pingPoolCount + 1
				pingPool[pingPoolCount] = dead
			else
				i = i + 1
			end
		end
	end

	glDepthTest(true)
	glColor(1, 1, 1, 1)
end
