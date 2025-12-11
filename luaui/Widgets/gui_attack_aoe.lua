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
local mathMax = math.max
local mathSqrt = math.sqrt
local mathSin = math.sin
local mathCos = math.cos
local mathAtan2 = math.atan2
local mathPi = math.pi

-- Localized Spring API for performance
local spGetMyTeamID = Spring.GetMyTeamID
local spGetGroundHeight = Spring.GetGroundHeight

--------------------------------------------------------------------------------
--config
--------------------------------------------------------------------------------
local numScatterPoints = 32
local aoeColor = { 1, 0, 0, 1 }
local aoeColorNoEnergy = { 1, 1, 0, 1 }
local aoeLineWidthMult = 64
local scatterColor = { 1, 1, 0, 1 }
local scatterLineWidthMult = 1024
local circleDivs = 96
local minSpread = 8 --weapons with this spread or less are ignored
local numAoECircles = 9
local pointSizeMult = 2048

--------------------------------------------------------------------------------
--vars
--------------------------------------------------------------------------------
local weaponInfo = {}
local manualWeaponInfo = {}
local hasSelection = false
local attackUnitDefID, manualFireUnitDefID
local attackUnitID, manualFireUnitID
local circleList
local secondPart = 0
local mouseDistance = 1000

local selectionChanged

--------------------------------------------------------------------------------
--speedups
--------------------------------------------------------------------------------
local GetActiveCommand = Spring.GetActiveCommand
local GetCameraPosition = Spring.GetCameraPosition
local GetGroundHeight = spGetGroundHeight
local GetMouseState = Spring.GetMouseState
local GetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitRadius = Spring.GetUnitRadius
local GetUnitStates = Spring.GetUnitStates
local TraceScreenRay = Spring.TraceScreenRay
local CMD_ATTACK = CMD.ATTACK
local CMD_MANUALFIRE = CMD.MANUALFIRE
local CMD_MANUAL_LAUNCH = GameCMD.MANUAL_LAUNCH
local g = Game.gravity
local GAME_SPEED = 30
local g_f = g / GAME_SPEED / GAME_SPEED
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
local GL_LINES = GL.LINES
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_POINTS = GL.POINTS
local PI = mathPi
local atan2 = mathAtan2
local cos = mathCos
local sin = mathSin
local floor = math.floor
local max = mathMax
local sqrt = mathSqrt

local unitCost = {}
local isAirUnit = {}
local isShip = {}
local isUnderwater = {}
local isHover = {}
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

--------------------------------------------------------------------------------
-- utility functions
--------------------------------------------------------------------------------

local function ToBool(x)
	return x and x ~= 0 and x ~= "false"
end

local function Normalize(x, y, z)
	local mag = sqrt(x * x + y * y + z * z)
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
	local mx, my = GetMouseState()
	local mouseTargetType, mouseTarget = TraceScreenRay(mx, my)
	if mouseTarget and mouseTargetType then
		if mouseTargetType == "ground" then
			return mouseTarget[1], mouseTarget[2], mouseTarget[3]
		elseif mouseTargetType == "unit" then
			if ((dgun and WG['dgunnoally'] ~= nil) or (not dgun and WG['attacknoally'] ~= nil)) and Spring.IsUnitAllied(mouseTarget) then
				mouseTargetType, mouseTarget = TraceScreenRay(mx, my, true)
				if mouseTarget then
					return mouseTarget[1], mouseTarget[2], mouseTarget[3]
				else
					return nil
				end
			elseif ((dgun and WG['dgunnoenemy'] ~= nil) or (not dgun and WG['attacknoenemy'] ~= nil)) and not Spring.IsUnitAllied(mouseTarget) then
				local unitDefID = Spring.GetUnitDefID(mouseTarget)
				local mouseTargetType2, mouseTarget2 = TraceScreenRay(mx, my, true)
				if mouseTarget2 then
					if isAirUnit[unitDefID] or isShip[unitDefID] or isUnderwater[unitDefID] or (spGetGroundHeight(mouseTarget2[1], mouseTarget2[3]) < 0 and isHover[unitDefID]) then
						return GetUnitPosition(mouseTarget)
					else
						return mouseTarget2[1], mouseTarget2[2], mouseTarget2[3]
					end
				else
					return nil
				end
			else
				return GetUnitPosition(mouseTarget)
			end
		elseif mouseTargetType == "feature" then
			local mouseTargetType, mouseTarget = TraceScreenRay(mx, my, true)
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
	local cx, cy, cz = GetCameraPosition()
	local mx, my, mz = GetMouseTargetPosition()
	if not mx then
		return nil
	end
	local dx = cx - mx
	local dy = cy - my
	local dz = cz - mz
	return sqrt(dx * dx + dy * dy + dz * dz)
end

local function UnitCircleVertices()
	for i = 1, circleDivs do
		local theta = 2 * PI * i / circleDivs
		glVertex(cos(theta), 0, sin(theta))
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

local function GetSecondPart(offset)
	local result = secondPart + (offset or 0)
	return result - floor(result)
end

--------------------------------------------------------------------------------
--initialization
--------------------------------------------------------------------------------

local function SetupUnitDef(unitDefID, unitDef)
	local weaponTable

	if not unitDef.weapons then
		return
	end

	-- put this block here, to hand ON/OFF dual weapons
	for ii, weapon in ipairs(unitDef.weapons) do
		if weapon.weaponDef then
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if weaponDef then
				if weaponDef.customParams then
					-- for now, just handling tremor sector fire
					if weaponDef.customParams.speceffect == "sector_fire" then
						if not weaponInfo[unitDefID] then
							weaponInfo[unitDefID] = { type = "sector"}
						end
						weaponInfo[unitDefID].type = "sector"
						weaponInfo[unitDefID].sector_angle = tonumber(weaponDef.customParams.spread_angle)
						weaponInfo[unitDefID].sector_shortfall = tonumber(weaponDef.customParams.max_range_reduction)
						weaponInfo[unitDefID].sector_range_max = weaponDef.range
					end
				end
			end
		end
	end
	-- break early if sector weapon
	if weaponInfo[unitDefID] then
		if weaponInfo[unitDefID].type == "sector" then
			return
		end
	end

	local maxSpread = minSpread
	local maxWeaponDef

	for _, weapon in ipairs(unitDef.weapons) do
		if weapon.weaponDef then
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if weaponDef then
				if weaponDef.canAttackGround
					and not (weaponDef.type == "Shield")
					and not ToBool(weaponDef.interceptor)
					and (weaponDef.damageAreaOfEffect > maxSpread or weaponDef.range * (weaponDef.accuracy + weaponDef.sprayAngle) > maxSpread)
					and not string.find(weaponDef.name, "flak", nil, true) then

					maxSpread = max(weaponDef.damageAreaOfEffect, weaponDef.range * (weaponDef.accuracy + weaponDef.sprayAngle))
					maxWeaponDef = weaponDef

					weaponTable = (weaponDef.manualFire and unitDef.canManualFire) and manualWeaponInfo or weaponInfo
				end
			end
		end
	end

	if not maxWeaponDef then
		return
	end

	local weaponType = maxWeaponDef.type
	local scatter = maxWeaponDef.accuracy + maxWeaponDef.sprayAngle
	local aoe = maxWeaponDef.damageAreaOfEffect
	local cost = unitDef.cost
	local mobile = unitDef.speed > 0
	local waterWeapon = maxWeaponDef.waterWeapon
	local ee = maxWeaponDef.edgeEffectiveness

	if weaponType == "DGun" then
		weaponTable[unitDefID] = { type = "dgun", range = maxWeaponDef.range, unitname = unitDef.name, requiredEnergy = maxWeaponDef.energyCost }
	elseif maxWeaponDef.cylinderTargeting >= 100 then
		weaponTable[unitDefID] = { type = "orbital", scatter = scatter }
	elseif weaponType == "Cannon" then
		weaponTable[unitDefID] = { type = "ballistic", scatter = scatter, v = maxWeaponDef.projectilespeed * 30, range = maxWeaponDef.range }
	elseif weaponType == "MissileLauncher" then
		local turnRate = 0
		if maxWeaponDef.tracks then
			turnRate = maxWeaponDef.turnRate
		end
		if maxWeaponDef.wobble > turnRate * 1.4 then
			scatter = (maxWeaponDef.wobble - maxWeaponDef.turnRate) * maxWeaponDef.projectilespeed * 30 * 16
			local rangeScatter = (8 * maxWeaponDef.wobble - maxWeaponDef.turnRate)
			weaponTable[unitDefID] = { type = "wobble", scatter = scatter, rangeScatter = rangeScatter, range = maxWeaponDef.range }
		elseif (maxWeaponDef.wobble > turnRate) then
			scatter = (maxWeaponDef.wobble - maxWeaponDef.turnRate) * maxWeaponDef.projectilespeed * 30 * 16
			weaponTable[unitDefID] = { type = "wobble", scatter = scatter }
		elseif (maxWeaponDef.tracks) then
			weaponTable[unitDefID] = { type = "tracking" }
		else
			weaponTable[unitDefID] = { type = "direct", scatter = scatter, range = maxWeaponDef.range }
		end
	elseif weaponType == "AircraftBomb" then
		weaponTable[unitDefID] = { type = "dropped", scatter = scatter, v = unitDef.speed, h = unitDef.cruiseAltitude, salvoSize = maxWeaponDef.salvoSize, salvoDelay = maxWeaponDef.salvoDelay }
	elseif weaponType == "StarburstLauncher" then
		if maxWeaponDef.tracks then
			weaponTable[unitDefID] = { type = "tracking", range = maxWeaponDef.range }
		else
			weaponTable[unitDefID] = { type = "cruise", range = maxWeaponDef.range }
		end
	elseif weaponType == "TorpedoLauncher" then
		if maxWeaponDef.tracks then
			weaponTable[unitDefID] = { type = "tracking" }
		else
			weaponTable[unitDefID] = { type = "direct", scatter = scatter, range = maxWeaponDef.range }
		end
	elseif weaponType == "Flame" then
		weaponTable[unitDefID] = { type = "noexplode", range = maxWeaponDef.range }
	else
		weaponTable[unitDefID] = { type = "direct", scatter = scatter, range = maxWeaponDef.range }
	end

	if maxWeaponDef.energyCost > 0 then
		weaponTable[unitDefID].requiredEnergy = maxWeaponDef.energyCost
	end

	weaponTable[unitDefID].aoe = aoe
	weaponTable[unitDefID].cost = cost
	weaponTable[unitDefID].mobile = mobile
	weaponTable[unitDefID].waterWeapon = waterWeapon
	weaponTable[unitDefID].ee = ee
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
local function GetRepUnitID(unitIDs)
	return unitIDs[1]
end

local function UpdateSelection()
	local maxCost = 0
	manualFireUnitDefID = nil
	attackUnitDefID = nil
	attackUnitID = nil
	manualFireUnitID = nil
	hasSelection = false

	local sel = GetSelectedUnitsSorted()
	for unitDefID, unitIDs in pairs(sel) do
		if manualWeaponInfo[unitDefID] then
			manualFireUnitDefID = unitDefID
			manualFireUnitID = unitIDs[1]
			hasSelection = true
		end

		if weaponInfo[unitDefID] then
			local currCost = unitCost[unitDefID] * #unitIDs
			if currCost > maxCost then
				maxCost = currCost
				attackUnitDefID = unitDefID
				attackUnitID = GetRepUnitID(unitIDs)
				hasSelection = true
			end
		end
	end
end

--------------------------------------------------------------------------------
--aoe
--------------------------------------------------------------------------------

local function DrawAoE(tx, ty, tz, aoe, ee, alphaMult, offset, requiredEnergy)
	glLineWidth(mathMax(aoeLineWidthMult * aoe / mouseDistance, 0.5))

	for i = 1, numAoECircles do
		local proportion = i / (numAoECircles + 1)
		local radius = aoe * proportion
		local alpha = aoeColor[4] * (1 - proportion) / (1 - proportion * ee) * (1 - GetSecondPart(offset or 0)) * (alphaMult or 1)
		if requiredEnergy and select(1, Spring.GetTeamResources(spGetMyTeamID(), 'energy')) < requiredEnergy then
			glColor(aoeColorNoEnergy[1], aoeColorNoEnergy[2], aoeColorNoEnergy[3], alpha)
		else
			glColor(aoeColor[1], aoeColor[2], aoeColor[3], alpha)
		end
		DrawCircle(tx, ty, tz, radius)
	end

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
--dgun/noexplode
--------------------------------------------------------------------------------
local function DrawNoExplode(aoe, fx, fy, fz, tx, ty, tz, range, requiredEnergy)
	local dx = tx - fx
	local dy = ty - fy
	local dz = tz - fz

	local bx, by, bz, dist = Normalize(dx, dy, dz)

	if not bx or dist > range then
		return
	end

	local br = sqrt(bx * bx + bz * bz)

	local wx = -aoe * bz / br
	local wz = aoe * bx / br

	local ex = range * bx / br
	local ez = range * bz / br

	local vertices = { { fx + wx, fy, fz + wz }, { fx + ex + wx, ty, fz + ez + wz },
					   { fx - wx, fy, fz - wz }, { fx + ex - wx, ty, fz + ez - wz } }
	local alpha = (1 - GetSecondPart()) * aoeColor[4]

	if requiredEnergy and select(1, Spring.GetTeamResources(spGetMyTeamID(), 'energy')) < requiredEnergy then
		glColor(aoeColorNoEnergy[1], aoeColorNoEnergy[2], aoeColorNoEnergy[3], alpha)
	else
		glColor(aoeColor[1], aoeColor[2], aoeColor[3], alpha)
	end

	glLineWidth(1 + (scatterLineWidthMult / mouseDistance))

	glBeginEnd(GL_LINES, VertexList, vertices)

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
--ballistics
--------------------------------------------------------------------------------

local function GetBallisticVector(v, dx, dy, dz, trajectory, range)
	local dr_sq = dx * dx + dz * dz
	local dr = sqrt(dr_sq)

	if dr > range then
		return nil
	end

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

local function GetBallisticImpactPoint(v, fx, fy, fz, bx, by, bz)
	local v_f = v / GAME_SPEED
	local vx_f = bx * v_f
	local vy_f = by * v_f
	local vz_f = bz * v_f
	local px = fx
	local py = fy
	local pz = fz

	local ttl = 4 * v_f / g_f

	for i = 1, ttl do
		px = px + vx_f
		py = py + vy_f
		pz = pz + vz_f
		vy_f = vy_f - g_f

		local gwh = GetGroundHeight(px, pz)
		if gwh < 0 then
			gwh = 0
		end

		if py < gwh then
			local interpolate = (py - gwh) / vy_f
			if interpolate > 1 then
				interpolate = 1
			end
			local x = px - interpolate * vx_f
			local z = pz - interpolate * vz_f
			return { x, max(GetGroundHeight(x, z), 0), z }
		end
	end

	return { px, py, pz }
end

--v: weaponvelocity
--trajectory: +1 for high, -1 for low
local function DrawBallisticScatter(scatter, v, fx, fy, fz, tx, ty, tz, trajectory, range)
	if (scatter == 0) then
		return
	end
	local dx = tx - fx
	local dy = ty - fy
	local dz = tz - fz
	if (dx == 0 and dz == 0) then
		return
	end

	local bx, by, bz = GetBallisticVector(v, dx, dy, dz, trajectory, range)

	--don't draw anything if out of range
	if (not bx) then
		return
	end

	local br = sqrt(bx * bx + bz * bz)

	--bars
	local rx = dx / br
	local rz = dz / br
	local wx = -scatter * rz
	local wz = scatter * rx
	local barLength = sqrt(wx * wx + wz * wz) --length of bars
	local barX = 0.5 * barLength * bx / br
	local barZ = 0.5 * barLength * bz / br
	local sx = tx - barX
	local sz = tz - barZ
	local lx = tx + barX
	local lz = tz + barZ
	local wsx = -scatter * (rz - barZ)
	local wsz = scatter * (rx - barX)
	local wlx = -scatter * (rz + barZ)
	local wlz = scatter * (rx + barX)

	local bars = { { tx + wx, ty, tz + wz }, { tx - wx, ty, tz - wz },
				   { sx + wsx, ty, sz + wsz }, { lx + wlx, ty, lz + wlz },
				   { sx - wsx, ty, sz - wsz }, { lx - wlx, ty, lz - wlz } }

	local scatterDiv = scatter / numScatterPoints
	local vertices = {}

	--trace impact points
	for i = -numScatterPoints, numScatterPoints do
		local currScatter = i * scatterDiv
		local currScatterCos = sqrt(1 - currScatter * currScatter)
		local rMult = currScatterCos - by * currScatter / br
		local bx_c = bx * rMult
		local by_c = by * currScatterCos + br * currScatter
		local bz_c = bz * rMult

		vertices[i + numScatterPoints + 1] = GetBallisticImpactPoint(v, fx, fy, fz, bx_c, by_c, bz_c)
	end

	glLineWidth(scatterLineWidthMult / mouseDistance)
	glPointSize(pointSizeMult / mouseDistance)
	glColor(scatterColor)
	glDepthTest(false)
	glBeginEnd(GL_LINES, VertexList, bars)
	glBeginEnd(GL_POINTS, VertexList, vertices)
	glDepthTest(true)
	glColor(1, 1, 1, 1)
	glPointSize(1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
--sector
--------------------------------------------------------------------------------

local function DrawSectorScatter(angle, shortfall, rangeMax, fx, fy, fz, tx, ty, tz)
	--x2=cosβx1−sinβy1
	--y2=sinβx1+cosβy1
	local bars = {}
	local vx = tx - fx
	local vz = tz - fz
	local px = fx
	local pz = fz
	local vw = vx * vx + vz * vz
	if vw > 1 and vw > rangeMax * rangeMax then
		vw = mathSqrt(vw)
		local scale = rangeMax / vw
		local angleAim = mathAtan2(vx, vz)
		px = px + (vw - rangeMax) * mathSin(angleAim)
		pz = pz + (vw - rangeMax) * mathCos(angleAim)
		vx = vx * scale
		vz = vz * scale
	end
	local vx2 = 0
	local vz2 = 0
	local segments = mathMax(3, angle / 30)
	local toRadians = mathPi / 180
	local count = 1
	for ii = -segments, segments do
		vx2 = vx * mathCos(0.5 * angle * ii / 3 * toRadians) - vz * mathSin(0.5 * angle * ii / 3 * toRadians)
		vz2 = vx * mathSin(0.5 * angle * ii / 3 * toRadians) + vz * mathCos(0.5 * angle * ii / 3 * toRadians)
		bars[count] = { px + vx2, ty, pz + vz2 }
		count = count + 1
	end
	bars[count] = { px + (1 - shortfall) * vx2, ty, pz + (1 - shortfall) * vz2 }
	count = count + 1
	for ii = segments, -segments, -1 do
		vx2 = vx * mathCos(0.5 * angle * ii / 3 * toRadians) - vz * mathSin(0.5 * angle * ii / 3 * toRadians)
		vz2 = vx * mathSin(0.5 * angle * ii / 3 * toRadians) + vz * mathCos(0.5 * angle * ii / 3 * toRadians)
		bars[count] = { px + (1 - shortfall) * vx2, ty, pz + (1 - shortfall) * vz2 }
		count = count + 1
	end
	bars[count] = { px + vx2, ty, pz + vz2 }
	count = count + 1
	glLineWidth(scatterLineWidthMult / mouseDistance)
	glPointSize(pointSizeMult / mouseDistance)
	glColor(scatterColor)
	glDepthTest(false)
	glBeginEnd(GL.LINE_STRIP, VertexList, bars)
	glDepthTest(true)
	glColor(1, 1, 1, 1)
	glPointSize(1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
--wobble
--------------------------------------------------------------------------------
local function DrawWobbleScatter(scatter, fx, fy, fz, tx, ty, tz, rangeScatter, range)
	local dx = tx - fx
	local dy = ty - fy
	local dz = tz - fz

	local bx, by, bz, d = Normalize(dx, dy, dz)

	glColor(scatterColor)
	glLineWidth(scatterLineWidthMult / mouseDistance)
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
local function DrawDirectScatter(scatter, fx, fy, fz, tx, ty, tz, range, unitRadius)
	local dx = tx - fx
	local dy = ty - fy
	local dz = tz - fz

	local bx, by, bz, d = Normalize(dx, dy, dz)

	if (not bx or d == 0 or d > range) then
		return
	end

	local ux = bx * unitRadius / sqrt(1 - by * by)
	local uz = bz * unitRadius / sqrt(1 - by * by)

	local cx = -scatter * uz
	local cz = scatter * ux
	local wx = -scatter * dz / sqrt(1 - by * by)
	local wz = scatter * dx / sqrt(1 - by * by)

	local vertices = { { fx + ux + cx, fy, fz + uz + cz }, { tx + wx, ty, tz + wz },
					   { fx + ux - cx, fy, fz + uz - cz }, { tx - wx, ty, tz - wz } }

	glColor(scatterColor)
	glLineWidth(scatterLineWidthMult / mouseDistance)
	glBeginEnd(GL_LINES, VertexList, vertices)
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
--dropped
--------------------------------------------------------------------------------
local function DrawDroppedScatter(aoe, ee, scatter, v, fx, fy, fz, tx, ty, tz, salvoSize, salvoDelay)
	local dx = tx - fx
	local dz = tz - fz

	local bx, _, bz = Normalize(dx, 0, dz)

	if (not bx) then
		return
	end

	local currScatter = scatter * v * sqrt(2 * fy / g)
	local alphaMult = v * salvoDelay / aoe
	if alphaMult > 1 then
		alphaMult = 1
	end

	for i = 1, salvoSize do
		local delay = salvoDelay * (i - (salvoSize + 1) / 2)
		local dist = v * delay
		local px_c = dist * bx + tx
		local pz_c = dist * bz + tz
		local py_c = GetGroundHeight(px_c, pz_c)
		if py_c < 0 then
			py_c = 0
		end
		DrawAoE(px_c, py_c, pz_c, aoe, ee, alphaMult, -delay)
		glColor(scatterColor[1], scatterColor[2], scatterColor[3], scatterColor[4] * alphaMult)
		glLineWidth(0.5 + scatterLineWidthMult / mouseDistance)
		DrawCircle(px_c, py_c, pz_c, currScatter)
	end
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

--------------------------------------------------------------------------------
--orbital
--------------------------------------------------------------------------------
local function DrawOrbitalScatter(scatter, tx, ty, tz)
	glColor(scatterColor)
	glLineWidth(scatterLineWidthMult / mouseDistance)
	DrawCircle(tx, ty, tz, scatter)
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

local function DrawDGun(aoe, fx, fy, fz, tx, ty, tz, range, requiredEnergy, unitName)
	local angle = atan2(fx - tx, fz - tz) + (mathPi / 2.1)
	local dx, dz, offset_x, offset_z = fx, fz, 0, 0
	if unitName == 'armcom' then
		offset_x = (sin(angle) * 10)
		offset_z = (cos(angle) * 10)
		dx = fx - offset_x
		dz = fz - offset_z
	elseif unitName == 'corcom' then
		offset_x = (sin(angle) * 14)
		offset_z = (cos(angle) * 14)
		dx = fx + offset_x
		dz = fz + offset_z
	end
	gl.DepthTest(false)
	DrawNoExplode(aoe, dx, fy, dz, tx, ty, tz, range + (aoe * 0.7), requiredEnergy)
	gl.DepthTest(true)
	glColor(1, 0, 0, 0.75)
	glLineWidth(1.5)
	glDrawGroundCircle(fx, fy, fz, range + (aoe * 0.7), circleDivs)
	glColor(1, 1, 1, 1)
end
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
	if not hasSelection then
		return
	end

	local info, manualFire, aimingUnitID
	local _, cmd, _ = GetActiveCommand()

	if ((cmd == CMD_MANUALFIRE or cmd == CMD_MANUAL_LAUNCH) and manualFireUnitDefID) then
		info = manualWeaponInfo[manualFireUnitDefID]
		aimingUnitID = manualFireUnitID
		manualFire = true
	elseif (cmd == CMD_ATTACK and attackUnitDefID) then
		info = weaponInfo[attackUnitDefID]
		aimingUnitID = attackUnitID
	else
		return
	end

	mouseDistance = GetMouseDistance() or 1000
	local tx, ty, tz = GetMouseTargetPosition(true)
	if (not tx) then
		return
	end

	local fx, fy, fz = GetUnitPosition(aimingUnitID)
	if (not fx) then
		return
	end

	if (not info.mobile) then
		fy = fy + GetUnitRadius(aimingUnitID)
	end

	if not info.waterWeapon and ty < 0 then
		ty = 0
	end

	local weaponType = info.type

	-- Engine draws weapon range circles for attack, but does not for manual fire
	-- For some reason, DGun weapon type has effective range slightly higher than weapon range,
	-- so its range circle is handled separately
	if manualFire and weaponType ~= 'dgun' then
		glColor(1, 0, 0, 0.75)
		glLineWidth(1.5)
		glDrawGroundCircle(fx, fy, fz, info.range, circleDivs)
		glColor(1, 1, 1, 1)
	end

	-- tremor customdef weapon
	if (weaponType == "sector") then
		local angle = info.sector_angle
		local shortfall = info.sector_shortfall
		local rangeMax = info.sector_range_max

		DrawSectorScatter(angle, shortfall, rangeMax, fx, fy, fz, tx, ty, tz)

		return
	end

	if (weaponType == "ballistic") then
		local trajectory = select(7, GetUnitStates(aimingUnitID, false, true))
		if trajectory then
			trajectory = 1
		else
			trajectory = -1
		end
		DrawAoE(tx, ty, tz, info.aoe, info.ee, info.requiredEnergy)
		DrawBallisticScatter(info.scatter, info.v, fx, fy, fz, tx, ty, tz, trajectory, info.range)
	elseif (weaponType == "noexplode") then
		DrawNoExplode(info.aoe, fx, fy, fz, tx, ty, tz, info.range, info.requiredEnergy)
	elseif (weaponType == "tracking") then
		DrawAoE(tx, ty, tz, info.aoe, info.ee, info.requiredEnergy)
	elseif (weaponType == "direct") then
		DrawAoE(tx, ty, tz, info.aoe, info.ee, info.requiredEnergy)
		DrawDirectScatter(info.scatter, fx, fy, fz, tx, ty, tz, info.range, GetUnitRadius(aimingUnitID))
	elseif (weaponType == "dropped") then
		DrawDroppedScatter(info.aoe, info.ee, info.scatter, info.v, fx, info.h, fz, tx, ty, tz, info.salvoSize, info.salvoDelay)
	elseif (weaponType == "wobble") then
		DrawAoE(tx, ty, tz, info.aoe, info.ee, info.requiredEnergy)
		DrawWobbleScatter(info.scatter, fx, fy, fz, tx, ty, tz, info.rangeScatter, info.range)
	elseif (weaponType == "orbital") then
		DrawAoE(tx, ty, tz, info.aoe, info.ee, info.requiredEnergy)
		DrawOrbitalScatter(info.scatter, tx, ty, tz)
	elseif weaponType == "dgun" then
		DrawDGun(info.aoe, fx, fy, fz, tx, ty, tz, info.range, info.requiredEnergy, info.unitname)
	else
		DrawAoE(tx, ty, tz, info.aoe, info.ee, info.requiredEnergy)
	end
end

function widget:SelectionChanged(sel)
	selectionChanged = true
end

local selChangedSec = 0
function widget:Update(dt)
	secondPart = secondPart + dt
	secondPart = secondPart - floor(secondPart)

	selChangedSec = selChangedSec + dt
	if selectionChanged and selChangedSec > 0.15 then
		selChangedSec = 0
		selectionChanged = nil
		UpdateSelection()
	end
end
