local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Transport Handler",
		desc    = "Underwater gating for all transports; distance gating, slot/seat gating and LUS load/unload dispatch for custom air transports",
		author  = "DoodVanDaag",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 1, -- must be > 0 (unit_script.lua is layer 0) so LUS environments are ready when UnitCreated fires
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

if Spring.GetModOptions and Spring.GetModOptions().beta_tractorbeam == false then
	Spring.Echo("Custom transports disabled via modoption, skipping transport handler gadget")
	return false
end

local TransportAPI = GG.TransportAPI
if not TransportAPI then
	Spring.Echo("TransportAPI must be loaded before this gadget")
	return false
end

-- Math locals
local mathSqrt = math.sqrt

-- Spring API locals
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

-- Constants
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local mobilityDist = mapSizeX * mapSizeZ          -- priority offset: mobile < immobile
local alliedDist = 2 * mobilityDist          -- priority offset: own team < allied < enemy (never)
local maxDistSq = 2 * alliedDist               -- guaranteed > any real sq distance on the map
local LOAD_RADIUS = 128    -- elmos XZ; transporter must be within this range to fire PerformLoad
local UNLOAD_RADIUS = 32  -- elmos XZ; transporter must be within this range to fire PerformUnload
local CMD_AREA_LOAD = 39751 -- custom area-load command; needs to be logged in customcmds
local CMD_LOAD_UNIT = 39752 -- custom load-unit command; needs to be logged in customcmds
local cachedCylinderUnitsLifespan = 1 -- 1 frame
local cachedCylinderUnitsRounding = 16 -- 1 how close a previously cached result do we need to be to actually use it?


local customTransportLoad = {} -- transporterDefID → LUS function or COB script function
local customTransportUnload = {} -- transporterDefID → LUS function or COB script function
local claimedBy = {} -- passengerID → transporterID;
local queuedSeats = {} -- transporterID → number seats
local transporterClaims = {} -- transporterID → { passengerID, passengerID, ... }
local areaLoadCoroutines = {} -- transporterID → coroutine
local successiveLoadCoroutines = {} -- transporterID → coroutine
local cylinderCache = {} -- [key] = { frame = N, units = {...} }
local isAirTransport = {} -- transporterDefID → bool;
local offset = 0 -- reusable offset for coroutines cleanup in GameFrame
local unitOffset = 0 -- reusable offset for units table cleanup in findUnitToTransport; separate from couroutine's as this can run during a coroutine tick
local areaLoadCoroutinesCount = 0
local successiveLoadCoroutinesCount = 0
local transporterCoroutines = {} -- transporterID → { type = "area" or "successive", index = number }

for udefID, def in ipairs(UnitDefs) do
	if def.canFly and def.isTransport then
		isAirTransport[udefID] = true
	end
end
---------------------
-- Helper functions--
---------------------

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

local function isUnderwater(passengerID, y) -- i leave it hanging for now; TODOO: use engine's phys state bit or exact same calc to match
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

local function inLoadRange(transporterPosX, transporterPosY, transporterPosZ, goalX, goalY, goalZ)
	local dY = transporterPosY - goalY
	return dist2D(transporterPosX, transporterPosZ, goalX, goalZ) <= LOAD_RADIUS and dY >= 0
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
	cz, cx, radius = math.floor(cz / cachedCylinderUnitsRounding) * cachedCylinderUnitsRounding, math.floor(cx / cachedCylinderUnitsRounding) * cachedCylinderUnitsRounding, math.ceil(radius / cachedCylinderUnitsRounding) * cachedCylinderUnitsRounding
	local key = allyTeam .. "," .. cx .. "," .. cz .. "," .. radius
	local cached = cylinderCache[key]
	local frame = math.floor(spGetGameFrame() / cachedCylinderUnitsLifespan) * cachedCylinderUnitsLifespan -- cache over cachedCylinderUnitsLifespan frames
	if cached and cached.frame == frame then
		return cached.units
	end
	local units = spGetUnitsInCylinder(cx, cz, radius, allyTeam)
	cylinderCache[key] = { frame = frame, units = units }
	return units
end

local function BuggerOff(x, y, z, padDefID, transporterID) -- prolly needs to filter out units that should not be buggered off
	local padSize = UnitDefs[padDefID].xsize * 8 -- it's by definition a square
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	local units = Spring.GetUnitsInBox(x - padSize/2, y-50, z - padSize/2, x + padSize/2, y+5, z + padSize/2)
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
				spSetUnitMoveGoal(unitID, x-dirX*padSize, y, z-dirZ*padSize)
			end
		else
		end
	end
end

-------------------------
-- Core logic functions--
-------------------------

--- @param transporterID number
--- @return nil

local function RemoveAreaLoadCoroutine(transporterID)
	local index = transporterCoroutines[transporterID] and transporterCoroutines[transporterID].index
	if not index then 
		return SpEcho("Error in RemoveAreaLoadCoroutine: no coroutine found for transporterID " .. transporterID)
	end 
	areaLoadCoroutines[index] = nil -- no need to clean up, killed from within
	transporterCoroutines[transporterID] = nil
end

--- @param transporterID number
--- @return nil

local function RemoveSuccessiveCoroutine(transporterID)
	local index = transporterCoroutines[transporterID] and transporterCoroutines[transporterID].index
	if not index then 
		return SpEcho("Error in RemoveSuccessiveCoroutine: no coroutine found for transporterID " .. transporterID)
	end 
	successiveLoadCoroutines[index] = nil -- no need to clean up, killed from within	
	transporterCoroutines[transporterID] = nil
end

---
--- @param passengerID number
--- @param passengerDefID number
--- @param passengerPosY number
--- @param transporterID number
--- @param transporterAllyTeam number  -- transporter allyTeam (not teamID!)
--- @return boolean
local function CanBeTransportedStatic(passengerID, passengerDefID, transporterID) -- things that should cancel or deny queueing and are mostly immutable
	if not spValidUnitID(passengerID) then
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

---
--- @param passengerID number
--- @param passengerDefID number
--- @param passengerPosY number
--- @param transporterID number
--- @param transporterAllyTeam number  -- transporter allyTeam (not teamID!)
--- @return boolean
local function CanBeTransportedDynamic(passengerID, passengerDefID, passengerPosY, transporterID, transporterAllyTeam)  -- things that might have changed since CanBeTransportedStatic and should cancel queue (lightweight check for dynamic conditions))
	if not spValidUnitID(passengerID) then
		return false
	end
	if spGetUnitTransporter(passengerID) ~= nil then
		return false	
	end
	if spGetUnitIsBeingBuilt(passengerID) then -- moved to dynamic, to support other reclaimMode modrules that allows a unit to turn back to a nanoFrame
		return false	
	end
	local losState = spGetUnitLosState(passengerID, transporterAllyTeam, false)
	if not losState or not (losState.los or losState.radar) then
		return false	
	end
	if isUnderwater(passengerID, passengerPosY) then
		return false
	end
	if spGetUnitRulesParam(passengerID, "inTransportAnim") == 1 then
		return false	
	end
	return true
end

---
--- @param passengerID number
--- @param transporterAllyTeam number  -- transporter allyTeam (not teamID!)
--- @return boolean
local function CanBeAutoClaimed(passengerID, transporterAllyTeam) -- things that should only deny queueing if within area cmds
	if not spValidUnitID(passengerID) then
		return false
	end
	return not claimedBy[transporterAllyTeam][passengerID]
end

---
--- @param passengerID number
--- @param passengerTeamID number  -- passenger teamID
--- @param passengerPosX number
--- @param passengerPosY number
--- @param passengerPosZ number
--- @param transporterID number
--- @param transporterTeamID number  -- transporter teamID
--- @param transporterPosX number
--- @param transporterPosY number
--- @param transporterPosZ number
--- @return boolean
local function CanBeTransportedNow(passengerID, passengerTeamID, passengerPosX, passengerPosY, passengerPosZ, transporterID, transporterTeamID, transporterPosX, transporterPosY, transporterPosZ) -- things that should delay loading without removing from queue
	if not inLoadRange(transporterPosX, transporterPosY, transporterPosZ, passengerPosX, passengerPosY, passengerPosZ) then
		return false
	end
	if not spAreTeamsAllied(passengerTeamID, transporterTeamID) then
		local isStunned = Spring.GetUnitIsStunned(passengerID) -- the first bool is (beingBuilt OR stunned), but we supposedly already excluded beingBuilt
		if not isStunned then
			return false -- if the unit isn't stunned, it can't be transported 'yet' (not removed from queue)
		end
	end
	return true
end

---
--- @param passengerID number
--- @param passengerTeamID number  -- passenger teamID
--- @param transporterID number
--- @param transporterTeamID number  -- transporter teamID
--- @return boolean
local function CanMoveToTransporter(passengerID, passengerTeamID, transporterID, transporterTeamID) -- things that should allow moving towards transporter to facilitate loading
	if passengerTeamID == transporterTeamID then
		return true -- if it's the same team, we can move it towards the transport to facilitate loading
	end
	if spAreTeamsAllied(passengerTeamID, transporterTeamID) then
		local hasQ = spGetUnitCommands(passengerID, 0) >= 1
		return not hasQ -- if it's an allied unit, we only can if it's idling
	else
		return false -- if it's an enemy unit, we never can
	end
end

---
--- @param passengerID number
--- @param transporterAllyTeam number  -- transporter allyTeam (not teamID!)
--- @return nil
local function releasePassenger(passengerID, transporterAllyTeam)
	local transporterID = claimedBy[transporterAllyTeam][passengerID]
	if not transporterID then return end
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
			total = total + (TransportAPI.GetPassengerSize(transporterClaims[transporterID][i]) or 0) -- API handles the invalid case
		end
		if resumeFrom > 0 then
			for i = resumeFrom, 1, -1 do
				total = total + (TransportAPI.GetPassengerSize(transporterClaims[transporterID][i]) or 0) -- API handles the invalid case
			end
		end
		queuedSeats[transporterID] = total
	else
		queuedSeats[transporterID] = 0
	end
end

---
--- @param transporterID number
--- @param passengerID number
--- @param passengerSize number
--- @param manualClaim boolean
--- @return boolean claimSuccessful
local function claimPassenger(transporterID, passengerID, passengerSize, manualClaim)
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	if not manualClaim and claimedBy[transporterAllyTeam][passengerID] then return false end -- already claimed by another transporter from the allyTeam, and this is not a manual claim (from CMD_LOAD_UNIT))
	if claimedBy[transporterAllyTeam][passengerID] then 
		releasePassenger(passengerID, transporterAllyTeam) -- release previous claim
	end
	claimedBy[transporterAllyTeam][passengerID] = transporterID
	transporterClaims[transporterID][#transporterClaims[transporterID] + 1] = passengerID
	local total = 0
	local ct = 0
	for i = #transporterClaims[transporterID], 1, -1 do
		if transporterClaims[transporterID][i] == passengerID then
			ct = ct + 1
			if ct > 1 then
				spEcho("Error: duplicate claim for passenger " .. passengerID .. " in transporter " .. transporterID .. "'s claims list") -- debug kept for now to debug potential double claims
			end
		end
		total = total + (TransportAPI.GetPassengerSize(transporterClaims[transporterID][i]) or 0) -- API handles the invalid case
	end
	queuedSeats[transporterID] = total
	return true
end

---
--- @param transporterID number
--- @return nil
local function releaseAllClaims(transporterID)
	local claims = transporterClaims[transporterID]
	if not claims then return end
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	for i = 1, #claims do
		local passengerID = claims[i]
		claimedBy[transporterAllyTeam][passengerID] = nil
	end
	transporterClaims[transporterID] = {}
	queuedSeats[transporterID] = 0
end

---
--- @param transporterID number
--- @param transporterDefID number
--- @param transporterTeamID number  -- transporter teamID
--- @param cx number
--- @param cz number
--- @param radius number
--- @return number|nil bestUnit
local function findUnitToTransport(transporterID, transporterDefID, transporterTeamID, cx, cz, radius)
	local transporterAllyTeam      = spGetUnitAllyTeam(transporterID)
	local transporterPosX, transporterPosY, transporterPosZ = spGetUnitPosition(transporterID)
	local units = getCachedUnitsInCylinder(cx, cz, radius, transporterAllyTeam)
	local unitsCount = #units
	local bestUnit = nil
	local bestDist = maxDistSq
	if TransportAPI.IsTransportFull(transporterID, queuedSeats[transporterID]) then
		-- early exit if no seats
		return nil
	end
	-- TODO: remove unclaimable units from cache at runtime
	if unitsCount == 0 then
		return nil
	end
	unitOffset = 0
	for i = 1, unitsCount do
		local passengerID = units[i]
		repeat
			-- global checks (write back into cache)
			if not CanBeAutoClaimed(passengerID, transporterAllyTeam) then -- at worse, will be reconsidered in 8 frames
				unitOffset = unitOffset + 1
				units[i] = units[i + unitOffset]
				break 
			end
			local passengerDefID = spGetUnitDefID(passengerID)
			local passengerTeamID = spGetUnitTeam(passengerID)
			local passengerSize = TransportAPI.GetPassengerSize(passengerID)
			if not CanBeTransportedStatic(passengerID, passengerDefID, transporterID) then
				unitOffset = unitOffset + 1
				units[i] = units[i + unitOffset]
				break 
			end
			local passengerPosX, passengerPosY, passengerPosZ = spGetUnitPosition(passengerID)
			if not CanBeTransportedDynamic(passengerID, passengerDefID, passengerPosY, transporterID, transporterAllyTeam) then
				unitOffset = unitOffset + 1
				units[i] = units[i + unitOffset]
				break
			end
			-- transporter dependant checks (should not write back into cache)
			if not TransportAPI.CanPassengerFitInTransporter(transporterID, passengerID, transporterDefID, passengerSize, queuedSeats[transporterID]) then
				break
			end
			local dx, dz    = passengerPosX - transporterPosX, passengerPosZ - transporterPosZ
			local rawDistSq = dx * dx + dz * dz
			-- alliedDist is the offset applied to allied units, by definition dist < alliedDist for all units (alliedDist = mapSizeX*mapSizeZ)
			-- mobilityDist is the offset applied to immobile units, by definition dist < mobilityDist for mobile units.
			-- this gives priority order: mobile own > immobile own > mobile allied > immobile allied
			local mDist = UnitDefs[passengerDefID].speed>0 and 0 or mobilityDist
			local aDist = (passengerTeamID ~= transporterTeamID) and alliedDist or 0
			local unitDist  =  rawDistSq + aDist + mDist
			if unitDist >= bestDist then break end
			bestDist = unitDist
			bestUnit = passengerID
		until true
	end
	return bestUnit
end

---
--- @param transporterID number
--- @param transporterDefID number
--- @param transporterTeamID number  -- transporter teamID
--- @param transporterPosX number
--- @param transporterPosY number
--- @param transporterPosZ number
--- @param cx number
--- @param cy number
--- @param cz number
--- @param radius number
--- @return nil
local function ExecuteLoadUnits(transporterID, transporterDefID, transporterTeamID, transporterPosX, transporterPosY, transporterPosZ, cx, cy, cz, radius)
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	local transporterTeamID = spGetUnitTeam(transporterID)
	for i = #transporterClaims[transporterID], 1, -1 do
		local passengerID = transporterClaims[transporterID][i]
		local passengerPosX, passengerPosY, passengerPosZ = spGetUnitPosition(passengerID)
		local passengerDefID = spGetUnitDefID(passengerID)
		local removalFlag = false
		local moveToTransporterFlag = false
		if claimedBy[transporterAllyTeam][passengerID] ~= transporterID then -- keep it during test runs so we can debug if this ever happens
			spEcho("Error: claim inconsistency for passenger " .. passengerID .. " in transporter " .. transporterID .. "'s claims list")
		end
		if not CanBeTransportedDynamic(passengerID, passengerDefID, passengerPosY, transporterID, transporterAllyTeam) then
			removalFlag = true
		end
		local passengerSize = TransportAPI.GetPassengerSize(passengerID)
		if not TransportAPI.CanPassengerFitInTransporter(transporterID, passengerID, transporterDefID, passengerSize, 0) then
			removalFlag = true
		end
		local passengerTeamID = spGetUnitTeam(passengerID)
		if removalFlag then
			releasePassenger(passengerID, transporterAllyTeam) -- release claim so it can be targeted by future loads
		elseif CanBeTransportedNow(passengerID, passengerTeamID, passengerPosX, passengerPosY, passengerPosZ, transporterID, transporterAllyTeam, transporterPosX, transporterPosY, transporterPosZ) then
			customTransportLoad[transporterDefID](transporterID, 'PerformLoad', passengerID)
			removalFlag = true
		elseif dist2D(transporterPosX, transporterPosZ, cx, cz) < radius and CanMoveToTransporter(passengerID, passengerTeamID, transporterID, transporterTeamID) then
			moveToTransporterFlag = true
		end
		if moveToTransporterFlag then
			spSetUnitMoveGoal(passengerID, transporterPosX, spGetGroundHeight(transporterPosX, transporterPosZ), transporterPosZ,64,nil, true) -- moves to the transport
		end
		if removalFlag then
			releasePassenger(passengerID, transporterAllyTeam) -- release claim so it can be targeted by future loads
		end
	end

	if spValidUnitID(transporterClaims[transporterID][1]) then -- because it might now be empty after releasing claims, check before trying to access
		-- move to first in queue, not avg pos, in case of blocked or immobile passengers
		local passenger1x, passenger1y, passenger1z = spGetUnitPosition(transporterClaims[transporterID][1])
		spSetUnitMoveGoal(transporterID, passenger1x, passenger1y, passenger1z)
	end
end


---
--- @param transporterID number
--- @param transporterDefID number
--- @param transporterTeamID number  -- transporter teamID
--- @param cx number
--- @param cy number
--- @param cz number
--- @param radius number
--- @return boolean commandFinished
local function ExecuteAreaLoad(transporterID, transporterDefID, transporterTeamID, cx, cy, cz, radius)
	local passengerID = findUnitToTransport(transporterID, transporterDefID, transporterTeamID, cx, cz, radius)
	
	-- OPTION: one per frame or until filled
	-- if perfs are a concern, or if you want units to be split among area-loading transports, use one per frame
	-- i personnally prefer in batch as it allows the commands to be instantly performed in some edge cases

	if passengerID then
		claimPassenger(transporterID, passengerID, TransportAPI.GetPassengerSize(passengerID), false)
	end
	--[[while passengerID do
		claimPassenger(transporterID, passengerID, TransportAPI.GetPassengerSize(passengerID), false)
		passengerID = findUnitToTransport(transporterID, transporterDefID, transporterTeamID, cx, cz, radius)
	end]]--

	if queuedSeats[transporterID] == 0 then -- queuedSeats val ~= #transporterClaims but both are 0 when no queue.
		areaLoadCoroutines[transporterID] = nil
		return true -- either no claimable units, or all claims loaded, command is finished
	end
	local transporterPosX, transporterPosY, transporterPosZ = spGetUnitPosition(transporterID)
	local distToArea = dist2D(transporterPosX, transporterPosZ, cx, cz)
	if distToArea < radius then
		ExecuteLoadUnits(transporterID, transporterDefID, transporterTeamID, transporterPosX, transporterPosY, transporterPosZ, cx, cy, cz, radius)
	else
		spSetUnitMoveGoal(transporterID, cx, cy, cz, 64)
	end
	return false -- command is still in progress
end

---
--- @param transporterID number
--- @param transporterDefID number
--- @param transporterTeamID number  -- transporter teamID
--- @return nil
local function ExecuteSuccessiveLoadUnits(transporterID, transporterDefID, transporterTeamID)
	local idsToRemove = {}
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	-- 1: Get current queue, remove invalid units, claim valid ones
	local queue = spGetUnitCommands(transporterID,  spGetUnitRulesParam(transporterID, "transporterSeats")) --  spGetUnitRulesParam(transporterID, "transporterSeats") being the max number of units we can queue on a single transport
	local i = 1
	local cmd = queue and queue[i]
	if not TransportAPI.IsTransportFull(transporterID, queuedSeats[transporterID]) then
		while cmd and cmd.id == CMD_LOAD_UNIT and not TransportAPI.IsTransportFull(transporterID, queuedSeats[transporterID]) do
			local passengerID = cmd.params[1]
			local passengerDefID = spGetUnitDefID(passengerID)
			local _, passengerPosY = spGetUnitPosition(passengerID)
			if not CanBeTransportedStatic(passengerID, passengerDefID, transporterID) then
				idsToRemove[passengerID] = true -- can't be transported, mark for removal
			elseif not CanBeTransportedDynamic(passengerID, passengerDefID, passengerPosY, transporterID, transporterAllyTeam) then
				idsToRemove[passengerID] = true -- can't be transported right now, mark for removal
			elseif transporterID ~= claimedBy[transporterAllyTeam][passengerID] then
				claimPassenger(transporterID, passengerID, TransportAPI.GetPassengerSize(passengerID), true) -- force claim for ourselves if not already claimed
			end
			i = i + 1
			cmd = queue and queue[i]
		end
	elseif TransportAPI.IsTransportFull(transporterID, 0) then -- we still have queued commands despite being full, they can't be performed
		while cmd and cmd.id == CMD_LOAD_UNIT do
			local passengerID = cmd.params[1]
			idsToRemove[passengerID] = true -- mark command for removal
			i = i + 1
			cmd = queue and queue[i]
		end
	end

	-- 2: proceed to loading all units in queue
	local transporterPosX, transporterPosY, transporterPosZ = spGetUnitPosition(transporterID)
	local transporterTeamID = spGetUnitTeam(transporterID)
	for i = #transporterClaims[transporterID], 1, -1 do
		local passengerID = transporterClaims[transporterID][i]
		local passengerDefID = spGetUnitDefID(passengerID)
		local passengerPosX, passengerPosY, passengerPosZ = spGetUnitPosition(passengerID)
		local removalFlag = false
		local moveToTransporterFlag = false
		if claimedBy[transporterAllyTeam][passengerID] ~= transporterID then -- keep it during test runs so we can debug if this ever happens
			spEcho("Error: claim inconsistency for passenger " .. passengerID .. " in transporter " .. transporterID .. "'s claims list")
		end
		if not CanBeTransportedDynamic(passengerID, passengerDefID, passengerPosY, transporterID, transporterAllyTeam) then
			removalFlag = true
		end
		local passengerSize = TransportAPI.GetPassengerSize(passengerID)
		if not TransportAPI.CanPassengerFitInTransporter(transporterID, passengerID, transporterDefID, passengerSize, 0) then
			removalFlag = true
		end
		local passengerTeamID = spGetUnitTeam(passengerID)
		if removalFlag then
			idsToRemove[passengerID] = true
		elseif CanBeTransportedNow(passengerID, passengerTeamID, passengerPosX, passengerPosY, passengerPosZ, transporterID, transporterAllyTeam, transporterPosX, transporterPosY, transporterPosZ) then
			customTransportLoad[transporterDefID](transporterID, 'PerformLoad', passengerID)
			removalFlag = true
		elseif dist2D(transporterPosX, transporterPosZ, passengerPosX, passengerPosZ) < 512  and CanMoveToTransporter(passengerID, passengerTeamID, transporterID, transporterTeamID) then
			moveToTransporterFlag = true
		end
		if moveToTransporterFlag then -- do not order skipped passengers
			spSetUnitMoveGoal(passengerID, transporterPosX, spGetGroundHeight(transporterPosX, transporterPosZ), transporterPosZ,64,nil, true) -- moves to the transport
		end
		if removalFlag then
			idsToRemove[passengerID] = true
		end
	end
	-- remove invalidated/finished commands before giving a move goal, making sure don't accidently movegoal to a skipped unit
	for passengerID,v in pairs(idsToRemove) do
		releasePassenger(passengerID, transporterAllyTeam) -- release claim so it can be targeted by future loads
		for i = 1, #queue do
			if queue[i].id == CMD_LOAD_UNIT and queue[i].params[1] == passengerID then -- find the corresponding command
				spGiveOrderToUnit(transporterID, CMD.REMOVE, {queue[i].tag}, 0) -- consume the command so the transporter proceeds to the next
				break
			end
		end
	end
	if spValidUnitID(transporterClaims[transporterID][1]) then --it could have been loaded
		-- move to first in queue, not avg pos, in case of blocked or immobile passengers
		local passenger1x, passenger1y, passenger1z = spGetUnitPosition(transporterClaims[transporterID][1])
		spSetUnitMoveGoal(transporterID, passenger1x, passenger1y, passenger1z)
	end
end

------------------
--Gadget Callins--
------------------

function gadget:Initialize()
	local AllUnits = spGetAllUnits()
	if #AllUnits > 0 then
		for i = 1, #AllUnits do -- save/load compat
			local unitID = AllUnits[i]
			if spGetUnitRulesParam(unitID, "inTransportAnim") == 1 then
				spEcho("Repairing unit " .. unitID .. " stuck in transport anim on gadget initialization")
				-- this unit was in the middle of an unload anim, we need to "repair" it by releasing MoveCtrl and clip it to ground level (not fall, otherwise fall damages !!)
				spMoveCtrlDisable(unitID, false)
				spSetUnitRulesParam(unitID, "inTransportAnim", 0)
				local unitPosX, unitPosY, unitPosZ = spGetUnitPosition(unitID)
				spSetUnitPosition(unitID, unitPosX, spGetGroundHeight(unitPosX, unitPosZ), unitPosZ)
			end
			gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
		end
	end
	spSetCustomCommandDrawData(CMD_AREA_LOAD, CMD.LOAD_UNITS, {0.6, 0.6, 1, 0.5}, true)
	spSetCustomCommandDrawData(CMD_LOAD_UNIT, CMD.LOAD_UNITS, {0.6, 0.6, 1, 0.5}, true)
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
		customTransportLoad[unitDefID]   = GetScriptFunc(unitID, 'PerformLoad')
		customTransportUnload[unitDefID] = GetScriptFunc(unitID, 'PerformUnload')
	end
	if isAirTransport[unitDefID] then
		transporterClaims[unitID] = {}
		queuedSeats[unitID] = 0
	end
end

function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
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
	releasePassenger(unitID, transporterAllyTeam)  -- no-op if not claimed
	releaseAllClaims(unitID)    -- no-op if not a transporter with claims
	local transporterID = spGetUnitTransporter(unitID)
	if not transporterID then return end
	local transporterDefID = spGetUnitDefID(transporterID)
	if customTransportUnload[transporterDefID] then
		local gx, gy, gz = spGetUnitPosition(transporterID)
		customTransportUnload[transporterDefID](transporterID, 'PerformUnload', unitID, gx, gy, gz)
	end
end

function gadget:GameFrame(frame)
	offset = 0
	for i = 1, areaLoadCoroutinesCount do
		local co =  areaLoadCoroutines[i] and areaLoadCoroutines[i].co or nil
		if co then
			local transporterID = areaLoadCoroutines[i].transporterID
			-- option 1: update the index on "frame 3" without nil checking transporterID, right before the coroutine runs, before it can get removed, so the table is updated if it gets its removal code
			transporterCoroutines[transporterID].index = i - offset
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
		else
			offset = offset + 1
		end
		areaLoadCoroutines[i] = areaLoadCoroutines[i + offset]
		-- options 2: update the index here, so on "frame 2", recquiring a nilcheck on transporterID beforehand
	end
	areaLoadCoroutinesCount = areaLoadCoroutinesCount - offset
	offset = 0 -- reuseable offset for successive loads
	for i = 1, successiveLoadCoroutinesCount do
		local co = successiveLoadCoroutines[i] and successiveLoadCoroutines[i].co or nil
		if co then
			local transporterID = successiveLoadCoroutines[i].transporterID
			transporterCoroutines[transporterID].index = i - offset -- keep the index updated before a possible removal
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
		else
			offset = offset + 1
		end
		successiveLoadCoroutines[i] = successiveLoadCoroutines[i + offset]
		-- do not nil the i+offset, it's either already nil, or is a valid coroutine that has to be processed first before its value is shifted to i+1+offset, until i+1+offset reaches nil
	end
	successiveLoadCoroutinesCount = successiveLoadCoroutinesCount - offset
end


-- CMD_AREA_LOAD lifecycle:
-- 1. On first CommandFallback, ExecuteAreaLoad runs: if no claimable units (or all are instantly loaded), the command finishes immediately with no coroutine.
-- 2. If there are claimable units, a coroutine is started to monitor the area and manage claiming/loading over time.
-- 3. The coroutine continues running until the command is either completed or removed from the queue.
-- 4. When all claims are resolved, a final CommandFallback call with finished = true is required to finish the command; the coroutine will then detect this and stop.

-- CMD_LOAD_UNIT lifecycle:
-- 1. On CommandFallback, ExecuteSuccessiveLoadUnits runs to update the queue and attempt to load units in order. If a CMD_LOAD_UNIT command is still in the queue after this, a coroutine is started to monitor the queue and manage claiming/loading over time.
-- 2. The coroutine continues running until the successive load commands are removed from the queue (either by being finished or by being invalidated), at which point it stops.

function gadget:CommandFallback(transporterID, transporterDefID, transporterTeamID, cmdID, cmdParams, cmdOptions, cmdTag)
	if cmdID == CMD_LOAD_UNIT then
		ExecuteSuccessiveLoadUnits(transporterID, transporterDefID, transporterTeamID)
		if not transporterCoroutines[transporterID] or transporterCoroutines[transporterID].type ~= "successive" then

			local co = coroutine.create(function()
					while true do
						coroutine.yield() -- ticked by GameFrame every frame
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
			if transporterCoroutines[transporterID] then -- no need to test for type
				RemoveAreaLoadCoroutine(transporterID) -- if we had an area load coroutine, remove it, as successive load takes precedence and they can't run simultaneously
			end
			successiveLoadCoroutinesCount = successiveLoadCoroutinesCount + 1
			successiveLoadCoroutines[successiveLoadCoroutinesCount] = { co = co, transporterID = transporterID }
			transporterCoroutines[transporterID] = { type = "successive", index = successiveLoadCoroutinesCount}
		end
		return true, false
	end
	if cmdID ~= CMD_AREA_LOAD then return false, false end -- we do not handle this command;
	local finished = ExecuteAreaLoad(transporterID, transporterDefID, transporterTeamID, cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4])
	-- 1st pass of ExecuteAreaLoad: attempt to instantly finish cmd to avoid spawning a coroutine
	if finished and spGetUnitRulesParam(transporterID, "canLoad") == 0 then
		-- optional: if we're busy unloading, don't finish the command yet
		-- this enables overlapping area load/unload cycles
		finished = false
	end
	if not finished then
		if not transporterCoroutines[transporterID] or transporterCoroutines[transporterID].type ~= "area" then -- only start a coroutine if one doesn't already exist for this transporter.
			local cx, cy, cz, radius = cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4]
			-- coroutine params on start
			local co = coroutine.create(function()
				while true do
					coroutine.yield() -- ticked by GameFrame every frame
					coroutine.lastKnownParams = { cx, cy, cz, radius }
					-- update the coroutine's last known params 
					-- so we can detect mid-coroutine changes, instead of exiting + recreating
					local Q = spGetUnitCommands(transporterID, 1)
					local cmd = Q and Q[1]
					-- are we still performing a CMD_AREA_LOAD ?
					if not (cmd and cmd.id == CMD_AREA_LOAD) then
						-- exit coroutine and clean up if command is finished or removed from queue
						RemoveAreaLoadCoroutine(transporterID)
						releaseAllClaims(transporterID)
						break
					-- have our params changed mid-coroutine ?
					elseif coroutine.lastKnownParams[1] ~= cmd.params[1] or coroutine.lastKnownParams[2] ~= cmd.params[2] or coroutine.lastKnownParams[3] ~= cmd.params[3] or coroutine.lastKnownParams[4] ~= cmd.params[4] then
						-- release all claims but keep the coroutine alive
						releaseAllClaims(transporterID)
						coroutine.lastKnownParams = cmd.params
						cx, cy, cz, radius = cmd.params[1], cmd.params[2], cmd.params[3], cmd.params[4]
					end
					-- Execute our command logic every tick
					ExecuteAreaLoad(transporterID, transporterDefID, transporterTeamID, cx, cy, cz, radius)					
					-- Could Spring.UnitFinishCommand() here instead of waiting next CommandFallback if we need to stop the coroutine ASAP for perfs
				end
			end)
			if transporterCoroutines[transporterID] then -- no need to test for type
				RemoveSuccessiveCoroutine(transporterID) -- if we had a successive load coroutine, remove it, as area load takes precedence and they can't run simultaneously
			end
			areaLoadCoroutinesCount = areaLoadCoroutinesCount + 1
			areaLoadCoroutines[areaLoadCoroutinesCount] = { co = co, transporterID = transporterID }
			transporterCoroutines[transporterID] = { type = "area", index = areaLoadCoroutinesCount }
		end
		return true, false -- handled, but not finished; keep command in queue
	end
	return true, true -- handled and finished; remove command from queue
end

-- still recquired for defaultCommand to work
function gadget:AllowUnitTransport(transporterID, transporterDefID, transporterTeamID, passengerID, passengerDefID, passengerTeamID)
	--use our helper CanTransport
	--I separated both to avoid FindUnitToTransport calling gadget:AllowUnitTransportLoad with an additional arg
	local transporterAllyTeam = spGetUnitAllyTeam(transporterID)
	local passengerPosX, passengerPosY, passengerPosZ = spGetUnitPosition(passengerID)
	return CanBeTransportedStatic(passengerID, passengerDefID, transporterID) and CanBeTransportedDynamic(passengerID, passengerDefID, passengerPosY, transporterID, transporterAllyTeam) and TransportAPI.CanPassengerFitInTransporter(transporterID, passengerID, transporterDefID, TransportAPI.GetPassengerSize(passengerID), 0)
end

-- unload commands haven't been changed (yet?)
function gadget:AllowUnitTransportUnload(transporterID, transporterDefID, transporterTeamID, passengerID, passengerDefID, passengerTeamID, goalX, goalY, goalZ)
	if isUnderwater(passengerID, goalY) then return false end
	if not isAirTransport[transporterDefID] then return true end	
	-- distance gate for individual unload commands
	local transporterPosX, transporterPosY, transporterPosZ = spGetUnitPosition(transporterID)
	local blocked = Spring.TestBuildOrder(TransportAPI.GetUnloadPadType(transporterID), goalX, goalY, goalZ, 0)
	if blocked == 0 then
		--spEcho("unload position blocked for transporter " .. transporterID .. ", finding closest valid position")
		goalX, goalY, goalZ = Spring.ClosestBuildPos(transporterTeamID, TransportAPI.GetUnloadPadType(transporterID), goalX, goalY, goalZ, 512, 0, 0)
		if not goalX then
			spEcho("Error: no valid unload position found near target point for transporter " .. transporterID .. ", aborting unload")
			return false
		end
	end
	-- retest because we might still have mobile units in the way
	blocked = Spring.TestBuildOrder(TransportAPI.GetUnloadPadType(transporterID), goalX, goalY, goalZ, 0)
	if blocked == 1 then
		BuggerOff(goalX, goalY, goalZ,TransportAPI.GetUnloadPadType(transporterID), transporterID)
		--spEcho("need bugger off logic")
	elseif blocked == 3 then
		--spEcho("reclaimable feature in the way, should we unload ?")
	end
	if not inUnloadRange(transporterPosX, transporterPosY, transporterPosZ, goalX, goalY, goalZ) then
		spSetUnitMoveGoal(transporterID, goalX, goalY, goalZ) -- move closer
		return false
	end	
	-- handle custom transports
	if customTransportUnload[transporterDefID] then
		if spGetUnitRulesParam(transporterID, "canUnload") == 0 then return false end
		local targets = TransportAPI.GetUnloadTargets(transporterID, passengerID)
		for _, passengerID in ipairs(targets) do
			customTransportUnload[transporterDefID](transporterID, 'PerformUnload', passengerID, goalX, goalY, goalZ)
		end
		spUnitFinishCommand(transporterID) -- consume the command so the transporter proceeds to the next
		return false
	end
	return true -- default for standard transports
end


function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua, fromInsert)
	if cmdID == CMD.LOAD_ONTO then
		if fromInsert then
			spEcho("Warning: CMD_LOAD_ONTO is deprecated and will be removed in a future update; this command will be ignored")
			return false
		end
		spEcho("Warning: CMD_LOAD_ONTO is deprecated and will be removed in a future update; use CMD.INSERT + CMD_LOAD_UNIT instead")
		spGiveOrderToUnit( cmdParams[1], CMD.INSERT, { 0, CMD_LOAD_UNIT, 0, unitID }, {"alt"}) -- insert in front of target's queue a load units cmd
		return false
	end
	if cmdID == CMD.LOAD_UNITS then
		if fromInsert then
			if #cmdParams == 4 then -- inserted area cmd
				spGiveOrderToUnit(unitID, CMD.INSERT, { 0, CMD_AREA_LOAD, 0, cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4] }, {"alt"})
				return false
			elseif #cmdParams == 1 then -- inserted successive cmd
				spGiveOrderToUnit(unitID, CMD.INSERT, { 0, CMD_LOAD_UNIT, 0, cmdParams[1] }, {"alt"})
				return false
			end
			return false -- malformed cmd ? ignore
		end
		if #cmdParams == 4 then
			spGiveOrderToUnit(unitID, CMD_AREA_LOAD, cmdParams, cmdOptions)
			return false
		elseif #cmdParams == 1 then
			spGiveOrderToUnit(unitID, CMD_LOAD_UNIT, cmdParams, cmdOptions)
			return false
		end
	end
	if cmdID == CMD.UNLOAD_UNIT then
		local posX, posY, posZ = cmdParams[1], cmdParams[2], cmdParams[3]
		local newPosX, newPosY, newPosZ = Spring.ClosestBuildPos(unitTeam, TransportAPI.GetUnloadPadType(unitID), posX, posY, posZ, 512, 0, 0)
		if newPosX ~= posX or newPosY ~= posY or newPosZ ~= posZ then
			cmdParams[1], cmdParams[2], cmdParams[3] = newPosX, newPosY, newPosZ
			if fromInsert then
				spGiveOrderToUnit(unitID, CMD.INSERT, { 0, CMD.UNLOAD_UNIT, 0, cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4] }, {"alt"})
				return false
			end
			spGiveOrderToUnit(unitID, CMD.UNLOAD_UNIT, cmdParams, cmdOptions)
			return false
		end
	end
	if cmdID == CMD.UNLOAD_UNITS then
		if cmdParams[4] then
			spEcho("Warning: CMD.UNLOAD_UNITS areas deprecated, replacing with single point CMD.UNLOAD_UNIT command")
		end
		local posX, posY, posZ = cmdParams[1], cmdParams[2], cmdParams[3]
		local newPosX, newPosY, newPosZ = Spring.ClosestBuildPos(unitTeam, TransportAPI.GetUnloadPadType(unitID), posX, posY, posZ, 512, 0, 0)
		if newPosX ~= posX or newPosY ~= posY or newPosZ ~= posZ then
			cmdParams[1], cmdParams[2], cmdParams[3] = newPosX, newPosY, newPosZ
			cmdParams[4] = nil
			cmdParams[5] = nil
			if fromInsert then
				spGiveOrderToUnit(unitID, CMD.INSERT, { 0, CMD.UNLOAD_UNIT, 0, cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4] }, {"alt"})
				return false
			end
			spGiveOrderToUnit(unitID, CMD.UNLOAD_UNIT, cmdParams, cmdOptions)
			return false
		end
	end
	return true, true
end