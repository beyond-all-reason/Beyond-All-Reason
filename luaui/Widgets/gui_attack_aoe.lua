local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Attack AoE",
		desc = "Cursor indicator for area of effect and scatter when giving attack command.",
		author = "Evil4Zerggin",
		date = "26 September 2008",
		license = "GNU LGPL, v2.1 or later",
		layer = 1,
		enabled = true
	}
end

-- Localized functions for performance
local max = math.max
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos
local atan2 = math.atan2
local pi = math.pi
local floor = math.floor
local tan = math.tan
local abs = math.abs
local pow = math.pow
local distance2d = math.distance2d
local distance2dSquared = math.distance2dSquared
local distance3d = math.distance3d

local spGetMyTeamID = Spring.GetMyTeamID
local spGetGroundHeight = Spring.GetGroundHeight
local spGetActiveCommand = Spring.GetActiveCommand
local spGetCameraPosition = Spring.GetCameraPosition
local spGetMouseState = Spring.GetMouseState
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitRadius = Spring.GetUnitRadius
local spGetUnitStates = Spring.GetUnitStates
local spTraceScreenRay = Spring.TraceScreenRay
local spIsUnitAllied = Spring.IsUnitAllied
local spGetUnitDefID = Spring.GetUnitDefID
local spGetTeamResources = Spring.GetTeamResources
local spGetUnitWeaponTestRange = Spring.GetUnitWeaponTestRange
local spGetUnitStockpile = Spring.GetUnitStockpile

local CMD_ATTACK = CMD.ATTACK
local CMD_UNIT_SET_TARGET = GameCMD.UNIT_SET_TARGET
local CMD_UNIT_SET_TARGET_NO_GROUND = GameCMD.UNIT_SET_TARGET_NO_GROUND
local CMD_MANUALFIRE = CMD.MANUALFIRE
local CMD_MANUAL_LAUNCH = GameCMD.MANUAL_LAUNCH

local glBeginEnd = gl.BeginEnd
local glCallList = gl.CallList
local glCreateList = gl.CreateList
local glColor = gl.Color
local glDeleteList = gl.DeleteList
local glDepthTest = gl.DepthTest
local glDrawGroundCircle = gl.DrawGroundCircle
local glLineWidth = gl.LineWidth
local glPointSize = gl.PointSize
local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glScale = gl.Scale
local glTranslate = gl.Translate
local glVertex = gl.Vertex
local glStencilTest = gl.StencilTest
local glStencilMask = gl.StencilMask
local glStencilFunc = gl.StencilFunc
local glStencilOp = gl.StencilOp
local glClear = gl.Clear

local GL_LINES = GL.LINES
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_LINE_STRIP = GL.LINE_STRIP
local GL_TRIANGLE_STRIP = GL.TRIANGLE_STRIP
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN
local GL_STENCIL_BUFFER_BIT = GL.STENCIL_BUFFER_BIT
local GL_KEEP = GL.KEEP
local GL_REPLACE = GL.REPLACE
local GL_NOTEQUAL = GL.NOTEQUAL

local GAME_SPEED = 30
local g = Game.gravity
local g_f = g / GAME_SPEED / GAME_SPEED

--------------------------------------------------------------------------------
--config
--------------------------------------------------------------------------------
local aoeColor = { 1, 0, 0, 1 }
local aoeColorNoEnergy = { 1, 1, 0, 1 }
local junoColor = { 0.87, 0.94, 0.40, 1 }
local napalmColor = { 0.85, 0.62, 0.28, 1 }
local empColor = { 0.65, 0.65, 1, 1 }
local scatterColor = { 1, 1, 0, 1 }
local noStockpileColor = { 0.88, 0.88, 0.88, 1 }

local scatterMinAlpha = 0.5
local aoeLineWidthMult = 64
local scatterLineWidthMult = 1024
local circleDivs = 96
local scatterSegments = 64
local minSpread = 8 --weapons with this spread or less are ignored
local pointSizeMult = 2048
local maxFilledCircleAlpha = 0.2
local minFilledCircleAlpha = 0.1
local salvoAnimationSpeed = 0.1
local waveDuration = 0.35
local fadeDuration = 1 - waveDuration
local ringDamageLevels = { 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1 } -- draw aoe rings for these damage levels
local aoeDiskBandCount = 16

--------------------------------------------------------------------------------
--vars
--------------------------------------------------------------------------------
local weaponInfos = {} ---@type table<number, WeaponInfo>
local manualWeaponInfos = {} ---@type table<number, WeaponInfo>
local hasSelection = false
local isMonitoringStockpile = false
local unitsToMonitorStockpile = {}
local attackUnitDefID, manualFireUnitDefID
local attackUnitID, manualFireUnitID
local circleList
local pulsePhase = 0
local selectionChanged
local unitCost = {}
local isAirUnit = {}
local isShip = {}
local isUnderwater = {}
local isHover = {}
local ringWaveTriggerTimes = {}
local diskWaveTriggerTimes = {}
local unitCircles = {}
for udid, ud in pairs(UnitDefs) do
	unitCost[udid] = ud.cost
	if ud.isAirUnit then
		isAirUnit[udid] = ud.isAirUnit
	end
	if ud.modCategories then
		if ud.modCategories.ship then
			isShip[udid] = true
		end
		if ud.modCategories.underwater then
			isUnderwater[udid] = true
		end
		if ud.modCategories.hover then
			isHover[udid] = true
		end
	end
end
for i, _ in ipairs(ringDamageLevels) do
	ringWaveTriggerTimes[i] = (i / #ringDamageLevels) * waveDuration
end
for i = 1, aoeDiskBandCount do
	diskWaveTriggerTimes[i] = (i / aoeDiskBandCount) * waveDuration
end
for i = 0, circleDivs do
	local theta = 2 * pi * i / circleDivs
	unitCircles[i] = { cos(theta), sin(theta) }
end

--------------------------------------------------------------------------------
-- Stockpile status and animations
--------------------------------------------------------------------------------
local StockpileSystem = {
	state = "done",
	timer = 0,
	fadeProgress = 1,
	lastUnitID = nil,
	lastCount = 0,

	DELAY = 0.1,
	FADE_TIME = 0.5
}

function StockpileSystem:Reset()
	self.state = "done"
	self.timer = 0
	self.fadeProgress = 1
	self.lastUnitID = nil
	self.lastCount = 0
end

function StockpileSystem:Update(dt, unitID, hasStockpile)
	if not unitID or not hasStockpile then
		self.state = "done"
		self.fadeProgress = 1
		return
	end

	-- 1. Detect Selection Change
	if unitID ~= self.lastUnitID then
		self.lastUnitID = unitID
		local num = spGetUnitStockpile(unitID)
		self.lastCount = num
		if num > 0 then
			self.state = "done"
			self.fadeProgress = 1
		else
			self.state = "loading"
			self.fadeProgress = 0
		end
	end

	-- 2. Logic Update
	local numStockpiled = spGetUnitStockpile(unitID)

	-- Detect Firing (Transition: Ready -> Loading)
	if numStockpiled == 0 and self.lastCount > 0 then
		self.state = "draining"
	end
	self.lastCount = numStockpiled

	-- State Machine
	if self.state == "draining" then
		-- Fade OUT
		self.fadeProgress = self.fadeProgress - (dt / self.FADE_TIME)
		if self.fadeProgress <= 0 then
			self.fadeProgress = 0
			self.state = "loading"
		end

	elseif numStockpiled == 0 then
		if self.state ~= "draining" then
			self.state = "loading"
			self.fadeProgress = 0
		end

	elseif self.state == "loading" then
		self.state = "delay"
		self.timer = 0
		self.fadeProgress = 0

	elseif self.state == "delay" then
		-- Wait with full bar before fading
		self.timer = self.timer + dt
		self.fadeProgress = 0
		if self.timer > self.DELAY then
			self.state = "fading"
			self.timer = 0
		end

	elseif self.state == "fading" then
		self.timer = self.timer + dt
		self.fadeProgress = self.timer / self.FADE_TIME
		if self.fadeProgress >= 1 then
			self.fadeProgress = 1
			self.state = "done"
		end

	else
		self.fadeProgress = 1
	end
end

--------------------------------------------------------------------------------
-- utility functions
--------------------------------------------------------------------------------
local function GetFadedColor(color, alphaMult)
	return { color[1], color[2], color[3], color[4] * alphaMult }
end

local function lerp(a, b, time)
	return b - (b - a) * time
end

local function LerpColor(c1, c2, t)
	local invT = 1 - t
	return {
		c1[1] * invT + c2[1] * t,
		c1[2] * invT + c2[2] * t,
		c1[3] * invT + c2[3] * t,
		c1[4] * invT + c2[4] * t
	}
end

local function ToBool(x)
	return x and x ~= 0 and x ~= "false"
end

local function Normalize(x, y, z)
	local mag = distance3d(x, y, z, 0, 0, 0)
	if mag == 0 then
		return nil
	else
		return x / mag, y / mag, z / mag, mag
	end
end

local function VertexList(points)
	for i, point in pairs(points) do
		glVertex(point)
	end
end

local function GetMouseTargetPosition(dgun)
	local tx, ty = spGetMouseState()
	local mouseTargetType, mouseTarget = spTraceScreenRay(tx, ty)
	if mouseTarget and mouseTargetType then
		if mouseTargetType == "ground" then
			return mouseTarget[1], mouseTarget[2], mouseTarget[3]
		elseif mouseTargetType == "unit" then
			if ((dgun and WG['dgunnoally'] ~= nil) or (not dgun and WG['attacknoally'] ~= nil)) and spIsUnitAllied(mouseTarget) then
				mouseTargetType, mouseTarget = spTraceScreenRay(tx, ty, true)
				if mouseTarget then
					return mouseTarget[1], mouseTarget[2], mouseTarget[3]
				else
					return nil
				end
			elseif ((dgun and WG['dgunnoenety'] ~= nil) or (not dgun and WG['attacknoenety'] ~= nil)) and not spIsUnitAllied(mouseTarget) then
				local unitDefID = spGetUnitDefID(mouseTarget)
				local mouseTargetType2, mouseTarget2 = spTraceScreenRay(tx, ty, true)
				if mouseTarget2 then
					if isAirUnit[unitDefID] or isShip[unitDefID] or isUnderwater[unitDefID] or (spGetGroundHeight(mouseTarget2[1], mouseTarget2[3]) < 0 and isHover[unitDefID]) then
						return spGetUnitPosition(mouseTarget)
					else
						return mouseTarget2[1], mouseTarget2[2], mouseTarget2[3]
					end
				else
					return nil
				end
			else
				return spGetUnitPosition(mouseTarget)
			end
		elseif mouseTargetType == "feature" then
			local mouseTargetType, mouseTarget = spTraceScreenRay(tx, ty, true)
			if mouseTarget then
				return mouseTarget[1], mouseTarget[2], mouseTarget[3]
			end
		else
			return nil
		end
	else
		return nil
	end
end

local function GetMouseDistance()
	local cx, cy, cz = spGetCameraPosition()
	local tx, ty, tz = GetMouseTargetPosition()
	if not tx then
		return nil
	end
	return distance3d(cx, cy, cz, tx, ty, tz)
end

local function UnitCircleVertices()
	for i = 1, circleDivs do
		local uc = unitCircles[i]
		glVertex(uc[1], 0, uc[2])
	end
end

local function DrawUnitCircle()
	glBeginEnd(GL_LINE_LOOP, UnitCircleVertices)
end

local function DrawCircle(x, y, z, radius)
	glPushMatrix()
	glTranslate(x, y, z)
	glScale(radius, radius, radius)

	glCallList(circleList)

	glPopMatrix()
end

-- we don't want to start in the middle of animation when enabling the command
local function ResetPulseAnimation()
	pulsePhase = 0
end

local function SetColor(alphaFactor, color)
	glColor(color[1], color[2], color[3], color[4] * alphaFactor)
end

local function BeginNoOverlap()
	glClear(GL_STENCIL_BUFFER_BIT) -- Clear the stencil buffer (set all pixels to 0)
	glStencilTest(true)
	glStencilMask(255)
	glStencilFunc(GL_NOTEQUAL, 1, 255) -- RULE: Only draw if the pixel in the stencil buffer is NOT 1
	glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- ACTION: If we draw the pixel, replace the stencil value with 1
end

local function EndNoOverlap()
	glStencilTest(false)
	glStencilMask(0)
end

--------------------------------------------------------------------------------
--initialization
--------------------------------------------------------------------------------

local function ParseCustomParams(unitDef)
	for ii, weapon in ipairs(unitDef.weapons) do
		if weapon.weaponDef then
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if weaponDef and weaponDef.customParams and weaponDef.customParams.speceffect == "sector_fire" then
				return {
					type = "sector",
					sector_angle = tonumber(weaponDef.customParams.spread_angle),
					sector_shortfall = tonumber(weaponDef.customParams.max_range_reduction),
					sector_range_max = weaponDef.range
				}
			end
		end
	end
	return nil
end

local function FindBestWeapon(unitDef)
	local maxSpread = minSpread
	local bestDef, bestNum

	for weaponNum, weapon in ipairs(unitDef.weapons) do
		if weapon.weaponDef then
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if weaponDef then
				-- Filter out shields, interceptors, and non-ground attackers
				local isValid = weaponDef.canAttackGround
					and not (weaponDef.type == "Shield")
					and not ToBool(weaponDef.interceptor)
					and not string.find(weaponDef.name, "flak", nil, true)

				-- Check AoE/Spread threshold
				local currentSpread = max(weaponDef.damageAreaOfEffect, weaponDef.range * (weaponDef.accuracy + weaponDef.sprayAngle))

				if isValid and (weaponDef.damageAreaOfEffect > maxSpread or weaponDef.range * (weaponDef.accuracy + weaponDef.sprayAngle) > maxSpread) then
					maxSpread = currentSpread
					bestDef = weaponDef
					bestNum = weaponNum
				end
			end
		end
	end
	return bestDef, bestNum
end

---@return WeaponInfo
local function BuildWeaponInfo(unitDef, weaponDef, weaponNum)
	---@class WeaponInfo
	local info = {}
	local weaponType = weaponDef.type
	local scatter = weaponDef.accuracy + weaponDef.sprayAngle

	-- Basic Params
	info.aoe = weaponDef.damageAreaOfEffect
	info.cost = unitDef.cost
	info.mobile = unitDef.speed > 0
	info.waterWeapon = weaponDef.waterWeapon
	info.ee = weaponDef.edgeEffectiveness
	info.weaponNum = weaponNum
	info.hasStockpile = weaponDef.stockpile
	info.reloadTime = weaponDef.reload

	-- Colors and Special Properties
	if weaponDef.paralyzer then
		info.color = empColor
	end
	if weaponDef.customParams.area_onhit_resistance == "fire" then
		info.isNapalm = true
		info.napalmRange = weaponDef.customParams.area_onhit_range
		info.color = napalmColor
	end

	-- Type Classification
	if weaponType == "DGun" then
		info.type = "dgun"
		info.range = weaponDef.range
		info.unitname = unitDef.name
		info.requiredEnergy = weaponDef.energyCost
	elseif weaponDef.customParams.junotype then
		info.type = "juno"
		info.isMiniJuno = (weaponDef.customParams.junotype == "mini")
		info.color = junoColor
	elseif weaponDef.cylinderTargeting >= 100 then
		info.type = "orbital"
		info.scatter = scatter
	elseif weaponType == "Cannon" then
		info.type = "ballistic"
		info.scatter = scatter
		info.range = weaponDef.range
		info.v = weaponDef.projectilespeed * 30
		info.projectileCount = weaponDef.projectiles or 1
		info.salvoSize = weaponDef.salvoSize or 1
	elseif weaponType == "MissileLauncher" then
		local turnRate = weaponDef.tracks and weaponDef.turnRate or 0
		if weaponDef.wobble > turnRate * 1.4 then
			info.type = "wobble"
			info.scatter = (weaponDef.wobble - weaponDef.turnRate) * weaponDef.projectilespeed * 30 * 16
			info.rangeScatter = (8 * weaponDef.wobble - weaponDef.turnRate)
			info.range = weaponDef.range
		elseif weaponDef.wobble > turnRate then
			info.type = "wobble"
			info.scatter = (weaponDef.wobble - weaponDef.turnRate) * weaponDef.projectilespeed * 30 * 16
		elseif weaponDef.tracks then
			info.type = "tracking"
		else
			info.type = "direct"
			info.scatter = scatter
			info.range = weaponDef.range
		end
	elseif weaponType == "AircraftBomb" then
		info.type = "dropped"
		info.scatter = scatter
		info.v = unitDef.speed
		info.h = unitDef.cruiseAltitude
		info.salvoSize = weaponDef.salvoSize
		info.salvoDelay = weaponDef.salvoDelay
	elseif weaponType == "StarburstLauncher" then
		info.type = weaponDef.tracks and "tracking" or "cruise"
		info.range = weaponDef.range
	elseif weaponType == "TorpedoLauncher" then
		if weaponDef.tracks then
			info.type = "tracking"
		else
			info.type = "direct"
			info.scatter = scatter
			info.range = weaponDef.range
		end
	elseif weaponType == "Flame" then
		info.type = "noexplode"
		info.range = weaponDef.range
	else
		info.type = "direct"
		info.scatter = scatter
		info.range = weaponDef.range
	end

	return info
end

local function SetupUnitDef(unitDefID, unitDef)
	if not unitDef.weapons then
		return
	end

	-- 1. Check for custom sector fire
	local sectorInfo = ParseCustomParams(unitDef)
	if sectorInfo then
		weaponInfos[unitDefID] = sectorInfo
		return
	end

	-- 2. Find best weapon
	local maxWeaponDef, maxWeaponNum = FindBestWeapon(unitDef)
	if not maxWeaponDef then
		return
	end

	-- 3. Build Info
	local info = BuildWeaponInfo(unitDef, maxWeaponDef, maxWeaponNum)

	-- 4. Assign to correct table (Manual vs Standard)
	if maxWeaponDef.manualFire and unitDef.canManualFire then
		manualWeaponInfos[unitDefID] = info
	else
		weaponInfos[unitDefID] = info
	end
end

local function SetupDisplayLists()
	circleList = glCreateList(DrawUnitCircle)
end

local function DeleteDisplayLists()
	glDeleteList(circleList)
end

--------------------------------------------------------------------------------
--updates
--------------------------------------------------------------------------------
local function GetUnitWithBestStockpile(unitIDs)
	local bestUnit = unitIDs[1]
	local maxProgress = 0
	for _, unitId in ipairs(unitIDs) do
		local numStockpiled, numStockpileQued, buildPercent = spGetUnitStockpile(unitId)
		if numStockpiled > 0 then
			return unitId
		elseif buildPercent > maxProgress then
			maxProgress = buildPercent
			bestUnit = unitId
		end
	end
	return bestUnit
end

local function GetRepUnitID(unitIDs, info)
	local bestUnit = unitIDs[1]
	if info.hasStockpile then
		isMonitoringStockpile = true
		unitsToMonitorStockpile = unitIDs
		bestUnit = GetUnitWithBestStockpile(unitIDs)
	end
	return bestUnit
end

local function UpdateSelection()
	local maxCost = 0
	manualFireUnitDefID = nil
	attackUnitDefID = nil
	attackUnitID = nil
	manualFireUnitID = nil
	hasSelection = false
	isMonitoringStockpile = false
	unitsToMonitorStockpile = {}

	local sel = spGetSelectedUnitsSorted()
	for unitDefID, unitIDs in pairs(sel) do
		if manualWeaponInfos[unitDefID] then
			manualFireUnitDefID = unitDefID
			manualFireUnitID = unitIDs[1]
			hasSelection = true
		end

		if weaponInfos[unitDefID] then
			local currCost = unitCost[unitDefID] * #unitIDs
			if currCost > maxCost then
				maxCost = currCost
				attackUnitDefID = unitDefID
				attackUnitID = GetRepUnitID(unitIDs, weaponInfos[unitDefID])
				hasSelection = true
			end
		end
	end
end

---@return WeaponInfo, number
local function GetActiveUnitInfo()
	if not hasSelection then
		return nil, nil
	end

	local _, cmd, _ = spGetActiveCommand()

	if ((cmd == CMD_MANUALFIRE or cmd == CMD_MANUAL_LAUNCH) and manualFireUnitDefID) then
		return manualWeaponInfos[manualFireUnitDefID], manualFireUnitID
	elseif ((cmd == CMD_ATTACK or cmd == CMD_UNIT_SET_TARGET or cmd == CMD_UNIT_SET_TARGET_NO_GROUND) and attackUnitDefID) then
		return weaponInfos[attackUnitDefID], attackUnitID
	end

	return nil, nil
end

--------------------------------------------------------------------------------
--aoe
--------------------------------------------------------------------------------
local function GetRadiusForDamageLevel(aoe, damageLevel, edgeEffectiveness)
	local denominator = 1 - (damageLevel * edgeEffectiveness)
	if denominator == 0 then
		return aoe
	end
	local radius = aoe * (1 - damageLevel) / denominator
	if radius < 0 then
		radius = 0
	elseif radius > aoe then
		radius = aoe
	end
	return radius
end

local function GetAlphaFactorForRing(minAlpha, maxAlpha, index, phase, alphaMult, triggerTimes, blinkEachRing)
	maxAlpha = maxAlpha or 1
	alphaMult = alphaMult or 1
	local result

	-- First ring does not blink
	if not blinkEachRing and index == 1 then
		result = maxAlpha
	elseif phase < waveDuration then
		if phase >= triggerTimes[index] then
			result = maxAlpha
		else
			result = minAlpha
		end
	else
		local fadeProgress = (phase - waveDuration) / fadeDuration
		result = lerp(minAlpha, maxAlpha, fadeProgress)
	end

	return result * alphaMult
end

local function DrawAoeRange(tx, ty, tz, aoe, alphaMult, phase, color)
	alphaMult = alphaMult or 1
	glPushMatrix()
	glTranslate(tx, ty, tz)
	glBeginEnd(GL_TRIANGLE_STRIP, function()
		for idx = 1, aoeDiskBandCount do
			local innerRing = aoe * (idx - 1) / aoeDiskBandCount
			local outerRing = aoe * idx / aoeDiskBandCount
			local alphaFactor = GetAlphaFactorForRing(minFilledCircleAlpha, maxFilledCircleAlpha, idx, phase, alphaMult, diskWaveTriggerTimes)

			SetColor(alphaFactor, color)
			for i = 0, circleDivs do
				local unitCircle = unitCircles[i]
				glVertex(unitCircle[1] * outerRing, 0, unitCircle[2] * outerRing)
				glVertex(unitCircle[1] * innerRing, 0, unitCircle[2] * innerRing)
			end
		end
	end)
	glPopMatrix()
end

local function DrawDamageRings(tx, ty, tz, aoe, edgeEffectiveness, alphaMult, phase, color)
	for ringIndex, damageLevel in ipairs(ringDamageLevels) do
		local ringRadius = GetRadiusForDamageLevel(aoe, damageLevel, edgeEffectiveness)
		local alphaFactor = GetAlphaFactorForRing(damageLevel, damageLevel + 0.2, ringIndex, phase, alphaMult, ringWaveTriggerTimes)
		SetColor(alphaFactor, color)
		DrawCircle(tx, ty, tz, ringRadius)
	end
end

---@param data AttackIndicatorData
local function DrawAoe(data, baseColorOverride, targetOverride, ringAlphaMult, phaseOffset)
	local dist = data.dist
	local color = baseColorOverride or data.colors.base
	local target = targetOverride or data.target
	local tx, ty, tz = target.x, target.y, target.z
	local aoe, edgeEffectiveness = data.info.aoe, data.info.ee

	glLineWidth(max(aoeLineWidthMult * aoe / dist, 0.5))
	ringAlphaMult = ringAlphaMult or 1

	local phase = pulsePhase + (phaseOffset or 0)
	phase = phase - floor(phase)

	if edgeEffectiveness == 1 then
		DrawAoeRange(tx, ty, tz, aoe, ringAlphaMult, phase, color)
	else
		DrawDamageRings(tx, ty, tz, aoe, edgeEffectiveness, ringAlphaMult, phase, color)
	end

	-- draw a max radius outline for clarity
	SetColor(1, color)
	glLineWidth(1)
	DrawCircle(tx, ty, tz, aoe)

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

---@param data AttackIndicatorData
local function DrawJunoArea(data)
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local aoe = data.info.aoe
	local phase = pulsePhase - floor(pulsePhase)
	local color = data.colors.base

	local areaDenialRadius = 450 -- defined in unit_juno_damage.lua - "outer radius of area denial ring"
	local impactRingWidth = aoe - areaDenialRadius

	glPushMatrix()
	glTranslate(tx, ty, tz)
	glBeginEnd(GL_TRIANGLE_STRIP, function()
		SetColor(maxFilledCircleAlpha, color)
		for i = 0, circleDivs do
			local unitCircle = unitCircles[i]
			glVertex(unitCircle[1] * areaDenialRadius, 0, unitCircle[2] * areaDenialRadius)
			glVertex(0, 0, 0)
		end
	end)
	glBeginEnd(GL_TRIANGLE_STRIP, function()
		for idx = 1, aoeDiskBandCount do
			local innerRing = areaDenialRadius + (impactRingWidth * (idx - 1) / aoeDiskBandCount)
			local outerRing = areaDenialRadius + (impactRingWidth * idx / aoeDiskBandCount)

			local alphaFactor = GetAlphaFactorForRing(minFilledCircleAlpha, maxFilledCircleAlpha, idx, phase, 1, diskWaveTriggerTimes, true)

			SetColor(alphaFactor, color)
			for i = 0, circleDivs do
				local unitCircle = unitCircles[i]
				glVertex(unitCircle[1] * outerRing, 0, unitCircle[2] * outerRing)
				glVertex(unitCircle[1] * innerRing, 0, unitCircle[2] * innerRing)
			end
		end
	end)
	glPopMatrix()

	SetColor(1, color)
	glLineWidth(1)
	DrawCircle(tx, ty, tz, aoe) -- impact radius outline
	DrawCircle(tx, ty, tz, areaDenialRadius) -- area denial ring outline

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

local function DrawStockpileProgress(data, buildPercent, barColor, bgColor)
	local dist = data.dist
	local aoe = data.info.aoe
	local tx, ty, tz = data.target.x, data.target.y, data.target.z

	bgColor = bgColor or noStockpileColor
	SetColor(1, bgColor)
	glLineWidth(max(aoeLineWidthMult * aoe / 2 / dist, 2))

	glPushMatrix()
	glTranslate(tx, ty, tz)
	glScale(aoe, aoe, aoe)

	glCallList(circleList)

	if buildPercent > 0 then
		SetColor(1, barColor)

		local limit = floor(circleDivs * buildPercent)
		if limit > circleDivs then
			limit = circleDivs
		end

		glBeginEnd(GL_LINE_STRIP, function()
			for i = 0, limit do
				local v = unitCircles[i]
				glVertex(v[1], 0, v[2])
			end

			if buildPercent < 1 then
				local angle = 2 * pi * buildPercent
				glVertex(cos(angle), 0, sin(angle))
			end
		end)
	end

	glPopMatrix()

	-- Reset
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
--dgun/noexplode
--------------------------------------------------------------------------------
---@param data AttackIndicatorData
local function DrawNoExplode(data, overrideSource)
	local source = overrideSource or data.source
	local ux, uy, uz = source.x, source.y, source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local aoe = data.info.aoe
	local range = data.info.range
	local requiredEnergy = data.info.requiredEnergy
	local dist = data.dist

	local dx = tx - ux
	local dy = ty - uy
	local dz = tz - uz

	local bx, by, bz, len = Normalize(dx, dy, dz)

	if not bx or len > range then
		return
	end

	local br = sqrt(bx * bx + bz * bz)

	local wx = -aoe * bz / br
	local wz = aoe * bx / br

	local ex = range * bx / br
	local ez = range * bz / br

	local vertices = { { ux + wx, uy, uz + wz }, { ux + ex + wx, ty, uz + ez + wz },
					   { ux - wx, uy, uz - wz }, { ux + ex - wx, ty, uz + ez - wz } }
	local alpha = lerp(minFilledCircleAlpha, 1, pulsePhase) * aoeColor[4]

	if requiredEnergy and select(1, spGetTeamResources(spGetMyTeamID(), 'energy')) < requiredEnergy then
		glColor(aoeColorNoEnergy[1], aoeColorNoEnergy[2], aoeColorNoEnergy[3], alpha)
	else
		glColor(aoeColor[1], aoeColor[2], aoeColor[3], alpha)
	end

	glLineWidth(1 + (scatterLineWidthMult / dist))

	glBeginEnd(GL_LINES, VertexList, vertices)

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
--ballistics
--------------------------------------------------------------------------------
local function GetBallisticVector(v, dx, dy, dz, trajectory)
	local dr_sq = distance2dSquared(dx, dz, 0, 0)
	local dr = sqrt(dr_sq)

	local d_sq = dr_sq + dy * dy

	if d_sq == 0 then
		return 0, v * trajectory, 0
	end

	local root1 = v * v * v * v - 2 * v * v * g * dy - g * g * dr_sq
	if root1 < 0 then
		return nil
	end

	local root2 = 2 * dr_sq * d_sq * (v * v - g * dy - trajectory * sqrt(root1))

	if root2 < 0 then
		return nil
	end

	local vr = sqrt(root2) / (2 * d_sq)
	local vy

	if vr == 0 then
		vy = v
	else
		vy = vr * dy / dr + dr * g / (2 * vr)
	end

	local bx = dx * vr / dr
	local bz = dz * vr / dr
	local by = vy
	return Normalize(bx, by, bz)
end

local function GetFadeAlpha(theta)
	local sinTheta = sin(theta)
	return 1 - (pow(abs(sinTheta), 2) * (1 - scatterMinAlpha))
end

---@param data AttackIndicatorData
local function DrawBallisticScatter(data)
	local info = data.info
	local ux, uy, uz = data.source.x, data.source.y, data.source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local dist = data.dist
	local aimingUnitID = data.unitID
	local fillColor, lineColor = data.colors.fill, data.colors.scatter
	local trajectory = select(7, spGetUnitStates(aimingUnitID, false, true)) and 1 or -1

	local scatter = info.scatter
	if scatter < 0.01 then
		return
	end
	local v = info.v
	local isFilled = fillColor[4] > 0

	-- 1. Math Setup
	local aimDist = distance3d(tx, ty, tz, ux, uy, uz)
	local isOutsideMaxRange = aimDist > info.range and not spGetUnitWeaponTestRange(aimingUnitID, info.weaponNum, tx, ty, tz)

	local calc_tx, calc_ty, calc_tz = tx, ty, tz
	local calc_dist = aimDist

	-- If pointing outside the max range we don't want to use actual target for calculations as it will produce
	-- misleading shape. Instead, we pretend that mouse points at the max range
	if isOutsideMaxRange then
		local factor = info.range / aimDist
		calc_tx = ux + (tx - ux) * factor
		calc_tz = uz + (tz - uz) * factor
		calc_ty = spGetGroundHeight(calc_tx, calc_tz)
		calc_dist = info.range
	end

	local dx, dy, dz = calc_tx - ux, calc_ty - uy, calc_tz - uz

	local bx, by, bz, _ = GetBallisticVector(v, dx, dy, dz, trajectory)
	if not bx then
		return
	end

	-- 2. Create Orthonormal Basis
	local rx, ry, rz
	if abs(bx) < 0.001 and abs(bz) < 0.001 then
		rx, ry, rz = 1, 0, 0
	else
		local inv_len = 1 / sqrt(bx * bx + bz * bz)
		rx = -bz * inv_len
		ry = 0
		rz = bx * inv_len
	end

	local v_f = v / GAME_SPEED
	local gravity_f = -0.5 * g_f
	local heightDiff = uy - calc_ty

	local function GetImpactPoint(dirX, dirY, dirZ)
		local velY = dirY * v_f
		local a = gravity_f
		local b = velY
		local discriminant = b * b - 4 * a * heightDiff

		if discriminant >= 0 then
			local sqrtDisc = sqrt(discriminant)
			local t1 = (-b - sqrtDisc) / (2 * a)
			local t2 = (-b + sqrtDisc) / (2 * a)

			local x1 = ux + (dirX * v_f * t1)
			local z1 = uz + (dirZ * v_f * t1)
			local x2 = ux + (dirX * v_f * t2)
			local z2 = uz + (dirZ * v_f * t2)

			local d1 = distance2dSquared(x1, z1, calc_tx, calc_tz)
			local d2 = distance2dSquared(x2, z2, calc_tx, calc_tz)

			if t1 < 0 then
				return x2, z2, true
			end
			if t2 < 0 then
				return x1, z1, true
			end

			if d1 < d2 then
				return x1, z1, true
			else
				return x2, z2, true
			end
		else
			-- Linear Fallback
			local flatDist = distance2d(calc_tx, calc_tz, ux, uz)
			local dirFlat = distance2d(dirX, dirZ, 0, 0)
			if dirFlat > 0.0001 then
				local scale = flatDist / dirFlat
				return ux + (dirX * scale), uz + (dirZ * scale), true
			end
			return calc_tx, calc_tz, true
		end
	end

	----------------------------------------------------------------------------
	-- AXIS CALCULATION & CLAMPING
	----------------------------------------------------------------------------
	local cosScatter = sqrt(max(0, 1 - scatter * scatter))

	local naturalRadius = calc_dist * (tan(scatter) + 0.01)

	local scatterAlphaFactor = 0
	local baseThreshold = max(info.aoe, 15)
	local minScatterRadius = baseThreshold * 0.5

	if naturalRadius >= baseThreshold then
		scatterAlphaFactor = 1
	elseif naturalRadius > minScatterRadius then
		scatterAlphaFactor = (naturalRadius - minScatterRadius) / (baseThreshold - minScatterRadius)
	end

	if scatterAlphaFactor <= 0 then
		return
	end

	local maxAxisLen = naturalRadius * 2.5

	-- Yaw
	local vx_right = bx * cosScatter + rx * scatter
	local vy_right = by * cosScatter + ry * scatter
	local vz_right = bz * cosScatter + rz * scatter
	local hx_right, hz_right = GetImpactPoint(vx_right, vy_right, vz_right)

	local axisRightX = hx_right - calc_tx
	local axisRightZ = hz_right - calc_tz
	local lenRight = distance2d(axisRightX, axisRightZ, 0, 0)

	if lenRight > maxAxisLen then
		local scale = maxAxisLen / lenRight
		axisRightX = axisRightX * scale
		axisRightZ = axisRightZ * scale
	end

	-- Pitch
	local up_x = ry * bz - rz * by
	local up_y = rz * bx - rx * bz
	local up_z = rx * by - ry * bx

	local vx_up = bx * cosScatter + up_x * scatter
	local vy_up = by * cosScatter + up_y * scatter
	local vz_up = bz * cosScatter + up_z * scatter
	local hx_up, hz_up = GetImpactPoint(vx_up, vy_up, vz_up)

	local axisUpX = hx_up - calc_tx
	local axisUpZ = hz_up - calc_tz
	local lenUp = distance2d(axisUpX, axisUpZ, 0, 0)

	if lenUp > maxAxisLen then
		local scale = maxAxisLen / lenUp
		axisUpX = axisUpX * scale
		axisUpZ = axisUpZ * scale
	end

	----------------------------------------------------------------------------
	-- DRAWING
	----------------------------------------------------------------------------

	local angleStep = (pi * 2) / scatterSegments
	glDepthTest(true)
	-- Fill
	if isFilled then
		local fillAlphaMult = 0.2
		BeginNoOverlap()
		glBeginEnd(GL_TRIANGLE_FAN, function()
			local cy = spGetGroundHeight(tx, tz)
			glColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] * fillAlphaMult * scatterAlphaFactor)
			glVertex(tx, cy, tz)

			for i = 0, scatterSegments do
				local theta = i * angleStep
				local fadeFactor = GetFadeAlpha(theta)
				glColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] * fillAlphaMult * fadeFactor * scatterAlphaFactor)

				local cosTheta = cos(theta)
				local sinTheta = sin(theta)

				local px = tx + (axisRightX * cosTheta) + (axisUpX * sinTheta)
				local pz = tz + (axisRightZ * cosTheta) + (axisUpZ * sinTheta)
				local py = spGetGroundHeight(px, pz)

				glVertex(px, py, pz)
			end
		end)
		EndNoOverlap()
	end

	-- Outline
	glLineWidth(scatterLineWidthMult / dist)
	glBeginEnd(GL_LINE_LOOP, function()
		for i = 0, scatterSegments do
			local theta = i * angleStep
			local fadeFactor = GetFadeAlpha(theta)
			glColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4] * fadeFactor * scatterAlphaFactor)

			local cosTheta = cos(theta)
			local sinTheta = sin(theta)

			local px = tx + (axisRightX * cosTheta) + (axisUpX * sinTheta)
			local pz = tz + (axisRightZ * cosTheta) + (axisUpZ * sinTheta)
			local py = spGetGroundHeight(px, pz)

			glVertex(px, py, pz)
		end
	end)

	glColor(1, 1, 1, 1)
	glLineWidth(1)
	glDepthTest(false)
	return scatterAlphaFactor
end

--------------------------------------------------------------------------------
--sector
--------------------------------------------------------------------------------
---@param data AttackIndicatorData
local function DrawSectorScatter(data)
	local ux, uz = data.source.x, data.source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local angle = data.info.sector_angle
	local shortfall = data.info.sector_shortfall
	local rangeMax = data.info.sector_range_max
	local dist = data.dist

	local bars = {}
	local vx = tx - ux
	local vz = tz - uz
	local px = ux
	local pz = uz
	local vw = distance2dSquared(tx, tz, ux, uz)
	if vw > 1 and vw > rangeMax * rangeMax then
		vw = sqrt(vw)
		local scale = rangeMax / vw
		local angleAim = atan2(vx, vz)
		px = px + (vw - rangeMax) * sin(angleAim)
		pz = pz + (vw - rangeMax) * cos(angleAim)
		vx = vx * scale
		vz = vz * scale
	end
	local vx2 = 0
	local vz2 = 0
	local segments = max(3, angle / 30)
	local toRadians = pi / 180
	local count = 1
	for ii = -segments, segments do
		vx2 = vx * cos(0.5 * angle * ii / 3 * toRadians) - vz * sin(0.5 * angle * ii / 3 * toRadians)
		vz2 = vx * sin(0.5 * angle * ii / 3 * toRadians) + vz * cos(0.5 * angle * ii / 3 * toRadians)
		bars[count] = { px + vx2, ty, pz + vz2 }
		count = count + 1
	end
	bars[count] = { px + (1 - shortfall) * vx2, ty, pz + (1 - shortfall) * vz2 }
	count = count + 1
	for ii = segments, -segments, -1 do
		vx2 = vx * cos(0.5 * angle * ii / 3 * toRadians) - vz * sin(0.5 * angle * ii / 3 * toRadians)
		vz2 = vx * sin(0.5 * angle * ii / 3 * toRadians) + vz * cos(0.5 * angle * ii / 3 * toRadians)
		bars[count] = { px + (1 - shortfall) * vx2, ty, pz + (1 - shortfall) * vz2 }
		count = count + 1
	end
	bars[count] = { px + vx2, ty, pz + vz2 }
	count = count + 1
	glLineWidth(scatterLineWidthMult / dist)
	glPointSize(pointSizeMult / dist)
	glColor(scatterColor)
	glDepthTest(false)
	glBeginEnd(GL_LINE_STRIP, VertexList, bars)
	glDepthTest(true)
	glColor(1, 1, 1, 1)
	glPointSize(1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
--wobble
--------------------------------------------------------------------------------
---@param data AttackIndicatorData
local function DrawWobbleScatter(data)
	local scatter = data.info.scatter
	local ux, uy, uz = data.source.x, data.source.y, data.source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local rangeScatter = data.info.rangeScatter
	local range = data.info.range
	local dist = data.dist

	local d = distance3d(tx, ty, tz, ux, uy, uz)

	glColor(scatterColor)
	glLineWidth(scatterLineWidthMult / dist)
	if d and range then
		if d <= range then
			DrawCircle(tx, ty, tz, rangeScatter * d + scatter)
		end
	else
		DrawCircle(tx, ty, tz, scatter)
	end
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
--direct
--------------------------------------------------------------------------------
---@param data AttackIndicatorData
local function DrawDirectScatter(data)
	local scatter = data.info.scatter
	if scatter < 0.01 then
		return
	end
	local ux, uy, uz = data.source.x, data.source.y, data.source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local range = data.info.range
	local unitRadius = spGetUnitRadius(data.unitID)
	local dist = data.dist

	local dx = tx - ux
	local dy = ty - uy
	local dz = tz - uz

	local aimDirX, aimDirY, aimDirZ, d = Normalize(dx, dy, dz)

	if (not aimDirX or d == 0 or d > range) then
		return
	end

	-- 1. Calculate the 2D Ground Magnitude
	-- We need to ignore the Y component (height difference) to do
	-- flat ground calculations for the unit radius.
	-- sqrt(1 - y^2) is equivalent to sqrt(x^2 + z^2) for a normalized vector.
	local groundVectorMag = sqrt(1 - aimDirY * aimDirY)

	-- 2. Calculate the "Forward" offset to the Unit's Edge
	-- This pushes the start point from the center of the unit to the perimeter
	local edgeOffsetX = (aimDirX / groundVectorMag) * unitRadius
	local edgeOffsetZ = (aimDirZ / groundVectorMag) * unitRadius

	-- 3. Calculate the "Cone" Width

	-- This makes the cone start slightly wide based on unit size and scatter
	local startSpreadX = -scatter * edgeOffsetZ
	local startSpreadZ = scatter * edgeOffsetX

	local targetSpreadX = -scatter * (dz / groundVectorMag)
	local targetSpreadZ = scatter * (dx / groundVectorMag)

	-- 4. Define the Lines
	local vertices = {
		{ ux + edgeOffsetX + startSpreadX, uy, uz + edgeOffsetZ + startSpreadZ },
		{ tx + targetSpreadX, ty, tz + targetSpreadZ },

		{ ux + edgeOffsetX - startSpreadX, uy, uz + edgeOffsetZ - startSpreadZ },
		{ tx - targetSpreadX, ty, tz - targetSpreadZ }
	}

	glColor(data.colors.scatter)
	glLineWidth(scatterLineWidthMult / dist)
	glBeginEnd(GL_LINES, VertexList, vertices)
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
--dropped
--------------------------------------------------------------------------------
---@param data AttackIndicatorData
local function DrawDropped(data)
	local info = data.info
	if not info.salvoSize or info.salvoSize <= 1 then
		DrawAoe(data)
		return
	end

	local ux, uz = data.source.x, data.source.z
	local tx, tz = data.target.x, data.target.z

	local dx = tx - ux
	local dz = tz - uz

	local bx, _, bz = Normalize(dx, 0, dz)

	if (not bx) then
		return
	end

	local ringAlphaMult = info.v * info.salvoDelay / info.aoe
	if ringAlphaMult > 1 then
		ringAlphaMult = 1
	end

	for i = 1, info.salvoSize do
		local delay = info.salvoDelay * (i - (info.salvoSize + 1) / 2)
		local dist = info.v * delay
		local x = dist * bx + tx
		local z = dist * bz + tz
		local y = spGetGroundHeight(x, z)
		if y < 0 then
			y = 0
		end
		DrawAoe(data, nil, { x = x, y = y, z = z }, ringAlphaMult, -salvoAnimationSpeed * i)
	end
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
--orbital
--------------------------------------------------------------------------------
---@param data AttackIndicatorData
local function DrawOrbitalScatter(data)
	local scatter = data.info.scatter
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local dist = data.dist

	glColor(scatterColor)
	glLineWidth(scatterLineWidthMult / dist)
	DrawCircle(tx, ty, tz, scatter)
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

---@param data AttackIndicatorData
local function DrawDGun(data)
	local ux, uy, uz = data.source.x, data.source.y, data.source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local unitName = data.info.unitname
	local aoe = data.info.aoe
	local range = data.info.range

	local angle = atan2(ux - tx, uz - tz) + (pi / 2.1)
	local dx, dz, offset_x, offset_z = ux, uz, 0, 0
	if unitName == 'armcom' then
		offset_x = (sin(angle) * 10)
		offset_z = (cos(angle) * 10)
		dx = ux - offset_x
		dz = uz - offset_z
	elseif unitName == 'corcom' then
		offset_x = (sin(angle) * 14)
		offset_z = (cos(angle) * 14)
		dx = ux + offset_x
		dz = uz + offset_z
	end
	glDepthTest(false)
	DrawNoExplode(data, { x = dx, y = uy, z = dz })
	glDepthTest(true)
	glColor(1, 0, 0, 0.75)
	glLineWidth(1.5)
	glDrawGroundCircle(ux, uy, uz, range + (aoe * 0.7), circleDivs)
	glColor(1, 1, 1, 1)
end

--------------------------------------------------------------------------------
-- Drawing Dispatch
--------------------------------------------------------------------------------

-- Reusable context table to reduce garbage collection
---@class AttackIndicatorData
local aimData = {
	info = nil,
	unitID = 0,
	dist = 0,
	source = { x = 0, y = 0, z = 0 },
	target = { x = 0, y = 0, z = 0 },
	colors = { base = nil, fill = nil, scatter = nil, aoe = nil }
}

---@param data AttackIndicatorData
local function DrawBallistic(data)
	local scatterAlphaFactor = DrawBallisticScatter(data)
	local baseColorOverride = scatterAlphaFactor and GetFadedColor(data.colors.base, 1 - (scatterAlphaFactor * 0.9))
	DrawAoe(data, baseColorOverride)
end

---@param data AttackIndicatorData
local function DrawDirect(data)
	DrawAoe(data)
	DrawDirectScatter(data)
end

---@param data AttackIndicatorData
local function DrawWobble(data)
	DrawAoe(data)
	DrawWobbleScatter(data)
end

---@param data AttackIndicatorData
local function DrawOrbital(data)
	DrawAoe(data)
	DrawOrbitalScatter(data)
end

---@param data AttackIndicatorData
local function DrawJuno(data)
	if not data.info.isMiniJuno then
		DrawJunoArea(data)
	else
		DrawAoe(data)
	end
end

local WeaponTypeHandlers = {
	sector = DrawSectorScatter,
	ballistic = DrawBallistic,
	noexplode = DrawNoExplode,
	direct = DrawDirect,
	dropped = DrawDropped,
	wobble = DrawWobble,
	orbital = DrawOrbital,
	dgun = DrawDGun,
	juno = DrawJuno
}

--------------------------------------------------------------------------------
--callins
--------------------------------------------------------------------------------

function widget:Initialize()
	for unitDefID, unitDef in pairs(UnitDefs) do
		SetupUnitDef(unitDefID, unitDef)
	end
	SetupDisplayLists()
end

function widget:Shutdown()
	DeleteDisplayLists()
end

function widget:DrawWorldPreUnit()
	local weaponInfo, aimingUnitID = GetActiveUnitInfo()
	if not weaponInfo then
		ResetPulseAnimation()
		return
	end

	local tx, ty, tz = GetMouseTargetPosition(true)
	if (not tx) then
		ResetPulseAnimation()
		return
	end

	-- Range check for static units
	if not weaponInfo.mobile and not spGetUnitWeaponTestRange(aimingUnitID, weaponInfo.weaponNum, tx, ty, tz) then
		ResetPulseAnimation()
		return
	end

	local ux, uy, uz = spGetUnitPosition(aimingUnitID)
	if (not ux) then
		ResetPulseAnimation()
		return
	end

	aimData.info = weaponInfo
	aimData.unitID = aimingUnitID
	aimData.dist = GetMouseDistance() or 1000

	-- Adjust Source Position
	if (not weaponInfo.mobile) then
		uy = uy + spGetUnitRadius(aimingUnitID)
	end
	aimData.source.x, aimData.source.y, aimData.source.z = ux, uy, uz

	-- Adjust Target Position
	if not weaponInfo.waterWeapon and ty < 0 then
		ty = 0
	end
	aimData.target.x, aimData.target.y, aimData.target.z = tx, ty, tz

	-- Color Calculation
	local baseColor = weaponInfo.color or aoeColor
	local baseFillColor = weaponInfo.color or ((weaponInfo.type == "ballistic") and GetFadedColor(aoeColor, 0)) or aoeColor

	if weaponInfo.hasStockpile then
		local progress = StockpileSystem.fadeProgress
		aimData.colors.base = LerpColor(noStockpileColor, baseColor, progress)
		aimData.colors.scatter = LerpColor(noStockpileColor, scatterColor, progress)
		aimData.colors.fill = LerpColor(noStockpileColor, baseFillColor, progress)
	else
		aimData.colors.base = baseColor
		aimData.colors.scatter = scatterColor
		aimData.colors.fill = baseFillColor
	end

	(WeaponTypeHandlers[weaponInfo.type] or DrawAoe)(aimData)

	-- Draw Stockpile Progress
	if weaponInfo.hasStockpile then
		local numStockpiled, _, buildPercent = spGetUnitStockpile(aimingUnitID)

		if StockpileSystem.state == "delay" or StockpileSystem.state == "fading" then
			buildPercent = 1
		end

		local barAlpha = 1 - StockpileSystem.fadeProgress
		if barAlpha > 0 then
			local barColor = { baseColor[1], baseColor[2], baseColor[3], baseColor[4] * barAlpha }
			local barBgColor = { noStockpileColor[1], noStockpileColor[2], noStockpileColor[3], noStockpileColor[4] * barAlpha }
			DrawStockpileProgress(aimData, buildPercent, barColor, barBgColor)
		end
	end
end

function widget:SelectionChanged(sel)
	selectionChanged = true
end

local selChangedSec = 0
function widget:Update(dt)
	pulsePhase = pulsePhase + dt
	pulsePhase = pulsePhase - floor(pulsePhase)

	if isMonitoringStockpile then
		attackUnitID = GetUnitWithBestStockpile(unitsToMonitorStockpile)
	end

	selChangedSec = selChangedSec + dt
	if selectionChanged and selChangedSec > 0.15 then
		selChangedSec = 0
		selectionChanged = nil
		UpdateSelection()
	end

	local weaponInfo, aimingUnitID = GetActiveUnitInfo()
	StockpileSystem:Update(dt, aimingUnitID, weaponInfo and weaponInfo.hasStockpile)
end
