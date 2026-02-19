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
local diag = math.diag
local rad = math.rad

local osClock = os.clock

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
local spGetViewGeometry = Spring.GetViewGeometry

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
local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glRotate = gl.Rotate
local glScale = gl.Scale
local glTranslate = gl.Translate
local glVertex = gl.Vertex
local LuaShader = gl.LuaShader

local GL_LINES = GL.LINES
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_LINE_STRIP = GL.LINE_STRIP
local GL_TRIANGLE_STRIP = GL.TRIANGLE_STRIP
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------
local Config = {
	General = {
		gameSpeed = Game.gameSpeed,
		minSpread = 8,
		minRingRadius = 1,
	},
	Colors = {
		aoe = { 1, 0, 0, 1 },
		none = { 0, 0, 0, 0 },
		noEnergy = { 1, 1, 0, 1 },
		juno = { 0.87, 0.94, 0.40, 1 },
		napalm = { 0.92, 0.62, 0.31, 1 },
		emp = { 0.5, 0.5, 1, 1 },
		scatter = { 1, 1, 0, 1 },
		noStockpile = { 0.88, 0.88, 0.88, 1 },
	},
	Render = {
		scatterLineWidthMult = 1024,
		aoeLineWidthMult = 64,
		aoeDiskBandCount = 12,
		circleDivs = 96,
		maxFilledCircleAlpha = 0.35,
		minFilledCircleAlpha = 0.15,
		ringDamageLevels = { 0.8, 0.6, 0.4, 0.2 },
		outerRingAlpha = 0.33,  -- Transparency for outer AOE circle
		baseLineWidth = 1,     -- Base line width (scaled by screen resolution)
	},
	Animation = {
		salvoSpeed = 0.1,
		waveDuration = 0.35,
		fadeDuration = 0,
	}
}

-- Derived Constants
Config.Animation.fadeDuration = 1 - Config.Animation.waveDuration
local g = Game.gravity
local gravityPerFrame = g / pow(Config.General.gameSpeed, 2)

-- Screen-based line width scale (1.0 at 1080p, ~2.3 at 2160p)
-- Uses linear interpolation: scale = 1 + (screenHeight - 1080) * (2.3 - 1) / (2160 - 1080)
local screenLineWidthScale = 1.0
local function UpdateScreenScale()
	local _, screenHeight = spGetViewGeometry()
	-- Linear scale: 1.0 at 1080p, 2.3 at 2160p
	screenLineWidthScale = 1.0 + (screenHeight - 1080) * (2 / 1080)
	if screenLineWidthScale < 0.5 then screenLineWidthScale = 0.5 end  -- Minimum for low res
end

--------------------------------------------------------------------------------
-- SHADER
--------------------------------------------------------------------------------
local napalmShader
local shaderSourceCache = {
	shaderName = 'AoE Napalm Shader',
	vssrcpath = "LuaUI/Shaders/gui_attack_aoe_napalm.vert.glsl",
	fssrcpath = "LuaUI/Shaders/gui_attack_aoe_napalm.frag.glsl",
	uniformInt = {},
	uniformFloat = {
		time = 0.0,
		center = { 0, 0 },
		u_color = { 1, 0, 0, 0.5 },
	},
	shaderConfig = {
	}
}

--------------------------------------------------------------------------------
-- STATE & CACHE
--------------------------------------------------------------------------------
local Cache = {
	weaponInfos = {}, ---@type table<number, WeaponInfos>
	manualWeaponInfos = {}, ---@type table<number, WeaponInfos>

	UnitProperties = {
		cost = {},
		isHover = {},
		alwaysTargetUnit = {},
	},

	Calculated = {
		ringWaveTriggerTimes = {},
		diskWaveTriggerTimes = {},
		unitCircles = {}, -- Unit circle vertices
	},
}

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
	hasSelection = false,
	selectionChanged = nil,
	selChangedSec = 0,

	isMonitoringStockpile = false,
	isStockpileForManualFire = false,
	unitsToMonitorStockpile = {},
	attackUnitDefID = nil,
	manualFireUnitDefID = nil,
	attackUnitID = nil,
	manualFireUnitID = nil,

	pulsePhase = 0,
	circleList = 0,
	unitDiskList = 0,
	nuclearTrefoilList = 0,

	aimData = defaultAimData
}

for udid, ud in pairs(UnitDefs) do
	local alwaysTargetUnit = false
	if ud.isAirUnit then
		alwaysTargetUnit = true
	end
	if ud.modCategories then
		if ud.modCategories.ship or ud.modCategories.underwater then
			alwaysTargetUnit = true
		end
		if ud.modCategories.hover then
			Cache.UnitProperties.isHover[udid] = true
		end
	end
	Cache.UnitProperties.alwaysTargetUnit[udid] = alwaysTargetUnit
	Cache.UnitProperties.cost[udid] = ud.cost
end

for i, _ in ipairs(Config.Render.ringDamageLevels) do
	Cache.Calculated.ringWaveTriggerTimes[i] = (i / #Config.Render.ringDamageLevels) * Config.Animation.waveDuration
end
for i = 1, Config.Render.aoeDiskBandCount do
	Cache.Calculated.diskWaveTriggerTimes[i] = (i / Config.Render.aoeDiskBandCount) * Config.Animation.waveDuration
end
for i = 0, Config.Render.circleDivs do
	local theta = tau * i / Config.Render.circleDivs
	Cache.Calculated.unitCircles[i] = { cos(theta), sin(theta) }
end

--------------------------------------------------------------------------------
-- STOCKPILE STATUS
--------------------------------------------------------------------------------
local StockpileStatus = {
	progressBarAlpha = 0,
	FADE_SPEED = 5.0,
}

function StockpileStatus:Update(dt, unitID, hasStockpile)
	local targetAlpha = 0

	if unitID and hasStockpile then
		local count = spGetUnitStockpile(unitID)
		if count == 0 then targetAlpha = 1 end
	end

	if self.progressBarAlpha < targetAlpha then
		self.progressBarAlpha = min(targetAlpha, self.progressBarAlpha + (dt * self.FADE_SPEED))
	elseif self.progressBarAlpha > targetAlpha then
		self.progressBarAlpha = max(targetAlpha, self.progressBarAlpha - (dt * self.FADE_SPEED))
	end
end

--------------------------------------------------------------------------------
-- MOUSE LOGIC
--------------------------------------------------------------------------------
local function GetMouseTargetPosition(weaponType, aimingUnitID)
	local isDgun = weaponType == "dgun"
	local mx, my = spGetMouseState()
	local targetType, target = spTraceScreenRay(mx, my)

	if not targetType or not target then
		return nil
	end

	local groundPositionCache
	local function GetGroundPosition()
		if groundPositionCache ~= nil then
			return groundPositionCache
		end
		local _, pos = spTraceScreenRay(mx, my, true)
		groundPositionCache = pos or false
		return groundPositionCache
	end

	if targetType == "ground" then
		return target[1], target[2], target[3]
	end

	if targetType == "feature" then
		local groundPosition = GetGroundPosition()
		if groundPosition then
			return groundPosition[1], groundPosition[2], groundPosition[3]
		end
		return nil
	end

	if targetType == "unit" then
		local unitID = target
		-- do not snap when aiming at yourself
		if unitID == aimingUnitID then
			local groundPosition = GetGroundPosition()
			if groundPosition then
				return groundPosition[1], groundPosition[2], groundPosition[3]
			else
				return nil
			end
		end
		local isAlly = spIsUnitAllied(unitID)
		local shouldIgnoreUnit = false

		if isDgun then
			shouldIgnoreUnit = (isAlly and WG['dgunnoally']) or (not isAlly and WG['dgunnoenemy'])
		else
			shouldIgnoreUnit = (isAlly and WG['attacknoally'])
		end

		if not shouldIgnoreUnit then
			return spGetUnitPosition(unitID)
		end

		local unitProperties = Cache.UnitProperties
		local unitDefID = spGetUnitDefID(unitID)

		if unitProperties.alwaysTargetUnit[unitDefID] then
			return spGetUnitPosition(unitID)
		end

		local groundPosition = GetGroundPosition()
		if not groundPosition then
			return nil
		end

		if unitProperties.isHover[unitDefID] and spGetGroundHeight(groundPosition[1], groundPosition[3]) < 0 then
			return spGetUnitPosition(unitID)
		end

		return groundPosition[1], groundPosition[2], groundPosition[3]
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
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
local function GetSizeBasedAlpha(currentSize, minRadius)
	local maxRadius = minRadius * 2

	if currentSize >= maxRadius then
		return 1
	elseif currentSize <= minRadius then
		return 0
	else
		return (currentSize - minRadius) / (maxRadius - minRadius)
	end
end

local function FadeColorInPlace(color, alphaMult)
	color[4] = color[4] * alphaMult
end

local function SetGlColor(alphaFactor, color)
	glColor(color[1], color[2], color[3], color[4] * alphaFactor)
end

local function LerpColor(sourceColor, targetColor, t, out)
	out[1] = lerp(sourceColor[1], targetColor[1], t)
	out[2] = lerp(sourceColor[2], targetColor[2], t)
	out[3] = lerp(sourceColor[3], targetColor[3], t)
	out[4] = lerp(sourceColor[4], targetColor[4], t)
	return out
end

local function CopyColor(source, target)
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
	if mag ~= 0 then
		return x / mag, y / mag, z / mag, mag
	end
end

-- Clamp the max range for scatter calculations
---@param data IndicatorDrawData
local function GetClampedTarget(data)
	local ux, uy, uz = data.source.x, data.source.y, data.source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local range, unitID, weaponNum = data.weaponInfo.range, data.unitID, data.weaponInfo.weaponNum

	local initialSpeed = data.weaponInfo.v
	-- weapons with very low initial speed produce nasty effects if their max range lies on high hill which they
	-- can't reach. This makes sure that it the calculated target is reachable.
	-- if initialSpeed is null then it's probably not a ballistic weapon so it doesn't matter
	if initialSpeed then
		ty = min(ty, initialSpeed / 2)
	end

	local aimDist = distance3d(tx, ty, tz, ux, uy, uz)

	if aimDist > range then
		local factor = range / aimDist
		local cx = ux + (tx - ux) * factor
		local cz = uz + (tz - uz) * factor
		local cy = ty
		return cx, cy, cz, range
	end

	return tx, ty, tz, aimDist
end

-- we don't want to start in the middle of animation when enabling the command
local function ResetPulseAnimation()
	State.pulsePhase = 0
end

--------------------------------------------------------------------------------
-- RENDER HELPERS
--------------------------------------------------------------------------------
---@param data IndicatorDrawData
local function DrawAnnularSectorFill(data, alphaFactor, segments, step, ux, uz, aimAngle, spreadAngle, rMin, rMax, ty)
	local fillColor = data.colors.fill
	local shader = data.weaponInfo.shader
	shader:Activate()
	shader:SetUniform("time", osClock())
	shader:SetUniform("center", data.target.x, data.target.z)
	shader:SetUniform("u_color", fillColor[1], fillColor[2], fillColor[3], fillColor[4] * alphaFactor)
	glBeginEnd(GL_TRIANGLE_STRIP, function()
		for i = 0, segments do
			local theta = (aimAngle - spreadAngle) + (i * step)
			local sinT, cosT = sin(theta), cos(theta)

			local pxi = ux + (sinT * rMin)
			local pzi = uz + (cosT * rMin)
			local pyi = ty or spGetGroundHeight(pxi, pzi)
			glVertex(pxi, pyi, pzi)

			local pxo = ux + (sinT * rMax)
			local pzo = uz + (cosT * rMax)
			local pyo = ty or spGetGroundHeight(pxo, pzo)
			glVertex(pxo, pyo, pzo)
		end
	end)
	shader:Deactivate()
end

local function DrawAnnularSectorOutline(data, alphaFactor, segments, step, ux, uz, aimAngle, spreadAngle, rMin, rMax, ty)
	SetGlColor(alphaFactor, data.colors.scatter)
	glLineWidth(max(1, Config.Render.scatterLineWidthMult / data.distanceFromCamera))
	glBeginEnd(GL_LINE_LOOP, function()
		for i = 0, segments do
			local theta = (aimAngle - spreadAngle) + (i * step)
			local px = ux + (sin(theta) * rMax)
			local pz = uz + (cos(theta) * rMax)
			local py = ty or spGetGroundHeight(px, pz)
			glVertex(px, py, pz)
		end

		for i = segments, 0, -1 do
			local theta = (aimAngle - spreadAngle) + (i * step)
			local px = ux + (sin(theta) * rMin)
			local pz = uz + (cos(theta) * rMin)
			local py = ty or spGetGroundHeight(px, pz)
			glVertex(px, py, pz)
		end
	end)
end

---@param data IndicatorDrawData
local function DrawScatterShape(data, ux, uz, ty, aimAngle, spreadAngle, rMin, rMax, alphaFactor)
	if alphaFactor <= 0 then return end

	local arcLength = rMax * spreadAngle * 2
	local segments = ceil(arcLength / 20)

	if segments < 8 then segments = 8 end
	if segments > 64 then segments = 64 end

	local step = (spreadAngle * 2) / segments

	if data.weaponInfo.shader then
		DrawAnnularSectorFill(data, alphaFactor, segments, step, ux, uz, aimAngle, spreadAngle, rMin, rMax, ty)
	end

	DrawAnnularSectorOutline(data, alphaFactor, segments, step, ux, uz, aimAngle, spreadAngle, rMin, rMax, ty)

	-- Reset GL State
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

local function DrawCircle(x, y, z, radius)
	glPushMatrix()
	glTranslate(x, y, z)
	glScale(radius, radius, radius)

	glCallList(State.circleList)

	glPopMatrix()
end

--------------------------------------------------------------------------------
-- INITIALIZATION LOGIC
--------------------------------------------------------------------------------
local function FindBestWeapon(unitDef)
	local maxSpread = Config.General.minSpread
	-- best = highest spread or lightning weapon
	local bestManual = { maxSpread = maxSpread }
	local best = { maxSpread = maxSpread }
	local bestRange = { range = 0 }
	local validSecondaryWeapons = {}

	for weaponNum, weapon in ipairs(unitDef.weapons) do
		if weapon.weaponDef then
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if weaponDef then
				local isValid = weaponDef.canAttackGround
					and not (weaponDef.type == "Shield")
					and not ToBool(weaponDef.interceptor)
					and not string.find(weaponDef.name, "flak", nil, true)

				if isValid then
					if weaponDef.manualFire and unitDef.canManualFire then
						local currentSpread = max(weaponDef.damageAreaOfEffect, weaponDef.range * (weaponDef.accuracy + weaponDef.sprayAngle))
						if currentSpread > bestManual.maxSpread then
							bestManual.maxSpread = currentSpread
							bestManual.weaponDef = weaponDef
							bestManual.weaponNum = weaponNum
						end
					else
						-- Primary (highest spread)
						validSecondaryWeapons[weaponNum] = weaponDef
						local currentSpread = max(weaponDef.damageAreaOfEffect, weaponDef.range * (weaponDef.accuracy + weaponDef.sprayAngle))
						if (weaponDef.damageAreaOfEffect > best.maxSpread
							or weaponDef.range * (weaponDef.accuracy + weaponDef.sprayAngle) > best.maxSpread
							or weaponDef.type == "LightningCannon") then
							best.maxSpread = currentSpread
							best.weaponDef = weaponDef
							best.weaponNum = weaponNum
						end
					end
				end
			end
		end
	end
	-- Secondary (highest range)
	if best.weaponDef then
		for weaponNum, weaponDef in pairs(validSecondaryWeapons) do
			if weaponDef.waterWeapon == best.weaponDef.waterWeapon and weaponDef.range > bestRange.range then
				bestRange.range = weaponDef.range
				bestRange.weaponDef = weaponDef
				bestRange.weaponNum = weaponNum
			end
		end
	end

	return best, bestManual, bestRange
end

---@return WeaponInfo
local function BuildWeaponInfo(unitDef, weaponDef, weaponNum)
	---@class WeaponInfo
	local info = {}
	local weaponType = weaponDef.type
	local scatter = weaponDef.accuracy + weaponDef.sprayAngle

	info.aoe = weaponDef.damageAreaOfEffect
	info.mobile = unitDef.speed > 0
	info.waterWeapon = weaponDef.waterWeapon
	info.ee = weaponDef.edgeEffectiveness
	info.weaponNum = weaponNum
	info.hasStockpile = weaponDef.stockpile
	info.isNuke = weaponDef.customParams and weaponDef.customParams.nuclear

	if weaponDef.paralyzer then
		info.color = Config.Colors.emp
	end
	if weaponDef.customParams.area_onhit_resistance == "fire" then
		info.color = Config.Colors.napalm
		info.shader = napalmShader
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
		info.range = weaponDef.range
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
		-- Missile wobbles only when turn rate is too small to counter it
		if weaponDef.wobble > turnRate * 1.5 then
			info.type = "wobble"
			info.wobble = weaponDef.wobble
			info.turnRate = turnRate
			info.v = weaponDef.projectilespeed
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
		-- Check for nuclear bombs (like armliche's atomic bomb)
		if info.isNuke then
			info.type = "nuke"
		else
			info.type = "dropped"
			info.scatter = scatter
			info.v = unitDef.speed
			info.salvoSize = weaponDef.salvoSize
			info.salvoDelay = weaponDef.salvoDelay
		end
	elseif weaponType == "StarburstLauncher" then
		-- Check for nuclear weapons (customParams.nuclear)
		if info.isNuke then
			info.type = "nuke"
		else
			info.type = weaponDef.tracks and "tracking" or "cruise"
		end
		info.range = weaponDef.range
	elseif weaponType == "TorpedoLauncher" then
		if weaponDef.tracks then
			info.type = "tracking"
			info.range = weaponDef.range
		else
			info.type = "direct"
			info.scatter = scatter
			info.range = weaponDef.range
		end
	elseif weaponType == "Flame" then
		info.type = "noexplode"
		info.range = weaponDef.range
	elseif weaponType == "LightningCannon" then
		info.type = "lightning"
		info.ee = 1 -- we don't want damage drop-off rings on lightning weapons because it works differently
		info.range = weaponDef.range
		info.aoe = tonumber(weaponDef.customParams.spark_range)
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

	local best, bestManual, longestRange = FindBestWeapon(unitDef)
	if best.weaponDef then
		local infoPrimary = BuildWeaponInfo(unitDef, best.weaponDef, best.weaponNum)
		local infoSecondary

		if longestRange.weaponDef and longestRange.weaponNum ~= best.weaponNum and longestRange.weaponDef.range > best.weaponDef.range then
			infoSecondary = BuildWeaponInfo(unitDef, longestRange.weaponDef, longestRange.weaponNum)
		end

		---@class WeaponInfos
		Cache.weaponInfos[unitDefID] = {
			primary = infoPrimary,
			secondary = infoSecondary
		}
	end
	if bestManual.weaponDef then
		local info = BuildWeaponInfo(unitDef, bestManual.weaponDef, bestManual.weaponNum)
		Cache.manualWeaponInfos[unitDefID] = { primary = info }
	end

end

local function SetupDisplayLists()
	State.circleList = glCreateList(function()
		glBeginEnd(GL_LINE_LOOP, function()
			local divs = Config.Render.circleDivs
			local circles = Cache.Calculated.unitCircles
			for i = 1, divs do
				local uc = circles[i]
				glVertex(uc[1], 0, uc[2])
			end
		end)
	end)

	State.unitDiskList = glCreateList(function()
		glBeginEnd(GL_TRIANGLE_FAN, function()
			glVertex(0, 0, 0)
			for i = 0, Config.Render.circleDivs do
				local v = Cache.Calculated.unitCircles[i]
				glVertex(v[1], 0, v[2])
			end
		end)
	end)

	-- Nuclear trefoil (radiation symbol) display list
	-- Consists of 3 fan blades at 120° intervals and a center hole
	State.nuclearTrefoilList = glCreateList(function()
		local innerRadius = 0.18  -- Center hole radius
		local outerRadius = 0.85  -- Blade outer radius
		local bladeAngle = rad(60)  -- Each blade spans 60 degrees
		local bladeSegments = 16

		for blade = 0, 2 do
			local baseAngle = blade * rad(120) - rad(90)  -- Start at top, 120° apart
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
	glDeleteList(State.circleList)
	glDeleteList(State.unitDiskList)
	glDeleteList(State.nuclearTrefoilList)
end

--------------------------------------------------------------------------------
-- UPDATE LOGIC
--------------------------------------------------------------------------------
local function GetUnitWithBestStockpile(unitIDs)
	local bestUnit = unitIDs[1]
	local maxProgress = 0
	for _, unitId in ipairs(unitIDs) do
		local numStockpiled, numStockpileQued, buildPercent = spGetUnitStockpile(unitId)
		-- these can be nil when switching teams as spectator
		if numStockpiled and numStockpiled > 0 then
			return unitId
		elseif buildPercent and buildPercent > maxProgress then
			maxProgress = buildPercent
			bestUnit = unitId
		end
	end
	return bestUnit
end

local function GetBestUnitID(unitIDs, info, isManual)
	local bestUnit = unitIDs[1]
	if info.hasStockpile then
		State.isStockpileForManualFire = isManual
		State.isMonitoringStockpile = true
		State.unitsToMonitorStockpile = unitIDs
		bestUnit = GetUnitWithBestStockpile(unitIDs)
	end
	return bestUnit
end

local function UpdateSelection()
	local maxCost = 0
	local maxCostManual = 0
	State.manualFireUnitDefID = nil
	State.attackUnitDefID = nil
	State.attackUnitID = nil
	State.manualFireUnitID = nil
	State.hasSelection = false
	State.isMonitoringStockpile = false
	State.unitsToMonitorStockpile = {}

	local sel = spGetSelectedUnitsSorted()
	for unitDefID, unitIDs in pairs(sel) do
		local currCost = Cache.UnitProperties.cost[unitDefID] * #unitIDs
		if Cache.manualWeaponInfos[unitDefID] and currCost > maxCostManual then
			maxCostManual = currCost
			State.manualFireUnitDefID = unitDefID
			State.manualFireUnitID = GetBestUnitID(unitIDs, Cache.manualWeaponInfos[unitDefID].primary, true)
			State.hasSelection = true
		end
		if Cache.weaponInfos[unitDefID] and currCost > maxCost then
			maxCost = currCost
			State.attackUnitDefID = unitDefID
			State.attackUnitID = GetBestUnitID(unitIDs, Cache.weaponInfos[unitDefID].primary)
			State.hasSelection = true
		end
	end
end

---@return WeaponInfos, number
local function GetActiveUnitInfo()
	if not State.hasSelection then
		return nil, nil
	end

	local _, cmd, _ = spGetActiveCommand()

	if ((cmd == CMD_MANUALFIRE or cmd == CMD_MANUAL_LAUNCH) and State.manualFireUnitDefID) then
		return Cache.manualWeaponInfos[State.manualFireUnitDefID], State.manualFireUnitID
	elseif ((cmd == CMD_ATTACK or cmd == CMD_UNIT_SET_TARGET or cmd == CMD_UNIT_SET_TARGET_NO_GROUND) and State.attackUnitDefID) then
		return Cache.weaponInfos[State.attackUnitDefID], State.attackUnitID
	else
		return nil, nil
	end
end

--------------------------------------------------------------------------------
-- WEAPON TYPE HANDLERS
--------------------------------------------------------------------------------

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
		result = lerp(maxAlpha, minAlpha, fadeProgress)
	end

	return result * alphaMult
end

local function DrawAoeShaderFill(shader, tx, ty, tz, color, aoe)
	local circles = Cache.Calculated.unitCircles
	local divs = Config.Render.circleDivs

	shader:Activate()
	shader:SetUniform("time", osClock())
	shader:SetUniform("center", tx, tz)
	shader:SetUniform("u_color", color[1], color[2], color[3], color[4])

	glBeginEnd(GL_TRIANGLE_FAN, function()
		glVertex(tx, ty, tz)

		for i = 0, divs do
			local cx = tx + (circles[i][1] * aoe)
			local cz = tz + (circles[i][2] * aoe)
			glVertex(cx, ty, cz)
		end
	end)

	shader:Deactivate()
	glColor(1, 1, 1, 1)
end

local function DrawAoePulseFill(tx, ty, tz, color, alphaMult, aoe, phase)
	local bandCount = Config.Render.aoeDiskBandCount
	local triggerTimes = Cache.Calculated.diskWaveTriggerTimes
	local maxAlpha = Config.Render.maxFilledCircleAlpha
	local minAlpha = Config.Render.minFilledCircleAlpha
	local divs = Config.Render.circleDivs
	local circles = Cache.Calculated.unitCircles
	glPushMatrix()
	glTranslate(tx, ty, tz)
	glBeginEnd(GL_TRIANGLE_STRIP, function()
		for idx = 1, bandCount do
			local innerRing = aoe * (idx - 1) / bandCount
			local outerRing = aoe * idx / bandCount
			local alphaFactor = GetAlphaFactorForRing(minAlpha, maxAlpha, idx, phase, alphaMult, triggerTimes)

			SetGlColor(alphaFactor, color)
			for i = 0, divs do
				local unitCircle = circles[i]
				glVertex(unitCircle[1] * outerRing, 0, unitCircle[2] * outerRing)
				glVertex(unitCircle[1] * innerRing, 0, unitCircle[2] * innerRing)
			end
		end
	end)
	glPopMatrix()
end

local function DrawFilledAoeCircle(tx, ty, tz, aoe, alphaMult, phase, color, shader)
	if shader then
		DrawAoeShaderFill(shader, tx, ty, tz, color, aoe, phase)
	else
		DrawAoePulseFill(tx, ty, tz, color, alphaMult or 1, aoe, phase)
	end
end

local function DrawAoeDamageRings(tx, ty, tz, aoe, edgeEffectiveness, alphaMult, phase, color)
	local damageLevels = Config.Render.ringDamageLevels
	local triggerTimes = Cache.Calculated.ringWaveTriggerTimes
	local minRingRadius = Config.General.minRingRadius

	for ringIndex, damageLevel in ipairs(damageLevels) do
		local ringRadius = GetRadiusForDamageLevel(aoe, damageLevel, edgeEffectiveness)
		if ringRadius < minRingRadius then
			return
		end
		local alphaFactor = GetAlphaFactorForRing(damageLevel, damageLevel + 0.4, ringIndex, phase, alphaMult, triggerTimes)
		SetGlColor(alphaFactor, color)
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

	if edgeEffectiveness == 1 or data.weaponInfo.shader then
		DrawFilledAoeCircle(tx, ty, tz, aoe, ringAlphaMult, phase, color, data.weaponInfo.shader)
	else
		DrawAoeDamageRings(tx, ty, tz, aoe, edgeEffectiveness, ringAlphaMult, phase, color)
	end

	-- draw a max radius outline for clarity
	SetGlColor(Config.Render.outerRingAlpha, color)
	glLineWidth(screenLineWidthScale)
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
	local triggerTimes = Cache.Calculated.diskWaveTriggerTimes
	local maxAlpha = Config.Render.maxFilledCircleAlpha
	local minAlpha = Config.Render.minFilledCircleAlpha
	local circles = Cache.Calculated.unitCircles
	local divs = Config.Render.circleDivs

	local areaDenialRadius = 450 -- defined in unit_juno_damage.lua
	local impactRingWidth = aoe - areaDenialRadius

	glPushMatrix()
	glTranslate(tx, ty, tz)
	glScale(areaDenialRadius, 1, areaDenialRadius)
	SetGlColor(maxAlpha, color)
	glCallList(State.unitDiskList)
	glPopMatrix()

	glPushMatrix()
	glTranslate(tx, ty, tz)
	glBeginEnd(GL_TRIANGLE_STRIP, function()
		for idx = 1, bandCount do
			local innerRing = areaDenialRadius + (impactRingWidth * (idx - 1) / bandCount)
			local outerRing = areaDenialRadius + (impactRingWidth * idx / bandCount)

			local alphaFactor = GetAlphaFactorForRing(minAlpha, maxAlpha, idx, phase, 1, triggerTimes, true)

			SetGlColor(alphaFactor, color)
			for i = 0, divs do
				local unitCircle = circles[i]
				local uc1, uc2 = unitCircle[1], unitCircle[2]
				glVertex(uc1 * outerRing, 0, uc2 * outerRing)
				glVertex(uc1 * innerRing, 0, uc2 * innerRing)
			end
		end
	end)
	glPopMatrix()

	SetGlColor(Config.Render.outerRingAlpha, color)
	glLineWidth(screenLineWidthScale)
	DrawCircle(tx, ty, tz, aoe)
	DrawCircle(tx, ty, tz, areaDenialRadius)

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

---@param data IndicatorDrawData
local function DrawStockpileProgress(data, buildPercent, barColor, bgColor)
	local progressBarAlpha = StockpileStatus.progressBarAlpha
	if progressBarAlpha == 0 then
		return
	end

	local dist = data.distanceFromCamera
	local aoe = data.weaponInfo.aoe
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local circles = Cache.Calculated.unitCircles
	local divs = Config.Render.circleDivs
	local isNuke = data.weaponInfo.isNuke

	if not isNuke then
		-- Draw regular filled circle for non-nuke stockpile weapons
		SetGlColor(progressBarAlpha * 0.6, bgColor)
		glPushMatrix()
		glTranslate(tx, ty, tz)
		glScale(aoe * 0.5, aoe * 0.5, aoe * 0.5)
		glCallList(State.unitDiskList)
		glPopMatrix()
	end

	-- Draw outer progress ring
	SetGlColor(progressBarAlpha, bgColor)
	glLineWidth(max(Config.Render.aoeLineWidthMult * aoe / 2 / dist, 2))

	glPushMatrix()
	glTranslate(tx, ty, tz)
	glScale(aoe, aoe, aoe)

	glCallList(State.circleList)

	if buildPercent > 0 then
		SetGlColor(progressBarAlpha, barColor)

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

	local bx, by, bz = normalize(dx, dy, dz)

	local br = diag(bx, bz)

	-- do not try to draw indicator when aiming at yourself
	if br == 0 then
		return
	end

	local wx = -aoe * bz / br
	local wz = aoe * bx / br

	local ex = range * bx / br
	local ez = range * bz / br

	local color
	local alpha

	if requiredEnergy and select(1, spGetTeamResources(spGetMyTeamID(), 'energy')) < requiredEnergy then
		color = Config.Colors.noEnergy
		alpha = lerp(0, 1, State.pulsePhase)
	else
		alpha = lerp(0.5, 1, State.pulsePhase)
		color = data.colors.base
	end

	SetGlColor(alpha, color)
	glLineWidth(1 + (Config.Render.scatterLineWidthMult / data.distanceFromCamera))
	glDepthTest(false)

	glBeginEnd(GL_LINES, function()
		glVertex(ux + wx, uy, uz + wz)
		glVertex(ux + ex + wx, ty, uz + ez + wz)

		glVertex(ux - wx, uy, uz - wz)
		glVertex(ux + ex - wx, ty, uz + ez - wz)
	end)

	glDepthTest(true)
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

---@param data IndicatorDrawData
local function DrawDGun(data)
	local ux, uy, uz = data.source.x, data.source.y, data.source.z
	local tx, tz = data.target.x, data.target.z
	local unitName = data.weaponInfo.unitname
	local range = data.weaponInfo.range
	local divs = Config.Render.circleDivs

	local angle = atan2(ux - tx, uz - tz) + (pi / 2.1)
	local dx, dz, offset_x, offset_z = ux, uz, 0, 0
	if unitName == 'armcom' then
		offset_x = (sin(angle) * 10)
		offset_z = (cos(angle) * 10)
		dx = ux - offset_x
		dz = uz - offset_z
	elseif unitName == 'corcom' or unitName == 'legcom' then
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
	glDrawGroundCircle(ux, uy, uz, range, divs)
	glColor(1, 1, 1, 1)
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

---@param data IndicatorDrawData
local function DrawBallisticScatter(data)
	local gameSpeed = Config.General.gameSpeed

	local weaponInfo = data.weaponInfo
	local ux, uy, uz = data.source.x, data.source.y, data.source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local aimingUnitID = data.unitID
	local trajectory = select(7, spGetUnitStates(aimingUnitID, false, true)) and 1 or -1
	local aoe = weaponInfo.aoe

	local scatter = weaponInfo.scatter
	if scatter < 0.01 then
		return 0
	end

	local v = weaponInfo.v

	-- 1. Math Setup
	-- We calculate the physical spread at the gun's max effective range (or current target if closer).
	local calc_tx, calc_ty, calc_tz, calc_dist = GetClampedTarget(data)
	local dx, dy, dz = calc_tx - ux, calc_ty - uy, calc_tz - uz
	local bx, by, bz, _ = GetBallisticVector(v, dx, dy, dz, trajectory)
	if not bx then
		return 0
	end

	-- 2. Create Orthonormal Basis
	local rx, ry, rz
	if abs(bx) < 0.001 and abs(bz) < 0.001 then
		rx, ry, rz = 1, 0, 0
	else
		local inv_len = 1 / diag(bx, bz)
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
	local maxAxisLen = naturalRadius * 2.5

	-- Width
	local vx_right = bx * cosScatter + rx * scatter
	local vy_right = by * cosScatter + ry * scatter
	local vz_right = bz * cosScatter + rz * scatter
	local hx_right, hz_right = GetScatterImpact(ux, uz, calc_tx, calc_tz, v_f, gravity_f, heightDiff, vx_right, vy_right, vz_right)

	local axisRightX = hx_right - calc_tx
	local axisRightZ = hz_right - calc_tz
	-- to avoid situation when scatter is visible but is narrower than aoe
	local lenRight = max(diag(axisRightX, axisRightZ), aoe)

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
	local lenUp = diag(axisUpX, axisUpZ)

	if lenRight > maxAxisLen then lenRight = maxAxisLen end
	if lenUp > maxAxisLen then lenUp = maxAxisLen end

	----------------------------------------------------------------------------
	-- VISIBILITY
	----------------------------------------------------------------------------
	local scatterSize = max(naturalRadius, lenUp)
	local minScatterRadius = max(weaponInfo.aoe, 15) * 1.4
	local scatterAlphaFactor = GetSizeBasedAlpha(scatterSize, minScatterRadius)

	if scatterAlphaFactor <= 0 then
		return 0
	end

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

	local aimAngle = atan2(tx - ux, tz - uz)

	DrawScatterShape(data, ux, uz, ty, aimAngle, spreadAngle, rMin, rMax, scatterAlphaFactor)

	return scatterAlphaFactor
end

--------------------------------------------------------------------------------
-- SECTOR
--------------------------------------------------------------------------------
---@param data IndicatorDrawData
local function DrawSectorScatter(data)
	local ux, uz = data.source.x, data.source.z
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local weaponInfo = data.weaponInfo

	local cx, cy, cz, clampedDistance = GetClampedTarget(data)

	local dist = distance2d(ux, uz, tx, tz)

	local angleDeg = weaponInfo.sector_angle
	local shortfall = weaponInfo.sector_shortfall
	local defaultSpreadAngle = rad(angleDeg / 2)

	local rMax = dist
	local spreadAngle = defaultSpreadAngle

	-- Preserve angle if aiming past max range
	if dist > clampedDistance then
		local maxSpreadRadius = clampedDistance * tan(defaultSpreadAngle)
		spreadAngle = atan2(maxSpreadRadius, dist)
	end

	local impactDepth = clampedDistance * shortfall
	local rMin = rMax - impactDepth

	local aimAngle = atan2(tx - ux, tz - uz)

	DrawScatterShape(data, ux, uz, ty, aimAngle, spreadAngle, rMin, rMax, 1)
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
	-- Constant that converts engine wobble units (e.g. 0.006).
	-- Calibrated so the drawing matches observed in-game spread
	local SPREAD_CALIBRATION = 12.0
	-- We are only interested in flight time which increases spread so I scaled it down until it felt right
	local TIME_EXPONENT = 0.20
	-- A multiplier applied to the TurnRate when fighting Wobble.
	-- A value of 2.0 means active guidance is twice as effective at reducing
	-- spread as the raw numbers suggest.
	local GUIDANCE_EFFICIENCY = 2.0
	-- Controls how much height advantage reduces the forward spread.
	-- Higher = height advantage tightens the shape more aggressively.
	local ELEVATION_IMPACT_FACTOR = 8
	--------------------------------------------------------------------------------

	local dist = distance2d(ux, uz, tx, tz)
	local clampedDist = min(dist, range)

	local arcFactor = 1.0 + (trajectoryHeight * 0.5)
	local flightFrames = (clampedDist * arcFactor) / projSpeed
	if flightFrames < 1 then
		flightFrames = 1
	end

	-- Range factor (% of max possible distance) for bias interpolation
	local maxFlightFrames = (range * arcFactor) / projSpeed
	local rangeFactor = maxFlightFrames > 0 and (flightFrames / maxFlightFrames) or 0

	local netWobble = max(0, wobble - (turnRate * GUIDANCE_EFFICIENCY))

	if netWobble <= 0.0001 then
		return 0
	end

	local timeFactor = pow(flightFrames, TIME_EXPONENT)
	local spreadAngle = netWobble * SPREAD_CALIBRATION * timeFactor

	if spreadAngle > 1.2 then spreadAngle = 1.2 end
	if spreadAngle < 0.02 then spreadAngle = 0.02 end

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
	local backwardBias = ((trajectoryHeight + guidance) * rangeFactor) * 0.5

	local rMax = dist + (spreadRadius * forwardBias)
	local rMin = dist - (spreadRadius * backwardBias)

	if rMin < 50 then rMin = 50 end

	-- Using lower overrangeDistance because projectiles won't reach it most of the time
	-- but ensure it's actually larger than the range
	local overrange = max(data.weaponInfo.overrangeDistance * 0.9, range * 1.05)

	-- If we are aiming past the clamp limit, we scale the overrange accordingly
	-- This keeps the indicator shaped exactly as it is at max range
	if dist > clampedDist then
		overrange = overrange + (dist - clampedDist)
	end

	if rMax > overrange then rMax = overrange end
	if rMin >= rMax then rMin = rMax - 10 end

	-- 7. Recalculate Draw Angle for overrange
	-- This keeps the indicator shaped exactly as it is at max range
	if dist > clampedDist then
		spreadAngle = atan2(spreadRadius, dist)
	end

	local dx = tx - ux
	local dz = tz - uz
	local aimAngle = atan2(dx, dz)

	local visualSpreadRadius = max(spreadRadius, spreadRadius * forwardBias)
	local minSpreadRadius = max(data.weaponInfo.aoe, 25)
	local spreadAlphaFactor = GetSizeBasedAlpha(visualSpreadRadius, minSpreadRadius)

	DrawScatterShape(data, ux, uz, ty, aimAngle, spreadAngle, rMin, rMax, spreadAlphaFactor)

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

	-- do not try to draw indicator when aiming at yourself
	if groundVectorMag == 0 then
		return
	end

	-- Push the start point from the center of the unit to the perimeter
	local edgeOffsetX = (aimDirX / groundVectorMag) * unitRadius
	local edgeOffsetZ = (aimDirZ / groundVectorMag) * unitRadius

	local startSpreadX = -scatter * edgeOffsetZ
	local startSpreadZ = scatter * edgeOffsetX

	local targetSpreadX = -scatter * (dz / groundVectorMag)
	local targetSpreadZ = scatter * (dx / groundVectorMag)

	glColor(Config.Colors.scatter)
	glLineWidth(Config.Render.scatterLineWidthMult / data.distanceFromCamera)

	glBeginEnd(GL_LINES, function()
		glVertex(ux + edgeOffsetX + startSpreadX, uy, uz + edgeOffsetZ + startSpreadZ)
		glVertex(ctx + targetSpreadX, cty, ctz + targetSpreadZ)

		glVertex(ux + edgeOffsetX - startSpreadX, uy, uz + edgeOffsetZ - startSpreadZ)
		glVertex(ctx - targetSpreadX, cty, ctz - targetSpreadZ)
	end)

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

--------------------------------------------------------------------------------
-- DRAWING DISPATCH
--------------------------------------------------------------------------------
---@param data IndicatorDrawData
local function DrawBallistic(data)
	local scatterAlphaFactor = DrawBallisticScatter(data)
	FadeColorInPlace(data.colors.base, 1 - scatterAlphaFactor)
	DrawAoe(data)
end

---@param data IndicatorDrawData
local function DrawDirect(data)
	DrawAoe(data)
	DrawDirectScatter(data)
end

---@param data IndicatorDrawData
local function DrawWobble(data)
	local scatterAlphaFactor = DrawWobbleScatter(data)
	FadeColorInPlace(data.colors.base, 1 - scatterAlphaFactor)
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

---@param data IndicatorDrawData
local function DrawNuke(data)
	local tx, ty, tz = data.target.x, data.target.y, data.target.z
	local aoe = data.weaponInfo.aoe
	local edgeEffectiveness = data.weaponInfo.ee
	local color = data.colors.base
	local phase = State.pulsePhase - floor(State.pulsePhase)

	glLineWidth(max(Config.Render.aoeLineWidthMult * aoe / data.distanceFromCamera, 0.5))

	-- Draw outer damage rings (skip the innermost ring at index 1)
	local damageLevels = Config.Render.ringDamageLevels
	local triggerTimes = Cache.Calculated.ringWaveTriggerTimes
	local minRingRadius = Config.General.minRingRadius

	for ringIndex, damageLevel in ipairs(damageLevels) do
		if ringIndex > 1 then  -- Skip innermost ring
			local ringRadius = GetRadiusForDamageLevel(aoe, damageLevel, edgeEffectiveness)
			if ringRadius >= minRingRadius then
				local alphaFactor = GetAlphaFactorForRing(damageLevel, damageLevel + 0.4, ringIndex, phase, 1, triggerTimes)
				SetGlColor(alphaFactor, color)
				DrawCircle(tx, ty, tz, ringRadius)
			end
		end
	end

	-- Draw outer AOE circle
	SetGlColor(Config.Render.outerRingAlpha, color)
	glLineWidth(screenLineWidthScale)
	DrawCircle(tx, ty, tz, aoe)

	-- Draw rotating nuclear trefoil symbol with pulsing opacity
	-- Opacity synced with ring animation phase (0.4 ± 0.1)
	-- Scale so outer edge of trefoil (0.85 * scale) is smaller than innermost ring (~26% of aoe)
	local trefoilOpacity = 0.4 + 0.08 * sin(phase * tau)
	SetGlColor(trefoilOpacity, color)
	glPushMatrix()
	glTranslate(tx, ty, tz)
	glRotate(osClock() * 30, 0, 1, 0)  -- Slow rotation: 30 degrees per second
	glScale(aoe * 0.55, aoe * 0.55, aoe * 0.55)
	glCallList(State.nuclearTrefoilList)
	glPopMatrix()

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

local WeaponTypeHandlers = {
	sector = DrawSectorScatter,
	ballistic = DrawBallistic,
	noexplode = DrawNoExplode,
	direct = DrawDirect,
	dropped = DrawDropped,
	wobble = DrawWobble,
	dgun = DrawDGun,
	juno = DrawJuno,
	nuke = DrawNuke,
}

--------------------------------------------------------------------------------
-- CALLINS
--------------------------------------------------------------------------------
function widget:Initialize()
	-- shader has to be created before setting up unit defs
	napalmShader = LuaShader.CheckShaderUpdates(shaderSourceCache, 0)
	for unitDefID, unitDef in pairs(UnitDefs) do
		SetupUnitDef(unitDefID, unitDef)
	end
	SetupDisplayLists()
	UpdateScreenScale()
	UpdateSelection()
end

function widget:ViewResize()
	UpdateScreenScale()
end

function widget:Shutdown()
	DeleteDisplayLists()
end

function widget:DrawWorldPreUnit()
	local weaponInfos, aimingUnitID = GetActiveUnitInfo()
	if not weaponInfos then
		ResetPulseAnimation()
		return
	end

	local tx, ty, tz = GetMouseTargetPosition(weaponInfos.primary.type, aimingUnitID)
	if not tx then
		ResetPulseAnimation()
		return
	end

	local ux, uy, uz = spGetUnitPosition(aimingUnitID)
	if not ux then
		ResetPulseAnimation()
		return
	end

	local weaponInfo = weaponInfos.primary
	local dist = distance3d(ux, uy, uz, tx, ty, tz)
	if weaponInfos.secondary and dist > weaponInfo.range then
		weaponInfo = weaponInfos.secondary
	end

	-- Do not draw if unit can't move and targeting outside the range
	if not weaponInfo.mobile and not spGetUnitWeaponTestRange(aimingUnitID, weaponInfo.weaponNum, tx, ty, tz) then
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
	local baseFillColor = weaponInfo.color or Config.Colors.none
	local noStockpileColor = Config.Colors.noStockpile
	local scatterColor = Config.Colors.scatter

	if weaponInfo.hasStockpile then
		-- handle transition from stockpile loading bar
		local alpha = 1 - StockpileStatus.progressBarAlpha
		LerpColor(noStockpileColor, baseColor, alpha, aimData.colors.base)
		LerpColor(noStockpileColor, scatterColor, alpha, aimData.colors.scatter)
		LerpColor(noStockpileColor, baseFillColor, alpha, aimData.colors.fill)
	else
		-- Copy to avoid creating new tables
		CopyColor(baseColor, aimData.colors.base)
		CopyColor(baseFillColor, aimData.colors.fill)
		CopyColor(scatterColor, aimData.colors.scatter)
	end

	local handleWeaponType = WeaponTypeHandlers[weaponInfo.type] or DrawAoe
	handleWeaponType(aimData)

	-- Draw Stockpile Progress
	if weaponInfo.hasStockpile then
		local numStockpiled, numStockpileQued, buildPercent = spGetUnitStockpile(aimingUnitID)

		if numStockpiled > 0 then
			-- do not 'load' the bar during transition
			buildPercent = 1
		end
		DrawStockpileProgress(aimData, buildPercent, baseColor, noStockpileColor)
	end
end

function widget:SelectionChanged(sel)
	State.selectionChanged = true
end

function widget:Update(dt)
	local pulsePhase = State.pulsePhase + dt
	State.pulsePhase = pulsePhase - floor(pulsePhase)

	if State.isMonitoringStockpile then
		if State.isStockpileForManualFire then
			State.manualFireUnitID = GetUnitWithBestStockpile(State.unitsToMonitorStockpile)
		else
			State.attackUnitID = GetUnitWithBestStockpile(State.unitsToMonitorStockpile)
		end
	end

	State.selChangedSec = State.selChangedSec + dt
	if State.selectionChanged and State.selChangedSec > 0.15 then
		State.selChangedSec = 0
		State.selectionChanged = nil
		UpdateSelection()
	end

	local weaponInfos, aimingUnitID = GetActiveUnitInfo()
	local weaponInfo = weaponInfos and weaponInfos.primary or nil
	StockpileStatus:Update(dt, aimingUnitID, weaponInfo and weaponInfo.hasStockpile)
end
