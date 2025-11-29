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
local min = math.min
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos
local atan2 = math.atan2
local pi = math.pi
local tau = math.tau
local floor = math.floor
local tan = math.tan
local abs = math.abs
local pow = math.pow
local lerp = math.mix
local distance2d = math.distance2d
local distance2dSquared = math.distance2dSquared
local distance3d = math.distance3d
local normalize = math.normalize
local ceil = math.ceil

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

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------
local Config = {
	General = {
		gameSpeed = Game.gameSpeed,
		minSpread = 8, -- weapons with this spread or less are ignored
	},
	Colors = {
		aoe = { 1, 0, 0, 1 },
		noEnergy = { 1, 1, 0, 1 },
		juno = { 0.87, 0.94, 0.40, 1 },
		napalm = { 0.85, 0.62, 0.28, 1 },
		emp = { 0.65, 0.65, 1, 1 },
		scatter = { 1, 1, 0, 1 },
		noStockpile = { 0.88, 0.88, 0.88, 1 },
	},
	Render = {
		scatterMinAlpha = 0.5,
		scatterLineWidthMult = 1024,
		scatterSegments = 64,
		aoeLineWidthMult = 64,
		aoeDiskBandCount = 16,
		circleDivs = 96,
		pointSizeMult = 2048,
		maxFilledCircleAlpha = 0.2,
		minFilledCircleAlpha = 0.1,
		ringDamageLevels = { 0.8, 0.6, 0.4, 0.2 }, -- draw aoe rings for these damage levels
	},
	Animation = {
		salvoSpeed = 0.1,
		waveDuration = 0.35,
		fadeDuration = 0, -- Calculated below
	}
}

-- Derived Constants
Config.Animation.fadeDuration = 1 - Config.Animation.waveDuration
local g = Game.gravity
local gravityPerFrame = g / pow(Config.General.gameSpeed, 2)

--------------------------------------------------------------------------------
-- STATE & CACHE
--------------------------------------------------------------------------------

---@class IndicatorDrawData
---@field weaponInfo WeaponInfo
local defaultAimData = {
	weaponInfo = nil,
	unitID = nil,
	distanceFromCamera = nil,
	source = { x = 0, y = 0, z = 0 },
	target = { x = 0, y = 0, z = 0 },
	colors = {
		base = { 0, 0, 0, 0 },
		fill = { 0, 0, 0, 0 },
		scatter = { 0, 0, 0, 0 },
	}
}

local State = {
	weaponInfos = {}, ---@type table<number, WeaponInfo>
	manualWeaponInfos = {}, ---@type table<number, WeaponInfo>

	-- Selection State
	hasSelection = false,
	selectionChanged = nil,
	selChangedSec = 0,

	-- Unit Logic State
	isMonitoringStockpile = false,
	unitsToMonitorStockpile = {},
	attackUnitDefID = nil,
	manualFireUnitDefID = nil,
	attackUnitID = nil,
	manualFireUnitID = nil,

	-- Animation State
	pulsePhase = 0,
	circleList = 0,

	-- Precalculated Unit Properties
	UnitCache = {
		cost = {},
		isAir = {},
		isShip = {},
		isUnderwater = {},
		isHover = {},
	},

	-- Precalculated Math
	Calculated = {
		ringWaveTriggerTimes = {},
		diskWaveTriggerTimes = {},
		unitCircles = {}, -- Unit circle vertices
	},

	-- Reusable Render Data Container (prevents GC)
	-- It's declared outside to setup the class
	aimData = defaultAimData
}

--------------------------------------------------------------------------------
-- Initialization Loops
--------------------------------------------------------------------------------
for udid, ud in pairs(UnitDefs) do
	State.UnitCache.cost[udid] = ud.cost
	if ud.isAirUnit then
		State.UnitCache.isAir[udid] = ud.isAirUnit
	end
	if ud.modCategories then
		if ud.modCategories.ship then
			State.UnitCache.isShip[udid] = true
		end
		if ud.modCategories.underwater then
			State.UnitCache.isUnderwater[udid] = true
		end
		if ud.modCategories.hover then
			State.UnitCache.isHover[udid] = true
		end
	end
end

for i, _ in ipairs(Config.Render.ringDamageLevels) do
	State.Calculated.ringWaveTriggerTimes[i] = (i / #Config.Render.ringDamageLevels) * Config.Animation.waveDuration
end
for i = 1, Config.Render.aoeDiskBandCount do
	State.Calculated.diskWaveTriggerTimes[i] = (i / Config.Render.aoeDiskBandCount) * Config.Animation.waveDuration
end
for i = 0, Config.Render.circleDivs do
	local theta = tau * i / Config.Render.circleDivs
	State.Calculated.unitCircles[i] = { cos(theta), sin(theta) }
end

--------------------------------------------------------------------------------
-- STOCKPILE STATUS
--------------------------------------------------------------------------------
local STOCKPILE_STATE = {
	DONE = 1,
	LOADING_START = 2,
	LOADING = 3,
	DELAY = 4,
	LOADING_END = 5
}

local StockpileSystem = {
	state = STOCKPILE_STATE.DONE,
	timer = 0,
	fadeProgress = 1,
	lastUnitID = -1,
	lastCount = 0,

	DELAY = 0.1,
	FADE_TIME = 0.5
}

function StockpileSystem:Reset()
	self.state = STOCKPILE_STATE.DONE
	self.timer = 0
	self.fadeProgress = 1
	self.lastUnitID = -1
	self.lastCount = 0
end

function StockpileSystem:Update(dt, unitID, hasStockpile)
	if not unitID or not hasStockpile then
		self.state = STOCKPILE_STATE.DONE
		self.fadeProgress = 1
		return
	end

	local numStockpiled = spGetUnitStockpile(unitID)

	if unitID ~= self.lastUnitID then
		self.lastUnitID = unitID
		self.lastCount = numStockpiled

		if numStockpiled > 0 then
			self.state = STOCKPILE_STATE.DONE
			self.fadeProgress = 1
		else
			self.state = STOCKPILE_STATE.LOADING
			self.fadeProgress = 0
		end
		return
	end

	if numStockpiled == 0 and self.lastCount > 0 then
		self.state = STOCKPILE_STATE.LOADING_START
	end
	self.lastCount = numStockpiled

	local currentState = self.state

	if currentState == STOCKPILE_STATE.LOADING_START then
		self.fadeProgress = self.fadeProgress - (dt / self.FADE_TIME)
		if self.fadeProgress <= 0 then
			self.fadeProgress = 0
			self.state = STOCKPILE_STATE.LOADING
		end

	elseif numStockpiled == 0 then
		if currentState ~= STOCKPILE_STATE.LOADING_START then
			self.state = STOCKPILE_STATE.LOADING
			self.fadeProgress = 0
		end

	elseif currentState == STOCKPILE_STATE.LOADING then
		self.state = STOCKPILE_STATE.DELAY
		self.timer = 0
		self.fadeProgress = 0

	elseif currentState == STOCKPILE_STATE.DELAY then
		self.timer = self.timer + dt
		self.fadeProgress = 0
		if self.timer > self.DELAY then
			self.state = STOCKPILE_STATE.LOADING_END
			self.timer = 0
		end

	elseif currentState == STOCKPILE_STATE.LOADING_END then
		self.timer = self.timer + dt
		self.fadeProgress = self.timer / self.FADE_TIME
		if self.fadeProgress >= 1 then
			self.fadeProgress = 1
			self.state = STOCKPILE_STATE.DONE
		end

	else
		self.fadeProgress = 1
	end
end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
local function GetFadedColor(color, alphaMult)
	return { color[1], color[2], color[3], color[4] * alphaMult }
end

local function FadeColorInPlace(color, alphaMult)
	color[4] = color[4] * alphaMult
end

local function LerpColorInPlace(sourceColor, targetColor, t, out)
	out[1] = lerp(sourceColor[1], targetColor[1], t)
	out[2] = lerp(sourceColor[2], targetColor[2], t)
	out[3] = lerp(sourceColor[3], targetColor[3], t)
	out[4] = lerp(sourceColor[4], targetColor[4], t)
end

local function CopyColor(target, source)
	target[1] = source[1]
	target[2] = source[2]
	target[3] = source[3]
	target[4] = source[4]
end

local function ToBool(x)
	return x and x ~= 0 and x ~= "false"
end

local function GetNormalizedAndMagnitude(x, y, z)
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

-- Clamp the max range for scatter calculations
---@param data IndicatorDrawData
local function GetClampedTarget(data)
	local ux, uy, uz = data.source.x, data.source.y, data.source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local range, unitID, weaponNum = data.weaponInfo.range, data.unitID, data.weaponInfo.weaponNum

	local aimDist = distance3d(tx, ty, tz, ux, uy, uz)

	-- If the engine says we can hit it, don't clamp
	if spGetUnitWeaponTestRange(unitID, weaponNum, tx, ty, tz) then
		return tx, ty, tz, aimDist
	end

	if aimDist > range then
		local factor = range / aimDist
		local cx = ux + (tx - ux) * factor
		local cz = uz + (tz - uz) * factor
		local cy = spGetGroundHeight(cx, cz)
		return cx, cy, cz, range
	end

	return tx, ty, tz, aimDist
end

local function GetAnnularSectorVertices(ux, uz, aimAngle, halfAngle, rMin, rMax, segments)
	local vertices = {}
	local count = 1
	-- Dynamic segment count based on size of the arc to keep it smooth
	local arcLength = rMax * halfAngle * 2
	if segments == nil then
		segments = ceil(arcLength / 20) -- 1 segment per 20 elmo
		if segments < 8 then segments = 8 end
		if segments > 64 then segments = 64 end
	end

	local step = (halfAngle * 2) / segments

	-- 1. Outer Arc (Clockwise)
	for i = 0, segments do
		local theta = (aimAngle + halfAngle) - (i * step)
		local px = ux + (sin(theta) * rMax)
		local pz = uz + (cos(theta) * rMax)
		local py = spGetGroundHeight(px, pz)
		vertices[count] = { px, py, pz }
		count = count + 1
	end

	-- 2. Inner Arc (Counter-Clockwise)
	for i = 0, segments do
		local theta = (aimAngle - halfAngle) + (i * step)
		local px = ux + (sin(theta) * rMin)
		local pz = uz + (cos(theta) * rMin)
		local py = spGetGroundHeight(px, pz)
		vertices[count] = { px, py, pz }
		count = count + 1
	end

	return vertices
end

--------------------------------------------------------------------------------
-- MOUSE LOGIC
--------------------------------------------------------------------------------

local function GetMouseTargetPosition(dgun)
	local tx, ty = spGetMouseState()
	local type, target = spTraceScreenRay(tx, ty)

	if not type or not target then
		return nil
	end

	if type == "ground" then
		return target[1], target[2], target[3]
	end

	if type == "feature" then
		local _, groundTarget = spTraceScreenRay(tx, ty, true)
		if groundTarget then
			return groundTarget[1], groundTarget[2], groundTarget[3]
		end
		return nil
	end

	if type == "unit" then
		local isAlly = spIsUnitAllied(target)
		local ignoreAlly = (dgun and WG['dgunnoally'] ~= nil) or (not dgun and WG['attacknoally'] ~= nil)
		local ignoreEnemy = (dgun and WG['dgunnoenety'] ~= nil) or (not dgun and WG['attacknoenety'] ~= nil)

		if isAlly and ignoreAlly then
			local _, groundTarget = spTraceScreenRay(tx, ty, true)
			if groundTarget then
				return groundTarget[1], groundTarget[2], groundTarget[3]
			end
			return nil
		end

		if not isAlly and ignoreEnemy then
			local unitDefID = spGetUnitDefID(target)
			local uc = State.UnitCache
			local isPassThrough = uc.isAir[unitDefID] or uc.isShip[unitDefID] or uc.isUnderwater[unitDefID]

			if not isPassThrough and uc.isHover[unitDefID] then
				local _, pos = spTraceScreenRay(tx, ty, true)
				if pos and spGetGroundHeight(pos[1], pos[3]) < 0 then
					isPassThrough = true
				end
			end

			if isPassThrough then
				return spGetUnitPosition(target)
			else
				local _, groundTarget = spTraceScreenRay(tx, ty, true)
				if groundTarget then
					return groundTarget[1], groundTarget[2], groundTarget[3]
				end
				return nil
			end
		end

		return spGetUnitPosition(target)
	end

	return nil
end

local function GetMouseDistance()
	local cx, cy, cz = spGetCameraPosition()
	local tx, ty, tz = GetMouseTargetPosition()
	if not tx then
		return nil
	end
	return distance3d(cx, cy, cz, tx, ty, tz)
end

--------------------------------------------------------------------------------
-- RENDER HELPERS
--------------------------------------------------------------------------------

local function UnitCircleVertices()
	local divs = Config.Render.circleDivs
	local circles = State.Calculated.unitCircles
	for i = 1, divs do
		local uc = circles[i]
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

	glCallList(State.circleList)

	glPopMatrix()
end

-- we don't want to start in the middle of animation when enabling the command
local function ResetPulseAnimation()
	State.pulsePhase = 0
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
-- INITIALIZATION LOGIC
--------------------------------------------------------------------------------
local function FindBestWeapon(unitDef)
	local maxSpread = Config.General.minSpread
	local bestDef, bestNum

	for weaponNum, weapon in ipairs(unitDef.weapons) do
		if weapon.weaponDef then
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if weaponDef then
				local isValid = weaponDef.canAttackGround
					and not (weaponDef.type == "Shield")
					and not ToBool(weaponDef.interceptor)
					and not string.find(weaponDef.name, "flak", nil, true)

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
local function BuildWeaponInfo(unitDef, weaponDef, weaponNum, unitDefID)
	---@class WeaponInfo
	local info = {}
	local weaponType = weaponDef.type
	local scatter = weaponDef.accuracy + weaponDef.sprayAngle

	info.aoe = weaponDef.damageAreaOfEffect
	info.cost = unitDef.cost
	info.mobile = unitDef.speed > 0
	info.waterWeapon = weaponDef.waterWeapon
	info.ee = weaponDef.edgeEffectiveness
	info.weaponNum = weaponNum
	info.hasStockpile = weaponDef.stockpile
	info.reloadTime = weaponDef.reload

	if weaponDef.paralyzer then
		info.color = Config.Colors.emp
	end
	if weaponDef.customParams.area_onhit_resistance == "fire" then
		info.isNapalm = true
		info.napalmRange = weaponDef.customParams.area_onhit_range
		info.color = Config.Colors.napalm
	end

	if weaponType == "DGun" then
		info.type = "dgun"
		info.range = weaponDef.range
		info.unitname = unitDef.name
		info.requiredEnergy = weaponDef.energyCost
	elseif weaponDef.customParams.speceffect == "sector_fire" then
		info.type = "sector"
		info.sector_angle = tonumber(weaponDef.customParams.spread_angle)
		info.sector_shortfall = tonumber(weaponDef.customParams.max_range_reduction)
		info.sector_range_max = weaponDef.range
	elseif weaponDef.customParams.junotype then
		info.type = "juno"
		info.isMiniJuno = (weaponDef.customParams.junotype == "mini")
		info.color = Config.Colors.juno
	elseif weaponType == "Cannon" then
		info.type = "ballistic"
		info.scatter = scatter
		info.range = weaponDef.range
		info.v = weaponDef.projectilespeed * Config.General.gameSpeed
		info.projectileCount = weaponDef.projectiles or 1
		info.salvoSize = weaponDef.salvoSize or 1
	elseif weaponType == "MissileLauncher" then
		local turnRate = weaponDef.turnRate or 0
		if weaponDef.wobble > turnRate * 1.5 then
			info.type = "wobble"
			info.wobble = weaponDef.wobble
			info.turnRate = turnRate
			info.v = weaponDef.projectilespeed
			info.startVelocity = weaponDef.startvelocity or 0
			info.range = weaponDef.range
			info.trajectoryHeight = weaponDef.trajectoryHeight
			info.overrangeDistance = tonumber(weaponDef.customParams.overrange_distance)
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

	local maxWeaponDef, maxWeaponNum = FindBestWeapon(unitDef)
	if not maxWeaponDef then
		return
	end

	local info = BuildWeaponInfo(unitDef, maxWeaponDef, maxWeaponNum, unitDefID)

	if maxWeaponDef.manualFire and unitDef.canManualFire then
		State.manualWeaponInfos[unitDefID] = info
	else
		State.weaponInfos[unitDefID] = info
	end
end

local function SetupDisplayLists()
	State.circleList = glCreateList(DrawUnitCircle)
end

local function DeleteDisplayLists()
	glDeleteList(State.circleList)
end

--------------------------------------------------------------------------------
-- UPDATE LOGIC
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
		State.isMonitoringStockpile = true
		State.unitsToMonitorStockpile = unitIDs
		bestUnit = GetUnitWithBestStockpile(unitIDs)
	end
	return bestUnit
end

local function UpdateSelection()
	local maxCost = 0
	State.manualFireUnitDefID = nil
	State.attackUnitDefID = nil
	State.attackUnitID = nil
	State.manualFireUnitID = nil
	State.hasSelection = false
	State.isMonitoringStockpile = false
	State.unitsToMonitorStockpile = {}

	local sel = spGetSelectedUnitsSorted()
	for unitDefID, unitIDs in pairs(sel) do
		if State.manualWeaponInfos[unitDefID] then
			State.manualFireUnitDefID = unitDefID
			State.manualFireUnitID = unitIDs[1]
			State.hasSelection = true
		end

		if State.weaponInfos[unitDefID] then
			local currCost = State.UnitCache.cost[unitDefID] * #unitIDs
			if currCost > maxCost then
				maxCost = currCost
				State.attackUnitDefID = unitDefID
				State.attackUnitID = GetRepUnitID(unitIDs, State.weaponInfos[unitDefID])
				State.hasSelection = true
			end
		end
	end
end

---@return WeaponInfo, number
local function GetActiveUnitInfo()
	if not State.hasSelection then
		return nil, nil
	end

	local _, cmd, _ = spGetActiveCommand()

	if ((cmd == CMD_MANUALFIRE or cmd == CMD_MANUAL_LAUNCH) and State.manualFireUnitDefID) then
		return State.manualWeaponInfos[State.manualFireUnitDefID], State.manualFireUnitID
	elseif ((cmd == CMD_ATTACK or cmd == CMD_UNIT_SET_TARGET or cmd == CMD_UNIT_SET_TARGET_NO_GROUND) and State.attackUnitDefID) then
		return State.weaponInfos[State.attackUnitDefID], State.attackUnitID
	end

	return nil, nil
end

--------------------------------------------------------------------------------
-- AOE
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
	local waveDuration = Config.Animation.waveDuration
	local fadeDuration = Config.Animation.fadeDuration
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
	local bandCount = Config.Render.aoeDiskBandCount
	local triggerTimes = State.Calculated.diskWaveTriggerTimes
	local maxAlpha = Config.Render.maxFilledCircleAlpha
	local minAlpha = Config.Render.minFilledCircleAlpha
	local circles = State.Calculated.unitCircles
	local divs = Config.Render.circleDivs

	glPushMatrix()
	glTranslate(tx, ty, tz)
	glBeginEnd(GL_TRIANGLE_STRIP, function()
		for idx = 1, bandCount do
			local innerRing = aoe * (idx - 1) / bandCount
			local outerRing = aoe * idx / bandCount
			local alphaFactor = GetAlphaFactorForRing(minAlpha, maxAlpha, idx, phase, alphaMult, triggerTimes)

			SetColor(alphaFactor, color)
			for i = 0, divs do
				local unitCircle = circles[i]
				glVertex(unitCircle[1] * outerRing, 0, unitCircle[2] * outerRing)
				glVertex(unitCircle[1] * innerRing, 0, unitCircle[2] * innerRing)
			end
		end
	end)
	glPopMatrix()
end

local function DrawDamageRings(tx, ty, tz, aoe, edgeEffectiveness, alphaMult, phase, color)
	local damageLevels = Config.Render.ringDamageLevels
	local triggerTimes = State.Calculated.ringWaveTriggerTimes

	for ringIndex, damageLevel in ipairs(damageLevels) do
		local ringRadius = GetRadiusForDamageLevel(aoe, damageLevel, edgeEffectiveness)
		local alphaFactor = GetAlphaFactorForRing(damageLevel, damageLevel + 0.2, ringIndex, phase, alphaMult, triggerTimes)
		SetColor(alphaFactor, color)
		DrawCircle(tx, ty, tz, ringRadius)
	end
end

---@param data IndicatorDrawData
local function DrawAoe(data, baseColorOverride, targetOverride, ringAlphaMult, phaseOffset)
	local color = baseColorOverride or data.colors.base
	local target = targetOverride or data.target
	local tx, ty, tz = target.x, target.y, target.z
	local aoe, edgeEffectiveness = data.weaponInfo.aoe, data.weaponInfo.ee

	glLineWidth(max(Config.Render.aoeLineWidthMult * aoe / data.distanceFromCamera, 0.5))
	ringAlphaMult = ringAlphaMult or 1

	local phase = State.pulsePhase + (phaseOffset or 0)
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

---@param data IndicatorDrawData
local function DrawJunoArea(data)
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local aoe = data.weaponInfo.aoe
	local phase = State.pulsePhase - floor(State.pulsePhase)
	local color = data.colors.base

	local bandCount = Config.Render.aoeDiskBandCount
	local triggerTimes = State.Calculated.diskWaveTriggerTimes
	local maxAlpha = Config.Render.maxFilledCircleAlpha
	local minAlpha = Config.Render.minFilledCircleAlpha
	local circles = State.Calculated.unitCircles
	local divs = Config.Render.circleDivs

	local areaDenialRadius = 450 -- defined in unit_juno_damage.lua
	local impactRingWidth = aoe - areaDenialRadius

	glPushMatrix()
	glTranslate(tx, ty, tz)
	glBeginEnd(GL_TRIANGLE_STRIP, function()
		SetColor(maxAlpha, color)
		for i = 0, divs do
			local unitCircle = circles[i]
			glVertex(unitCircle[1] * areaDenialRadius, 0, unitCircle[2] * areaDenialRadius)
			glVertex(0, 0, 0)
		end
	end)
	glBeginEnd(GL_TRIANGLE_STRIP, function()
		for idx = 1, bandCount do
			local innerRing = areaDenialRadius + (impactRingWidth * (idx - 1) / bandCount)
			local outerRing = areaDenialRadius + (impactRingWidth * idx / bandCount)

			local alphaFactor = GetAlphaFactorForRing(minAlpha, maxAlpha, idx, phase, 1, triggerTimes, true)

			SetColor(alphaFactor, color)
			for i = 0, divs do
				local unitCircle = circles[i]
				glVertex(unitCircle[1] * outerRing, 0, unitCircle[2] * outerRing)
				glVertex(unitCircle[1] * innerRing, 0, unitCircle[2] * innerRing)
			end
		end
	end)
	glPopMatrix()

	SetColor(1, color)
	glLineWidth(1)
	DrawCircle(tx, ty, tz, aoe)
	DrawCircle(tx, ty, tz, areaDenialRadius)

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

---@param data IndicatorDrawData
local function DrawStockpileProgress(data, buildPercent, barColor, bgColor)
	local dist = data.distanceFromCamera
	local aoe = data.weaponInfo.aoe
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local circles = State.Calculated.unitCircles
	local divs = Config.Render.circleDivs

	bgColor = bgColor or Config.Colors.noStockpile
	SetColor(1, bgColor)
	glLineWidth(max(Config.Render.aoeLineWidthMult * aoe / 2 / dist, 2))

	glPushMatrix()
	glTranslate(tx, ty, tz)
	glScale(aoe, aoe, aoe)

	glCallList(State.circleList)

	if buildPercent > 0 then
		SetColor(1, barColor)

		local limit = floor(divs * buildPercent)
		if limit > divs then
			limit = divs
		end

		glBeginEnd(GL_LINE_STRIP, function()
			for i = 0, limit do
				local v = circles[i]
				glVertex(v[1], 0, v[2])
			end

			if buildPercent < 1 then
				local angle = tau * buildPercent
				glVertex(cos(angle), 0, sin(angle))
			end
		end)
	end

	glPopMatrix()

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
-- DGUN / NO EXPLODE
--------------------------------------------------------------------------------
---@param data IndicatorDrawData
local function DrawNoExplode(data, overrideSource)
	local source = overrideSource or data.source
	local ux, uy, uz = source.x, source.y, source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local aoe = data.weaponInfo.aoe
	local range = data.weaponInfo.range
	local requiredEnergy = data.weaponInfo.requiredEnergy

	local dx = tx - ux
	local dy = ty - uy
	local dz = tz - uz

	local bx, by, bz, len = GetNormalizedAndMagnitude(dx, dy, dz)

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

	local colorAoe = Config.Colors.aoe
	local colorNoEnergy = Config.Colors.noEnergy
	local alpha = lerp(Config.Render.minFilledCircleAlpha, 1, State.pulsePhase) * colorAoe[4]

	if requiredEnergy and select(1, spGetTeamResources(spGetMyTeamID(), 'energy')) < requiredEnergy then
		glColor(colorNoEnergy[1], colorNoEnergy[2], colorNoEnergy[3], alpha)
	else
		glColor(colorAoe[1], colorAoe[2], colorAoe[3], alpha)
	end

	glLineWidth(1 + (Config.Render.scatterLineWidthMult / data.distanceFromCamera))

	glBeginEnd(GL_LINES, VertexList, vertices)

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
-- BALLISTIC
--------------------------------------------------------------------------------
--- Calculates the launch vector to hit a target (dx, dy, dz) with speed v
--- @param trajectoryMode number low (-1) or high (1) trajectory
local function GetBallisticVector(initialSpeed, dx, dy, dz, trajectoryMode)

	local horizontalDistSq = distance2dSquared(dx, dz, 0, 0)
	local horizontalDist = sqrt(horizontalDistSq)

	local totalDistSq = horizontalDistSq + dy * dy

	if totalDistSq == 0 then
		return 0, initialSpeed * trajectoryMode, 0
	end

	local speedSq = pow(initialSpeed, 2)
	local speedQuad = pow(speedSq, 2)
	local gravitySq = pow(g, 2)

	local discriminant = speedQuad - 2 * speedSq * g * dy - gravitySq * horizontalDistSq

	-- Check if the target is reachable
	if discriminant < 0 then
		return nil
	end

	local rootValue = sqrt(discriminant)

	local horizontalSpeedSqNumerator = 2 * horizontalDistSq * totalDistSq * (speedSq - g * dy - trajectoryMode * rootValue)

	if horizontalSpeedSqNumerator < 0 then
		return nil
	end

	local horizontalSpeed = sqrt(horizontalSpeedSqNumerator) / (2 * totalDistSq)

	local verticalSpeed

	if horizontalSpeed == 0 then
		verticalSpeed = initialSpeed
	else
		verticalSpeed = horizontalSpeed * dy / horizontalDist + horizontalDist * g / (2 * horizontalSpeed)
	end

	local launchVecX = dx * horizontalSpeed / horizontalDist
	local launchVecZ = dz * horizontalSpeed / horizontalDist
	local launchVecY = verticalSpeed

	return normalize(launchVecX, launchVecY, launchVecZ)
end

--- Calculates where a projectile with specific velocity vector will intersect the target plane
local function GetScatterImpact(ux, uz, calc_tx, calc_tz, v_f, gravity_f, heightDiff, dirX, dirY, dirZ)
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

		if t1 < 0 then return x2, z2 end
		if t2 < 0 then return x1, z1 end

		if d1 < d2 then
			return x1, z1
		else
			return x2, z2
		end
	else
		local flatDist = distance2d(calc_tx, calc_tz, ux, uz)
		local dirFlat = distance2d(dirX, dirZ, 0, 0)
		if dirFlat > 0.0001 then
			local scale = flatDist / dirFlat
			return ux + (dirX * scale), uz + (dirZ * scale)
		end
		return calc_tx, calc_tz
	end
end

local function DrawAnnularSectorFill(ux, uz, aimAngle, halfAngle, rMin, rMax)
	local arcLength = rMax * halfAngle * 2
	local segments = ceil(arcLength / 20)
	if segments < 8 then segments = 8 end
	if segments > 64 then segments = 64 end

	local step = (halfAngle * 2) / segments

	glBeginEnd(GL_TRIANGLE_STRIP, function()
		for i = 0, segments do
			local theta = (aimAngle - halfAngle) + (i * step)
			local sinT, cosT = sin(theta), cos(theta)

			-- Inner point
			local px_in = ux + (sinT * rMin)
			local pz_in = uz + (cosT * rMin)
			local py_in = spGetGroundHeight(px_in, pz_in)
			glVertex(px_in, py_in, pz_in)

			-- Outer point
			local px_out = ux + (sinT * rMax)
			local pz_out = uz + (cosT * rMax)
			local py_out = spGetGroundHeight(px_out, pz_out)
			glVertex(px_out, py_out, pz_out)
		end
	end)
end

---@param data IndicatorDrawData
local function DrawBallisticScatter(data)
	local scatterLineWidthMult = Config.Render.scatterLineWidthMult
	local gameSpeed = Config.General.gameSpeed

	local weaponInfo = data.weaponInfo
	local ux, uy, uz = data.source.x, data.source.y, data.source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local aimingUnitID = data.unitID
	local fillColor, lineColor = data.colors.fill, data.colors.scatter
	local trajectory = select(7, spGetUnitStates(aimingUnitID, false, true)) and 1 or -1

	local scatter = weaponInfo.scatter
	if scatter < 0.01 then return end

	local v = weaponInfo.v
	local isFilled = fillColor[4] > 0

	-- 1. Math Setup
	-- We calculate the physical spread at the gun's max effective range (or current target if closer).
	local calc_tx, calc_ty, calc_tz, calc_dist = GetClampedTarget(data)
	local dx, dy, dz = calc_tx - ux, calc_ty - uy, calc_tz - uz
	local bx, by, bz, _ = GetBallisticVector(v, dx, dy, dz, trajectory, g)
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

	local v_f = v / gameSpeed
	local gravity_f = -0.5 * gravityPerFrame
	local heightDiff = uy - calc_ty
	local cosScatter = sqrt(max(0, 1 - scatter * scatter))

	----------------------------------------------------------------------------
	-- AXIS CALCULATION
	----------------------------------------------------------------------------
	local naturalRadius = calc_dist * (tan(scatter) + 0.01)
	local scatterAlphaFactor = 0
	local baseThreshold = max(weaponInfo.aoe, 15)
	local minScatterRadius = baseThreshold * 0.5

	if naturalRadius >= baseThreshold then
		scatterAlphaFactor = 1
	elseif naturalRadius > minScatterRadius then
		scatterAlphaFactor = (naturalRadius - minScatterRadius) / (baseThreshold - minScatterRadius)
	end

	if scatterAlphaFactor <= 0 then return end

	local maxAxisLen = naturalRadius * 2.5

	-- Width
	local vx_right = bx * cosScatter + rx * scatter
	local vy_right = by * cosScatter + ry * scatter
	local vz_right = bz * cosScatter + rz * scatter
	local hx_right, hz_right = GetScatterImpact(ux, uz, calc_tx, calc_tz, v_f, gravity_f, heightDiff, vx_right, vy_right, vz_right)

	local axisRightX = hx_right - calc_tx
	local axisRightZ = hz_right - calc_tz
	local lenRight = distance2d(axisRightX, axisRightZ, 0, 0)

	-- Length
	local up_x = ry * bz - rz * by
	local up_y = rz * bx - rx * bz
	local up_z = rx * by - ry * bx

	local vx_up = bx * cosScatter + up_x * scatter
	local vy_up = by * cosScatter + up_y * scatter
	local vz_up = bz * cosScatter + up_z * scatter
	local hx_up, hz_up = GetScatterImpact(ux, uz, calc_tx, calc_tz, v_f, gravity_f, heightDiff, vx_up, vy_up, vz_up)

	local axisUpX = hx_up - calc_tx
	local axisUpZ = hz_up - calc_tz
	local lenUp = distance2d(axisUpX, axisUpZ, 0, 0)

	if lenRight > maxAxisLen then lenRight = maxAxisLen end
	if lenUp > maxAxisLen then lenUp = maxAxisLen end

	----------------------------------------------------------------------------
	-- SHAPE GENERATION
	----------------------------------------------------------------------------

	-- Actual Cursor Distance
	local dist = distance2d(ux, uz, tx, tz)

	-- Map ballistic dimensions to Sector parameters centered on cursor
	local rMax = dist + lenUp
	local rMin = dist - lenUp

	-- Prevent drawing behind the unit
	if rMin < 50 then rMin = 50 end

	-- Calculate Draw Angle:
	-- We want the visual cone width to match the physical width (lenRight).
	-- atan2(opposite, adjacent) -> atan2(width, distance)
	local spreadAngle = atan2(lenRight, dist)

	-- Generate Vertices
	local aimAngle = atan2(tx - ux, tz - uz)
	local vertices = GetAnnularSectorVertices(ux, uz, aimAngle, spreadAngle, rMin, rMax)

	----------------------------------------------------------------------------
	-- DRAWING
	----------------------------------------------------------------------------
	SetColor(scatterAlphaFactor, lineColor)
	glLineWidth(math.max(1, scatterLineWidthMult / data.distanceFromCamera))

	glBeginEnd(GL_LINE_LOOP, VertexList, vertices)

	if isFilled then
		BeginNoOverlap()
		glColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] * 0.2 * scatterAlphaFactor)
		DrawAnnularSectorFill(ux, uz, aimAngle, spreadAngle, rMin, rMax)
		EndNoOverlap()
	end

	glColor(1, 1, 1, 1)
	glLineWidth(1)
	return scatterAlphaFactor
end

--------------------------------------------------------------------------------
-- SECTOR
--------------------------------------------------------------------------------
---@param data IndicatorDrawData
local function DrawSectorScatter(data)
	local ux, uz = data.source.x, data.source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local angle = data.weaponInfo.sector_angle
	local shortfall = data.weaponInfo.sector_shortfall
	local rangeMax = data.weaponInfo.sector_range_max
	local distanceFromCamera = data.distanceFromCamera

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
	glLineWidth(Config.Render.scatterLineWidthMult / distanceFromCamera)
	glPointSize(Config.Render.pointSizeMult / distanceFromCamera)
	glColor(Config.Colors.scatter)
	glDepthTest(false)
	glBeginEnd(GL_LINE_STRIP, VertexList, bars)
	glDepthTest(true)
	glColor(1, 1, 1, 1)
	glPointSize(1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
-- WOBBLE
--------------------------------------------------------------------------------
--- At the moment used only by Catapult (0 path correction) and Thanatos (some path correction) and it's tweaked
--- to work well for both of them. It's very likely that it will have to be tweaked if their weapondefs change or
--- new unit will be introduced
--- @param data IndicatorDrawData
local function DrawWobbleScatter(data)
	local ux, uy, uz = data.source.x, data.source.y, data.source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z

	local range = data.weaponInfo.range
	local wobble = data.weaponInfo.wobble or 0
	local turnRate = data.weaponInfo.turnRate or 0
	local projSpeed = data.weaponInfo.v or 500
	local trajectoryHeight = data.weaponInfo.trajectoryHeight or 0

	--------------------------------------------------------------------------------
	-- CALIBRATION (aka magic numbers)
	--------------------------------------------------------------------------------
	-- Constant that converts engine wobble units (e.g. 0.006) into visual radians.
	-- Calibrated so the drawing matches observed in-game spread
	local SPREAD_CALIBRATION = 12.0
	-- Because wobble is random chaos, the deviation does not grow linearly with flight time.
	-- A low exponent prevents long-range shots from drawing impossibly wide cones.
	local TIME_EXPONENT = 0.20
	-- A multiplier applied to the TurnRate when fighting Wobble.
	-- A value of 2.0 means active guidance is twice as effective at reducing
	-- spread as the raw numbers suggest.
	local GUIDANCE_EFFICIENCY = 2.0
	-- Controls how much height advantage reduces the forward spread.
	-- Higher = height advantage tightens the shape more aggressively.
	local ELEVATION_IMPACT_FACTOR = 8
	--------------------------------------------------------------------------------

	-- 1. Clamp Aim Distance
	local dist = distance2d(ux, uz, tx, tz)
	local clampedDist = min(dist, range)

	-- 2. Calculate Flight Duration
	local arcFactor = 1.0 + (trajectoryHeight * 0.5)
	local flightFrames = (clampedDist * arcFactor) / projSpeed
	if flightFrames < 1 then
		flightFrames = 1
	end

	-- Range factor (% of maxDistance) for Bias interpolation
	local maxFlightFrames = (range * arcFactor) / projSpeed
	local rangeFactor = maxFlightFrames > 0 and (flightFrames / maxFlightFrames) or 0

	-- 3. Calculate Net Wobble
	local netWobble = max(0, wobble - (turnRate * GUIDANCE_EFFICIENCY))

	if netWobble <= 0.0001 then
		return
	end

	-- 4. Calculate Angle
	local timeFactor = pow(flightFrames, TIME_EXPONENT)
	local spreadAngle = netWobble * SPREAD_CALIBRATION * timeFactor

	if spreadAngle > 1.2 then spreadAngle = 1.2 end
	if spreadAngle < 0.02 then spreadAngle = 0.02 end

	-- 5. Calculate Shape Biases
	local spreadRadius = clampedDist * tan(spreadAngle)

	local guidance = wobble > 0 and turnRate / wobble or 0

	-- FORWARD BIAS (Overshoot)
	-- Projectiles go up before turning towards the ground which always makes them overshoot at close distance
	local closeRangeBias = (trajectoryHeight - guidance) * 3.0

	local maxRangeBias = trajectoryHeight * (1.0 - guidance)
	if guidance > 0 then
		maxRangeBias = maxRangeBias * 0.5
	end

	local forwardBias = lerp(closeRangeBias, maxRangeBias, rangeFactor)

	-- If we are above the target, the impact angle is steeper, reducing overshoot.
	if uy > ty then
		local heightDiff = uy - ty
		local slope = heightDiff / max(1, clampedDist)
		local trajectoryDamping = 1.0 + trajectoryHeight
		local elevationCorrection = (slope * ELEVATION_IMPACT_FACTOR) / trajectoryDamping
		forwardBias = max(0, forwardBias - elevationCorrection)
	end

	-- BACKWARD BIAS (Undershoot)
	-- Increases linearly with range
	local backwardBias = ((trajectoryHeight + guidance) * rangeFactor) * 0.5

	-- Apply Biases
	local rMax = dist + (spreadRadius * forwardBias)
	local rMin = dist - (spreadRadius * backwardBias)

	-- 6. Clamps and Draw
	if rMin < 50 then rMin = 50 end

	-- Handle Over-range. Using lower overrangeDistance because projectiles won't reach it most of the time
	local overrange = data.weaponInfo.overrangeDistance * 0.9 or (range * 1.15)
	-- ensure overrange is actually larger than range
	if overrange < range then overrange = range * 1.05 end

	-- If we are aiming past the clamp limit, we push the overrange wall back
	-- This keeps the shape "squashed" against the wall exactly as it is at max range
	if dist > clampedDist then
		overrange = overrange + (dist - clampedDist)
	end

	if rMax > overrange then rMax = overrange end
	if rMin >= rMax then rMin = rMax - 10 end

	-- 7. Recalculate Draw Angle for Over-range
	-- If we use the original 'spreadAngle' at distance 'dist', the cone will get wider.
	-- We want the physical width (spreadRadius) to stay the same as it was at 'clampedDist'.
	if dist > clampedDist then
		spreadAngle = atan2(spreadRadius, dist)
	end

	local dx = tx - ux
	local dz = tz - uz
	local aimAngle = atan2(dx, dz)

	local vertices = GetAnnularSectorVertices(ux, uz, aimAngle, spreadAngle, rMin, rMax)

	local spreadAlphaFactor = 0
	local baseThreshold = max(data.weaponInfo.aoe * 2, 50)
	local minSpreadRadius = baseThreshold * 0.5

	local visualSpreadRadius = max(spreadRadius, spreadRadius * forwardBias)

	if visualSpreadRadius >= baseThreshold then
		spreadAlphaFactor = 1
	elseif visualSpreadRadius > minSpreadRadius then
		spreadAlphaFactor = (visualSpreadRadius - minSpreadRadius) / (baseThreshold - minSpreadRadius)
	end

	if spreadAlphaFactor <= 0 then
		return 0
	end

	SetColor(spreadAlphaFactor, data.colors.scatter)
	glLineWidth(max(1, Config.Render.scatterLineWidthMult / data.distanceFromCamera))
	glBeginEnd(GL_LINE_LOOP, VertexList, vertices)

	glColor(1, 1, 1, 1)
	glLineWidth(1)
	return spreadAlphaFactor
end

--------------------------------------------------------------------------------
-- DIRECT
--------------------------------------------------------------------------------
---@param data IndicatorDrawData
local function DrawDirectScatter(data)
	local scatter = data.weaponInfo.scatter
	if scatter < 0.01 then
		return
	end
	local ux, uy, uz = data.source.x, data.source.y, data.source.z
	local unitRadius = spGetUnitRadius(data.unitID)

	local ctx, cty, ctz = GetClampedTarget(data)

	local dx = ctx - ux
	local dy = cty - uy
	local dz = ctz - uz

	local aimDirX, aimDirY, aimDirZ, len = GetNormalizedAndMagnitude(dx, dy, dz)

	if len == 0 or not aimDirX then
		return
	end

	-- We need to ignore the height difference
	local groundVectorMag = sqrt(1 - aimDirY * aimDirY)

	-- Push the start point from the center of the unit to the perimeter
	local edgeOffsetX = (aimDirX / groundVectorMag) * unitRadius
	local edgeOffsetZ = (aimDirZ / groundVectorMag) * unitRadius

	local startSpreadX = -scatter * edgeOffsetZ
	local startSpreadZ = scatter * edgeOffsetX

	local targetSpreadX = -scatter * (dz / groundVectorMag)
	local targetSpreadZ = scatter * (dx / groundVectorMag)

	-- Use Clamped Targets (ctx, cty, ctz) for drawing the tip of the cone
	local vertices = {
		{ ux + edgeOffsetX + startSpreadX, uy, uz + edgeOffsetZ + startSpreadZ },
		{ ctx + targetSpreadX, cty, ctz + targetSpreadZ },

		{ ux + edgeOffsetX - startSpreadX, uy, uz + edgeOffsetZ - startSpreadZ },
		{ ctx - targetSpreadX, cty, ctz - targetSpreadZ }
	}

	glColor(Config.Colors.scatter)
	glLineWidth(Config.Render.scatterLineWidthMult / data.distanceFromCamera)
	glBeginEnd(GL_LINES, VertexList, vertices)
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
-- DROPPED
--------------------------------------------------------------------------------
---@param data IndicatorDrawData
local function DrawDropped(data)
	local weaponInfo = data.weaponInfo
	if not weaponInfo.salvoSize or weaponInfo.salvoSize <= 1 then
		DrawAoe(data)
		return
	end

	local ux, uz = data.source.x, data.source.z
	local tx, tz = data.target.x, data.target.z

	local dx = tx - ux
	local dz = tz - uz

	local bx, _, bz = normalize(dx, 0, dz)

	if (not bx) then
		return
	end

	local ringAlphaMult = weaponInfo.v * weaponInfo.salvoDelay / weaponInfo.aoe
	if ringAlphaMult > 1 then
		ringAlphaMult = 1
	end

	local salvoAnimationSpeed = Config.Animation.salvoSpeed

	for i = 1, weaponInfo.salvoSize do
		local delay = weaponInfo.salvoDelay * (i - (weaponInfo.salvoSize + 1) / 2)
		local dist = weaponInfo.v * delay
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

---@param data IndicatorDrawData
local function DrawDGun(data)
	local ux, uy, uz = data.source.x, data.source.y, data.source.z
	local tx, tz = data.target.x, data.target.z
	local unitName = data.weaponInfo.unitname
	local aoe = data.weaponInfo.aoe
	local range = data.weaponInfo.range
	local divs = Config.Render.circleDivs

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
	glDrawGroundCircle(ux, uy, uz, range + (aoe * 0.7), divs)
	glColor(1, 1, 1, 1)
end

--------------------------------------------------------------------------------
-- DRAWING DISPATCH
--------------------------------------------------------------------------------

---@param data IndicatorDrawData
local function DrawBallistic(data)
	local scatterAlphaFactor = DrawBallisticScatter(data)
	local baseColorOverride = scatterAlphaFactor and GetFadedColor(data.colors.base, 1 - (scatterAlphaFactor * 0.7))
	DrawAoe(data, baseColorOverride)
end

---@param data IndicatorDrawData
local function DrawDirect(data)
	DrawAoe(data)
	DrawDirectScatter(data)
end

---@param data IndicatorDrawData
local function DrawWobble(data)
	local scatterAlphaFactor = DrawWobbleScatter(data) or 0
	FadeColorInPlace(data.colors.base, 1 - (scatterAlphaFactor * 0.5))
	DrawAoe(data)
end

---@param data IndicatorDrawData
local function DrawJuno(data)
	if not data.weaponInfo.isMiniJuno then
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
	dgun = DrawDGun,
	juno = DrawJuno
}

--------------------------------------------------------------------------------
-- CALLINS
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

	-- Do not draw if unit can't move and targeting outside the range
	if not weaponInfo.mobile and not spGetUnitWeaponTestRange(aimingUnitID, weaponInfo.weaponNum, tx, ty, tz) then
		ResetPulseAnimation()
		return
	end

	local ux, uy, uz = spGetUnitPosition(aimingUnitID)
	if (not ux) then
		ResetPulseAnimation()
		return
	end

	local aimData = State.aimData

	aimData.weaponInfo = weaponInfo
	aimData.unitID = aimingUnitID
	aimData.distanceFromCamera = GetMouseDistance() or 1000

	if (not weaponInfo.mobile) then
		uy = uy + spGetUnitRadius(aimingUnitID)
	end
	aimData.source.x, aimData.source.y, aimData.source.z = ux, uy, uz

	if not weaponInfo.waterWeapon and ty < 0 then
		ty = 0
	end
	aimData.target.x, aimData.target.y, aimData.target.z = tx, ty, tz

	-- Color Calculation
	local baseColor = weaponInfo.color or Config.Colors.aoe
	local baseFillColor = weaponInfo.color or ((weaponInfo.type == "ballistic") and GetFadedColor(Config.Colors.aoe, 0)) or Config.Colors.aoe
	local noStockpileColor = Config.Colors.noStockpile
	local scatterColor = Config.Colors.scatter

	if weaponInfo.hasStockpile then
		local progress = StockpileSystem.fadeProgress
		LerpColorInPlace(noStockpileColor, baseColor, progress, aimData.colors.base)
		LerpColorInPlace(noStockpileColor, scatterColor, progress, aimData.colors.scatter)
		LerpColorInPlace(noStockpileColor, baseFillColor, progress, aimData.colors.fill)
	else
		-- Copy to avoid creating new tables
		CopyColor(aimData.colors.base, baseColor)
		CopyColor(aimData.colors.fill, baseFillColor)
		CopyColor(aimData.colors.scatter, scatterColor)
	end

	(WeaponTypeHandlers[weaponInfo.type] or DrawAoe)(aimData)

	-- Draw Stockpile Progress
	if weaponInfo.hasStockpile then
		local numStockpiled, numStockpileQued, buildPercent = spGetUnitStockpile(aimingUnitID)

		if StockpileSystem.state == STOCKPILE_STATE.DELAY or StockpileSystem.state == STOCKPILE_STATE.LOADING_END then
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
	State.selectionChanged = true
end

function widget:Update(dt)
	local pulsePhase = State.pulsePhase + dt
	State.pulsePhase = pulsePhase - floor(pulsePhase)

	if State.isMonitoringStockpile then
		State.attackUnitID = GetUnitWithBestStockpile(State.unitsToMonitorStockpile)
	end

	State.selChangedSec = State.selChangedSec + dt
	if State.selectionChanged and State.selChangedSec > 0.15 then
		State.selChangedSec = 0
		State.selectionChanged = nil
		UpdateSelection()
	end

	local weaponInfo, aimingUnitID = GetActiveUnitInfo()
	StockpileSystem:Update(dt, aimingUnitID, weaponInfo and weaponInfo.hasStockpile)
end
