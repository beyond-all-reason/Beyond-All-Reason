local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Projectile Target AoE",
		desc = "Shows impact target indicators for launched starburst missiles and nukes.",
		author = "Floris",
		version = "1.0",
		date = "January 2026",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true
	}
end

--------------------------------------------------------------------------------
-- Localized functions
--------------------------------------------------------------------------------
local max = math.max
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos
local pi = math.pi
local tau = math.tau
local rad = math.rad

local osClock = os.clock

local spGetProjectilesInRectangle = Spring.GetProjectilesInRectangle
local spGetProjectileDefID = Spring.GetProjectileDefID
local spGetProjectileTarget = Spring.GetProjectileTarget
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetGroundHeight = Spring.GetGroundHeight
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetProjectileTeamID = Spring.GetProjectileTeamID
local spGetTeamInfo = Spring.GetTeamInfo
local spGetUnitPosition = Spring.GetUnitPosition
local spGetViewGeometry = Spring.GetViewGeometry
local spIsGUIHidden = Spring.IsGUIHidden
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMyTeamID = Spring.GetMyTeamID

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

local glBeginEnd = gl.BeginEnd
local glCallList = gl.CallList
local glCreateList = gl.CreateList
local glColor = gl.Color
local glDeleteList = gl.DeleteList
local glLineWidth = gl.LineWidth
local glLoadIdentity = gl.LoadIdentity
local glPointSize = gl.PointSize
local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glRotate = gl.Rotate
local glScale = gl.Scale
local glTranslate = gl.Translate
local glVertex = gl.Vertex
local glDepthTest = gl.DepthTest

local GL_LINE_LOOP = GL.LINE_LOOP
local GL_LINES = GL.LINES
local GL_LINE_STRIP = GL.LINE_STRIP
local GL_TRIANGLE_STRIP = GL.TRIANGLE_STRIP
local GL_POINTS = GL.POINTS

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------
local Config = {
	minAoeThreshold = 30,         -- Minimum AOE to show indicator
	circleDivs = 32,              -- Circle segments
	baseLineWidth = 1.3,          -- Base line width
	updateInterval = 0.25,        -- Seconds between projectile updates (0 = every frame)

	-- Colors (RGBA)
	allyColor = { 1.0, 0.3, 0.2, 1.0 },           -- Red for allied (your missiles)
	enemyColor = { 1.0, 0.3, 0.2, 1.0 },          -- Red for enemy (same, they shouldn't show for players)
	paralyzerColor = { 0.2, 0.8, 1.0, 1.0 },      -- Cyan for paralyzer weapons
	nukeAllyColor = { 1.0, 0.2, 0.0, 1.0 },       -- Orange for allied nukes
	nukeEnemyColor = { 1.0, 0.0, 0.0, 1.0 },      -- Bright red for enemy nukes

	-- Animation
	blinkSpeed = 0,               -- Blinks per second at max urgency
	rotationSpeedMax = 120,        -- Degrees per second at start
	rotationSpeedMin = 40,        -- Degrees per second at end
	pulseMinOpacity = 0.2,
	pulseMaxOpacity = 0.4,

	-- Ring animation
	ringCount = 4,                -- Number of concentric rings
	ringPulseSpeed = 0.02,        -- Ring pulse animation speed
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local trackedProjectiles = {}     -- Active projectiles we're tracking
local trackedCount = 0            -- Number of tracked projectiles (avoids pairs iteration)
local starburstWeapons = {}       -- Cache of starburst weapon info
local circleList = nil            -- Display list for circle
local trefoilList = nil           -- Display list for nuclear trefoil
local targetMarkerList = nil      -- Display list for target marker
local screenLineWidthScale = 1.0
local myAllyTeamID = 0
local myTeamID = 0
local isSpectator = false
local updateAccum = 0             -- Accumulator for update rate limiting

--------------------------------------------------------------------------------
-- Initialization - Build weapon cache
--------------------------------------------------------------------------------
local function BuildWeaponCache()
	for wdid, wd in pairs(WeaponDefs) do
		if wd.type == "StarburstLauncher" and wd.interceptor == 0 then
			local aoe = wd.damageAreaOfEffect or 0
			if aoe >= Config.minAoeThreshold then
				local isNuke = wd.customParams and wd.customParams.nuclear
				local isParalyzer = wd.paralyzer or false
				starburstWeapons[wdid] = {
					aoe = aoe,
					isNuke = isNuke,
					isParalyzer = isParalyzer,
					name = wd.name,
					range = wd.range,
					projectileSpeed = wd.projectilespeed or 1,
				}
				--Spring.Echo(wdid, wd.name, aoe, wd.range, isNuke, isParalyzer)
			 end
		end
	end
end

--------------------------------------------------------------------------------
-- Display Lists
--------------------------------------------------------------------------------
local function CreateDisplayLists()
	-- Circle display list
	circleList = glCreateList(function()
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 0, Config.circleDivs - 1 do
				local theta = tau * i / Config.circleDivs
				glVertex(cos(theta), 0, sin(theta))
			end
		end)
	end)

	-- Target marker (crosshair style with inner circle and ticks)
	targetMarkerList = glCreateList(function()
		local innerRadius = 0.3
		local outerRadius = 0.5
		local tickLength = 0.15

		-- Inner circle
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 0, Config.circleDivs - 1 do
				local theta = tau * i / Config.circleDivs
				glVertex(cos(theta) * innerRadius, 0, sin(theta) * innerRadius)
			end
		end)

		-- Cross ticks pointing outward
		for i = 0, 3 do
			local angle = i * (pi / 2)
			local cosA, sinA = cos(angle), sin(angle)
			glBeginEnd(GL_LINES, function()
				glVertex(cosA * outerRadius, 0, sinA * outerRadius)
				glVertex(cosA * (outerRadius + tickLength), 0, sinA * (outerRadius + tickLength))
			end)
		end
	end)

	-- Nuclear trefoil display list
	trefoilList = glCreateList(function()
		local innerRadius = 0.18
		local outerRadius = 0.85
		local bladeAngle = rad(60)
		local bladeSegments = 16

		for blade = 0, 2 do
			local baseAngle = blade * rad(120) - rad(90)
			local startAngle = baseAngle - bladeAngle / 2
			local step = bladeAngle / bladeSegments

			glBeginEnd(GL_TRIANGLE_STRIP, function()
				for i = 0, bladeSegments do
					local angle = startAngle + i * step
					local cosA, sinA = cos(angle), sin(angle)
					glVertex(cosA * innerRadius, 0, sinA * innerRadius)
					glVertex(cosA * outerRadius, 0, sinA * outerRadius)
				end
			end)
		end
	end)
end

local function DeleteDisplayLists()
	if circleList then glDeleteList(circleList) end
	if trefoilList then glDeleteList(trefoilList) end
	if targetMarkerList then glDeleteList(targetMarkerList) end
end

--------------------------------------------------------------------------------
-- Screen scaling
--------------------------------------------------------------------------------
local function UpdateScreenScale()
	local _, screenHeight = spGetViewGeometry()
	screenLineWidthScale = 1.0 + (screenHeight - 1080) * (1.5 / 1080)
	if screenLineWidthScale < 0.5 then screenLineWidthScale = 0.5 end
end

--------------------------------------------------------------------------------
-- Helper functions
--------------------------------------------------------------------------------
local function DrawCircle(x, y, z, radius)
	glPushMatrix()
	glTranslate(x, y, z)
	glScale(radius, radius, radius)
	glCallList(circleList)
	glPopMatrix()
end

local function DrawTrefoil(x, y, z, radius, rotation)
	glPushMatrix()
	glTranslate(x, y, z)
	glRotate(rotation, 0, 1, 0)
	glScale(radius, radius, radius)
	glCallList(trefoilList)
	glPopMatrix()
end

local function DrawTargetMarker(x, y, z, radius, rotation)
	glPushMatrix()
	glTranslate(x, y, z)
	glRotate(rotation, 0, 1, 0)
	glScale(radius, radius, radius)
	glCallList(targetMarkerList)
	glPopMatrix()
end

local function SetColor(color, alpha)
	glColor(color[1], color[2], color[3], color[4] * alpha)
end

--------------------------------------------------------------------------------
-- Projectile tracking
--------------------------------------------------------------------------------
local function GetProjectileTargetPos(proID)
	local targetType, targetData = spGetProjectileTarget(proID)

	if not targetType then
		return nil
	end

	-- Ground target
	if targetType == 103 then  -- ASCII 'g'
		if type(targetData) == "table" then
			return targetData[1], targetData[2], targetData[3]
		end
	-- Unit target
	elseif targetType == 117 then  -- ASCII 'u'
		local ux, uy, uz = spGetUnitPosition(targetData)
		if ux then
			return ux, uy, uz
		end
	-- Feature target
	elseif targetType == 102 then  -- ASCII 'f'
		-- Could add feature position lookup if needed
		return nil
	-- Projectile target (interceptor)
	elseif targetType == 112 then  -- ASCII 'p'
		local px, py, pz = spGetProjectilePosition(targetData)
		if px then
			return px, py, pz
		end
	end

	return nil
end

local function UpdateTrackedProjectiles()
	local currentTime = osClock()
	local allProjectiles = spGetProjectilesInRectangle(0, 0, mapSizeX, mapSizeZ)
	local activeIDs = {}
	local newCount = 0

	if not allProjectiles then
		-- Clear all tracked if no projectiles exist
		if trackedCount > 0 then
			trackedProjectiles = {}
			trackedCount = 0
		end
		return
	end

	for i = 1, #allProjectiles do
		local proID = allProjectiles[i]
		local defID = spGetProjectileDefID(proID)
		local weaponInfo = starburstWeapons[defID]

		if weaponInfo then
			local existingData = trackedProjectiles[proID]

			if existingData then
				-- Spectators see all, players only see their own team
				if isSpectator or existingData.isOwnTeam then
					activeIDs[proID] = true
					newCount = newCount + 1
					-- Update projectile position
					local px, py, pz = spGetProjectilePosition(proID)
					if px then
						existingData.projectileX = px
						existingData.projectileY = py
						existingData.projectileZ = pz
					end
				end
			else
				-- New projectile - check team
				local teamID = spGetProjectileTeamID(proID)
				local isOwnTeam = (teamID == myTeamID)
				local _, _, _, _, _, allyTeamID = spGetTeamInfo(teamID)
				local isAlly = (allyTeamID == myAllyTeamID)

				-- Spectators see all, players only see their own team's projectiles
				if isSpectator or isOwnTeam then
					local tx, ty, tz = GetProjectileTargetPos(proID)
					local px, py, pz = spGetProjectilePosition(proID)

					if tx and px then
						local dx, dy, dz = tx - px, ty - py, tz - pz
						local distance = sqrt(dx * dx + dy * dy + dz * dz)
						local speed = max(weaponInfo.projectileSpeed * 30, 1) -- Cache speed
						local estimatedFlightTime = distance / speed

						activeIDs[proID] = true
						newCount = newCount + 1

						trackedProjectiles[proID] = {
							weaponInfo = weaponInfo,
							targetX = tx,
							targetY = ty,
							targetZ = tz,
							projectileX = px,
							projectileY = py,
							projectileZ = pz,
							startTime = currentTime,
							initialFlightTime = estimatedFlightTime, -- Store initial for smooth progress
							isOwnTeam = isOwnTeam,
							isAlly = isAlly,
							speed = speed,  -- Cache speed in data
						}
					end
				end
			end
		end
	end

	-- Remove projectiles that no longer exist
	if trackedCount > 0 then
		for proID in pairs(trackedProjectiles) do
			if not activeIDs[proID] then
				trackedProjectiles[proID] = nil
			end
		end
	end

	trackedCount = newCount
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------
local function DrawImpactIndicator(data, currentTime)
	local tx, ty, tz = data.targetX, data.targetY, data.targetZ
	local weaponInfo = data.weaponInfo
	local aoe = weaponInfo.aoe
	local isNuke = weaponInfo.isNuke

	-- Calculate progress using initial flight time for smooth animation
	local elapsed = currentTime - data.startTime
	local progress = elapsed / max(data.initialFlightTime, 0.1)
	if progress > 1 then progress = 1 elseif progress < 0 then progress = 0 end

	-- Select color based on paralyzer, nuke, and ally/enemy status
	local color
	if weaponInfo.isParalyzer then
		color = Config.paralyzerColor
	elseif isNuke then
		color = data.isAlly and Config.nukeAllyColor or Config.nukeEnemyColor
	else
		color = data.isAlly and Config.allyColor or Config.enemyColor
	end

	-- Animation calculations (simplified - blinkSpeed is 0 by default)
	local blinkPhase = 0
	if Config.blinkSpeed > 0 then
		local blinkFreq = Config.blinkSpeed * (1 + progress * 2)
		blinkPhase = sin(currentTime * blinkFreq * tau)
	end

	local baseOpacity = Config.pulseMinOpacity + (Config.pulseMaxOpacity - Config.pulseMinOpacity) * 0.5
	local minOpacity = Config.pulseMinOpacity + progress * 0.3
	local opacity = minOpacity > baseOpacity and minOpacity or baseOpacity

	-- Fade in during first half of flight time
	if progress < 0.5 then
		opacity = opacity * (progress * 2)
	end

	-- Rotation - integrate variable speed for smooth deceleration
	-- Speed decreases linearly from max to min as progress goes 0->1
	-- Integral gives: rotation = elapsed * (maxSpeed - (maxSpeed - minSpeed) * progress / 2)
	local avgSpeed = Config.rotationSpeedMax - (Config.rotationSpeedMax - Config.rotationSpeedMin) * progress * 0.5
	local rotation = (elapsed * avgSpeed) % 360

	-- Ensure target Y is at ground level
	local groundY = spGetGroundHeight(tx, tz)
	if groundY and groundY > ty then ty = groundY end

	if isNuke then
		-- Trefoil symbol in center (rotating, pulsing)
		local trefoilSize = aoe * 0.75 * (0.6 + 0.08 * sin(currentTime * tau * 0.4))
		local trefoilOpacity = 0.35 + 0.1 * progress + 0.1 * blinkPhase
		SetColor(color, trefoilOpacity)
		DrawTrefoil(tx, ty + 3, tz, trefoilSize, rotation)
	else
		-- Regular starburst - draw target marker and rings
		-- Inner progress rings (shrinking as impact approaches)
		local ringCount = Config.ringCount
		for i = 1, ringCount do
			local ringProgress = i / ringCount
			local ringRadius = aoe * (1 - progress * 0.5) * ringProgress
			local ringOpacity = opacity * (0.2 + 0.3 * ringProgress)
			local ringPhase = sin(currentTime * tau * 1.5 + i * pi / 3)
			ringOpacity = ringOpacity * (0.6 + 0.4 * ringPhase)

			SetColor(color, ringOpacity)
			DrawCircle(tx, ty + 2, tz, ringRadius)
		end

		-- Center target marker (rotating)
		local markerSize = aoe * 0.4
		local markerOpacity = 0.6 + 0.3 * blinkPhase
		SetColor(color, markerOpacity)
		DrawTargetMarker(tx, ty + 3, tz, markerSize, -rotation * 0.5)
	end
end

--------------------------------------------------------------------------------
-- Widget callins
--------------------------------------------------------------------------------
function widget:Initialize()
	myAllyTeamID = spGetMyAllyTeamID()
	myTeamID = spGetMyTeamID()
	isSpectator = spGetSpectatingState()
	BuildWeaponCache()
	CreateDisplayLists()
	UpdateScreenScale()
end

function widget:Shutdown()
	DeleteDisplayLists()
end

function widget:ViewResize()
	UpdateScreenScale()
end

function widget:PlayerChanged(playerID)
	myAllyTeamID = spGetMyAllyTeamID()
	myTeamID = spGetMyTeamID()
	isSpectator = spGetSpectatingState()
	-- Clear tracked projectiles when player state changes
	trackedProjectiles = {}
	trackedCount = 0
end

function widget:Update(dt)
	-- Rate limit updates for performance
	updateAccum = updateAccum + dt
	if updateAccum >= Config.updateInterval then
		updateAccum = 0
		UpdateTrackedProjectiles()
	end
end

function widget:DrawWorld()
	if spIsGUIHidden() or trackedCount == 0 then return end

	-- Set GL state once for all indicators
	glDepthTest(false)
	glLineWidth(Config.baseLineWidth * screenLineWidthScale)

	local currentTime = osClock()
	for _, data in pairs(trackedProjectiles) do
		DrawImpactIndicator(data, currentTime)
	end

	-- Restore GL state
	glDepthTest(true)
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

function widget:DrawInMiniMap(sx, sy)
	if trackedCount == 0 then return end

	-- Check if any nukes are being tracked
	local hasNukes = false
	for _, data in pairs(trackedProjectiles) do
		if data.weaponInfo.isNuke then
			hasNukes = true
			break
		end
	end
	if not hasNukes then return end

	-- Set up minimap coordinate system
	-- Widgets draw in pixel coords [0, sx] x [0, sy] where (0,0) is top-left
	-- World X maps to pixel X: worldX / mapSizeX * sx
	-- World Z maps to pixel Y: (1 - worldZ / mapSizeZ) * sy (Y flipped, north=top)
	--
	-- For PIP mode: the PIP widget sets up gl.Ortho to transform these same pixel
	-- coords to show only the visible portion, so we don't need special handling.

	local currentTime = osClock()

	-- Draw for each nuke
	for _, data in pairs(trackedProjectiles) do
		if data.weaponInfo.isNuke then
			local tx, tz = data.targetX, data.targetZ
			local px, pz = data.projectileX, data.projectileZ
			local aoe = data.weaponInfo.aoe

			-- Convert world coords to minimap pixel coords
			local targetPixelX = tx / mapSizeX * sx
			local targetPixelY = (1 - tz / mapSizeZ) * sy  -- Y flipped
			local projPixelX = px / mapSizeX * sx
			local projPixelY = (1 - pz / mapSizeZ) * sy  -- Y flipped

			-- Calculate progress for animation
			local elapsed = currentTime - data.startTime
			local progress = elapsed / max(data.initialFlightTime, 0.1)
			if progress > 1 then progress = 1 elseif progress < 0 then progress = 0 end

			-- Animation calculations (matching DrawWorld)
			local blinkPhase = 0
			if Config.blinkSpeed > 0 then
				local blinkFreq = Config.blinkSpeed * (1 + progress * 2)
				blinkPhase = sin(currentTime * blinkFreq * tau)
			end

			-- Rotation
			local avgSpeed = Config.rotationSpeedMax - (Config.rotationSpeedMax - Config.rotationSpeedMin) * progress * 0.5
			local rotation = (elapsed * avgSpeed) % 360

			-- Select color
			local color = data.isAlly and Config.nukeAllyColor or Config.nukeEnemyColor

			-- Draw line from projectile to target
			glColor(1, 0.2, 0.2, 0.22)  -- Red line
			glLineWidth(1.5)
			glBeginEnd(GL_LINES, function()
				glVertex(projPixelX, projPixelY, 0)
				glVertex(targetPixelX, targetPixelY, 0)
			end)

			-- Trefoil symbol (scaled for minimap)
			-- Scale: pixels per world elmo
			local worldToPixelScale = sx / mapSizeX
			local trefoilWorldSize = aoe * 0.75 * (0.6 + 0.08 * sin(currentTime * tau * 0.4))
			local trefoilPixelSize = trefoilWorldSize * worldToPixelScale
			-- Clamp to reasonable size
			trefoilPixelSize = math.max(5, math.min(trefoilPixelSize, 40))

			local trefoilOpacity = 0.5 + 0.15 * progress + 0.1 * blinkPhase

			SetColor(color, trefoilOpacity)

			-- Draw trefoil at target position
			glPushMatrix()
			glTranslate(targetPixelX, targetPixelY, 0)
			glRotate(rotation, 0, 0, 1)  -- Rotate around Z since we're in 2D minimap space
			glScale(trefoilPixelSize, trefoilPixelSize, 1)

			-- Draw trefoil blades manually (since display list uses 3D coords)
			local innerRadius = 0.18
			local outerRadius = 0.85
			local bladeAngle = rad(60)
			local bladeSegments = 8  -- Fewer segments for minimap

			for blade = 0, 2 do
				local baseAngle = blade * rad(120) - rad(90)
				local startAngle = baseAngle - bladeAngle / 2
				local step = bladeAngle / bladeSegments

				glBeginEnd(GL_TRIANGLE_STRIP, function()
					for i = 0, bladeSegments do
						local angle = startAngle + i * step
						local cosA, sinA = cos(angle), sin(angle)
						glVertex(cosA * innerRadius, sinA * innerRadius)
						glVertex(cosA * outerRadius, sinA * outerRadius)
					end
				end)
			end

			glPopMatrix()
		end
	end

	glColor(1, 1, 1, 1)
end
