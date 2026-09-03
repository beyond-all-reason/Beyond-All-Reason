local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Transport Handler",
		desc = "Main handler for tractor beam transports",
		author = "DoodVanDaag",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

if Spring.GetModOptions and Spring.GetModOptions().beta_tractorbeam == "disabled" then
	Spring.Echo("Custom transports disabled via modoption, skipping gadget" .. gadget:GetInfo().name)
	return false
end

local TransportAPI = GG.TransportAPI
if not TransportAPI then
	Spring.Echo("TransportAPI must be loaded before this gadget")
	return false
end

local modOptions = Spring.GetModOptions() or {}
local tractorBeamEnabled = modOptions.beta_tractorbeam ~= "disabled"
local tractorBeamMode = tractorBeamEnabled and modOptions.beta_tractorbeam or nil
local tractorbeamDefs = tractorBeamMode
		and VFS.Include("tractor_beams_temp_defs/transporter_defs_" .. tractorBeamMode .. ".lua")
	or {}

local GetPassengerSize = TransportAPI.GetPassengerSize
local EnablePassenger = TransportAPI.EnablePassenger
local IsTransportFull = TransportAPI.IsTransportFull
local CanPassengerFitInTransporter = TransportAPI.CanPassengerFitInTransporter
local GetUnloadPadType = TransportAPI.GetUnloadPadType
local GetUnloadTargets = TransportAPI.GetUnloadTargets

local mathSqrt = math.sqrt
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitHeight = Spring.GetUnitHeight
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitLosState = Spring.GetUnitLosState
local spGetUnitTransporter = Spring.GetUnitTransporter
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spSetUnitMoveGoal = Spring.SetUnitMoveGoal
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spUnitFinishCommand = Spring.UnitFinishCommand
local spValidUnitID = Spring.ValidUnitID
local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetAllUnits = Spring.GetAllUnits
local spGetCOBScriptID = Spring.GetCOBScriptID
local spCallCOBScript = Spring.CallCOBScript
local spEcho = Spring.Echo
local spSetCustomCommandDrawData = Spring.SetCustomCommandDrawData
local spGetGameFrame = Spring.GetGameFrame
local spMoveCtrlDisable = Spring.MoveCtrl.Disable
local spMoveCtrlEnable = Spring.MoveCtrl.Enable
local spGetAllyTeamList = Spring.GetAllyTeamList
local spSetUnitPosition = Spring.SetUnitPosition
local spSetUnitRadiusAndHeight = Spring.SetUnitRadiusAndHeight
local spTestBuildOrder = Spring.TestBuildOrder
local spClosestBuildPos = Spring.ClosestBuildPos
local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitsInBox = Spring.GetUnitsInBox
local reissueOrder = Game.Commands.ReissueOrder
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting

local LOAD_RADIUS = tractorbeamDefs.LOAD_RADIUS or 128
local UNLOAD_RADIUS = tractorbeamDefs.UNLOAD_RADIUS or 32
local CMD_AREA_LOAD = 39751
local CMD_LOAD_UNIT = 39752
local CMD_LOAD_WAIT = 39753
local CACHED_CYLINDER_UNITS_LIFESPAN = 1
local CACHED_CYLINDER_UNITS_ROUNDING = 16
local ALLOW_ENEMY_LOAD_MODE = tractorbeamDefs.ALLOW_ENEMY_LOAD_MODE or 2
local ENEMY_LOAD_RADIUS_MULTIPLIER = tractorbeamDefs.ENEMY_LOAD_RADIUS_MULTIPLIER or 0.5
local MIN_CONSECUTIVE_FRAMES_TO_LOAD_ENEMY = tractorbeamDefs.MIN_CONSECUTIVE_FRAMES_TO_LOAD_ENEMY or 60

local MAP_SIZE_X = Game.mapSizeX
local MAP_SIZE_Z = Game.mapSizeZ
local MOBILITY_DIST = MAP_SIZE_X * MAP_SIZE_Z
local ALLIED_DIST = 2 * MOBILITY_DIST
local MAX_DIST_SQ = 2 * ALLIED_DIST
local ENEMY_LOAD_RADIUS = LOAD_RADIUS * ENEMY_LOAD_RADIUS_MULTIPLIER

local customTransportLoad = {}
local customTransportUnload = {}
local claimedBy = {}
local queuedSeats = {}
local transporterClaims = {}
local areaLoadCoroutines = {}
local successiveLoadCoroutines = {}
local cylinderCache = {}
local isAirTransport = {}
local offset = 0
local areaLoadCoroutinesCount = 0
local successiveLoadCoroutinesCount = 0
local transporterCoroutines = {}
local consecutiveFramesOverEnemyPassenger = {}

local autoClaimBlackList = {}
local autoClaimBlackListDefIDs = {}

for udefID, def in ipairs(UnitDefs) do
	if def.canFly and def.isTransport then
		isAirTransport[udefID] = true
	end
	if def.customParams.cantbeautoloaded == "1" then
		autoClaimBlackListDefIDs[udefID] = true
	end
end

---@param unitID number
---@param functionName string
---@return function|false
local function GetScriptFunc(unitID, functionName)
	if spGetCOBScriptID(unitID, functionName) then
		return spCallCOBScript
	end
	local env = Spring.UnitScript.GetScriptEnv(unitID)
	if env and env[functionName] then
		return function(uid, fname, ...)
			local scriptEnv = Spring.UnitScript.GetScriptEnv(uid)
			Spring.UnitScript.CallAsUnit(uid, scriptEnv[fname], ...)
		end
	end
	return false
end

---@param passengerID number
---@param y number
---@return boolean isUnderwater
local function isUnderwater(passengerID, y)
	local height = spGetUnitHeight(passengerID)
	return not height or y + height < 0
end

---@param x1 number
---@param z1 number
---@param x2 number
---@param z2 number
---@return number distance
local function dist2D(x1, z1, x2, z2)
	local dx, dz = x1 - x2, z1 - z2
	return mathSqrt(dx * dx + dz * dz)
end

---@param transporterPosX number
---@param transporterPosY number
---@param transporterPosZ number
---@param goalX number
---@param goalY number
---@param goalZ number
---@return boolean inLoadRange
local function inLoadRange(transporterPosX, transporterPosY, transporterPosZ, goalX, goalY, goalZ, reducedRadius)
	local dY = transporterPosY - goalY
	return dist2D(transporterPosX, transporterPosZ, goalX, goalZ)
			<= (reducedRadius and ENEMY_LOAD_RADIUS or LOAD_RADIUS)
		and dY >= 0
end

---@param transporterPosX number
---@param transporterPosY number
---@param transporterPosZ number
---@param goalX number
---@param goalY number
---@param goalZ number
---@return boolean inUnloadRange
local function inUnloadRange(transporterPosX, transporterPosY, transporterPosZ, goalX, goalY, goalZ)
	local dY = transporterPosY - goalY
	return dist2D(transporterPosX, transporterPosZ, goalX, goalZ) <= UNLOAD_RADIUS and dY >= 0
end

---@param cx number
---@param cz number
---@param radius number
---@param allyTeam number
---@return number[] units
local function getCachedUnitsInCylinder(cx, cz, radius, allyTeam)
	cz, cx, radius =
		math.floor(cz / CACHED_CYLINDER_UNITS_ROUNDING) * CACHED_CYLINDER_UNITS_ROUNDING,
		math.floor(cx / CACHED_CYLINDER_UNITS_ROUNDING) * CACHED_CYLINDER_UNITS_ROUNDING,
		math.ceil(radius / CACHED_CYLINDER_UNITS_ROUNDING) * CACHED_CYLINDER_UNITS_ROUNDING
	local key = allyTeam .. "," .. cx .. "," .. cz .. "," .. radius
	local cached = cylinderCache[key]
	local frame = math.floor(spGetGameFrame() / CACHED_CYLINDER_UNITS_LIFESPAN) * CACHED_CYLINDER_UNITS_LIFESPAN
	if cached and cached.frame == frame then
		return cached.units
	end
	local units = spGetUnitsInCylinder(cx, cz, radius, allyTeam)
	cylinderCache[key] = { frame = frame, units = units }
	return units
end

local function BuggerOff(x, y, z, padDefID, transporterID)
	local padSize = UnitDefs[padDefID].xsize * 8
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	local units = spGetUnitsInBox(x - padSize / 2, y - 50, z - padSize / 2, x + padSize / 2, y + 5, z + padSize / 2)
	for i = 1, #units do
		local unitID = units[i]
		local allyTeam = spGetUnitAllyTeam(unitID)
		if allyTeam == transporterAllyTeam then
			if unitID ~= transporterID then
				local unitX, unitY, unitZ = spGetUnitPosition(unitID)
				local dirX, dirY, dirZ = x - unitX, y - unitY, z - unitZ
				local length = math.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ)
				if length > 0 then
					dirX, dirY, dirZ = dirX / length, dirY / length, dirZ / length
				end
				spSetUnitMoveGoal(unitID, x - dirX * padSize, y, z - dirZ * padSize, 8)
			end
		else
		end
	end
end

---@param transporterID number
---@return nil
local function RemoveAreaLoadCoroutine(transporterID)
	local index = transporterCoroutines[transporterID] and transporterCoroutines[transporterID].index
	if not index then
		return spEcho("Error in RemoveAreaLoadCoroutine: no coroutine found for transporterID " .. transporterID)
	end
	areaLoadCoroutines[index] = nil
	transporterCoroutines[transporterID] = nil
end

---@param transporterID number
---@return nil
local function RemoveSuccessiveCoroutine(transporterID)
	local index = transporterCoroutines[transporterID] and transporterCoroutines[transporterID].index
	if not index then
		return spEcho("Error in RemoveSuccessiveCoroutine: no coroutine found for transporterID " .. transporterID)
	end
	successiveLoadCoroutines[index] = nil
	transporterCoroutines[transporterID] = nil
end

---@param passengerID number
---@param passengerDefID number
---@param passengerPosY number
---@param transporterID number
---@param transporterAllyTeam number  -- transporter allyTeam (not teamID!)
---@return boolean
local function CanBeTransportedStatic(passengerID, passengerDefID, transporterID)
	if not spValidUnitID(passengerID) then
		return false
	end
	if spGetUnitIsDead(passengerID) then
		return false
	end
	if passengerID == transporterID then
		return false
	end
	if UnitDefs[passengerDefID].cantBeTransported then
		return false
	end
	return true
end

---@param passengerID number
---@param passengerDefID number
---@param passengerPosY number
---@param transporterID number
---@param transporterAllyTeam number  -- transporter allyTeam (not teamID!)
---@return boolean
local function CanBeTransportedDynamic(
	passengerID,
	passengerDefID,
	passengerPosY,
	transporterID,
	transporterAllyTeam,
	transporterTeamID,
	passengerTeamID
)
	if not spValidUnitID(passengerID) then
		return false
	end
	if spGetUnitIsDead(passengerID) then
		return false
	end
	if spGetUnitTransporter(passengerID) ~= nil then
		return false
	end
	if spGetUnitIsBeingBuilt(passengerID) then
		return false
	end
	if isUnderwater(passengerID, passengerPosY) then
		return false
	end
	if spGetUnitRulesParam(passengerID, "inUnloadAnim") == 1 then
		return false
	end
	if (spGetUnitRulesParam(passengerID, "inLoadAnim") or 0) > 0 then
		return false
	end
	local allied = spAreTeamsAllied(passengerTeamID, transporterTeamID)
	if allied then
		return true
	end
	if ALLOW_ENEMY_LOAD_MODE == 1 then
		return false
	end
	local cantLoadAsEnemy = UnitDefs[passengerDefID].customParams.isCommander
		or UnitDefs[passengerDefID].transportByEnemy == false
	if cantLoadAsEnemy then
		return false
	end
	local losState = spGetUnitLosState(passengerID, transporterAllyTeam, false)
	if not losState or not (losState.los or losState.radar) then
		return false
	end
	return true
end

---@param passengerID number
---@param transporterAllyTeam number  -- transporter allyTeam (not teamID!)
---@return boolean
local function CanBeAutoClaimed(passengerID, transporterAllyTeam)
	if not spValidUnitID(passengerID) then
		return false
	end
	if spGetUnitIsDead(passengerID) then
		return false
	end
	if autoClaimBlackList[passengerID] then
		return false
	end
	return not claimedBy[transporterAllyTeam][passengerID]
end

local function SpawnWeakBeam(transporterID, passengerID, size)
	local spawnPosX, spawnPosY, spawnPosZ = spGetUnitPosition(passengerID)
	spawnPosY = spawnPosY + Spring.GetUnitHeight(passengerID)
	local dirPosX, dirPosY, dirPosZ = spGetUnitPosition(transporterID)
	local dirX, dirY, dirZ = dirPosX - spawnPosX, dirPosY - spawnPosY, dirPosZ - spawnPosZ
	Spring.SpawnCEG("tractorbeam_weak", spawnPosX, spawnPosY, spawnPosZ, dirX * size, dirY * size, dirZ * size, 1, 0)
end

---@param passengerID number
---@param passengerTeamID number  -- passenger teamID
---@param passengerPosX number
---@param passengerPosY number
---@param passengerPosZ number
---@param transporterID number
---@param transporterTeamID number  -- transporter teamID
---@param transporterPosX number
---@param transporterPosY number
---@param transporterPosZ number
---@return boolean
local function CanBeTransportedNow(
	passengerID,
	passengerTeamID,
	passengerPosX,
	passengerPosY,
	passengerPosZ,
	transporterID,
	transporterTeamID,
	transporterPosX,
	transporterPosY,
	transporterPosZ
)
	if spAreTeamsAllied(passengerTeamID, transporterTeamID) then
		return inLoadRange(
			transporterPosX,
			transporterPosY,
			transporterPosZ,
			passengerPosX,
			passengerPosY,
			passengerPosZ
		)
	end

	local isStunned = spGetUnitIsStunned(passengerID)
	if isStunned then
		return inLoadRange(
			transporterPosX,
			transporterPosY,
			transporterPosZ,
			passengerPosX,
			passengerPosY,
			passengerPosZ
		)
	end

	local useReducedRadius = ALLOW_ENEMY_LOAD_MODE >= 4
	if
		not inLoadRange(
			transporterPosX,
			transporterPosY,
			transporterPosZ,
			passengerPosX,
			passengerPosY,
			passengerPosZ,
			useReducedRadius
		)
	then
		if ALLOW_ENEMY_LOAD_MODE >= 3 then
			consecutiveFramesOverEnemyPassenger[transporterID][passengerID] = nil
		end
		return false
	end
	if ALLOW_ENEMY_LOAD_MODE >= 3 then
		local _, _, _, vw = spGetUnitVelocity(passengerID)
		if vw < 0.5 then
			consecutiveFramesOverEnemyPassenger[transporterID][passengerID] = (
				consecutiveFramesOverEnemyPassenger[transporterID][passengerID] or 0
			) + 1
			SpawnWeakBeam(
				transporterID,
				passengerID,
				consecutiveFramesOverEnemyPassenger[transporterID][passengerID] / MIN_CONSECUTIVE_FRAMES_TO_LOAD_ENEMY
			)
			if
				consecutiveFramesOverEnemyPassenger[transporterID][passengerID] > MIN_CONSECUTIVE_FRAMES_TO_LOAD_ENEMY
			then
				consecutiveFramesOverEnemyPassenger[transporterID][passengerID] = nil
				return true
			end
		else
			consecutiveFramesOverEnemyPassenger[transporterID][passengerID] = nil
		end
	end
	return false
end

---@param passengerID number
---@param passengerTeamID number  -- passenger teamID
---@param transporterID number
---@param transporterTeamID number  -- transporter teamID
---@return boolean
local function CanMoveToTransporter(passengerID, passengerTeamID, transporterID, transporterTeamID, posY)
	if posY < 0 then
		local passengerDefID = spGetUnitDefID(passengerID)
		local isHover = UnitDefs[passengerDefID].modCategories["hover"] == true
		if not isHover then
			return false
		end
	end
	if passengerTeamID == transporterTeamID then
		return true
	end
	if spAreTeamsAllied(passengerTeamID, transporterTeamID) then
		local hasQ = spGetUnitCommands(passengerID, 0) >= 1
		return not hasQ
	else
		return false
	end
end

---@param passengerID number
---@param transporterAllyTeam number  -- transporter allyTeam (not teamID!)
---@return nil
local function releasePassenger(passengerID, transporterAllyTeam)
	local transporterID = claimedBy[transporterAllyTeam][passengerID]
	if not transporterID then
		return
	end
	if ALLOW_ENEMY_LOAD_MODE >= 3 and consecutiveFramesOverEnemyPassenger[transporterID] then
		consecutiveFramesOverEnemyPassenger[transporterID][passengerID] = nil
	end
	claimedBy[transporterAllyTeam][passengerID] = nil
	if transporterClaims[transporterID] then
		local total = 0
		local resumeFrom = #transporterClaims[transporterID]
		for i = resumeFrom, 1, -1 do
			if transporterClaims[transporterID][i] == passengerID then
				table.remove(transporterClaims[transporterID], i)
				resumeFrom = i - 1
				break
			end
			total = total + (GetPassengerSize(transporterClaims[transporterID][i]) or 0)
		end
		if resumeFrom > 0 then
			for i = resumeFrom, 1, -1 do
				total = total + (GetPassengerSize(transporterClaims[transporterID][i]) or 0)
			end
		end
		queuedSeats[transporterID] = total
	else
		queuedSeats[transporterID] = 0
	end
end

---@param transporterID number
---@param passengerID number
---@param passengerSize number
---@param manualClaim boolean
---@return boolean claimSuccessful
local function claimPassenger(transporterID, passengerID, passengerSize, manualClaim)
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	if not manualClaim and claimedBy[transporterAllyTeam][passengerID] then
		return false
	end
	if claimedBy[transporterAllyTeam][passengerID] then
		releasePassenger(passengerID, transporterAllyTeam)
	end
	claimedBy[transporterAllyTeam][passengerID] = transporterID
	transporterClaims[transporterID][#transporterClaims[transporterID] + 1] = passengerID
	local total = 0
	local ct = 0
	for i = #transporterClaims[transporterID], 1, -1 do
		if transporterClaims[transporterID][i] == passengerID then
			ct = ct + 1
			if ct > 1 then
				spEcho(
					"Error: duplicate claim for passenger "
						.. passengerID
						.. " in transporter "
						.. transporterID
						.. "'s claims list"
				)
			end
		end
		total = total + (GetPassengerSize(transporterClaims[transporterID][i]) or 0)
	end
	queuedSeats[transporterID] = total
	return true
end

---@param transporterID number
---@return nil
local function releaseAllClaims(transporterID)
	local claims = transporterClaims[transporterID]
	if not claims then
		return
	end
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	for i = 1, #claims do
		local passengerID = claims[i]
		claimedBy[transporterAllyTeam][passengerID] = nil
	end
	if ALLOW_ENEMY_LOAD_MODE >= 3 and consecutiveFramesOverEnemyPassenger[transporterID] then
		consecutiveFramesOverEnemyPassenger[transporterID] = {}
	end
	transporterClaims[transporterID] = {}
	queuedSeats[transporterID] = 0
end

---@param transporterID number
---@param transporterDefID number
---@param transporterTeamID number  -- transporter teamID
---@param cx number
---@param cz number
---@param radius number
---@return number|nil bestUnit
local function findUnitToTransport(transporterID, transporterDefID, transporterTeamID, cx, cz, radius)
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	local transporterPosX, transporterPosY, transporterPosZ = spGetUnitPosition(transporterID)
	local units = getCachedUnitsInCylinder(cx, cz, radius, transporterAllyTeam)
	local unitsCount = #units
	local bestUnit = nil
	local bestDist = MAX_DIST_SQ
	if IsTransportFull(transporterID, queuedSeats[transporterID]) then
		return nil
	end
	if unitsCount == 0 then
		return nil
	end
	local w = 1
	for r = 1, unitsCount do
		local passengerID = units[r]
		repeat
			if not CanBeAutoClaimed(passengerID, transporterAllyTeam) then
				break
			end
			local passengerDefID = spGetUnitDefID(passengerID)
			local passengerTeamID = spGetUnitTeam(passengerID)
			local passengerSize = GetPassengerSize(passengerID)
			if not CanBeTransportedStatic(passengerID, passengerDefID, transporterID) then
				break
			end
			local passengerPosX, passengerPosY, passengerPosZ = spGetUnitPosition(passengerID)
			if
				not CanBeTransportedDynamic(
					passengerID,
					passengerDefID,
					passengerPosY,
					transporterID,
					transporterAllyTeam,
					transporterTeamID,
					passengerTeamID
				)
			then
				break
			end
			units[w] = passengerID
			w = w + 1
			if
				not CanPassengerFitInTransporter(
					transporterID,
					passengerID,
					transporterDefID,
					passengerSize,
					queuedSeats[transporterID]
				)
			then
				break
			end
			local dx, dz = passengerPosX - transporterPosX, passengerPosZ - transporterPosZ
			local rawDistSq = dx * dx + dz * dz
			local mDist = UnitDefs[passengerDefID].speed > 0 and 0 or MOBILITY_DIST
			local aDist = (passengerTeamID ~= transporterTeamID) and ALLIED_DIST or 0
			local unitDist = rawDistSq + aDist + mDist
			if unitDist >= bestDist then
				break
			end
			bestDist = unitDist
			bestUnit = passengerID
		until true
	end
	for j = w, unitsCount do
		units[j] = nil
	end
	return bestUnit
end

---@param transporterID number
---@param transporterDefID number
---@param transporterTeamID number  -- transporter teamID
---@param transporterPosX number
---@param transporterPosY number
---@param transporterPosZ number
---@param cx number
---@param cy number
---@param cz number
---@param radius number
---@return nil
local function ExecuteLoadUnits(
	transporterID,
	transporterDefID,
	transporterTeamID,
	transporterPosX,
	transporterPosY,
	transporterPosZ,
	cx,
	cy,
	cz,
	radius
)
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	for i = #transporterClaims[transporterID], 1, -1 do
		local passengerID = transporterClaims[transporterID][i]
		local passengerPosX, passengerPosY, passengerPosZ = spGetUnitPosition(passengerID)
		local passengerDefID = spGetUnitDefID(passengerID)
		local passengerTeamID = spGetUnitTeam(passengerID)
		local removalFlag = false
		local moveToTransporterFlag = false
		if claimedBy[transporterAllyTeam][passengerID] ~= transporterID then
			spEcho(
				"Error: claim inconsistency for passenger "
					.. passengerID
					.. " in transporter "
					.. transporterID
					.. "'s claims list"
			)
		end
		if
			not CanBeTransportedDynamic(
				passengerID,
				passengerDefID,
				passengerPosY,
				transporterID,
				transporterAllyTeam,
				transporterTeamID,
				passengerTeamID
			)
		then
			removalFlag = true
		end
		local passengerSize = GetPassengerSize(passengerID)
		if not CanPassengerFitInTransporter(transporterID, passengerID, transporterDefID, passengerSize, 0) then
			removalFlag = true
		end
		if removalFlag then
			releasePassenger(passengerID, transporterAllyTeam)
		elseif
			CanBeTransportedNow(
				passengerID,
				passengerTeamID,
				passengerPosX,
				passengerPosY,
				passengerPosZ,
				transporterID,
				transporterTeamID,
				transporterPosX,
				transporterPosY,
				transporterPosZ
			)
		then
			customTransportLoad[transporterDefID](transporterID, "PerformLoad", passengerID)
			removalFlag = true
		elseif
			dist2D(transporterPosX, transporterPosZ, cx, cz) < radius
			and CanMoveToTransporter(
				passengerID,
				passengerTeamID,
				transporterID,
				transporterTeamID,
				spGetGroundHeight(transporterPosX, transporterPosZ)
			)
		then
			moveToTransporterFlag = true
		end
		if moveToTransporterFlag then
			spSetUnitMoveGoal(
				passengerID,
				transporterPosX,
				spGetGroundHeight(transporterPosX, transporterPosZ),
				transporterPosZ,
				64,
				nil,
				true
			)
		end
		if removalFlag then
			releasePassenger(passengerID, transporterAllyTeam)
		end
	end

	if spValidUnitID(transporterClaims[transporterID][1]) then
		local passenger1 = transporterClaims[transporterID][1]
		local skipMoveGoal = ALLOW_ENEMY_LOAD_MODE >= 5
			and not spAreTeamsAllied(spGetUnitTeam(passenger1), transporterTeamID)
			and not spGetUnitIsStunned(passenger1)
		if not skipMoveGoal then
			local passenger1x, passenger1y, passenger1z = spGetUnitPosition(passenger1)
			spSetUnitMoveGoal(transporterID, passenger1x, passenger1y, passenger1z)
		end
	end
end

---@param transporterID number
---@param transporterDefID number
---@param transporterTeamID number  -- transporter teamID
---@param cx number
---@param cy number
---@param cz number
---@param radius number
---@return boolean commandFinished
local function ExecuteAreaLoad(transporterID, transporterDefID, transporterTeamID, cx, cy, cz, radius)
	local passengerID = findUnitToTransport(transporterID, transporterDefID, transporterTeamID, cx, cz, radius)

	while passengerID do
		claimPassenger(transporterID, passengerID, GetPassengerSize(passengerID), false)
		passengerID = findUnitToTransport(transporterID, transporterDefID, transporterTeamID, cx, cz, radius)
	end

	if queuedSeats[transporterID] == 0 then
		areaLoadCoroutines[transporterID] = nil
		local canUnload = spGetUnitRulesParam(transporterID, "canUnload") == 1
		if not canUnload then
			return false
		end
		return true
	end
	local transporterPosX, transporterPosY, transporterPosZ = spGetUnitPosition(transporterID)
	local distToArea = dist2D(transporterPosX, transporterPosZ, cx, cz)
	if distToArea < radius then
		ExecuteLoadUnits(
			transporterID,
			transporterDefID,
			transporterTeamID,
			transporterPosX,
			transporterPosY,
			transporterPosZ,
			cx,
			cy,
			cz,
			radius
		)
	else
		spSetUnitMoveGoal(transporterID, cx, cy, cz, 64)
	end
	return false
end

---@param transporterID number
---@param transporterDefID number
---@param transporterTeamID number  -- transporter teamID
---@return nil
local function ExecuteSuccessiveLoadUnits(transporterID, transporterDefID, transporterTeamID)
	local idsToRemove = {}
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)

	local queue = spGetUnitCommands(transporterID, spGetUnitRulesParam(transporterID, "transporterSeats"))
	local i = 1
	local cmd = queue and queue[i]
	if not IsTransportFull(transporterID, queuedSeats[transporterID]) then
		while cmd and cmd.id == CMD_LOAD_UNIT and not IsTransportFull(transporterID, queuedSeats[transporterID]) do
			local passengerID = cmd.params[1]
			local passengerTeamID = spGetUnitTeam(passengerID)
			local passengerDefID = spGetUnitDefID(passengerID)
			local _, passengerPosY = spGetUnitPosition(passengerID)
			if not CanBeTransportedStatic(passengerID, passengerDefID, transporterID) then
				idsToRemove[passengerID] = true
			elseif
				not CanBeTransportedDynamic(
					passengerID,
					passengerDefID,
					passengerPosY,
					transporterID,
					transporterAllyTeam,
					transporterTeamID,
					passengerTeamID
				)
			then
				idsToRemove[passengerID] = true
			elseif transporterID ~= claimedBy[transporterAllyTeam][passengerID] then
				claimPassenger(transporterID, passengerID, GetPassengerSize(passengerID), true)
			end
			i = i + 1
			cmd = queue and queue[i]
		end
	elseif IsTransportFull(transporterID, 0) then
		while cmd and cmd.id == CMD_LOAD_UNIT do
			local passengerID = cmd.params[1]
			idsToRemove[passengerID] = true
			i = i + 1
			cmd = queue and queue[i]
		end
	end

	local transporterPosX, transporterPosY, transporterPosZ = spGetUnitPosition(transporterID)
	for i = #transporterClaims[transporterID], 1, -1 do
		local passengerID = transporterClaims[transporterID][i]
		local passengerDefID = spGetUnitDefID(passengerID)
		local passengerPosX, passengerPosY, passengerPosZ = spGetUnitPosition(passengerID)
		local removalFlag = false
		local moveToTransporterFlag = false
		if claimedBy[transporterAllyTeam][passengerID] ~= transporterID then
			spEcho(
				"Error: claim inconsistency for passenger "
					.. passengerID
					.. " in transporter "
					.. transporterID
					.. "'s claims list"
			)
		end
		local passengerTeamID = spGetUnitTeam(passengerID)
		if
			not CanBeTransportedDynamic(
				passengerID,
				passengerDefID,
				passengerPosY,
				transporterID,
				transporterAllyTeam,
				transporterTeamID,
				passengerTeamID
			)
		then
			removalFlag = true
		end
		local passengerSize = GetPassengerSize(passengerID)
		if not CanPassengerFitInTransporter(transporterID, passengerID, transporterDefID, passengerSize, 0) then
			removalFlag = true
		end
		if removalFlag then
			idsToRemove[passengerID] = true
		elseif
			CanBeTransportedNow(
				passengerID,
				passengerTeamID,
				passengerPosX,
				passengerPosY,
				passengerPosZ,
				transporterID,
				transporterTeamID,
				transporterPosX,
				transporterPosY,
				transporterPosZ
			)
		then
			customTransportLoad[transporterDefID](transporterID, "PerformLoad", passengerID)
			removalFlag = true
		elseif
			dist2D(transporterPosX, transporterPosZ, passengerPosX, passengerPosZ) < 512
			and CanMoveToTransporter(
				passengerID,
				passengerTeamID,
				transporterID,
				transporterTeamID,
				spGetGroundHeight(transporterPosX, transporterPosZ)
			)
		then
			moveToTransporterFlag = true
		end
		if moveToTransporterFlag then
			spSetUnitMoveGoal(
				passengerID,
				transporterPosX,
				spGetGroundHeight(transporterPosX, transporterPosZ),
				transporterPosZ,
				64,
				nil,
				true
			)
		end
		if removalFlag then
			idsToRemove[passengerID] = true
		end
	end

	for passengerID, v in pairs(idsToRemove) do
		releasePassenger(passengerID, transporterAllyTeam)
		if (queue[2] and queue[2].id ~= CMD_LOAD_UNIT) or not queue[2] then
			local canUnload = spGetUnitRulesParam(transporterID, "canUnload") == 1
			if canUnload then
				spUnitFinishCommand(transporterID)
			end
		else
			for i = 1, #queue do
				if queue[i].id == CMD_LOAD_UNIT and queue[i].params[1] == passengerID then
					spGiveOrderToUnit(transporterID, CMD.REMOVE, { queue[i].tag }, 0)
					break
				end
			end
		end
	end
	if spValidUnitID(transporterClaims[transporterID][1]) then
		local passenger1 = transporterClaims[transporterID][1]
		local skipMoveGoal = ALLOW_ENEMY_LOAD_MODE >= 5
			and not spAreTeamsAllied(spGetUnitTeam(passenger1), transporterTeamID)
			and not spGetUnitIsStunned(passenger1)
		if not skipMoveGoal then
			local passenger1x, passenger1y, passenger1z = spGetUnitPosition(passenger1)
			spSetUnitMoveGoal(transporterID, passenger1x, passenger1y, passenger1z)
		end
	end
end

function gadget:Initialize()
	local AllUnits = spGetAllUnits()
	if #AllUnits > 0 then
		for i = 1, #AllUnits do
			local unitID = AllUnits[i]
			if spGetUnitRulesParam(unitID, "inUnloadAnim") == 1 then
				spEcho("Repairing unit " .. unitID .. " stuck in unload anim on gadget initialization")
				spMoveCtrlDisable(unitID, false)
				spSetUnitRulesParam(unitID, "inUnloadAnim", 0)
				EnablePassenger(unitID)
				local unitDefID = spGetUnitDefID(unitID)
				spSetUnitRadiusAndHeight(unitID, UnitDefs[unitDefID].radius, UnitDefs[unitDefID].height)
				local unitPosX, unitPosY, unitPosZ = spGetUnitPosition(unitID)
				spSetUnitPosition(unitID, unitPosX, spGetGroundHeight(unitPosX, unitPosZ), unitPosZ)
			end
			if (spGetUnitRulesParam(unitID, "inLoadAnim") or 0) > 0 then
				spEcho("Repairing unit " .. unitID .. " stuck in load anim on gadget initialization")
				EnablePassenger(unitID)
				spMoveCtrlDisable(unitID, false)
				spSetUnitRulesParam(unitID, "inLoadAnim", 0)
				local unitPosX, unitPosY, unitPosZ = spGetUnitPosition(unitID)
				spSetUnitPosition(unitID, unitPosX, spGetGroundHeight(unitPosX, unitPosZ), unitPosZ)
			end
			gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
		end
	end
	spSetCustomCommandDrawData(CMD_AREA_LOAD, CMD.LOAD_UNITS, { 0.6, 0.6, 1, 0.5 }, true)
	spSetCustomCommandDrawData(CMD_LOAD_UNIT, CMD.LOAD_UNITS, { 0.6, 0.6, 1, 0.5 }, true)
	gadgetHandler:RegisterAllowCommand(CMD.LOAD_UNITS)
	gadgetHandler:RegisterAllowCommand(CMD.LOAD_ONTO)
	gadgetHandler:RegisterAllowCommand(CMD.UNLOAD_UNIT)
	gadgetHandler:RegisterAllowCommand(CMD.UNLOAD_UNITS)
	local allyTeams = spGetAllyTeamList()
	for _, allyTeam in pairs(allyTeams) do
		claimedBy[allyTeam] = {}
	end

end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if customTransportLoad[unitDefID] == nil or customTransportUnload[unitDefID] == nil then
		customTransportLoad[unitDefID] = GetScriptFunc(unitID, "PerformLoad")
		customTransportUnload[unitDefID] = GetScriptFunc(unitID, "PerformUnload")
	end
	if isAirTransport[unitDefID] then
		if ALLOW_ENEMY_LOAD_MODE >= 3 then
			consecutiveFramesOverEnemyPassenger[unitID] = {}
		end
		transporterClaims[unitID] = {}
		queuedSeats[unitID] = 0
	end
	if autoClaimBlackListDefIDs[unitDefID] then
		autoClaimBlackList[unitID] = true
	end
end

function gadget:UnitCommand(
	unitID,
	unitDefID,
	unitTeam,
	cmdID,
	cmdParams,
	cmdOptions,
	cmdTag,
	playerID,
	fromSynced,
	fromLua
)
	if transporterClaims[unitID] then
		local cmds = spGetUnitCommands(unitID, 1)
		if not (cmds[1] and (cmds[1].id == CMD_AREA_LOAD or cmds[1].id == CMD.LOAD_UNITS)) then
			releaseAllClaims(unitID)
		end
	end
end

function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
	if transporterClaims[unitID] then
		local cmds = spGetUnitCommands(unitID, 1)
		if not (cmds[1] and (cmds[1].id == CMD_AREA_LOAD or cmds[1].id == CMD.LOAD_UNITS)) then
			releaseAllClaims(unitID)
		end
	end
end

function gadget:UnitGiven(unitID, unitDefID, oldTeam, newTeam)
	local transporterAllyTeam = spGetUnitAllyTeam(unitID)
	releasePassenger(unitID, transporterAllyTeam)
	releaseAllClaims(unitID)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local transporterAllyTeam = spGetUnitAllyTeam(unitID)
	releasePassenger(unitID, transporterAllyTeam)
	releaseAllClaims(unitID)
	local transporterID = spGetUnitTransporter(unitID)
	if not transporterID then
		return
	end
	local transporterDefID = spGetUnitDefID(transporterID)
	if customTransportUnload[transporterDefID] then
		local gx, gy, gz = spGetUnitPosition(transporterID)
		customTransportUnload[transporterDefID](transporterID, "PerformUnload", unitID, gx, gy, gz)
	end
	autoClaimBlackList[unitID] = nil
	if ALLOW_ENEMY_LOAD_MODE >= 3 then
		consecutiveFramesOverEnemyPassenger[unitID] = nil
	end
end

function gadget:GameFrame(frame)
	offset = 0
	for i = 1, areaLoadCoroutinesCount do
		local co = areaLoadCoroutines[i] and areaLoadCoroutines[i].co or nil
		if co then
			local transporterID = areaLoadCoroutines[i].transporterID
			local status = coroutine.status(co)
			if status == "suspended" then
				local ok, err = coroutine.resume(co)
				if not ok then
					spEcho("Error in CMD_AREA_LOAD coroutine for transporter " .. transporterID .. ": " .. err)
					RemoveAreaLoadCoroutine(transporterID)
				end
			else
				RemoveAreaLoadCoroutine(transporterID)
			end
		end
		while areaLoadCoroutines[i + offset] == nil and (i + offset) <= areaLoadCoroutinesCount do
			offset = offset + 1
		end
		areaLoadCoroutines[i] = areaLoadCoroutines[i + offset]
		if i + offset <= areaLoadCoroutinesCount then
			transporterCoroutines[areaLoadCoroutines[i + offset].transporterID].index = i
		end
	end
	areaLoadCoroutinesCount = areaLoadCoroutinesCount - offset
	offset = 0
	for i = 1, successiveLoadCoroutinesCount do
		local co = successiveLoadCoroutines[i] and successiveLoadCoroutines[i].co or nil
		if co then
			local transporterID = successiveLoadCoroutines[i].transporterID
			local status = coroutine.status(co)
			if status == "suspended" then
				local ok, err = coroutine.resume(co)
				if not ok then
					spEcho("Error in CMD_LOAD_UNIT coroutine for transporter " .. transporterID .. ": " .. err)
					RemoveSuccessiveCoroutine(transporterID)
				end
			else
				RemoveSuccessiveCoroutine(transporterID)
			end
		end
		while successiveLoadCoroutines[i + offset] == nil and (i + offset) <= successiveLoadCoroutinesCount do
			offset = offset + 1
		end
		successiveLoadCoroutines[i] = successiveLoadCoroutines[i + offset]
		if i + offset <= successiveLoadCoroutinesCount then
			transporterCoroutines[successiveLoadCoroutines[i + offset].transporterID].index = i
		end
	end
	successiveLoadCoroutinesCount = successiveLoadCoroutinesCount - offset
end

function gadget:CommandFallback(
	transporterID,
	transporterDefID,
	transporterTeamID,
	cmdID,
	cmdParams,
	cmdOptions,
	cmdTag
)
	if cmdID == CMD_LOAD_WAIT then
		local canUnload = spGetUnitRulesParam(transporterID, "canUnload") == 1
		if canUnload then
			return true, true
		else
			return true, false
		end
	end

	if cmdID == CMD_LOAD_UNIT then
		ExecuteSuccessiveLoadUnits(transporterID, transporterDefID, transporterTeamID)
		if not transporterCoroutines[transporterID] or transporterCoroutines[transporterID].type ~= "successive" then
			local co = coroutine.create(function()
				while true do
					coroutine.yield()
					local posX, posY, posZ = spGetUnitPosition(transporterID)
					local passengerPosX, passengerPosY, passengerPosZ = spGetUnitPosition(cmdParams[1])
					local disttoArea = dist2D(posX, posZ, passengerPosX, passengerPosZ)
					while (disttoArea > 1024) and (spGetGameFrame() % 15 ~= transporterID % 15) do
						coroutine.yield()
						posX, posY, posZ = spGetUnitPosition(transporterID)
						passengerPosX, passengerPosY, passengerPosZ = spGetUnitPosition(cmdParams[1])
						disttoArea = dist2D(posX, posZ, passengerPosX, passengerPosZ)
					end
					local Q = spGetUnitCommands(transporterID, 1)
					local cmd = Q and Q[1]
					if not (cmd and cmd.id == CMD_LOAD_UNIT) then
						RemoveSuccessiveCoroutine(transporterID)
						releaseAllClaims(transporterID)
						break
					end
					ExecuteSuccessiveLoadUnits(transporterID, transporterDefID, transporterTeamID)
				end
			end)
			if transporterCoroutines[transporterID] then
				RemoveAreaLoadCoroutine(transporterID)
			end
			successiveLoadCoroutinesCount = successiveLoadCoroutinesCount + 1
			successiveLoadCoroutines[successiveLoadCoroutinesCount] = { co = co, transporterID = transporterID }
			transporterCoroutines[transporterID] = { type = "successive", index = successiveLoadCoroutinesCount }
		end
		return true, false
	end
	if cmdID ~= CMD_AREA_LOAD then
		return false, false
	end
	local finished = ExecuteAreaLoad(
		transporterID,
		transporterDefID,
		transporterTeamID,
		cmdParams[1],
		cmdParams[2],
		cmdParams[3],
		cmdParams[4]
	)
	if finished and spGetUnitRulesParam(transporterID, "canLoad") == 0 then
		finished = false
	end
	if not finished then
		if not transporterCoroutines[transporterID] or transporterCoroutines[transporterID].type ~= "area" then
			local cx, cy, cz, radius = cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4]
			local co = coroutine.create(function()
				while true do
					coroutine.yield()
					coroutine.lastKnownParams = { cx, cy, cz, radius }
					local posX, posY, posZ = spGetUnitPosition(transporterID)
					local disttoArea = dist2D(posX, posZ, cx, cz)
					while (disttoArea > 2 * radius) and (spGetGameFrame() % 15 ~= transporterID % 15) do
						coroutine.yield()
						posX, posY, posZ = spGetUnitPosition(transporterID)
						disttoArea = dist2D(posX, posZ, cx, cz)
					end
					local Q = spGetUnitCommands(transporterID, 1)
					local cmd = Q and Q[1]
					if not (cmd and cmd.id == CMD_AREA_LOAD) then
						RemoveAreaLoadCoroutine(transporterID)
						releaseAllClaims(transporterID)
						break
					elseif
						coroutine.lastKnownParams[1] ~= cmd.params[1]
						or coroutine.lastKnownParams[2] ~= cmd.params[2]
						or coroutine.lastKnownParams[3] ~= cmd.params[3]
						or coroutine.lastKnownParams[4] ~= cmd.params[4]
					then
						releaseAllClaims(transporterID)
						coroutine.lastKnownParams = cmd.params
						cx, cy, cz, radius = cmd.params[1], cmd.params[2], cmd.params[3], cmd.params[4]
					end
					ExecuteAreaLoad(transporterID, transporterDefID, transporterTeamID, cx, cy, cz, radius)
				end
			end)
			if transporterCoroutines[transporterID] then
				RemoveSuccessiveCoroutine(transporterID)
			end
			areaLoadCoroutinesCount = areaLoadCoroutinesCount + 1
			areaLoadCoroutines[areaLoadCoroutinesCount] = { co = co, transporterID = transporterID }
			transporterCoroutines[transporterID] = { type = "area", index = areaLoadCoroutinesCount }
		end
		return true, false
	end
	return true, true
end

function gadget:AllowUnitTransport(
	transporterID,
	transporterDefID,
	transporterTeamID,
	passengerID,
	passengerDefID,
	passengerTeamID
)
	if spGetUnitRulesParam(passengerID, "inLoadAnim") == transporterID then
		return true
	end
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	local passengerPosX, passengerPosY, passengerPosZ = spGetUnitPosition(passengerID)
	return CanBeTransportedStatic(passengerID, passengerDefID, transporterID)
		and CanBeTransportedDynamic(
			passengerID,
			passengerDefID,
			passengerPosY,
			transporterID,
			transporterAllyTeam,
			transporterTeamID,
			passengerTeamID
		)
		and CanPassengerFitInTransporter(transporterID, passengerID, transporterDefID, GetPassengerSize(passengerID), 0)
end

function gadget:AllowUnitTransportUnload(
	transporterID,
	transporterDefID,
	transporterTeamID,
	passengerID,
	passengerDefID,
	passengerTeamID,
	goalX,
	goalY,
	goalZ
)
	if isUnderwater(passengerID, goalY) then
		return false
	end
	if not isAirTransport[transporterDefID] then
		return true
	end

	local transporterPosX, transporterPosY, transporterPosZ = spGetUnitPosition(transporterID)
	local unloadPadType = GetUnloadPadType(transporterID)
	local blocked = spTestBuildOrder(unloadPadType, goalX, goalY, goalZ, 0)
	if blocked == 0 then
		goalX, goalY, goalZ = spClosestBuildPos(transporterTeamID, unloadPadType, goalX, goalY, goalZ, 512, 0, 0)
		if not goalX then
			spEcho(
				"Error: no valid unload position found near target point for transporter "
					.. transporterID
					.. ", aborting unload"
			)
			return false
		end
	end
	blocked = spTestBuildOrder(unloadPadType, goalX, goalY, goalZ, 0)
	if blocked == 1 then
		BuggerOff(goalX, goalY, goalZ, unloadPadType, transporterID)
	elseif blocked == 3 then
	end

	if not inUnloadRange(transporterPosX, transporterPosY, transporterPosZ, goalX, goalY, goalZ) then
		spSetUnitMoveGoal(transporterID, goalX, goalY, goalZ)
		return false
	end

	if customTransportUnload[transporterDefID] then
		if spGetUnitRulesParam(transporterID, "canUnload") == 0 then
			spSetUnitMoveGoal(transporterID, goalX, goalY, goalZ)
			return false
		end
		local targets = GetUnloadTargets(transporterID, passengerID, goalX, goalY, goalZ)
		for i = 1, #targets do
			customTransportUnload[transporterDefID](transporterID, "PerformUnload", targets[i], goalX, goalY, goalZ)
		end
		spSetUnitMoveGoal(transporterID, goalX, goalY, goalZ)
		spUnitFinishCommand(transporterID)
		return false
	end

	return true
end

function gadget:AllowCommand(
	unitID,
	unitDefID,
	unitTeam,
	cmdID,
	cmdParams,
	cmdOptions,
	cmdTag,
	playerID,
	fromSynced,
	fromLua,
	fromInsert
)
	if cmdID == CMD.LOAD_ONTO then
		if fromInsert then
			spEcho(
				"Warning: CMD_LOAD_ONTO is deprecated and will be removed in a future update; this command will be ignored"
			)
			return false
		end
		spEcho(
			"Warning: CMD_LOAD_ONTO is deprecated and will be removed in a future update; use CMD.INSERT + CMD_LOAD_UNIT instead"
		)
		spGiveOrderToUnit(cmdParams[1], CMD.INSERT, { 0, CMD_LOAD_UNIT, 0, unitID }, { "alt" })
		return false
	end
	if not isAirTransport[unitDefID] then
		return true
	end

	if cmdID == CMD.LOAD_UNITS then
		if #cmdParams == 4 then
			reissueOrder(unitID, CMD_AREA_LOAD, cmdParams, cmdOptions, cmdTag, fromInsert)
		elseif #cmdParams == 1 then
			reissueOrder(unitID, CMD_LOAD_UNIT, cmdParams, cmdOptions, cmdTag, fromInsert)
		end
		return false
	end

	if cmdID == CMD.UNLOAD_UNIT then
		local transportedUnits = spGetUnitIsTransporting(unitID)
		local posX, posY, posZ = cmdParams[1], cmdParams[2], cmdParams[3]
		if not spValidUnitID(cmdParams[4]) then
			cmdParams[4] = nil
		end
		local needsShift = false
		local needsWaitStance = false
		local hasShift = cmdOptions.shift == true
		if #transportedUnits == 0 then
			local Q = spGetUnitCommands(unitID, 2)
			local queueEmpty = not Q or #Q == 0
			local inWaitStance = Q
				and Q[1]
				and (Q[1].id == CMD_AREA_LOAD or Q[1].id == CMD_LOAD_UNIT or Q[1].id == CMD_LOAD_WAIT)
			local hasMoreCommands = #Q > 1
			needsWaitStance = (queueEmpty or not hasShift) and not (inWaitStance and not hasMoreCommands)
			needsShift = needsWaitStance or (inWaitStance and not hasMoreCommands)
			if needsWaitStance then
				spGiveOrderToUnit(unitID, CMD_LOAD_WAIT, { posX, posY, posZ }, { "" })
			end
			needsShift = needsShift and not hasShift
			if needsShift then
				cmdOptions.shift = true
				cmdOptions.coded = cmdOptions.coded + CMD.OPT_SHIFT
			end
		end

		local newPosX, newPosY, newPosZ =
			spClosestBuildPos(unitTeam, GetUnloadPadType(unitID, cmdParams[4]), posX, posY, posZ, 512, 0, 0)
		if newPosX ~= posX or newPosY ~= posY or newPosZ ~= posZ then
			cmdParams[1], cmdParams[2], cmdParams[3] = newPosX, newPosY, newPosZ
			reissueOrder(unitID, CMD.UNLOAD_UNIT, cmdParams, cmdOptions, cmdTag, fromInsert)
			return false
		end

		if needsShift then
			reissueOrder(unitID, CMD.UNLOAD_UNIT, cmdParams, cmdOptions, cmdTag, fromInsert)
			return false
		end

		return true
	end

	if cmdID == CMD.UNLOAD_UNITS then
		if cmdParams[4] then
			spEcho("Warning: CMD.UNLOAD_UNITS areas deprecated, replacing with single point CMD.UNLOAD_UNIT command")
		end
		local posX, posY, posZ = cmdParams[1], cmdParams[2], cmdParams[3]
		local newPosX, newPosY, newPosZ =
			spClosestBuildPos(unitTeam, GetUnloadPadType(unitID), posX, posY, posZ, 512, 0, 0)
		if newPosX ~= posX or newPosY ~= posY or newPosZ ~= posZ then
			cmdParams[1], cmdParams[2], cmdParams[3] = newPosX, newPosY, newPosZ
			cmdParams[4] = nil
			cmdParams[5] = nil
			reissueOrder(unitID, CMD.UNLOAD_UNIT, cmdParams, cmdOptions, cmdTag, fromInsert)
		end
		return false
	end
	return true, true
end
