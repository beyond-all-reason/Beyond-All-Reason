local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Transport Handler",
		desc = "Main handler for tractor beam transports",
		author = "DoodVanDaag",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1, -- must be > 0 (unit_script.lua is layer 0) so LUS environments are ready when UnitCreated fires
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

if Spring.GetModOptions().beta_tractorbeam == "disabled" then
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

-- TRANSPORTAPI LOCALS
local GetPassengerSize = TransportAPI.GetPassengerSize
local EnablePassenger = TransportAPI.EnablePassenger
local IsTransportFull = TransportAPI.IsTransportFull
local CanPassengerFitInTransporter = TransportAPI.CanPassengerFitInTransporter
local GetUnloadPadType = TransportAPI.GetUnloadPadType
local GetUnloadTargets = TransportAPI.GetUnloadTargets

-- SPRING API LOCALS
local distance2d = math.distance2d
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
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spGetUnitCmdDescs = Spring.GetUnitCmdDescs ---@type fun(unitID: integer, first: integer?, last: integer?): table[]
local spGetUnitsInBox = Spring.GetUnitsInBox
local reissueOrder = Game.Commands.ReissueOrder
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting

-- CUSTOM SETTINGS
local LOAD_RADIUS = tractorbeamDefs.LOAD_RADIUS or 128 -- elmos XZ; transporter must be within this range to fire PerformLoad
local UNLOAD_RADIUS = tractorbeamDefs.UNLOAD_RADIUS or 32 -- elmos XZ; transporter must be within this range to fire PerformUnload
local CMD_AREA_LOAD = GameCMD.TRANSPORT_AREA_LOAD
local CMD_LOAD_UNIT = GameCMD.TRANSPORT_LOAD_UNIT
local CMD_LOAD_WAIT = GameCMD.TRANSPORT_LOAD_WAIT
local CACHED_CYLINDER_UNITS_LIFESPAN = 1 -- frames
local CACHED_CYLINDER_UNITS_ROUNDING = 16 -- rounds position and radius to nearest multiple of this to reduce cache misses
-- enemies: 1 never, 2 stunned only, 3 also unstunned ones barely moving under the transport for
-- MIN_CONSECUTIVE_FRAMES_TO_LOAD_ENEMY frames, 4 as 3 within ENEMY_LOAD_RADIUS, 5 as 4 without chasing them
local ALLOW_ENEMY_LOAD_MODE = tractorbeamDefs.ALLOW_ENEMY_LOAD_MODE or 2
local ENEMY_LOAD_RADIUS_MULTIPLIER = tractorbeamDefs.ENEMY_LOAD_RADIUS_MULTIPLIER or 0.5 -- of LOAD_RADIUS (modes 4-5)
local MIN_CONSECUTIVE_FRAMES_TO_LOAD_ENEMY = tractorbeamDefs.MIN_CONSECUTIVE_FRAMES_TO_LOAD_ENEMY or 60 -- modes 3-5

-- CONSTANTS
local MAP_SIZE_X = Game.mapSizeX
local MAP_SIZE_Z = Game.mapSizeZ
local MOBILITY_DIST = MAP_SIZE_X * MAP_SIZE_Z -- priority offset: mobile < immobile
local ALLIED_DIST = 2 * MOBILITY_DIST -- priority offset: own team < allied < enemy
local ENEMY_DIST = 2 * ALLIED_DIST
local MAX_DIST_SQ = 2 * ENEMY_DIST -- guaranteed > any real sq distance on the map
local ENEMY_LOAD_RADIUS = LOAD_RADIUS * ENEMY_LOAD_RADIUS_MULTIPLIER

-- VARS
local customTransportLoad = {} -- transporterDefID → LUS function or COB script function
local customTransportUnload = {} -- transporterDefID → LUS function or COB script function
---@type table<AllyTeamID, table<UnitID, UnitID?>>
local claimedBy = {} -- allyTeam → passengerID → transporterID
---@type table<UnitID, number>
local queuedSeats = {} -- transporterID → number seats
---@type table<UnitID, UnitID[]>
local transporterClaims = {} -- transporterID → { passengerID, passengerID, ... }
---@type table<integer, {co: thread?, transporterID: UnitID}>
local areaLoadCoroutines = {} -- index → { co, transporterID }
---@type table<integer, {co: thread?, transporterID: UnitID}>
local successiveLoadCoroutines = {} -- index → { co, transporterID }
---@type table<string, {frame: number, units: UnitID[]}>
local cylinderCache = {}
local isAirTransport = {} -- transporterDefID → bool;
local offset = 0 -- reusable offset for coroutines cleanup in GameFrame
local areaLoadCoroutinesCount = 0
local successiveLoadCoroutinesCount = 0
local transporterCoroutines = {} -- transporterID → { type = "area" or "successive", index = number }
---@type table<UnitID, table<UnitID, number>>
local consecutiveFramesOverEnemyPassenger = {} -- transporterID → { passengerID → number frames }; populated for modes 3-5

---@type table<UnitID, UnitID>
local boardingOrder = {} -- passengerID → transporterID its player sent it to board

---@type table<UnitID, table<UnitID, true>>
local droppedBy = {} -- transporterID → passengers it set down in its current run of unloads

for udefID, def in ipairs(UnitDefs) do
	if def.canFly and def.isTransport then
		isAirTransport[udefID] = true
	end
end

local STATE_COMMANDS = {
	[CMD.FIRE_STATE] = true,
	[CMD.MOVE_STATE] = true,
	[CMD.REPEAT] = true,
	[CMD.ONOFF] = true,
	[CMD.CLOAK] = true,
	[CMD.TRAJECTORY] = true,
	[CMD.IDLEMODE] = true,
}

-- INTERNAL FUNCTIONS

---@param unitID UnitID
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

---@param passengerID UnitID
---@param y number
---@return boolean isUnderwater
local function isUnderwater(passengerID, y)
	local height = spGetUnitHeight(passengerID)
	return not height or y + height < 0
end

-- a state toggle is not an order: it leaves a unit on its way
---@param unitID UnitID
---@param cmdID integer
---@return boolean
local function isStateCommand(unitID, cmdID)
	if STATE_COMMANDS[cmdID] then
		return true
	end
	local index = spFindUnitCmdDesc(unitID, cmdID)
	local desc = index and spGetUnitCmdDescs(unitID, index, index)[1]
	return desc ~= nil and desc.type == CMDTYPE.ICON_MODE
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
	return distance2d(transporterPosX, transporterPosZ, goalX, goalZ)
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
	return distance2d(transporterPosX, transporterPosZ, goalX, goalZ) <= UNLOAD_RADIUS and dY >= 0
end

---@param cx number
---@param cz number
---@param radius number
---@param allyTeam integer
---@param withEnemies boolean? every unit in the cylinder, not only the ally team's
---@return UnitID[] units
local function getCachedUnitsInCylinder(cx, cz, radius, allyTeam, withEnemies)
	cz, cx, radius =
		math.floor(cz / CACHED_CYLINDER_UNITS_ROUNDING) * CACHED_CYLINDER_UNITS_ROUNDING,
		math.floor(cx / CACHED_CYLINDER_UNITS_ROUNDING) * CACHED_CYLINDER_UNITS_ROUNDING,
		math.ceil(radius / CACHED_CYLINDER_UNITS_ROUNDING) * CACHED_CYLINDER_UNITS_ROUNDING
	local key = allyTeam .. "," .. cx .. "," .. cz .. "," .. radius .. (withEnemies and ",all" or "")
	local cached = cylinderCache[key]
	local frame = math.floor(spGetGameFrame() / CACHED_CYLINDER_UNITS_LIFESPAN) * CACHED_CYLINDER_UNITS_LIFESPAN
	if cached and cached.frame == frame then
		return cached.units
	end
	local units = withEnemies and spGetUnitsInCylinder(cx, cz, radius) or spGetUnitsInCylinder(cx, cz, radius, allyTeam)
	cylinderCache[key] = { frame = frame, units = units }
	return units
end

-- moves allied units off the pad, except the ones this transport just set down
---@param padDefID UnitDefID
---@param transporterID UnitID
local function BuggerOff(x, y, z, padDefID, transporterID)
	local padSize = UnitDefs[padDefID].xsize * 8
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	local dropped = droppedBy[transporterID]
	local units = spGetUnitsInBox(x - padSize / 2, y - 50, z - padSize / 2, x + padSize / 2, y + 5, z + padSize / 2)
	for i = 1, #units do
		local unitID = units[i]
		local allyTeam = spGetUnitAllyTeam(unitID)
		if allyTeam == transporterAllyTeam and unitID ~= transporterID and not (dropped and dropped[unitID]) then
			local unitX, unitY, unitZ = spGetUnitPosition(unitID)
			---@cast unitX -?
			local dirX, dirY, dirZ = x - unitX, y - unitY, z - unitZ
			local length = math.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ)
			if length > 0 then
				dirX, dirY, dirZ = dirX / length, dirY / length, dirZ / length
			end
			spSetUnitMoveGoal(unitID, x - dirX * padSize, y, z - dirZ * padSize, 8)
		end
	end
end

-- CORE LOGIC FUNCTIONS

---@param transporterID UnitID
---@return nil
local function RemoveAreaLoadCoroutine(transporterID)
	local index = transporterCoroutines[transporterID] and transporterCoroutines[transporterID].index
	if not index then
		return spEcho("Error in RemoveAreaLoadCoroutine: no coroutine found for transporterID " .. transporterID)
	end
	areaLoadCoroutines[index] = nil
	transporterCoroutines[transporterID] = nil
end

---@param transporterID UnitID
---@return nil
local function RemoveSuccessiveCoroutine(transporterID)
	local index = transporterCoroutines[transporterID] and transporterCoroutines[transporterID].index
	if not index then
		return spEcho("Error in RemoveSuccessiveCoroutine: no coroutine found for transporterID " .. transporterID)
	end
	successiveLoadCoroutines[index] = nil
	transporterCoroutines[transporterID] = nil
end

---@param passengerID UnitID
---@param passengerDefID UnitDefID?
---@param transporterID UnitID
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

---@param passengerID UnitID
---@param passengerDefID UnitDefID?
---@param passengerPosY number?
---@param transporterID UnitID
---@param transporterAllyTeam AllyTeamID
---@param transporterTeamID TeamID
---@param passengerTeamID TeamID?
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
	---@cast passengerPosY -?
	---@cast passengerTeamID -?
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
	local cantLoadAsEnemy = UnitDefs[passengerDefID].customParams.iscommander
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

---@param passengerID UnitID
---@param transporterAllyTeam AllyTeamID
---@return boolean
local function CanBeAutoClaimed(passengerID, transporterAllyTeam)
	if not spValidUnitID(passengerID) then
		return false
	end
	if spGetUnitIsDead(passengerID) then
		return false
	end
	return not claimedBy[transporterAllyTeam][passengerID]
end

-- cosmetic: a faint beam while an enemy's load countdown runs
---@param transporterID UnitID
---@param passengerID UnitID
---@param size number
local function SpawnWeakBeam(transporterID, passengerID, size)
	local spawnPosX, spawnPosY, spawnPosZ = spGetUnitPosition(passengerID)
	local height = Spring.GetUnitHeight(passengerID)
	---@cast spawnPosX -?
	---@cast height -?
	spawnPosY = spawnPosY + height
	local dirPosX, dirPosY, dirPosZ = spGetUnitPosition(transporterID)
	---@cast dirPosX -?
	local dirX, dirY, dirZ = dirPosX - spawnPosX, dirPosY - spawnPosY, dirPosZ - spawnPosZ
	Spring.SpawnCEG("tractorbeam_weak", spawnPosX, spawnPosY, spawnPosZ, dirX * size, dirY * size, dirZ * size, 1, 0)
end

-- not in range yet: the unit stays queued
---@param passengerID UnitID
---@param passengerTeamID TeamID?
---@param passengerPosX number?
---@param passengerPosY number?
---@param passengerPosZ number?
---@param transporterID UnitID
---@param transporterTeamID TeamID
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
	---@cast passengerTeamID -?
	---@cast passengerPosX -?
	---@cast passengerPosY -?
	---@cast passengerPosZ -?
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
		) -- stunned enemy treated as neutral; full LOAD_RADIUS applies
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

-- only a passenger its player sent to this transporter walks to it, once its own orders are done
---@param passengerID UnitID
---@param transporterID UnitID
---@param posY number ground height under the transporter
---@return boolean
local function CanMoveToTransporter(passengerID, transporterID, posY)
	if boardingOrder[passengerID] ~= transporterID then
		return false
	end
	if posY < 0 then
		local passengerDefID = spGetUnitDefID(passengerID)
		local isHover = UnitDefs[passengerDefID].modCategories["hover"] == true
		if not isHover then
			return false
		end
	end
	return spGetUnitCommands(passengerID, 0) == 0
end

---@param transporterID UnitID
local function clearBoarding(transporterID)
	for passengerID, boardedID in pairs(boardingOrder) do
		if boardedID == transporterID then
			boardingOrder[passengerID] = nil
		end
	end
end

-- an enemy an area load may pick: stunned, or any once hovering over one is enough to lift it
---@param passengerID UnitID
local function EnemyLoadable(passengerID)
	return ALLOW_ENEMY_LOAD_MODE > 2 or spGetUnitIsStunned(passengerID) == true
end

-- claims readable by allies: the load preview draws which transport picks which unit
local ALLIED_READ = { allied = true }
local function publishClaim(passengerID, transporterID)
	if spValidUnitID(passengerID) then
		spSetUnitRulesParam(passengerID, "transportClaimedBy", transporterID or 0, ALLIED_READ)
	end
end
local function publishClaimedSeats(transporterID)
	if spValidUnitID(transporterID) then
		spSetUnitRulesParam(transporterID, "transporterClaimedSeats", queuedSeats[transporterID] or 0, ALLIED_READ)
	end
end

---@param passengerID UnitID
---@param transporterAllyTeam AllyTeamID
---@return nil
local function releasePassenger(passengerID, transporterAllyTeam)
	local transporterID = claimedBy[transporterAllyTeam][passengerID]
	if not transporterID then
		return
	end
	if boardingOrder[passengerID] == transporterID then
		boardingOrder[passengerID] = nil
	end
	if ALLOW_ENEMY_LOAD_MODE >= 3 and consecutiveFramesOverEnemyPassenger[transporterID] then
		consecutiveFramesOverEnemyPassenger[transporterID][passengerID] = nil
	end
	claimedBy[transporterAllyTeam][passengerID] = nil
	if transporterClaims[transporterID] ~= nil then
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
	publishClaim(passengerID, nil)
	publishClaimedSeats(transporterID)
end

---@param transporterID UnitID
---@param passengerID UnitID
---@param passengerSize number
---@param manualClaim boolean
---@return boolean claimSuccessful
local function claimPassenger(transporterID, passengerID, passengerSize, manualClaim)
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	---@cast transporterAllyTeam -?
	if not manualClaim and claimedBy[transporterAllyTeam][passengerID] then
		return false
	end
	if claimedBy[transporterAllyTeam][passengerID] then
		releasePassenger(passengerID, transporterAllyTeam)
	end
	claimedBy[transporterAllyTeam][passengerID] = transporterID
	transporterClaims[transporterID][#transporterClaims[transporterID] + 1] = passengerID
	local total = 0
	for i = #transporterClaims[transporterID], 1, -1 do
		total = total + (GetPassengerSize(transporterClaims[transporterID][i]) or 0)
	end
	queuedSeats[transporterID] = total
	publishClaim(passengerID, transporterID)
	publishClaimedSeats(transporterID)
	return true
end

---@param transporterID UnitID
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
		publishClaim(passengerID, nil)
	end
	if ALLOW_ENEMY_LOAD_MODE >= 3 and consecutiveFramesOverEnemyPassenger[transporterID] then
		consecutiveFramesOverEnemyPassenger[transporterID] = {}
	end
	transporterClaims[transporterID] = {}
	queuedSeats[transporterID] = 0
	publishClaimedSeats(transporterID)
end

-- closest first; mobile before immobile, own before allied before enemy (the *_DIST offsets)
---@param transporterID UnitID
---@param transporterTeamID TeamID
---@param cx number
---@param cz number
---@param radius number
---@return UnitID|nil bestUnit
local function findUnitToTransport(transporterID, transporterTeamID, cx, cz, radius)
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	---@cast transporterAllyTeam -?
	local transporterPosX, transporterPosY, transporterPosZ = spGetUnitPosition(transporterID)
	---@cast transporterPosX -?
	local units = getCachedUnitsInCylinder(cx, cz, radius, transporterAllyTeam, ALLOW_ENEMY_LOAD_MODE > 1)
	local unitsCount = #units
	local bestUnit = nil
	local bestDist = MAX_DIST_SQ ---@type number
	if IsTransportFull(transporterID, queuedSeats[transporterID]) then
		return nil
	end
	if unitsCount == 0 then
		return nil
	end
	local w = 1
	for r = 1, unitsCount do
		local passengerID = units[r] ---@as UnitID
		repeat
			if not CanBeAutoClaimed(passengerID, transporterAllyTeam) then
				break
			end
			local passengerDefID = spGetUnitDefID(passengerID)
			local passengerTeamID = spGetUnitTeam(passengerID)
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
			---@cast passengerPosX -?
			---@cast passengerTeamID -?
			local allied = spAreTeamsAllied(passengerTeamID, transporterTeamID)
			if not allied and not EnemyLoadable(passengerID) then
				break
			end
			units[w] = passengerID
			w = w + 1
			if not CanPassengerFitInTransporter(transporterID, passengerID, queuedSeats[transporterID]) then
				break
			end
			local dx, dz = passengerPosX - transporterPosX, passengerPosZ - transporterPosZ
			local rawDistSq = dx * dx + dz * dz
			local mDist = UnitDefs[passengerDefID].speed > 0 and 0 or MOBILITY_DIST
			local aDist = (passengerTeamID == transporterTeamID and 0) or (allied and ALLIED_DIST) or ENEMY_DIST
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

---@param transporterID UnitID
---@param transporterDefID UnitDefID
---@param transporterTeamID TeamID
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
	---@cast transporterAllyTeam -?
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
		if not CanPassengerFitInTransporter(transporterID, passengerID, 0) then
			removalFlag = true
		end
		-- an enemy the area picked that can no longer be lifted
		if
			not removalFlag
			and not spAreTeamsAllied(passengerTeamID --[[@as TeamID]], transporterTeamID)
			and not EnemyLoadable(passengerID)
		then
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
			CanMoveToTransporter(passengerID, transporterID, spGetGroundHeight(transporterPosX, transporterPosZ))
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

	local passenger1 = transporterClaims[transporterID][1]
	if passenger1 and spValidUnitID(passenger1) then
		local skipMoveGoal = ALLOW_ENEMY_LOAD_MODE >= 5
			and not spAreTeamsAllied(spGetUnitTeam(passenger1) --[[@as TeamID]], transporterTeamID)
			and not spGetUnitIsStunned(passenger1)
		if not skipMoveGoal then
			local passenger1x, passenger1y, passenger1z = spGetUnitPosition(passenger1)
			---@cast passenger1x -?
			spSetUnitMoveGoal(transporterID, passenger1x, passenger1y, passenger1z)
		end
	end
end

---@param transporterID UnitID
---@param transporterDefID UnitDefID
---@param transporterTeamID TeamID
---@param cx number
---@param cy number
---@param cz number
---@param radius number
---@return boolean commandFinished
local function ExecuteAreaLoad(transporterID, transporterDefID, transporterTeamID, cx, cy, cz, radius)
	local passengerID = findUnitToTransport(transporterID, transporterTeamID, cx, cz, radius)

	while passengerID do
		claimPassenger(transporterID, passengerID, GetPassengerSize(passengerID), false)
		passengerID = findUnitToTransport(transporterID, transporterTeamID, cx, cz, radius)
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
	---@cast transporterPosX -?
	local distToArea = distance2d(transporterPosX, transporterPosZ, cx, cz)
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

---@param transporterID UnitID
---@param transporterDefID UnitDefID
---@param transporterTeamID TeamID
---@return nil
local function ExecuteSuccessiveLoadUnits(transporterID, transporterDefID, transporterTeamID)
	local idsToRemove = {} ---@type table<UnitID, true>
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	---@cast transporterAllyTeam -?

	-- 1: Get current queue, remove invalid units, claim valid ones
	local seats = spGetUnitRulesParam(transporterID, "transporterSeats")
	---@cast seats integer
	local queue = spGetUnitCommands(transporterID, seats)
	local i = 1
	local cmd = queue and queue[i]
	if not IsTransportFull(transporterID, queuedSeats[transporterID]) then
		while cmd and cmd.id == CMD_LOAD_UNIT and not IsTransportFull(transporterID, queuedSeats[transporterID]) do
			---@cast cmd.params -?
			local passengerID = cmd.params[1] ---@as UnitID
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
			---@cast cmd.params -?
			local passengerID = cmd.params[1] ---@as UnitID
			idsToRemove[passengerID] = true
			i = i + 1
			cmd = queue and queue[i]
		end
	end

	-- 2: proceed to loading all units in queue
	local transporterPosX, transporterPosY, transporterPosZ = spGetUnitPosition(transporterID)
	---@cast transporterPosX -?
	for i = #transporterClaims[transporterID], 1, -1 do
		local passengerID = transporterClaims[transporterID][i]
		local passengerDefID = spGetUnitDefID(passengerID)
		local passengerPosX, passengerPosY, passengerPosZ = spGetUnitPosition(passengerID)
		---@cast passengerPosX -?
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
		if not CanPassengerFitInTransporter(transporterID, passengerID, 0) then
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
			CanMoveToTransporter(passengerID, transporterID, spGetGroundHeight(transporterPosX, transporterPosZ))
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
				local queued = queue[i]
				---@cast queued.params -?
				if queued.id == CMD_LOAD_UNIT and queued.params[1] == passengerID then
					spGiveOrderToUnit(transporterID, CMD.REMOVE, { queued.tag }, 0)
					break
				end
			end
		end
	end
	local passenger1 = transporterClaims[transporterID][1]
	if passenger1 and spValidUnitID(passenger1) then --it could have been loaded
		local skipMoveGoal = ALLOW_ENEMY_LOAD_MODE >= 5
			and not spAreTeamsAllied(spGetUnitTeam(passenger1) --[[@as TeamID]], transporterTeamID)
			and not spGetUnitIsStunned(passenger1)
		if not skipMoveGoal then
			local passenger1x, passenger1y, passenger1z = spGetUnitPosition(passenger1)
			---@cast passenger1x -?
			spSetUnitMoveGoal(transporterID, passenger1x, passenger1y, passenger1z)
		end
	end
end

-- GADGET FUNCTIONS

-- UNIT LIFECYCLE
-- live settings for balance tests: cheats only, published to everyone as game rules params
local SPEED_OVERRIDES = { speedModMode = true, speedModStrength = true, comSpeedModStrength = true } ---@type table<string, boolean>
local liveSettings = {
	enemyLoadMode = { 1, 5, true },
	loadRadius = { 32, 512 },
	unloadRadius = { 16, 256 },
	enemyRadiusMult = { 0.1, 1 },
	enemyLoadFrames = { 1, 600, true },
	speedModMode = { -1, 2, true }, -- -1: each transport's own setting
	speedModStrength = { -1, 1 },
	comSpeedModStrength = { -1, 1 },
	unloadSpeed = { -1, 300 }, -- -1: a fifth of each transport's own
	unloadTime = { 0.1, 1 },
}
local liveDefaults = { unloadTime = 1 } ---@type table<string, number>

local function getLiveSetting(key)
	if key == "enemyLoadMode" then
		return ALLOW_ENEMY_LOAD_MODE
	elseif key == "loadRadius" then
		return LOAD_RADIUS
	elseif key == "unloadRadius" then
		return UNLOAD_RADIUS
	elseif key == "enemyRadiusMult" then
		return ENEMY_LOAD_RADIUS_MULTIPLIER
	elseif key == "enemyLoadFrames" then
		return MIN_CONSECUTIVE_FRAMES_TO_LOAD_ENEMY
	end
	return Spring.GetGameRulesParam("tractorbeam_" .. key) or liveDefaults[key] or -1
end

local function setLiveSetting(key, value)
	if key == "enemyLoadMode" then
		ALLOW_ENEMY_LOAD_MODE = value
	elseif key == "loadRadius" then
		LOAD_RADIUS = value
	elseif key == "unloadRadius" then
		UNLOAD_RADIUS = value
	elseif key == "enemyRadiusMult" then
		ENEMY_LOAD_RADIUS_MULTIPLIER = value
	elseif key == "enemyLoadFrames" then
		MIN_CONSECUTIVE_FRAMES_TO_LOAD_ENEMY = value
	end
	ENEMY_LOAD_RADIUS = LOAD_RADIUS * ENEMY_LOAD_RADIUS_MULTIPLIER
	Spring.SetGameRulesParam("tractorbeam_" .. key, value)
end

local function refreshTransportSpeeds()
	for transporterID in pairs(transporterClaims) do
		local refresh = spValidUnitID(transporterID) and GetScriptFunc(transporterID, "RefreshSpeed")
		if refresh then
			refresh(transporterID, "RefreshSpeed")
		end
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	local key, raw = msg:match("^tractorbeam_set (%a+) (%-?[%d%.]+)$")
	local range = key and liveSettings[key]
	if not range then
		return
	end
	local number = tonumber(raw)
	if not number then
		return true
	end
	local playerName = Spring.GetPlayerInfo(playerID, false) or "?"
	if not Spring.IsCheatingEnabled() then
		spEcho("Transport settings: " .. playerName .. " tried to change " .. key .. ", needs /cheat")
		return true
	end
	local value = math.max(range[1], math.min(range[2], number))
	if range[3] then
		value = math.floor(value + 0.5)
	end
	setLiveSetting(key, value)
	if SPEED_OVERRIDES[key] then
		refreshTransportSpeeds()
	end
	spEcho("Transport settings: " .. playerName .. " set " .. key .. " to " .. value)
	return true
end

---@param unitID UnitID
---@param unitDefID UnitDefID
local function registerUnit(unitID, unitDefID)
	if customTransportLoad[unitDefID] == nil or customTransportUnload[unitDefID] == nil then
		customTransportLoad[unitDefID] = GetScriptFunc(unitID, "PerformLoad")
		customTransportUnload[unitDefID] = GetScriptFunc(unitID, "PerformUnload")
	end
	if isAirTransport[unitDefID] then
		consecutiveFramesOverEnemyPassenger[unitID] = {} -- always: the enemy load mode can change live
		transporterClaims[unitID] = {}
		queuedSeats[unitID] = 0
	end
end

function gadget:Initialize()
	local AllUnits = spGetAllUnits()
	if #AllUnits > 0 then
		for i = 1, #AllUnits do
			local unitID = AllUnits[i]
			local unitDefID = spGetUnitDefID(unitID)
			---@cast unitDefID -?
			if spGetUnitRulesParam(unitID, "inUnloadAnim") == 1 then
				spEcho("Repairing unit " .. unitID .. " stuck in unload anim on gadget initialization")
				spMoveCtrlDisable(unitID)
				spSetUnitRulesParam(unitID, "inUnloadAnim", 0, ALLIED_READ)
				EnablePassenger(unitID)
				spSetUnitRadiusAndHeight(unitID, UnitDefs[unitDefID].radius, UnitDefs[unitDefID].height)
				local unitPosX, unitPosY, unitPosZ = spGetUnitPosition(unitID)
				---@cast unitPosX -?
				spSetUnitPosition(unitID, unitPosX, spGetGroundHeight(unitPosX, unitPosZ), unitPosZ)
			end
			if (spGetUnitRulesParam(unitID, "inLoadAnim") or 0) > 0 then
				spEcho("Repairing unit " .. unitID .. " stuck in load anim on gadget initialization")
				EnablePassenger(unitID)
				spMoveCtrlDisable(unitID)
				spSetUnitRulesParam(unitID, "inLoadAnim", 0, ALLIED_READ)
				local unitPosX, unitPosY, unitPosZ = spGetUnitPosition(unitID)
				---@cast unitPosX -?
				spSetUnitPosition(unitID, unitPosX, spGetGroundHeight(unitPosX, unitPosZ), unitPosZ)
			end
			registerUnit(unitID, unitDefID)
		end
	end
	spSetCustomCommandDrawData(CMD_AREA_LOAD, CMD.LOAD_UNITS, { 0.6, 0.6, 1, 0.5 }, true)
	spSetCustomCommandDrawData(CMD_LOAD_UNIT, CMD.LOAD_UNITS, { 0.6, 0.6, 1, 0.5 }, true)
	gadgetHandler:RegisterAllowCommand(CMD.LOAD_UNITS)
	gadgetHandler:RegisterAllowCommand(CMD.LOAD_ONTO)
	gadgetHandler:RegisterAllowCommand(CMD.UNLOAD_UNIT)
	gadgetHandler:RegisterAllowCommand(CMD.UNLOAD_UNITS)
	for key in pairs(liveSettings) do
		Spring.SetGameRulesParam("tractorbeam_" .. key, getLiveSetting(key))
	end
	local allyTeams = spGetAllyTeamList()
	for _, allyTeam in pairs(allyTeams) do
		claimedBy[allyTeam] = {}
	end

end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	registerUnit(unitID, unitDefID)
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
	-- a new plain order takes the unit off its way to a transporter, and starts a transport's next unloads afresh
	if (boardingOrder[unitID] or droppedBy[unitID]) and not cmdOptions.shift and not isStateCommand(unitID, cmdID) then
		boardingOrder[unitID] = nil
		droppedBy[unitID] = nil
	end
	if transporterClaims[unitID] ~= nil then
		local cmds = spGetUnitCommands(unitID, 1)
		if not (cmds[1] and (cmds[1].id == CMD_AREA_LOAD or cmds[1].id == CMD.LOAD_UNITS)) then
			releaseAllClaims(unitID)
		end
	end
end

function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
	if transporterClaims[unitID] ~= nil then
		local cmds = spGetUnitCommands(unitID, 1)
		if not (cmds[1] and (cmds[1].id == CMD_AREA_LOAD or cmds[1].id == CMD.LOAD_UNITS)) then
			releaseAllClaims(unitID)
		end
		if droppedBy[unitID] and not (cmds[1] and cmds[1].id == CMD.UNLOAD_UNIT) then
			droppedBy[unitID] = nil
		end
	end
end

function gadget:UnitGiven(unitID, unitDefID, oldTeam, newTeam)
	local transporterAllyTeam = spGetUnitAllyTeam(unitID)
	---@cast transporterAllyTeam -?
	releasePassenger(unitID, transporterAllyTeam)
	releaseAllClaims(unitID)
	boardingOrder[unitID] = nil
	droppedBy[unitID] = nil
	clearBoarding(unitID)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local transporterAllyTeam = spGetUnitAllyTeam(unitID)
	---@cast transporterAllyTeam -?
	releasePassenger(unitID, transporterAllyTeam)
	releaseAllClaims(unitID)
	boardingOrder[unitID] = nil
	droppedBy[unitID] = nil
	clearBoarding(unitID)
	local transporterID = spGetUnitTransporter(unitID)
	if not transporterID then
		return
	end
	local transporterDefID = spGetUnitDefID(transporterID)
	if customTransportUnload[transporterDefID] then
		local gx, gy, gz = spGetUnitPosition(transporterID)
		customTransportUnload[transporterDefID](transporterID, "PerformUnload", unitID, gx, gy, gz)
	end
	if ALLOW_ENEMY_LOAD_MODE >= 3 then
		consecutiveFramesOverEnemyPassenger[unitID] = nil
	end
end

-- CMD LIFECYCLE

-- the engine asks about a queued unload only every half second: a transport in a run of drops asks itself
---@param transporterID UnitID
local function tryNextUnload(transporterID)
	local Q = spGetUnitCommands(transporterID, 1)
	local params = Q and Q[1] and Q[1].id == CMD.UNLOAD_UNIT and Q[1].params
	local passengerID = params and params[4] ---@as UnitID?
	local dropped = droppedBy[transporterID]
	if not (passengerID and dropped and not dropped[passengerID] and spValidUnitID(passengerID)) then
		return
	end
	gadget:AllowUnitTransportUnload(
		transporterID,
		spGetUnitDefID(transporterID) --[[@as UnitDefID]],
		spGetUnitTeam(transporterID) --[[@as TeamID]],
		passengerID,
		spGetUnitDefID(passengerID) --[[@as UnitDefID]],
		spGetUnitTeam(passengerID) --[[@as TeamID]],
		params[1],
		params[2],
		params[3]
	)
end

function gadget:GameFrame(frame)
	for transporterID in pairs(droppedBy) do
		tryNextUnload(transporterID)
	end
	-- resumes and compacts in one pass; an entry removed from inside a coroutine may stay until next frame
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

-- CMD_AREA_LOAD and CMD_LOAD_UNIT: one pass here, then a coroutine claims and loads until the command
-- leaves the queue; an area load is finished by a later fallback once nothing is left to claim
---@return boolean used
---@return boolean remove
function gadget:CommandFallback(
	transporterID,
	transporterDefID,
	transporterTeamID,
	cmdID,
	cmdParams,
	cmdOptions,
	cmdTag
)
	if cmdID == CMD_LOAD_WAIT then -- wait until the load anim is finished
		local canUnload = spGetUnitRulesParam(transporterID, "canUnload") == 1
		if canUnload then
			return true, true
		else
			return true, false
		end
	end

	if cmdID == CMD_LOAD_UNIT then
		-- first pass before coroutine for an early escape
		ExecuteSuccessiveLoadUnits(transporterID, transporterDefID, transporterTeamID)
		if not transporterCoroutines[transporterID] or transporterCoroutines[transporterID].type ~= "successive" then
			local co = coroutine.create(function()
				while true do
					coroutine.yield()
					local posX, posY, posZ = spGetUnitPosition(transporterID)
					local passengerPosX, passengerPosY, passengerPosZ = spGetUnitPosition(cmdParams[1] --[[@as UnitID]])
					---@cast posX -?
					---@cast passengerPosX -?
					local disttoArea = distance2d(posX, posZ, passengerPosX, passengerPosZ)
					while (disttoArea > 1024) and (spGetGameFrame() % 15 ~= transporterID % 15) do -- throttle
						coroutine.yield()
						---@diagnostic disable-next-line: assign-type-mismatch
						posX, posY, posZ = spGetUnitPosition(transporterID)
						---@diagnostic disable-next-line: assign-type-mismatch
						passengerPosX, passengerPosY, passengerPosZ = spGetUnitPosition(cmdParams[1] --[[@as UnitID]])
						---@cast posX -?
						---@cast passengerPosX -?
						disttoArea = distance2d(posX, posZ, passengerPosX, passengerPosZ)
					end
					local Q = spGetUnitCommands(transporterID, 1)
					local cmd = Q and Q[1]
					if not (cmd and cmd.id == CMD_LOAD_UNIT) then
						RemoveSuccessiveCoroutine(transporterID)
						releaseAllClaims(transporterID)
						clearBoarding(transporterID)
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
	-- first pass before coroutine for an early escape
	local finished = ExecuteAreaLoad(
		transporterID,
		transporterDefID,
		transporterTeamID,
		cmdParams[1] --[[@as number]],
		cmdParams[2] --[[@as number]],
		cmdParams[3] --[[@as number]],
		cmdParams[4] --[[@as number]]
	)
	if finished and spGetUnitRulesParam(transporterID, "canLoad") == 0 then
		-- like CMD_LOAD_WAIT: the load finishes only once the unload anim is done
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
					---@cast posX -?
					local disttoArea = distance2d(posX, posZ, cx, cz)
					while (disttoArea > 2 * radius) and (spGetGameFrame() % 15 ~= transporterID % 15) do -- throttle
						coroutine.yield()
						---@diagnostic disable-next-line: assign-type-mismatch
						posX, posY, posZ = spGetUnitPosition(transporterID)
						---@cast posX -?
						disttoArea = distance2d(posX, posZ, cx, cz)
					end
					local Q = spGetUnitCommands(transporterID, 1)
					local cmd = Q and Q[1]
					if not (cmd and cmd.id == CMD_AREA_LOAD) then
						RemoveAreaLoadCoroutine(transporterID)
						releaseAllClaims(transporterID)
						break
					end
					---@cast cmd.params -?
					-- handle changes in area without respawning a new coroutine
					if
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

-- still required for the default load command
function gadget:AllowUnitTransport(
	transporterID,
	transporterDefID,
	transporterTeamID,
	passengerID,
	passengerDefID,
	passengerTeamID
)
	-- the attach our own load animation starts
	if spGetUnitRulesParam(passengerID, "inLoadAnim") == transporterID then
		return true
	end
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	---@cast transporterAllyTeam -?
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
		and CanPassengerFitInTransporter(transporterID, passengerID, 0)
end

-- a named unload of a building is placed like a build order: its own footprint, exactly on the spot
local isImmobileDef = {}
for defID, ud in pairs(UnitDefs) do
	isImmobileDef[defID] = ud.speed == 0 or nil
end
local function buildingUnloadDefID(passengerID)
	local passengerDefID = passengerID and spValidUnitID(passengerID) and spGetUnitDefID(passengerID)
	return passengerDefID and isImmobileDef[passengerDefID] and passengerDefID or nil
end

-- called every frame once the transport is within its loadingRadius of the drop, like a CommandFallback
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
	---@cast transporterPosX -?
	local Q = spGetUnitCommands(transporterID, 1)
	local unloadParams = Q and Q[1] and Q[1].id == CMD.UNLOAD_UNIT and Q[1].params
	-- passengerID is set for area unloads too; only a named unload carries the unit as its 4th param
	local buildingDefID = unloadParams and buildingUnloadDefID(unloadParams[4])
	local facing = (buildingDefID and unloadParams and unloadParams[5] or 0) --[[@as FacingInteger]]
	local unloadPadType = buildingDefID or GetUnloadPadType(transporterID)
	local blocked = spTestBuildOrder(unloadPadType, goalX, goalY, goalZ, facing)
	if blocked == 0 then
		goalX, goalY, goalZ = spClosestBuildPos(transporterTeamID, unloadPadType, goalX, goalY, goalZ, 512, 0, facing)
		if not goalX then
			-- for a building out of sight that blocks the spot once seen
			spEcho(
				"Error: no valid unload position found near target point for transporter "
					.. transporterID
					.. ", aborting unload"
			)
			return false
		end
	end
	-- test for non-blocking mobile units in the way
	blocked = spTestBuildOrder(unloadPadType, goalX, goalY, goalZ, facing)
	if blocked == 1 then
		BuggerOff(goalX, goalY, goalZ, unloadPadType, transporterID)
	end

	if not inUnloadRange(transporterPosX, transporterPosY, transporterPosZ, goalX, goalY, goalZ) then
		spSetUnitMoveGoal(transporterID, goalX, goalY, goalZ)
		return false
	end

	if customTransportUnload[transporterDefID] then
		if spGetUnitRulesParam(transporterID, "canUnload") == 0 then
			spSetUnitMoveGoal(transporterID, goalX, goalY, goalZ) -- Keep overriding engine's movegoal
			return false
		end
		local targets = GetUnloadTargets(transporterID, passengerID, goalX, goalY, goalZ)
		local dropped = droppedBy[transporterID] or {}
		droppedBy[transporterID] = dropped
		for i = 1, #targets do
			dropped[targets[i]] = true
			customTransportUnload[transporterDefID](
				transporterID,
				"PerformUnload",
				targets[i],
				goalX,
				goalY,
				goalZ,
				buildingDefID ~= nil,
				buildingDefID and facing
			)
		end
		spSetUnitMoveGoal(transporterID, goalX, goalY, goalZ) -- Keep overriding engine's movegoal
		spUnitFinishCommand(transporterID) -- consume the command
		tryNextUnload(transporterID)
		return false
	end

	return true -- an air transport without a tractor beam script unloads the engine's way
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
	-- LOAD_ONTO: the transporter gets the load in front of its queue and the passenger walks to it.
	-- The passenger keeps no command of its own; other kinds of transport keep the engine's.
	if cmdID == CMD.LOAD_ONTO then
		local transporterID = cmdParams[1] ---@as UnitID
		if not transporterClaims[transporterID] then
			return true
		end
		if fromInsert then
			return false
		end
		spGiveOrderToUnit(transporterID, CMD.INSERT, { 0, CMD_LOAD_UNIT, 0, unitID }, { "alt" })
		if not cmdOptions.shift then
			spGiveOrderToUnit(unitID, CMD.STOP, {}, 0)
		end
		boardingOrder[unitID] = transporterID
		return false
	end
	-- the rest is for air transports only
	if not isAirTransport[unitDefID] then
		return true
	end

	-- LOAD_UNITS => reissue an area command or a successive load command depending on the number of params
	if cmdID == CMD.LOAD_UNITS then
		if #cmdParams == 4 then -- inserted area cmd
			reissueOrder(unitID, CMD_AREA_LOAD, cmdParams, cmdOptions, cmdTag, fromInsert)
		elseif #cmdParams == 1 then -- inserted successive cmd
			reissueOrder(unitID, CMD_LOAD_UNIT, cmdParams, cmdOptions, cmdTag, fromInsert)
		end
		return false -- reissued above, or malformed
	end

	-- UNLOAD_UNIT, one unit or all: the spot snaps to a free pad, and an empty transport
	-- still loading gets a wait in front so the unload comes after the load
	if cmdID == CMD.UNLOAD_UNIT then
		local transportedUnits = spGetUnitIsTransporting(unitID)
		local posX, posY, posZ = cmdParams[1], cmdParams[2], cmdParams[3]
		local targetID = cmdParams[4] ---@as UnitID
		if not spValidUnitID(targetID) then
			cmdParams[4] = nil
		end
		local needsShift = false ---@type boolean?
		local needsWaitStance = false ---@type boolean?
		local hasShift = cmdOptions.shift == true
		if #transportedUnits == 0 then
			local Q = spGetUnitCommands(unitID, 2)
			local queueEmpty = not Q or #Q == 0
			local inWaitStance = Q
				and Q[1]
				and (Q[1].id == CMD_AREA_LOAD or Q[1].id == CMD_LOAD_UNIT or Q[1].id == CMD_LOAD_WAIT)
			local hasMoreCommands = #Q > 1
			needsWaitStance = (queueEmpty or not hasShift) and not (inWaitStance and not hasMoreCommands)
			-- if we want to override queue, or have no waitStance/queue; we need to spawn a wait stance first
			needsShift = needsWaitStance or (inWaitStance and not hasMoreCommands)
			-- if we just spawned a wait stance, or are already on a wait stance, we need to keep the wait stance
			if needsWaitStance then
				spGiveOrderToUnit(unitID, CMD_LOAD_WAIT, { posX, posY, posZ }, { "" })
			end
			needsShift = needsShift and not hasShift
			if needsShift then
				cmdOptions.shift = true
				cmdOptions.coded = (cmdOptions.coded + CMD.OPT_SHIFT) --[[@as integer]]
			end
		end

		local buildingDefID = buildingUnloadDefID(cmdParams[4])
		local snapDefID = buildingDefID or GetUnloadPadType(unitID, cmdParams[4], cmdOptions.shift)
		local snapFacing = buildingDefID and cmdParams[5] or 0
		local newPosX, newPosY, newPosZ = spClosestBuildPos(unitTeam, snapDefID, posX, posY, posZ, 512, 0, snapFacing)
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

	-- UNLOAD_UNITS => deprecated, reissue as UNLOAD_UNIT with undefined passengerID
	-- Special handling for position
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
	return true
end
