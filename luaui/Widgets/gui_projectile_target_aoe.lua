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
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Localized functions
--------------------------------------------------------------------------------
local max = math.max
local floor = math.floor
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos
local pi = math.pi
local tau = math.tau
local rad = math.rad

local osClock = os.clock

local spGetProjectilesInRectangle = SpringShared.GetProjectilesInRectangle
local spGetProjectileDefID = SpringShared.GetProjectileDefID
local spGetProjectileTarget = SpringShared.GetProjectileTarget
local spGetProjectilePosition = SpringShared.GetProjectilePosition
local spGetGroundHeight = SpringShared.GetGroundHeight
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetProjectileTeamID = SpringShared.GetProjectileTeamID
local spGetTeamInfo = SpringShared.GetTeamInfo
local spGetUnitPosition = SpringShared.GetUnitPosition
local spGetViewGeometry = SpringUnsynced.GetViewGeometry
local spIsGUIHidden = SpringUnsynced.IsGUIHidden
local spGetSpectatingState = SpringUnsynced.GetSpectatingState
local spGetMyTeamID = Spring.GetMyTeamID
local spIsSphereInView = SpringUnsynced.IsSphereInView

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

local glBeginEnd = gl.BeginEnd
local glCallList = gl.CallList
local glCreateList = gl.CreateList
local glColor = gl.Color
local glDeleteList = gl.DeleteList
local glLineWidth = gl.LineWidth
local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glRotate = gl.Rotate
local glScale = gl.Scale
local glTranslate = gl.Translate
local glVertex = gl.Vertex
local glDepthTest = gl.DepthTest

local GL_LINE_LOOP = GL.LINE_LOOP
local GL_LINES = GL.LINES
local GL_TRIANGLES = GL.TRIANGLES

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------
local Config = {
	minAoeThreshold = 30, -- Minimum AOE to show indicator
	circleDivs = 32, -- Circle segments
	baseLineWidth = 1.3, -- Base line width
	updateInterval = 0.25, -- Seconds between projectile updates (0 = every frame)

	-- Colors (RGBA)
	allyColor = { 1.0, 0.3, 0.2, 1.0 }, -- Red for allied (your missiles)
	enemyColor = { 1.0, 0.3, 0.2, 1.0 }, -- Red for enemy (same, they shouldn't show for players)
	paralyzerColor = { 0.2, 0.8, 1.0, 1.0 }, -- Cyan for paralyzer weapons
	nukeAllyColor = { 1.0, 0.2, 0.0, 1.0 }, -- Orange for allied nukes
	nukeEnemyColor = { 1.0, 0.0, 0.0, 1.0 }, -- Bright red for enemy nukes
	junoAllyColor = { 0.2, 1.0, 0.2, 1.0 }, -- Green for allied juno missiles
	junoEnemyColor = { 0.2, 1.0, 0.2, 1.0 }, -- Green for enemy juno missiles

	-- Animation
	blinkSpeed = 0, -- Blinks per second at max urgency
	rotationSpeedMax = 100, -- Degrees per second at start
	rotationSpeedMin = 30, -- Degrees per second at end
	pulseMinOpacity = 0.2,
	pulseMaxOpacity = 0.4,

	-- Ring animation
	ringCount = 4, -- Number of concentric rings
	ringPulseSpeed = 0.015, -- Ring pulse animation speed

	-- Nuke sub-layer animation
	nukeSubLayerMin = 12, -- Minimum sub-layers per trefoil blade
	nukeSubLayerMax = 64, -- Maximum sub-layers per trefoil blade
	nukeSubLayerAoeDivisor = 40, -- AOE / this = number of sub-layers
	nukeWaveSpeed = 1, -- Wave cycles per second (outside to inside)
	nukeWaveCount = 1.2, -- Number of wave bands visible across the shape at once
	nukeSubLayerGap = 0.25, -- Gap between sub-layers as fraction of layer thickness
	nukeBaseOpacity = 0.9, -- Overall opacity multiplier for nuke trefoil indicator (0-1)
	nukeGradientStrength = 0.75, -- Gradient strength: 0 = uniform, 1 = outer fully bright / inner fully dim
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local trackedProjectiles = {} -- Active projectiles we're tracking
local trackedCount = 0 -- Number of tracked projectiles (avoids pairs iteration)
local trackedNukeCount = 0 -- Number of tracked nuke projectiles (avoids iteration)
local starburstWeapons = {} -- Cache of starburst weapon info
local circleList = nil -- Display list for circle
local targetMarkerList = nil -- Display list for target marker
local screenLineWidthScale = 1.0
local myAllyTeamID = 0
local myTeamID = 0
local isSpectator = false
local updateAccum = 0 -- Accumulator for update rate limiting
local currentGeneration = 0 -- Generation counter for tracking (avoids temp table allocation)

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
					isJuno = wd.name:lower():find("juno") ~= nil,
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
end

local function DeleteDisplayLists()
	if circleList then
		glDeleteList(circleList)
	end
	if targetMarkerList then
		glDeleteList(targetMarkerList)
	end
end

--------------------------------------------------------------------------------
-- Pre-computed blade geometry (avoids per-frame trig)
--------------------------------------------------------------------------------
local BLADE_SEGMENTS = 16
local BLADE_SEGMENTS_MINI = 8
local bladeGeometry = {} -- [blade][segment] = {cos, sin} for world
local bladeGeometryMini = {} -- [blade][segment] = {cos, sin} for minimap

local function PrecomputeBladeGeometry()
	local bladeAngle = rad(60)
	-- World-space (16 segments)
	for blade = 0, 2 do
		bladeGeometry[blade] = {}
		local baseAngle = blade * rad(120) - rad(90)
		local startAngle = baseAngle - bladeAngle / 2
		local step = bladeAngle / BLADE_SEGMENTS
		for i = 0, BLADE_SEGMENTS do
			local angle = startAngle + i * step
			bladeGeometry[blade][i] = { cos(angle), sin(angle) }
		end
	end
	-- Minimap (8 segments)
	for blade = 0, 2 do
		bladeGeometryMini[blade] = {}
		local baseAngle = blade * rad(120) - rad(90)
		local startAngle = baseAngle - bladeAngle / 2
		local step = bladeAngle / BLADE_SEGMENTS_MINI
		for i = 0, BLADE_SEGMENTS_MINI do
			local angle = startAngle + i * step
			bladeGeometryMini[blade][i] = { cos(angle), sin(angle) }
		end
	end
end

--------------------------------------------------------------------------------
-- Screen scaling
--------------------------------------------------------------------------------
local function UpdateScreenScale()
	local _, screenHeight = spGetViewGeometry()
	screenLineWidthScale = 1.0 + (screenHeight - 1080) * (1.5 / 1080)
	if screenLineWidthScale < 0.5 then
		screenLineWidthScale = 0.5
	end
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

--------------------------------------------------------------------------------
-- Batched nuke drawing (world) — single closure, manual Y-axis rotation
-- Eliminates per-nuke closure allocation, matrix stack ops, and draw calls
--------------------------------------------------------------------------------
local nukeBatch = {}
local nukeBatchSize = 0

local function drawAllNukeGeometry()
	local innerR = 0.18
	local outerR = 0.85
	local nukeSubLayerMin = Config.nukeSubLayerMin
	local nukeSubLayerMax = Config.nukeSubLayerMax
	local nukeSubLayerAoeDivisor = Config.nukeSubLayerAoeDivisor
	local nukeSubLayerGap = Config.nukeSubLayerGap
	local nukeWaveCount = Config.nukeWaveCount
	local nukeGradientStrength = Config.nukeGradientStrength

	for n = 1, nukeBatchSize do
		local nd = nukeBatch[n]
		local tx, ty, tz = nd.tx, nd.ty, nd.tz
		local radius = nd.radius
		local cosR, sinR = nd.cosR, nd.sinR
		local cr, cg, cb, ca = nd.cr, nd.cg, nd.cb, nd.ca
		local baseOpacity = nd.baseOpacity
		local waveBase = nd.waveBase
		local aoe = nd.aoe

		local numLayers = max(nukeSubLayerMin, math.min(nukeSubLayerMax, floor(aoe / nukeSubLayerAoeDivisor)))
		if nukeBatchSize > 4 then
			numLayers = max(nukeSubLayerMin, floor(numLayers * 4 / nukeBatchSize))
		end

		local useGeo = (nukeBatchSize > 8) and bladeGeometryMini or bladeGeometry
		local useSegs = (nukeBatchSize > 8) and BLADE_SEGMENTS_MINI or BLADE_SEGMENTS

		local layerThickness = (outerR - innerR) / numLayers
		local gap = layerThickness * nukeSubLayerGap
		local invNumLayers = 1 / max(1, numLayers - 1)

		for layer = 1, numLayers do
			local layerInner = innerR + (layer - 1) * layerThickness + gap * 0.5
			local layerOuter = innerR + layer * layerThickness - gap * 0.5

			local normalizedPos = (layer - 1) * invNumLayers
			local wavePhase = (waveBase + normalizedPos * nukeWaveCount) * tau
			local waveBrightness = 0.25 + 0.75 * max(0, sin(wavePhase))
			local gradientMul = 1 - nukeGradientStrength * (1 - normalizedPos)
			local layerAlpha = ca * baseOpacity * waveBrightness * gradientMul

			if layerAlpha > 0.005 then -- skip invisible layers
				glColor(cr, cg, cb, layerAlpha)
				local rI = radius * layerInner
				local rO = radius * layerOuter

				for blade = 0, 2 do
					local bg = useGeo[blade]
					for i = 0, useSegs - 1 do
						local v0 = bg[i]
						local v1 = bg[i + 1]
						local c0, s0 = v0[1], v0[2]
						local c1, s1 = v1[1], v1[2]
						-- Manual Y-axis rotation (eliminates glPushMatrix/glRotate/glPopMatrix per nuke)
						local rc0 = c0 * cosR + s0 * sinR
						local rs0 = -c0 * sinR + s0 * cosR
						local rc1 = c1 * cosR + s1 * sinR
						local rs1 = -c1 * sinR + s1 * cosR

						glVertex(tx + rI * rc0, ty, tz + rI * rs0)
						glVertex(tx + rO * rc0, ty, tz + rO * rs0)
						glVertex(tx + rI * rc1, ty, tz + rI * rs1)

						glVertex(tx + rI * rc1, ty, tz + rI * rs1)
						glVertex(tx + rO * rc0, ty, tz + rO * rs0)
						glVertex(tx + rO * rc1, ty, tz + rO * rs1)
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Batched nuke drawing (minimap) — single closures, manual Z-axis rotation
--------------------------------------------------------------------------------
local minimapNukeBatch = {}
local minimapNukeBatchSize = 0

local function drawMinimapNukeLines()
	glColor(1, 0.2, 0.2, 0.22)
	for n = 1, minimapNukeBatchSize do
		local nd = minimapNukeBatch[n]
		glVertex(nd.projPX, nd.projPY, 0)
		glVertex(nd.targPX, nd.targPY, 0)
	end
end

local function drawMinimapNukeTrefoils()
	local innerR = 0.18
	local outerR = 0.85
	local nukeSubLayerMin = Config.nukeSubLayerMin
	local nukeSubLayerMax = Config.nukeSubLayerMax
	local nukeSubLayerAoeDivisor = Config.nukeSubLayerAoeDivisor
	local nukeSubLayerGap = Config.nukeSubLayerGap
	local nukeWaveCount = Config.nukeWaveCount
	local nukeGradientStrength = Config.nukeGradientStrength

	for n = 1, minimapNukeBatchSize do
		local nd = minimapNukeBatch[n]
		local px, py = nd.targPX, nd.targPY
		local size = nd.size
		local cosR, sinR = nd.cosR, nd.sinR
		local cr, cg, cb, ca = nd.cr, nd.cg, nd.cb, nd.ca
		local trefoilOpacity = nd.opacity
		local waveBase = nd.waveBase
		local aoe = nd.aoe

		local numLayers = max(nukeSubLayerMin, math.min(nukeSubLayerMax, floor(aoe / nukeSubLayerAoeDivisor)))
		if minimapNukeBatchSize > 4 then
			numLayers = max(nukeSubLayerMin, floor(numLayers * 4 / minimapNukeBatchSize))
		end

		local layerThickness = (outerR - innerR) / numLayers
		local gap = layerThickness * nukeSubLayerGap
		local invNumLayers = 1 / max(1, numLayers - 1)

		for layer = 1, numLayers do
			local layerInner = innerR + (layer - 1) * layerThickness + gap * 0.5
			local layerOuter = innerR + layer * layerThickness - gap * 0.5

			local normalizedPos = (layer - 1) * invNumLayers
			local wavePhase = (waveBase + normalizedPos * nukeWaveCount) * tau
			local waveBrightness = 0.25 + 0.75 * max(0, sin(wavePhase))
			local gradientMul = 1 - nukeGradientStrength * (1 - normalizedPos)
			local layerAlpha = ca * trefoilOpacity * waveBrightness * gradientMul

			if layerAlpha > 0.005 then
				glColor(cr, cg, cb, layerAlpha)
				local rI = size * layerInner
				local rO = size * layerOuter

				for blade = 0, 2 do
					local bg = bladeGeometryMini[blade]
					for i = 0, BLADE_SEGMENTS_MINI - 1 do
						local v0 = bg[i]
						local v1 = bg[i + 1]
						local c0, s0 = v0[1], v0[2]
						local c1, s1 = v1[1], v1[2]
						-- Manual Z-axis rotation for 2D minimap
						local rc0 = c0 * cosR - s0 * sinR
						local rs0 = c0 * sinR + s0 * cosR
						local rc1 = c1 * cosR - s1 * sinR
						local rs1 = c1 * sinR + s1 * cosR

						glVertex(px + rI * rc0, py + rI * rs0)
						glVertex(px + rO * rc0, py + rO * rs0)
						glVertex(px + rI * rc1, py + rI * rs1)

						glVertex(px + rI * rc1, py + rI * rs1)
						glVertex(px + rO * rc0, py + rO * rs0)
						glVertex(px + rO * rc1, py + rO * rs1)
					end
				end
			end
		end
	end
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
	if targetType == 103 then -- ASCII 'g'
		if type(targetData) == "table" then
			return targetData[1], targetData[2], targetData[3]
		end
	-- Unit target
	elseif targetType == 117 then -- ASCII 'u'
		local ux, uy, uz = spGetUnitPosition(targetData)
		if ux then
			return ux, uy, uz
		end
	-- Feature target
	elseif targetType == 102 then -- ASCII 'f'
		-- Could add feature position lookup if needed
		return nil
	-- Projectile target (interceptor)
	elseif targetType == 112 then -- ASCII 'p'
		local px, py, pz = spGetProjectilePosition(targetData)
		if px then
			return px, py, pz
		end
	end

	return nil
end

local function UpdateTrackedProjectiles()
	currentGeneration = currentGeneration + 1
	local gen = currentGeneration
	local currentTime = osClock()
	local allProjectiles = spGetProjectilesInRectangle(0, 0, mapSizeX, mapSizeZ)
	local newCount = 0
	local newNukeCount = 0

	if not allProjectiles then
		if trackedCount > 0 then
			trackedProjectiles = {}
			trackedCount = 0
			trackedNukeCount = 0
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
				if isSpectator or existingData.isOwnTeam then
					existingData.generation = gen
					newCount = newCount + 1
					if existingData.weaponInfo.isNuke then
						newNukeCount = newNukeCount + 1
					end
					local px, py, pz = spGetProjectilePosition(proID)
					if px then
						existingData.projectileX = px
						existingData.projectileY = py
						existingData.projectileZ = pz
					end
				end
			else
				local teamID = spGetProjectileTeamID(proID)
				local isOwnTeam = (teamID == myTeamID)
				local _, _, _, _, _, allyTeamID = spGetTeamInfo(teamID)
				local isAlly = (allyTeamID == myAllyTeamID)

				if isSpectator or isOwnTeam then
					local tx, ty, tz = GetProjectileTargetPos(proID)
					local px, py, pz = spGetProjectilePosition(proID)

					if tx and px then
						local dx, dy, dz = tx - px, ty - py, tz - pz
						local distance = sqrt(dx * dx + dy * dy + dz * dz)
						local speed = max(weaponInfo.projectileSpeed * 30, 1)
						local estimatedFlightTime = distance / speed

						newCount = newCount + 1
						if weaponInfo.isNuke then
							newNukeCount = newNukeCount + 1
						end

						-- Cache ground-adjusted target Y at creation (avoids per-frame API call)
						local groundY = spGetGroundHeight(tx, tz)
						if groundY and groundY > ty then
							ty = groundY
						end

						trackedProjectiles[proID] = {
							generation = gen,
							weaponInfo = weaponInfo,
							targetX = tx,
							targetY = ty,
							targetZ = tz,
							projectileX = px,
							projectileY = py,
							projectileZ = pz,
							startTime = currentTime,
							initialFlightTime = estimatedFlightTime,
							isOwnTeam = isOwnTeam,
							isAlly = isAlly,
							speed = speed,
						}
					end
				end
			end
		end
	end

	-- Remove stale projectiles (generation-based, no temp table needed)
	if trackedCount > 0 then
		for proID, data in pairs(trackedProjectiles) do
			if data.generation ~= gen then
				trackedProjectiles[proID] = nil
			end
		end
	end

	trackedCount = newCount
	trackedNukeCount = newNukeCount
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------
-- Draws non-nuke starburst indicators (nukes are batched separately in DrawWorld)
local function DrawImpactIndicator(data, currentTime)
	local tx, ty, tz = data.targetX, data.targetY, data.targetZ -- targetY already ground-adjusted
	local weaponInfo = data.weaponInfo
	local aoe = weaponInfo.aoe

	local elapsed = currentTime - data.startTime
	local progress = elapsed / max(data.initialFlightTime, 0.1)
	if progress > 1 then
		progress = 1
	elseif progress < 0 then
		progress = 0
	end

	local color
	if weaponInfo.isParalyzer then
		color = Config.paralyzerColor
	elseif weaponInfo.isJuno then
		color = data.isAlly and Config.junoAllyColor or Config.junoEnemyColor
	else
		color = data.isAlly and Config.allyColor or Config.enemyColor
	end

	local blinkPhase = 0
	if Config.blinkSpeed > 0 then
		local blinkFreq = Config.blinkSpeed * (1 + progress * 2)
		blinkPhase = sin(currentTime * blinkFreq * tau)
	end

	local baseOpacity = Config.pulseMinOpacity + (Config.pulseMaxOpacity - Config.pulseMinOpacity) * 0.5
	local minOpacity = Config.pulseMinOpacity + progress * 0.3
	local opacity = minOpacity > baseOpacity and minOpacity or baseOpacity

	if progress < 0.5 then
		opacity = opacity * (progress * 2)
	end

	local avgSpeed = Config.rotationSpeedMax - (Config.rotationSpeedMax - Config.rotationSpeedMin) * progress * 0.5
	local rotation = (elapsed * avgSpeed) % 360

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

--------------------------------------------------------------------------------
-- Widget callins
--------------------------------------------------------------------------------
function widget:Initialize()
	myAllyTeamID = spGetMyAllyTeamID()
	myTeamID = spGetMyTeamID()
	isSpectator = spGetSpectatingState()
	BuildWeaponCache()
	CreateDisplayLists()
	PrecomputeBladeGeometry()
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
	trackedNukeCount = 0
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
	if spIsGUIHidden() or trackedCount == 0 then
		return
	end

	glDepthTest(false)
	glLineWidth(Config.baseLineWidth * screenLineWidthScale)

	local currentTime = osClock()
	nukeBatchSize = 0

	for _, data in pairs(trackedProjectiles) do
		local aoe = data.weaponInfo.aoe
		if spIsSphereInView(data.targetX, data.targetY, data.targetZ, aoe) then
			if data.weaponInfo.isNuke then
				-- Collect nuke into batch for single-draw-call rendering
				local elapsed = currentTime - data.startTime
				local progress = elapsed / max(data.initialFlightTime, 0.1)
				if progress > 1 then
					progress = 1
				elseif progress < 0 then
					progress = 0
				end

				local blinkPhase = 0
				if Config.blinkSpeed > 0 then
					local blinkFreq = Config.blinkSpeed * (1 + progress * 2)
					blinkPhase = sin(currentTime * blinkFreq * tau)
				end

				local avgSpeed = Config.rotationSpeedMax - (Config.rotationSpeedMax - Config.rotationSpeedMin) * progress * 0.5
				local rotRad = ((elapsed * avgSpeed) % 360) * pi / 180

				local color = data.isAlly and Config.nukeAllyColor or Config.nukeEnemyColor

				nukeBatchSize = nukeBatchSize + 1
				local nd = nukeBatch[nukeBatchSize]
				if not nd then
					nd = {}
					nukeBatch[nukeBatchSize] = nd
				end
				nd.tx = data.targetX
				nd.ty = data.targetY + 3
				nd.tz = data.targetZ
				nd.radius = aoe * 0.75 * (0.6 + 0.08 * sin(currentTime * tau * 0.4))
				nd.cosR = cos(rotRad)
				nd.sinR = sin(rotRad)
				nd.cr = color[1]
				nd.cg = color[2]
				nd.cb = color[3]
				nd.ca = color[4]
				nd.baseOpacity = Config.nukeBaseOpacity * (0.7 + 0.2 * progress + 0.1 * blinkPhase)
				nd.waveBase = currentTime * Config.nukeWaveSpeed
				nd.aoe = aoe
			else
				DrawImpactIndicator(data, currentTime)
			end
		end
	end

	-- Batch draw all visible nukes in ONE draw call (no per-nuke closure/matrix ops)
	if nukeBatchSize > 0 then
		glBeginEnd(GL_TRIANGLES, drawAllNukeGeometry)
	end

	glDepthTest(true)
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

function widget:DrawInMiniMap(sx, sy)
	if trackedNukeCount == 0 then
		return
	end

	local currentTime = osClock()
	local worldToPixelX = sx / mapSizeX
	local worldToPixelY = sy / mapSizeZ
	local waveBase = currentTime * Config.nukeWaveSpeed

	-- Collect all nuke data into minimap batch (reuses tables)
	minimapNukeBatchSize = 0
	for _, data in pairs(trackedProjectiles) do
		if data.weaponInfo.isNuke then
			local elapsed = currentTime - data.startTime
			local progress = elapsed / max(data.initialFlightTime, 0.1)
			if progress > 1 then
				progress = 1
			elseif progress < 0 then
				progress = 0
			end

			local blinkPhase = 0
			if Config.blinkSpeed > 0 then
				local blinkFreq = Config.blinkSpeed * (1 + progress * 2)
				blinkPhase = sin(currentTime * blinkFreq * tau)
			end

			local avgSpeed = Config.rotationSpeedMax - (Config.rotationSpeedMax - Config.rotationSpeedMin) * progress * 0.5
			local rotRad = ((elapsed * avgSpeed) % 360) * pi / 180

			local color = data.isAlly and Config.nukeAllyColor or Config.nukeEnemyColor
			local aoe = data.weaponInfo.aoe

			local trefoilWorldSize = aoe * 0.75 * (0.6 + 0.08 * sin(currentTime * tau * 0.4))
			local trefoilPixelSize = trefoilWorldSize * worldToPixelX
			if trefoilPixelSize < 5 then
				trefoilPixelSize = 5
			elseif trefoilPixelSize > 40 then
				trefoilPixelSize = 40
			end

			minimapNukeBatchSize = minimapNukeBatchSize + 1
			local nd = minimapNukeBatch[minimapNukeBatchSize]
			if not nd then
				nd = {}
				minimapNukeBatch[minimapNukeBatchSize] = nd
			end
			nd.targPX = data.targetX * worldToPixelX
			nd.targPY = (1 - data.targetZ / mapSizeZ) * sy
			nd.projPX = data.projectileX * worldToPixelX
			nd.projPY = (1 - data.projectileZ / mapSizeZ) * sy
			nd.size = trefoilPixelSize
			nd.cosR = cos(rotRad)
			nd.sinR = sin(rotRad)
			nd.cr = color[1]
			nd.cg = color[2]
			nd.cb = color[3]
			nd.ca = color[4]
			nd.opacity = Config.nukeBaseOpacity * (0.8 + 0.15 * progress + 0.1 * blinkPhase)
			nd.waveBase = waveBase
			nd.aoe = aoe
		end
	end

	if minimapNukeBatchSize == 0 then
		return
	end

	-- Batch all lines in ONE draw call
	glLineWidth(1.5)
	glBeginEnd(GL_LINES, drawMinimapNukeLines)

	-- Batch all trefoils in ONE draw call
	glBeginEnd(GL_TRIANGLES, drawMinimapNukeTrefoils)

	glColor(1, 1, 1, 1)
end
