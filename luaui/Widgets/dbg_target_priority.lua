local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Target Priority Debug",
		desc = "/debugtargetpriority shows a selected unit's autotarget priority for every enemy weapon it sweeps",
		author = "efrec",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false,
		depends = { "gl4" },
	}
end

-- /debugtargetpriority [on|off|lines|details|weapon <n>]
--
-- This reproduces CGameHelper::GenerateWeaponTargets as well as our own priority modifiers.
-- The engine checks for game modifiers in AllowWeaponTarget (in addition to allow/disallow).
-- Then, it elects a single target based on the lowest priority value that it received.
--
-- There are some big approximations used:
-- - The angle term uses the weapon's wanted direction, not the direction of the weapon's aim piece
-- - Radar blips use the viewer's error position during live debugging. Be careful with /globallos.
-- - The avoidTarget and defend-firestate rules are not considered at all.

local math_sqrt = math.sqrt
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local format = string.format
local char = string.char
local sort = table.sort

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetGameFrame = Spring.GetGameFrame
local spGetGroundExtremes = Spring.GetGroundExtremes
local spGetViewGeometry = Spring.GetViewGeometry
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spIsGUIHidden = Spring.IsGUIHidden

local spValidUnitID = Spring.ValidUnitID
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitArmored = Spring.GetUnitArmored
local spGetUnitNeutral = Spring.GetUnitNeutral
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitLosState = Spring.GetUnitLosState
local spGetUnitLastAttacker = Spring.GetUnitLastAttacker
local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local spGetUnitStates = Spring.GetUnitStates
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitWeaponState = Spring.GetUnitWeaponState
local spGetUnitWeaponDamages = Spring.GetUnitWeaponDamages
local spGetUnitWeaponVectors = Spring.GetUnitWeaponVectors
local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local spGetUnitWeaponTryTarget = Spring.GetUnitWeaponTryTarget
local spGetUnitWeaponTestTarget = Spring.GetUnitWeaponTestTarget
local spGetUnitWeaponHaveFreeLineOfFire = Spring.GetUnitWeaponHaveFreeLineOfFire

local FIRESTATE_FIREATWILL = CMD.FIRESTATE_FIREATWILL
local FIRESTATE_FIREATNEUTRAL = CMD.FIRESTATE_FIREATNEUTRAL

local LOS_INLOS = 1
local LOS_INRADAR = 2
local LOS_PREVLOS = 4

local function hasBit(value, bit)
	return value % (bit * 2) >= bit
end

local paralyzeOnMaxHealth = Game.paralyzeOnMaxHealth
local fireAtCrashing = Game.fireAtCrashing ~= 0
local armorTypeCount = #Game.armorTypes + 1

local colorAndOutlineCode = (Engine and Engine.textColorCodes and Engine.textColorCodes.ColorAndOutline) or "\254"

-- Priority multipliers from CGameHelper::GenerateWeaponTargets:
local PRIORITY_RADAR_ONLY = 10
local PRIORITY_BAD_CATEGORY = 100
local PRIORITY_CRASHING = 1000
local PRIORITY_LAST_ATTACKER = 0.5
local PRIORITY_PARALYZED = 4
local PRIORITY_BEYOND_RANGE = 100000
local LAST_ATTACKER_FRAMES = 200

-- Priority multipliers from unit_aa_targeting_priority:
local PRIORITY_BOMBERS = 0.1
local PRIORITY_VTOLS = 1
local PRIORITY_FIGHTERS = 2
local PRIORITY_SCOUTS = 100

--------------------------------------------------------------------------------
-- State -----------------------------------------------------------------------

local active = false
local showLines = false
local showDetails = false
local weaponNumber = nil -- explicit weapon number, else the first weapon that autotargets, sorry

local vsx, vsy = spGetViewGeometry()

local attackerID, attackerDefID, attackerWeapon

local candidates = {} -- sorted array of target records
local candidateCount = 0

local currentTargetID, chaseTargetID
local selectionOrder = {}
local statusText = ""
local hintText = nil

local lastAttackFrame = {}

--------------------------------------------------------------------------------
-- Unit and weapon def data ----------------------------------------------------

local airPriorityMultiplier = {}
local hasAntiAirPriority = {}

do
	local isAirCategory = {
		vtol = true,
		mobile = true,
		nothover = true,
		notship = true,
		notsub = true,
	}

	local nonAntiAirTypes = {
		AircraftBomb = true,
		Shield = true,
		TorpedoLauncher = true,
	}

	local function hasTargeting(unitDef, weapon)
		return weapon.slavedTo == 0 and not (unitDef.canManualFire and WeaponDefs[weapon.weaponDef].manualFire)
	end

	local function hasAntiAirTargeting(weapon)
		return table.any(weapon.onlyTargets, function(v, k)
			return isAirCategory[k]
		end) and not table.any(weapon.badTargets, function(v, k)
			return isAirCategory[k]
		end)
	end

	local function isBomberWeapon(weapon)
		local weaponDef = WeaponDefs[weapon.weaponDef]
		return weaponDef.type == "AircraftBomb"
			or weaponDef.type == "TorpedoLauncher"
			or string.find(weaponDef.name, "arm_pidr", 1, true)
	end

	local function isFighterWeapon(weapon)
		return weapon.slavedTo == 0 and hasAntiAirTargeting(weapon)
	end

	local function isNotFakeWeapon(weapon)
		return not WeaponDefs[weapon.weaponDef].customParams.bogus
	end

	local function hasAntiAirPriorityWeapon(unitDef, weapon)
		if not hasTargeting(unitDef, weapon) or not hasAntiAirTargeting(weapon) then
			return false
		end
		local weaponDef = WeaponDefs[weapon.weaponDef]
		if nonAntiAirTypes[weaponDef.type] or weaponDef.range < 100 then
			return false
		end
		local damages = weaponDef.damages
		return damages[Game.armorTypes.vtol] > damages[Game.armorTypes.default] * 0.5
	end

	for unitDefID, unitDef in pairs(UnitDefs) do
		local weapons = unitDef.weapons
		if unitDef.isAirUnit then
			airPriorityMultiplier[unitDefID] = (unitDef.isTransport or unitDef.isBuilder) and PRIORITY_VTOLS
				or table.any(weapons, isBomberWeapon) and PRIORITY_BOMBERS
				or table.any(weapons, isFighterWeapon) and PRIORITY_FIGHTERS
				or table.any(weapons, isNotFakeWeapon) and PRIORITY_VTOLS
				or PRIORITY_SCOUTS
		end
		for i = 1, #weapons do
			if hasAntiAirPriorityWeapon(unitDef, weapons[i]) then
				hasAntiAirPriority[weapons[i].weaponDef] = true
			end
		end
	end
end

-- weaponAimAdjustPriority is a unit weapon tag the engine does not expose to Lua, so read the unit file.
local aimAdjustPriority = {} -- unitDefID -> { [weaponNum] = value }

local function getAimAdjustPriority(unitDefID, weaponNum)
	local byWeapon = aimAdjustPriority[unitDefID]
	if not byWeapon then
		byWeapon = {}
		aimAdjustPriority[unitDefID] = byWeapon

		local name = UnitDefs[unitDefID].name:gsub("_scav$", "")
		local files = VFS.DirList("units/", name .. ".lua", nil, true)
		local ok, defs = false, nil
		if files[1] then
			ok, defs = pcall(VFS.Include, files[1])
		end
		local unitDef = ok and type(defs) == "table" and defs[name]
		if unitDef and type(unitDef.weapons) == "table" then
			for index, weapon in pairs(unitDef.weapons) do
				for key, value in pairs(weapon) do
					if type(key) == "string" and key:lower() == "weaponaimadjustpriority" then
						byWeapon[index] = tonumber(value)
					end
				end
			end
		end
	end
	return byWeapon[weaponNum] or 1
end

local function getSweepWeapon(unitDef)
	local weapons = unitDef.weapons
	if weaponNumber then
		return weapons[weaponNumber] and weaponNumber or nil
	end
	for i = 1, #weapons do
		local weapon = weapons[i]
		local weaponDef = WeaponDefs[weapon.weaponDef]
		if
			weapon.slavedTo == 0
			and not weaponDef.noAutoTarget
			and weaponDef.interceptor == 0
			and not weaponDef.isShield
			and not weaponDef.customParams.bogus
			and not (unitDef.canManualFire and weaponDef.manualFire)
		then
			return i
		end
	end
end

local function intersects(categorySet, unitCategories)
	for category in pairs(categorySet) do
		if unitCategories[category] then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Autotargeting ---------------------------------------------------------------

local function canReadAllyTeam(allyTeam)
	local _, fullview = spGetSpectatingState()
	return fullview or allyTeam == spGetMyAllyTeamID()
end

local function isCrashing(unitID, fullview)
	-- Not sure about this:
	if not fullview then
		return false
	end
	local moveData = spGetUnitMoveTypeData(unitID)
	return moveData ~= nil and moveData.aircraftState == "crashing"
end

local function resetSweep()
	candidateCount = 0
	selectionOrder = {}
	currentTargetID, chaseTargetID = nil, nil
end

local function selectAttacker()
	local selected = spGetSelectedUnits()
	if #selected ~= 1 then
		attackerID = nil
		statusText = #selected == 0 and "Select a unit" or "Select a single unit"
		return false
	end

	local unitID = selected[1]
	local unitDefID = spGetUnitDefID(unitID)
	if not unitDefID then
		attackerID = nil
		statusText = "Unknown unit definition"
		return false
	end

	if not canReadAllyTeam(spGetUnitAllyTeam(unitID)) then
		attackerID = nil
		statusText = "Cannot read the targeting view of an enemy unit"
		return false
	end

	local weaponNum = getSweepWeapon(UnitDefs[unitDefID])
	if not weaponNum then
		attackerID = nil
		statusText = weaponNumber and ("No weapon " .. weaponNumber) or "No autotargeting weapon"
		return false
	end

	attackerID, attackerDefID, attackerWeapon = unitID, unitDefID, weaponNum
	return true
end

---Mirrors CWeapon::TestTarget for the checks Lua can see. Neutrals are checked in fire state.
local function passesTestTarget(unitID, targetDefID, onlyTargets, waterWeapon, aimY, fullview)
	if targetDefID and not intersects(onlyTargets, UnitDefs[targetDefID].springCategories) then
		return false
	end
	if spGetUnitIsDead(unitID) then
		return false
	end
	if not fireAtCrashing and isCrashing(unitID, fullview) then
		return false
	end
	if not waterWeapon and aimY < 0 then
		return false
	end
	return true
end

local function byPriority(a, b)
	return a.priority < b.priority
end

local function sweepTargets()
	local frame = spGetGameFrame()
	local unitID, weaponNum = attackerID, attackerWeapon
	local unitDef = UnitDefs[attackerDefID]
	local weapon = unitDef.weapons[weaponNum]
	local weaponDef = WeaponDefs[weapon.weaponDef]
	local allyTeam = spGetUnitAllyTeam(unitID)
	local _, fullview = spGetSpectatingState()

	local ownerX, ownerY, ownerZ = spGetUnitPosition(unitID)
	local aimX, aimY, aimZ, dirX, dirY, dirZ = spGetUnitWeaponVectors(unitID, weaponNum)
	if not ownerX or not aimX then
		resetSweep()
		return
	end

	local range = spGetUnitWeaponState(unitID, weaponNum, "range")
	local rangeBoost = spGetUnitWeaponState(unitID, weaponNum, "autoTargetRangeBoost")
	local salvoSize = spGetUnitWeaponState(unitID, weaponNum, "burst")
	local reloadTime = math_max(spGetUnitWeaponState(unitID, weaponNum, "reloadTime"), 1 / 30)
	local heightMod = weaponDef.heightMod
	local proximityPriority = weaponDef.proximityPriority
	local aimAdjust = getAimAdjustPriority(attackerDefID, weaponNum)

	local damages = {}
	for armorType = 0, armorTypeCount - 1 do
		damages[armorType] = spGetUnitWeaponDamages(unitID, weaponNum, armorType) or 0
	end
	local secDamage = damages[0] * salvoSize / reloadTime
	local paralyzer = (spGetUnitWeaponDamages(unitID, weaponNum, "paralyzeDamageTime") or 0) ~= 0

	local _, _, minMapHeight = spGetGroundExtremes()
	minMapHeight = math_max(0, minMapHeight)
	local scanRadius = range + rangeBoost + (aimY - minMapHeight) * heightMod

	local states = spGetUnitStates(unitID)
	local fireState = states.firestate
	local lastAttacker = spGetUnitLastAttacker(unitID)
	if (lastAttackFrame[unitID] or -LAST_ATTACKER_FRAMES) + LAST_ATTACKER_FRAMES <= frame then
		lastAttacker = nil
	end

	local badTargets = weapon.badTargets
	local onlyTargets = weapon.onlyTargets
	local antiAir = hasAntiAirPriority[weapon.weaponDef]

	candidateCount = 0
	local nearby = spGetUnitsInCylinder(ownerX, ownerZ, scanRadius)
	for i = 1, #nearby do
		local targetID = nearby[i]
		if spGetUnitAllyTeam(targetID) ~= allyTeam then
			local losState = spGetUnitLosState(targetID, allyTeam, true)
			local inLos = hasBit(losState, LOS_INLOS)
			local inRadar = hasBit(losState, LOS_INRADAR)
			local prevLos = inLos or hasBit(losState, LOS_PREVLOS)
			local targetDefID = spGetUnitDefID(targetID)
			local targetDef = targetDefID and UnitDefs[targetDefID]
			local posX, posY, posZ, _, _, _, targetX, targetY, targetZ = spGetUnitPosition(targetID, true, true)

			if
				posX
				and (inLos or inRadar)
				and passesTestTarget(targetID, targetDefID, onlyTargets, weaponDef.waterWeapon, targetY, fullview)
				and (fireState >= FIRESTATE_FIREATNEUTRAL or not spGetUnitNeutral(targetID))
			then
				-- Radar blips are aimed at the error position, which GetUnitPosition already applies.
				if not inLos then
					targetX, targetY, targetZ = posX, posY, posZ
				end

				local heightDiff = (targetY - aimY) * heightMod
				local modRange = math_sqrt(math_max(0, (range + rangeBoost) ^ 2 - heightDiff ^ 2))
				local dx, dz = targetX - ownerX, targetZ - ownerZ
				local dist2D = math_sqrt(dx * dx + dz * dz)

				if dist2D <= modRange then
					local dy = targetY - ownerY
					local length = math_sqrt(dx * dx + dy * dy + dz * dz)
					local angleOffset = 1
					if length > 0 then
						angleOffset = 1 - (dirX * dx + dirY * dy + dirZ * dz) / length
					end
					local angleMul = (angleOffset * aimAdjust + 1) ^ 2
					local rangeMul = dist2D * proximityPriority + modRange * 0.4 + 100

					local health, maxHealth, paralyzeDamage = spGetUnitHealth(targetID)
					local armored, armorMultiple = spGetUnitArmored(targetID)
					local damageMul = 1
					if targetDef then
						damageMul = math_max(0.0001, damages[targetDef.armorType] * (armored and armorMultiple or 1))
					end

					local priority = angleMul * rangeMul
					local healthMul, valueDiv = 1, 1
					local badCategory, crashing, isLastAttacker, paralyzed, beyondRange =
						false, false, false, false, false

					if not inLos then
						priority = priority * PRIORITY_RADAR_ONLY
					end
					if dist2D > range then
						beyondRange = true
						priority = priority * PRIORITY_BEYOND_RANGE
					end

					if inLos and health then
						healthMul = secDamage + health
						if paralyzer and paralyzeDamage > (paralyzeOnMaxHealth and maxHealth or health) then
							paralyzed = true
							healthMul = healthMul * PRIORITY_PARALYZED
						end
					else
						healthMul = secDamage + 10000
					end
					priority = priority * healthMul

					if prevLos and targetDef then
						valueDiv = damageMul * targetDef.power
						priority = priority / valueDiv
						badCategory = intersects(badTargets, targetDef.springCategories)
						crashing = isCrashing(targetID, fullview)
						isLastAttacker = targetID == lastAttacker
						if badCategory then
							priority = priority * PRIORITY_BAD_CATEGORY
						end
						if crashing then
							priority = priority * PRIORITY_CRASHING
						end
						if isLastAttacker then
							priority = priority * PRIORITY_LAST_ATTACKER
						end
					end

					local airMul = antiAir and targetDefID and airPriorityMultiplier[targetDefID] or 1
					priority = priority * airMul

					candidateCount = candidateCount + 1
					local candidate = candidates[candidateCount]
					if not candidate then
						candidate = {}
						candidates[candidateCount] = candidate
					end
					candidate.unitID = targetID
					candidate.unitDefID = targetDefID
					candidate.priority = priority
					candidate.height = targetDef and targetDef.height or 30
					candidate.inLos = inLos
					candidate.badCategory = badCategory
					candidate.beyondRange = beyondRange
					candidate.crashing = crashing
					candidate.lastAttacker = isLastAttacker
					candidate.paralyzed = paralyzed
					candidate.angleMul = angleMul
					candidate.rangeMul = rangeMul
					candidate.healthMul = healthMul
					candidate.valueDiv = valueDiv
					candidate.airMul = airMul
					candidate.dist2D = dist2D
					-- Autotargets may sit beyond range, where the Lua TryTarget rejects them.
					candidate.aimable = spGetUnitWeaponTryTarget(unitID, weaponNum, targetID)
						or (
							beyondRange
							and spGetUnitWeaponTestTarget(unitID, weaponNum, targetID)
							and spGetUnitWeaponHaveFreeLineOfFire(unitID, weaponNum, targetID)
						)
				end
			end
		end
	end

	for i = candidateCount + 1, #candidates do
		candidates[i] = nil
	end

	sort(candidates, byPriority)

	-- CWeapon::AutoTarget takes the first good target, else falls back to the best bad one.
	selectionOrder = {}
	for i = 1, candidateCount do
		local candidate = candidates[i]
		candidate.rank = i
		if candidate.aimable and not candidate.badCategory then
			selectionOrder[#selectionOrder + 1] = i
		end
	end
	for i = 1, candidateCount do
		local candidate = candidates[i]
		if candidate.aimable and candidate.badCategory then
			selectionOrder[#selectionOrder + 1] = i
		end
	end

	local targetType, _, target = spGetUnitWeaponTarget(unitID, weaponNum)
	currentTargetID = targetType == 1 and target or nil

	-- The command AI's own sweep chases the closest visible enemy any weapon can test as a target.
	chaseTargetID = nil
	if unitDef.canMove and not unitDef.isAirUnit and fireState >= FIRESTATE_FIREATWILL then
		local moveState = states.movestate
		local chaseRadius = unitDef.maxWeaponRange + 200 * moveState * moveState
		local closest = math.huge
		local noChase = unitDef.noChaseCategories
		local chaseable = spGetUnitsInCylinder(ownerX, ownerZ, chaseRadius)
		for i = 1, #chaseable do
			local targetID = chaseable[i]
			local targetDefID = spGetUnitDefID(targetID)
			if
				targetDefID
				and spGetUnitAllyTeam(targetID) ~= allyTeam
				and hasBit(spGetUnitLosState(targetID, allyTeam, true), LOS_INLOS)
				and not spGetUnitNeutral(targetID)
				and not intersects(noChase, UnitDefs[targetDefID].springCategories)
			then
				local tx, _, tz = spGetUnitPosition(targetID)
				local distance = tx and (tx - ownerX) ^ 2 + (tz - ownerZ) ^ 2 or math.huge
				if distance < closest then
					for w = 1, #unitDef.weapons do
						if spGetUnitWeaponTestTarget(unitID, w, targetID) then
							closest = distance
							chaseTargetID = targetID
							break
						end
					end
				end
			end
		end
	end

	statusText = format(
		"%s  ·  weapon %d %s  ·  %d candidates  ·  %s%s",
		unitDef.name,
		weaponNum,
		weaponDef.name,
		candidateCount,
		showLines and "lines on" or "lines off",
		showDetails and "  ·  details on" or ""
	)
end

--------------------------------------------------------------------------------
-- Rendering -------------------------------------------------------------------

local LuaShader = gl.LuaShader

local lineShader, lineVBO, lineVAO
local lineCapacity = 1536 -- vertices
local lineData = {}
local lineVertexCount = 0

local FLOATS_PER_VERTEX = 7

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

layout (location = 0) in vec3 posAcross; // screen xy, signed distance across the stroke in [-1, 1]
layout (location = 1) in vec4 color;

//__ENGINEUNIFORMBUFFERDEFS__

out vec4 v_color;
out float v_across;

void main() {
	vec2 ndc = posAcross.xy / viewGeometry.xy * 2.0 - 1.0;
	gl_Position = vec4(ndc, 0.0, 1.0);
	v_color = color;
	v_across = posAcross.z;
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in vec4 v_color;
in float v_across;

out vec4 fragColor;

void main() {
	float edge = 1.0 - smoothstep(1.0 - FEATHER, 1.0, abs(v_across));
	fragColor = vec4(v_color.rgb, v_color.a * edge);
}
]]

local STROKE_FEATHER_PX = 1.0

local function initLineBuffers(capacity)
	if lineVBO then
		lineVBO:Delete()
		lineVAO:Delete()
	end
	lineCapacity = capacity
	lineVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	lineVBO:Define(capacity, {
		{ id = 0, name = "posAcross", size = 3 },
		{ id = 1, name = "color", size = 4 },
	})
	lineVAO = gl.GetVAO()
	lineVAO:AttachVertexBuffer(lineVBO)
end

local function initShader()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	lineShader = LuaShader({
		vertex = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
		fragment = fsSrc
			:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
			:gsub("//__DEFINES__", "#define FEATHER 0.5"),
	}, "TargetPriorityLines")
	return lineShader:Initialize()
end

local function pushVertex(x, y, across, r, g, b, a)
	local base = lineVertexCount * FLOATS_PER_VERTEX
	lineData[base + 1] = x
	lineData[base + 2] = y
	lineData[base + 3] = across
	lineData[base + 4] = r
	lineData[base + 5] = g
	lineData[base + 6] = b
	lineData[base + 7] = a
	lineVertexCount = lineVertexCount + 1
end

---A stroke is two triangles with the feather baked into its half width.
local function pushStroke(x1, y1, x2, y2, width, c1, c2)
	local dx, dy = x2 - x1, y2 - y1
	local length = math_sqrt(dx * dx + dy * dy)
	if length < 0.5 then
		return
	end
	local half = width * 0.5 + STROKE_FEATHER_PX
	local nx, ny = -dy / length * half, dx / length * half
	c2 = c2 or c1
	pushVertex(x1 + nx, y1 + ny, -1, c1[1], c1[2], c1[3], c1[4])
	pushVertex(x1 - nx, y1 - ny, 1, c1[1], c1[2], c1[3], c1[4])
	pushVertex(x2 + nx, y2 + ny, -1, c2[1], c2[2], c2[3], c2[4])
	pushVertex(x2 + nx, y2 + ny, -1, c2[1], c2[2], c2[3], c2[4])
	pushVertex(x1 - nx, y1 - ny, 1, c1[1], c1[2], c1[3], c1[4])
	pushVertex(x2 - nx, y2 - ny, 1, c2[1], c2[2], c2[3], c2[4])
end

local function drawStrokes()
	if lineVertexCount == 0 then
		return
	end
	if lineVertexCount > lineCapacity then
		initLineBuffers(lineVertexCount * 2)
	end
	for i = lineVertexCount * FLOATS_PER_VERTEX + 1, #lineData do
		lineData[i] = nil
	end
	lineVBO:Upload(lineData)

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthTest(false)
	lineShader:Activate()
	lineVAO:DrawArrays(GL.TRIANGLES, lineVertexCount)
	lineShader:Deactivate()
end

-- Gradient from the most preferred target to the least:
local GRADIENT = {
	{ 1.0, 0.42, 0.24 },
	{ 1.0, 0.84, 0.32 },
	{ 0.42, 0.68, 1.0 },
}

local COLOR_IGNORED = { 0.62, 0.62, 0.66, 1.0 }
local COLOR_OUTLINE = { 0.0, 0.0, 0.0, 0.85 }
local COLOR_ATTACKER = { 1.0, 1.0, 1.0, 0.9 }

local function gradientColor(t)
	local segment = math_min(2, math_floor(t * 2) + 1)
	local a, b = GRADIENT[segment], GRADIENT[segment + 1]
	local s = t * 2 - (segment - 1)
	return { a[1] + (b[1] - a[1]) * s, a[2] + (b[2] - a[2]) * s, a[3] + (b[3] - a[3]) * s, 1.0 }
end

local function colorByte(value)
	return math_floor(math_max(0, math_min(1, value)) * 255 + 0.5)
end

local function colorizeText(text, color, alpha)
	return colorAndOutlineCode
		.. char(
			colorByte(color[1]),
			colorByte(color[2]),
			colorByte(color[3]),
			colorByte(alpha),
			colorByte(COLOR_OUTLINE[1]),
			colorByte(COLOR_OUTLINE[2]),
			colorByte(COLOR_OUTLINE[3]),
			colorByte(COLOR_OUTLINE[4] * alpha)
		)
		.. text
end

local function formatPriority(value)
	if value >= 100 then
		return format("%.0f", value)
	elseif value >= 10 then
		return format("%.1f", value)
	end
	return format("%.2f", value)
end

local function formatFactors(candidate)
	local factors = format(
		"angle %.2f  range %.0f  health %s  value %s",
		candidate.angleMul,
		candidate.rangeMul,
		formatPriority(candidate.healthMul),
		formatPriority(candidate.valueDiv)
	)
	if not candidate.inLos then
		factors = factors .. "  radar ×10"
	end
	if candidate.beyondRange then
		factors = factors .. "  beyond range ×1e5"
	end
	if candidate.badCategory then
		factors = factors .. "  bad category ×100"
	end
	if not candidate.aimable then
		factors = factors .. "  cannot aim"
	end
	if candidate.crashing then
		factors = factors .. "  crashing ×1000"
	end
	if candidate.paralyzed then
		factors = factors .. "  paralyzed ×4"
	end
	if candidate.lastAttacker then
		factors = factors .. "  last attacker ×0.5"
	end
	if candidate.airMul ~= 1 then
		factors = factors .. format("  air ×%g", candidate.airMul)
	end
	return factors
end

local font, fontSize
local labelScale = 0.6

local function refreshFont()
	if WG.fonts then
		font, fontSize = WG.fonts.getFont(2, labelScale, 0.22, 1.6)
	else
		fontSize = math_floor(17 * (vsy / 1080) + 0.5)
		font = gl.LoadFont("fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf"), fontSize, 4, 1.6)
	end
end

local screenX, screenY = {}, {} -- candidate index -> label anchor

function widget:DrawScreenEffects()
	if not active or spIsGUIHidden() then
		return
	end

	local labelSize = fontSize
	local valueSize = fontSize * 0.8
	local factorSize = fontSize * 0.7

	lineVertexCount = 0

	local attackerX, attackerY
	if attackerID and spValidUnitID(attackerID) then
		local ux, uy, uz = spGetUnitPosition(attackerID)
		if ux then
			attackerX, attackerY = spWorldToScreenCoords(ux, uy, uz)
		end
	end

	local lastIndex = math_max(1, candidateCount - 1)
	for i = 1, candidateCount do
		local candidate = candidates[i]
		local ux, uy, uz = spGetUnitPosition(candidate.unitID)
		if ux then
			local sx, sy = spWorldToScreenCoords(ux, uy + candidate.height + 12, uz)
			screenX[i], screenY[i] = sx, sy
			local ignored = candidate.badCategory or not candidate.aimable
			local color = ignored and COLOR_IGNORED or gradientColor((i - 1) / lastIndex)
			candidate.color = color

			if candidate.badCategory then
				-- An X above the label marks a bad-category target.
				local size = labelSize * 0.32
				local cx, cy = sx, sy + (showDetails and labelSize * 2.3 or labelSize * 1.2)
				pushStroke(cx - size, cy - size, cx + size, cy + size, 2.5, color)
				pushStroke(cx - size, cy + size, cx + size, cy - size, 2.5, color)
			end
			if candidate.unitID == currentTargetID then
				-- An underline marks the weapon's current target.
				local width = labelSize * 0.8
				pushStroke(sx - width, sy - 2, sx + width, sy - 2, 2.0, color)
			end
		else
			screenX[i] = nil
		end
	end

	if showLines and attackerX then
		local px, py, pc = attackerX, attackerY, COLOR_ATTACKER
		for n = 1, #selectionOrder do
			local i = selectionOrder[n]
			if screenX[i] then
				local candidate = candidates[i]
				pushStroke(px, py, screenX[i], screenY[i] - 4, 2.0, pc, candidate.color)
				px, py, pc = screenX[i], screenY[i] - 4, candidate.color
			end
		end
	end

	drawStrokes()

	font:Begin()
	font:Print(colorizeText(statusText, COLOR_ATTACKER, 1.0), vsx * 0.5, vsy * 0.86, valueSize, "co")
	if hintText then
		font:Print(colorizeText(hintText, COLOR_IGNORED, 1.0), vsx * 0.5, vsy * 0.86 - valueSize * 1.3, valueSize, "co")
	end

	for i = 1, candidateCount do
		local sx = screenX[i]
		if sx then
			local sy = screenY[i]
			local candidate = candidates[i]
			local alpha = candidate.aimable and 1.0 or 0.55
			local value = formatPriority(candidate.priority)
			font:Print(colorizeText(value, candidate.color, alpha), sx, sy, valueSize, "co")
			if showDetails then
				local rank = candidate.aimable and tostring(i) or ("(" .. i .. ")")
				if candidate.unitID == chaseTargetID then
					rank = rank .. "  chase"
				end
				font:Print(colorizeText(rank, candidate.color, alpha), sx, sy + valueSize * 1.1, labelSize, "co")
				font:Print(
					colorizeText(formatFactors(candidate), candidate.color, alpha),
					sx,
					sy - factorSize * 1.2,
					factorSize,
					"co"
				)
			end
		end
	end
	font:End()
end

--------------------------------------------------------------------------------
-- Engine callins --------------------------------------------------------------

function widget:GameFrame()
	if not active then
		return
	end
	if selectAttacker() then
		sweepTargets()
	else
		resetSweep()
	end
end

function widget:UnitDamaged(unitID)
	if unitID == attackerID then
		lastAttackFrame[unitID] = spGetGameFrame()
	end
end

function widget:UnitDestroyed(unitID)
	lastAttackFrame[unitID] = nil
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	refreshFont()
end

function widget:Initialize()
	if not initShader() then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "Shader compilation failed")
		widgetHandler:RemoveWidget()
		return
	end
	initLineBuffers(lineCapacity)
	refreshFont()

	local function debugTargetPriorityCmd(_, _, words)
		local option = words[1] and words[1]:lower()
		hintText = nil
		if option == nil then
			active = not active
		elseif option == "on" then
			active = true
		elseif option == "off" then
			active = false
		elseif option == "lines" then
			showLines = not showLines
			active = true
		elseif option == "details" then
			showDetails = not showDetails
			active = true
		elseif option == "weapon" then
			weaponNumber = tonumber(words[2])
			active = true
		else
			hintText = "Options: on, off, lines, details, weapon <n>"
			active = true
		end
		if active then
			widget:GameFrame()
		else
			resetSweep()
		end
		return true
	end
	widgetHandler:AddAction("debugtargetpriority", debugTargetPriorityCmd, nil, "t")
end

function widget:Shutdown()
	widgetHandler:RemoveAction("debugtargetpriority", "t")
	if lineShader then
		lineShader:Finalize()
	end
	if lineVBO then
		lineVBO:Delete()
		lineVAO:Delete()
	end
end
