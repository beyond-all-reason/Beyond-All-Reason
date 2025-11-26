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

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------
local Config = {
	General = {
		gameSpeed = 30,
		minSpread = 8, --weapons with this spread or less are ignored
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
		ringDamageLevels = { 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1 }, -- draw aoe rings for these damage levels
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
local gravityPerFrame = g / Config.General.gameSpeed / Config.General.gameSpeed

--------------------------------------------------------------------------------
-- STATE & CACHE
--------------------------------------------------------------------------------

---@class IndicatorDrawData
---@field info WeaponInfo
local defaultAimData = {
	info = nil,
	unitID = 0,
	dist = 0,
	source = { x = 0, y = 0, z = 0 },
	target = { x = 0, y = 0, z = 0 },
	colors = {
		base = { 0, 0, 0, 0 },
		fill = { 0, 0, 0, 0 },
		scatter = { 0, 0, 0, 0 },
		aoe = { 0, 0, 0, 0 }
	}
}

local State = {
	weaponInfos = {},       ---@type table<number, WeaponInfo>
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
	local theta = 2 * pi * i / Config.Render.circleDivs
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

local function Lerp(a, b, time)
	return b - (b - a) * time
end

local function LerpColorInPlace(c1, c2, t, out)
	local invT = 1 - t
	out[1] = c1[1] * invT + c2[1] * t
	out[2] = c1[2] * invT + c2[2] * t
	out[3] = c1[3] * invT + c2[3] * t
	out[4] = c1[4] * invT + c2[4] * t
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

--------------------------------------------------------------------------------
-- BALLISTICS HELPERS
--------------------------------------------------------------------------------
--- Calculates the launch vector to hit a target (dx, dy, dz) with speed v
local function GetBallisticVector(v, dx, dy, dz, trajectory, gravity)
	local dr_sq = distance2dSquared(dx, dz, 0, 0)
	local dr = sqrt(dr_sq)

	local d_sq = dr_sq + dy * dy

	if d_sq == 0 then
		return 0, v * trajectory, 0
	end

	local root1 = v * v * v * v - 2 * v * v * gravity * dy - gravity * gravity * dr_sq
	if root1 < 0 then
		return nil
	end

	local root2 = 2 * dr_sq * d_sq * (v * v - gravity * dy - trajectory * sqrt(root1))

	if root2 < 0 then
		return nil
	end

	local vr = sqrt(root2) / (2 * d_sq)
	local vy

	if vr == 0 then
		vy = v
	else
		vy = vr * dy / dr + dr * gravity / (2 * vr)
	end

	local bx = dx * vr / dr
	local bz = dz * vr / dr
	local by = vy
	return Normalize(bx, by, bz)
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
local function BuildWeaponInfo(unitDef, weaponDef, weaponNum)
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

	local maxWeaponDef, maxWeaponNum = FindBestWeapon(unitDef)
	if not maxWeaponDef then
		return
	end

	local info = BuildWeaponInfo(unitDef, maxWeaponDef, maxWeaponNum)

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
-- AOE RENDERING
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
		result = Lerp(minAlpha, maxAlpha, fadeProgress)
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
	local dist = data.dist
	local color = baseColorOverride or data.colors.base
	local target = targetOverride or data.target
	local tx, ty, tz = target.x, target.y, target.z
	local aoe, edgeEffectiveness = data.info.aoe, data.info.ee

	glLineWidth(max(Config.Render.aoeLineWidthMult * aoe / dist, 0.5))
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
	local aoe = data.info.aoe
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

local function DrawStockpileProgress(data, buildPercent, barColor, bgColor)
	local dist = data.dist
	local aoe = data.info.aoe
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
				local angle = 2 * pi * buildPercent
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

	local colorAoe = Config.Colors.aoe
	local colorNoEnergy = Config.Colors.noEnergy
	local alpha = Lerp(Config.Render.minFilledCircleAlpha, 1, State.pulsePhase) * colorAoe[4]

	if requiredEnergy and select(1, spGetTeamResources(spGetMyTeamID(), 'energy')) < requiredEnergy then
		glColor(colorNoEnergy[1], colorNoEnergy[2], colorNoEnergy[3], alpha)
	else
		glColor(colorAoe[1], colorAoe[2], colorAoe[3], alpha)
	end

	glLineWidth(1 + (Config.Render.scatterLineWidthMult / dist))

	glBeginEnd(GL_LINES, VertexList, vertices)

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
-- BALLISTICS RENDERING
--------------------------------------------------------------------------------

local function GetFadeAlpha(theta, minAlpha)
	local sinTheta = sin(theta)
	return 1 - (pow(abs(sinTheta), 2) * (1 - minAlpha))
end

---@param data IndicatorDrawData
local function DrawBallisticScatter(data)
	local scatterSegments = Config.Render.scatterSegments
	local scatterLineWidthMult = Config.Render.scatterLineWidthMult
	local scatterMinAlpha = Config.Render.scatterMinAlpha
	local gameSpeed = Config.General.gameSpeed

	local info = data.info
	local ux, uy, uz = data.source.x, data.source.y, data.source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local dist = data.dist
	local aimingUnitID = data.unitID
	local fillColor, lineColor = data.colors.fill, data.colors.scatter
	local trajectory = select(7, spGetUnitStates(aimingUnitID, false, true)) and 1 or -1

	local scatter = info.scatter
	if scatter < 0.01 then return end

	local v = info.v
	local isFilled = fillColor[4] > 0

	-- 1. Math Setup
	local aimDist = distance3d(tx, ty, tz, ux, uy, uz)
	local isOutsideMaxRange = aimDist > info.range and not spGetUnitWeaponTestRange(aimingUnitID, info.weaponNum, tx, ty, tz)

	local calc_tx, calc_ty, calc_tz = tx, ty, tz
	local calc_dist = aimDist

	if isOutsideMaxRange then
		local factor = info.range / aimDist
		calc_tx = ux + (tx - ux) * factor
		calc_tz = uz + (tz - uz) * factor
		calc_ty = spGetGroundHeight(calc_tx, calc_tz)
		calc_dist = info.range
	end

	local dx, dy, dz = calc_tx - ux, calc_ty - uy, calc_tz - uz

	local bx, by, bz, _ = GetBallisticVector(v, dx, dy, dz, trajectory, g)
	if not bx then return end

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
	local baseThreshold = max(info.aoe, 15)
	local minScatterRadius = baseThreshold * 0.5

	if naturalRadius >= baseThreshold then
		scatterAlphaFactor = 1
	elseif naturalRadius > minScatterRadius then
		scatterAlphaFactor = (naturalRadius - minScatterRadius) / (baseThreshold - minScatterRadius)
	end

	if scatterAlphaFactor <= 0 then return end

	local maxAxisLen = naturalRadius * 2.5

	-- Yaw Axis
	local vx_right = bx * cosScatter + rx * scatter
	local vy_right = by * cosScatter + ry * scatter
	local vz_right = bz * cosScatter + rz * scatter
	local hx_right, hz_right = GetScatterImpact(ux, uz, calc_tx, calc_tz, v_f, gravity_f, heightDiff, vx_right, vy_right, vz_right)

	local axisRightX = hx_right - calc_tx
	local axisRightZ = hz_right - calc_tz
	local lenRight = distance2d(axisRightX, axisRightZ, 0, 0)
	if lenRight > maxAxisLen then
		local scale = maxAxisLen / lenRight
		axisRightX = axisRightX * scale
		axisRightZ = axisRightZ * scale
	end

	-- Pitch Axis
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

	if isFilled then
		local fillAlphaMult = 0.2
		BeginNoOverlap()
		glBeginEnd(GL_TRIANGLE_FAN, function()
			local cy = spGetGroundHeight(tx, tz)
			glColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] * fillAlphaMult * scatterAlphaFactor)
			glVertex(tx, cy, tz)

			for i = 0, scatterSegments do
				local theta = i * angleStep
				local fadeFactor = GetFadeAlpha(theta, scatterMinAlpha)
				glColor(fillColor[1], fillColor[2], fillColor[3], fillColor[4] * fillAlphaMult * fadeFactor * scatterAlphaFactor)

				local cosTheta, sinTheta = cos(theta), sin(theta)
				local px = tx + (axisRightX * cosTheta) + (axisUpX * sinTheta)
				local pz = tz + (axisRightZ * cosTheta) + (axisUpZ * sinTheta)
				local py = spGetGroundHeight(px, pz)

				glVertex(px, py, pz)
			end
		end)
		EndNoOverlap()
	end

	glLineWidth(scatterLineWidthMult / dist)
	glBeginEnd(GL_LINE_LOOP, function()
		for i = 0, scatterSegments do
			local theta = i * angleStep
			local fadeFactor = GetFadeAlpha(theta, scatterMinAlpha)
			glColor(lineColor[1], lineColor[2], lineColor[3], lineColor[4] * fadeFactor * scatterAlphaFactor)

			local cosTheta, sinTheta = cos(theta), sin(theta)
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
-- SECTOR
--------------------------------------------------------------------------------
---@param data IndicatorDrawData
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
	glLineWidth(Config.Render.scatterLineWidthMult / dist)
	glPointSize(Config.Render.pointSizeMult / dist)
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
---@param data IndicatorDrawData
local function DrawWobbleScatter(data)
	local scatter = data.info.scatter
	local ux, uy, uz = data.source.x, data.source.y, data.source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local rangeScatter = data.info.rangeScatter
	local range = data.info.range
	local dist = data.dist

	local d = distance3d(tx, ty, tz, ux, uy, uz)

	glColor(Config.Colors.scatter)
	glLineWidth(Config.Render.scatterLineWidthMult / dist)
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
-- DIRECT
--------------------------------------------------------------------------------
---@param data IndicatorDrawData
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

	local vertices = {
		{ ux + edgeOffsetX + startSpreadX, uy, uz + edgeOffsetZ + startSpreadZ },
		{ tx + targetSpreadX, ty, tz + targetSpreadZ },

		{ ux + edgeOffsetX - startSpreadX, uy, uz + edgeOffsetZ - startSpreadZ },
		{ tx - targetSpreadX, ty, tz - targetSpreadZ }
	}

	glColor(Config.Colors.scatter)
	glLineWidth(Config.Render.scatterLineWidthMult / dist)
	glBeginEnd(GL_LINES, VertexList, vertices)
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
-- DROPPED
--------------------------------------------------------------------------------
---@param data IndicatorDrawData
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

	local salvoAnimationSpeed = Config.Animation.salvoSpeed

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
-- ORBITAL
--------------------------------------------------------------------------------
---@param data IndicatorDrawData
local function DrawOrbitalScatter(data)
	local scatter = data.info.scatter
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local dist = data.dist

	glColor(Config.Colors.scatter)
	glLineWidth(Config.Render.scatterLineWidthMult / dist)
	DrawCircle(tx, ty, tz, scatter)
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

---@param data IndicatorDrawData
local function DrawDGun(data)
	local ux, uy, uz = data.source.x, data.source.y, data.source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local unitName = data.info.unitname
	local aoe = data.info.aoe
	local range = data.info.range
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
	local baseColorOverride = scatterAlphaFactor and GetFadedColor(data.colors.base, 1 - (scatterAlphaFactor * 0.9))
	DrawAoe(data, baseColorOverride)
end

---@param data IndicatorDrawData
local function DrawDirect(data)
	DrawAoe(data)
	DrawDirectScatter(data)
end

---@param data IndicatorDrawData
local function DrawWobble(data)
	DrawAoe(data)
	DrawWobbleScatter(data)
end

---@param data IndicatorDrawData
local function DrawOrbital(data)
	DrawAoe(data)
	DrawOrbitalScatter(data)
end

---@param data IndicatorDrawData
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

	aimData.info = weaponInfo
	aimData.unitID = aimingUnitID
	aimData.dist = GetMouseDistance() or 1000

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
