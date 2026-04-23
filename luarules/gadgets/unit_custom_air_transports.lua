local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Transport Handler",
		desc    = "Underwater gating for all transports; distance gating, slot/seat gating and LUS load/unload dispatch for custom air transports",
		author  = "Doo, GitHub Copilot",
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

-- Constants
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local alliedDist = mapSizeX * mapSizeZ          -- priority offset: own team < allied < enemy (never)
local maxDistSq = 2 * alliedDist               -- guaranteed > any real sq distance on the map
local LOAD_RADIUS = 128    -- elmos XZ; transporter must be within this range to fire PerformLoad
local CMD_AREA_LOAD = 39751 -- custom area-load command; needs to be logged in customcmds
local CMD_LOAD_UNIT = 39752 -- custom load-unit command; needs to be logged in customcmds

local customTransportLoad = {} -- transporterDefID → LUS function or COB script function
local customTransportUnload = {} -- transporterDefID → LUS function or COB script function
local claimedBy = {} -- transporteeID → transporterID;
local queuedSeats = {} -- transporterID → number seats
local transporterClaims = {} -- transporterID → { transporteeID, transporteeID, ... }
local areaLoadCoroutines = {} -- transporterID → coroutine
local successiveLoadCoroutines = {} -- transporterID → coroutine
local cylinderCache = {} -- [key] = { frame = N, units = {...} }
local isAirTransport = {} -- transporterDefID → bool;

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
		return function(uid, fname, a, b, c, d, e, f, g, h, i, j, k, l)
			local scriptEnv = Spring.UnitScript.GetScriptEnv(uid)
			Spring.UnitScript.CallAsUnit(uid, scriptEnv[fname], a, b, c, d, e, f, g, h, i, j, k, l)
		end
	end
	return false
end

---@param unitID number
---@param y number
---@return boolean isUnderwater

local function isUnderwater(unitID, y)
	local height = spGetUnitHeight(unitID)
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

---@param transporterID number
---@param goalX number
---@param goalY number
---@param goalZ number
---@return boolean inRange

local function inRange(transporterID, goalX, goalY, goalZ)
	local tx, ty, tz = spGetUnitPosition(transporterID)
	local dY = ty - goalY
	return dist2D(tx, tz, goalX, goalZ) <= LOAD_RADIUS and dY >= 0
end

---@param cx number
---@param cz number
---@param radius number
---@param allyTeam number
---@return number[] units

local function getCachedUnitsInCylinder(cx, cz, radius, allyTeam)
	local key = allyTeam .. "," .. cx .. "," .. cz .. "," .. radius
	local cached = cylinderCache[key]
	local frame = spGetGameFrame()
	if cached and cached.frame == frame then
		return cached.units
	end
	local units = spGetUnitsInCylinder(cx, cz, radius, allyTeam)
	cylinderCache[key] = { frame = frame, units = units }
	return units
end


-------------------------
-- Core logic functions--
-------------------------

---@param transporterID number
---@param transporteeID number
---@param transporterDefID number
---@param fromAreaScan boolean
---@return boolean canTransport

function CanTransport(transporterID, transporteeID, transporterDefID, fromAreaScan)
	local _, y, _ = spGetUnitPosition(transporteeID)
	if isUnderwater(transporteeID, y) then return false end
	if spGetUnitRulesParam(transporteeID, "inTransportAnim") == 1 then
		return false
	end
	if customTransportLoad[transporterDefID] then
		local nSeats    = spGetUnitRulesParam(transporterID, "nSeats")    or 0
		local usedSeats = spGetUnitRulesParam(transporterID, "usedSeats") or 0
		local queued    = fromAreaScan and (queuedSeats[transporterID] or 0) or 0 -- include queued seats only if from area scan
		local teeSize   = TransportAPI.GetTransporteeSize(transporteeID)
		if nSeats - usedSeats - queued < teeSize then
			return false
		end
		local slotSizesStr = spGetUnitRulesParam(transporterID, "slotSizes") or ""
		local foundSlot = false
		for sizeStr in slotSizesStr:gmatch("[^,]+") do
			if tonumber(sizeStr) == teeSize then foundSlot = true; break end
		end
		if not foundSlot then
			return false
		end
		return true
	end
	return true
end

---@param transporterID number
---@param transporteeID number
---@param teeSize number
---@param manualClaim boolean
---@return boolean claimSuccessful

function claimTransportee(transporterID, transporteeID, teeSize, manualClaim)
	if not manualClaim and claimedBy[transporteeID] then return false end -- already claimed by another transporter, and this is not a manual claim (ie from AllowUnitTransportLoad)
	if claimedBy[transporteeID] then 
		releaseTransportee(transporteeID) -- release previous claim
	end
	claimedBy[transporteeID] = transporterID
	transporterClaims[transporterID][#transporterClaims[transporterID] + 1] = transporteeID
	local total = 0
	local ct = 0
	for i = #transporterClaims[transporterID], 1, -1 do
		if transporterClaims[transporterID][i] == transporteeID then
			ct = ct + 1
			if ct > 1 then
				spEcho("Error: duplicate claim for transportee " .. transporteeID .. " in transporter " .. transporterID .. "'s claims list") -- debug kept for now to debug potential double claims
			end
		end
		total = total + (TransportAPI.GetTransporteeSize(transporterClaims[transporterID][i]) or 0)
	end
	queuedSeats[transporterID] = total
	return true
end

---@param transporteeID number
---@return nil

function releaseTransportee(transporteeID)
	local transporterID = claimedBy[transporteeID]
	if not transporterID then return end
	claimedBy[transporteeID] = nil
	if transporterClaims[transporterID] then
		local total = 0
		local resumeFrom = #transporterClaims[transporterID]
		for i = resumeFrom, 1, -1 do
			if transporterClaims[transporterID][i] == transporteeID then 
				table.remove(transporterClaims[transporterID], i) 
				resumeFrom = i - 1
				break
			end
			total = total + (TransportAPI.GetTransporteeSize(transporterClaims[transporterID][i]) or 0)
		end
		if resumeFrom > 0 then
			for i = resumeFrom, 1, -1 do
				total = total + (TransportAPI.GetTransporteeSize(transporterClaims[transporterID][i]) or 0)
			end
		end
		queuedSeats[transporterID] = total
	else
		queuedSeats[transporterID] = 0
	end
end

---@param transporterID number
---@return nil

function releaseAllClaims(transporterID)
	local claims = transporterClaims[transporterID]
	if not claims then return end
	for _, teeID in ipairs(claims) do
		claimedBy[teeID] = nil
	end
	transporterClaims[transporterID] = {}
	queuedSeats[transporterID] = 0
end


---@param transporterID number
---@param transporterDefID number
---@param transporterTeam number
---@param cx number
---@param cz number
---@param radius number
---@return number|nil bestUnit

function findUnitToTransport(transporterID, transporterDefID, transporterTeam, cx, cz, radius)
	local allyTeam      = Spring.GetUnitAllyTeam(transporterID)
	local terx, _, terz = spGetUnitPosition(transporterID)
	local units = getCachedUnitsInCylinder(cx, cz, radius, allyTeam)
	local bestUnit = nil
	local bestDist = maxDistSq
	if spGetUnitRulesParam(transporterID, "nSeats") <= spGetUnitRulesParam(transporterID, "usedSeats") + (queuedSeats[transporterID] or 0) then
		-- early exit if no seats
		return nil
	end
	-- TODO: remove unclaimable units from cache at runtime
	for idx, unitID in ipairs(units) do
		repeat
			if unitID == transporterID then 
				break
			end
			if spGetUnitTransporter(unitID) ~= nil then
				break
			end
			if claimedBy[unitID] then
				break
			end
			local losState = spGetUnitLosState(unitID, allyTeam, false)
			if not losState or not (losState.los or losState.radar) then
				break
			end
			local teeDefID = spGetUnitDefID(unitID)
			local teeDef   = UnitDefs[teeDefID]
			if teeDef.cantBeTransported then
				break
			end
			if spGetUnitIsBeingBuilt(unitID) then
				break
			end
			local teeTeam   = spGetUnitTeam(unitID)
			local tx, _, tz = spGetUnitPosition(unitID)
			local dx, dz    = tx - terx, tz - terz
			local rawDistSq = dx * dx + dz * dz

			-- alliedDist is the offset applied to allied units, by definition dist < alliedDist for all units (alliedDist = mapSizeX*mapSizeZ)
			local unitDist  = (teeTeam == transporterTeam) and rawDistSq or (rawDistSq + alliedDist)
			if unitDist >= bestDist then break end
			if not CanTransport(transporterID, unitID, transporterDefID, true) then break end
			bestDist = unitDist
			bestUnit = unitID
		until true
	end
	return bestUnit
end

---@param transporterID number
---@param transporterDefID number
---@param transporterTeam number
---@param cx number
---@param cy number
---@param cz number
---@param radius number
---@return nil

function ExecuteLoadUnits(transporterID, transporterDefID, transporterTeam, cx, cy, cz, radius)
	local terPosX, terPosY, terPosZ = spGetUnitPosition(transporterID)
	for i = #transporterClaims[transporterID], 1, -1 do
		if claimedBy[transporterClaims[transporterID][i]] ~= transporterID then -- keep it during test runs so we can debug if this ever happens
			spEcho("Error: claim inconsistency for transportee " .. transporterClaims[transporterID][i] .. " in transporter " .. transporterID .. "'s claims list")
		end
		local teeID = transporterClaims[transporterID][i]
		if spValidUnitID(teeID) then
			local tx, ty, tz = spGetUnitPosition(teeID)
			local moveToTransporter = true
			local teeTeam = spGetUnitTeam(teeID)
			local teeHasQ = spGetUnitCommands(teeID, 1)
			if teeTeam ~= transporterTeam and teeHasQ and teeHasQ[1] then
				moveToTransporter = false -- if it's performing a command, don't give it a movegoal that might interfere
			end
			if not CanTransport(transporterID, teeID, transporterDefID, false) then
				-- if for some reason, we can't load anymore, release the claim so it can be targeted by future loads
				releaseTransportee(teeID)
				moveToTransporter = false
			elseif dist2D(tx, tz, cx, cz) > radius then
				-- tee exited area
				releaseTransportee(teeID)
				moveToTransporter = false
			elseif inRange(transporterID, tx, ty, tz) then
				if customTransportLoad[transporterDefID] then --nil check will be gone once code is finished
					if spGetUnitRulesParam(transporterID, "canLoad") == 1 then
						customTransportLoad[transporterDefID](transporterID, 'PerformLoad', teeID)
						releaseTransportee(teeID)
						moveToTransporter = false
					end
				end
			end
			if moveToTransporter then -- do not order skipped transportees
				spSetUnitMoveGoal(teeID, terPosX, spGetGroundHeight(terPosX, terPosZ), terPosZ,64,nil, true) -- moves to the transport
			end
		else
			releaseTransportee(teeID)
		end
	end
	if spValidUnitID(transporterClaims[transporterID][1]) then
		-- move to first in queue, not avg pos, in case of blocked or immobile tees
		local tee1x, tee1y, tee1z = spGetUnitPosition(transporterClaims[transporterID][1])
		spSetUnitMoveGoal(transporterID, tee1x, tee1y, tee1z)
	end
end

---@param transporterID number
---@param transporterDefID number
---@param transporterTeam number
---@param cx number
---@param cy number
---@param cz number
---@param radius number
---@return boolean commandFinished

function ExecuteAreaLoad(transporterID, transporterDefID, transporterTeam, cx, cy, cz, radius)
	local teeID = findUnitToTransport(transporterID, transporterDefID, transporterTeam, cx, cz, radius)
	
	-- OPTION: one per frame or until filled
	-- if perfs are a concern, or if you want units to be split among area-loading transports, use one per frame
	-- i personnally prefer in batch as it allows the commands to be instantly performed in some edge cases

	if teeID then
		claimTransportee(transporterID, teeID, TransportAPI.GetTransporteeSize(teeID), false)
	end
	--[[while teeID do
		claimTransportee(transporterID, teeID, TransportAPI.GetTransporteeSize(teeID), false)
		teeID = findUnitToTransport(transporterID, transporterDefID, transporterTeam, cx, cz, radius)
	end]]--

	if queuedSeats[transporterID] == 0 then -- queuedSeats val ~= #transporterClaims but both are 0 when no queue.
		areaLoadCoroutines[transporterID] = nil
		return true -- either no claimable units, or all claims loaded, command is finished
	end
	local terX, terY, terZ = spGetUnitPosition(transporterID)
	local distToArea = dist2D(terX, terZ, cx, cz)
	if distToArea < radius then
		ExecuteLoadUnits(transporterID, transporterDefID, transporterTeam, cx, cy, cz, radius)
	else
		spSetUnitMoveGoal(transporterID, cx, cy, cz, 64)
	end
	return false -- command is still in progress
end

function ExecuteSuccessiveLoadUnits(transporterID, transporterDefID, transporterTeam)
	local idsToRemove = {}
	-- 1: update the list of queued units
	local queue = spGetUnitCommands(transporterID,  Spring.GetUnitRulesParam(transporterID, "nSeats")) --  Spring.GetUnitRulesParam(transporterID, "nSeats") being the max number of units we can queue on a single transport
	local i = 1
	local cmd = queue and queue[i]
	if queuedSeats[transporterID] + Spring.GetUnitRulesParam(transporterID, "usedSeats") < Spring.GetUnitRulesParam(transporterID, "nSeats") then
		while cmd and cmd.id == CMD_LOAD_UNIT and (queuedSeats[transporterID] + Spring.GetUnitRulesParam(transporterID, "usedSeats") < Spring.GetUnitRulesParam(transporterID, "nSeats")) do
			local teeID = cmd.params[1]
			if spGetUnitTransporter(teeID) == transporterID then
				idsToRemove[teeID] = true -- already loaded, mark command for removal
			elseif transporterID ~= claimedBy[teeID] then
				claimTransportee(transporterID, teeID, TransportAPI.GetTransporteeSize(teeID), true) -- force claim for ourselves
			end
			i = i + 1
			cmd = queue and queue[i]
		end
	elseif not (Spring.GetUnitRulesParam(transporterID, "usedSeats") < Spring.GetUnitRulesParam(transporterID, "nSeats")) then -- we still have queued commands despite being full, they can't be performed
		while cmd and cmd.id == CMD_LOAD_UNIT do
			idsToRemove[cmd.params[1]] = true -- mark command for removal
			i = i + 1
			cmd = queue and queue[i]
		end
	end

	-- 2: proceed to loading all units in queue
	local terPosX, terPosY, terPosZ = spGetUnitPosition(transporterID)
	for i = #transporterClaims[transporterID], 1, -1 do
		if claimedBy[transporterClaims[transporterID][i]] ~= transporterID then -- keep it during test runs so we can debug if this ever happens
			spEcho("Error: claim inconsistency for transportee " .. transporterClaims[transporterID][i] .. " in transporter " .. transporterID .. "'s claims list")
		end
		local teeID = transporterClaims[transporterID][i]
		local moveToTransporter = true
		local removeFromQueue = false
		local canLoadNow = true
		if spValidUnitID(teeID) then
			local tx, ty, tz = spGetUnitPosition(teeID)
			local teeTeam = spGetUnitTeam(teeID)
			local losState = spGetUnitLosState(teeID, spGetUnitAllyTeam(transporterID), false)
			local alliedTee = spAreTeamsAllied(teeTeam, transporterTeam)
			if not losState or not (losState.los or losState.radar) then
				canLoadNow = false
				removeFromQueue = true
				moveToTransporter = false
			end
			if teeTeam ~= transporterTeam then
				local teeHasQ = Spring.GetUnitCommands(teeID, 1)
				if teeHasQ and teeHasQ[1] then
					moveToTransporter = false -- if it's performing a command, don't give it a movegoal that might interfere
				elseif not alliedTee then
					moveToTransporter = false -- enemy unit don't give it a movegoal that would make it move towards our transport
				end
			end
			if not CanTransport(transporterID, teeID, transporterDefID, false) then
				removeFromQueue = true
				canLoadNow = false
				moveToTransporter = false
			end
			if dist2D(tx, tz, terPosX, terPosZ) > 512 then -- hardcoded 512 for test, it's a threshold so units don't start moving towards trans from afar
				moveToTransporter = false
				canLoadNow = false
			end
			local _, _, _, vw = spGetUnitVelocity(teeID)
			if inRange(transporterID, tx, ty, tz) and spGetUnitRulesParam(transporterID, "canLoad") == 1  and (alliedTee or vw < 0.5)then
				moveToTransporter = false
				removeFromQueue = true
			else
				canLoadNow = false
			end		
			if moveToTransporter then -- do not order skipped transportees
				spSetUnitMoveGoal(teeID, terPosX, spGetGroundHeight(terPosX, terPosZ), terPosZ,64,nil, true) -- moves to the transport
			end
		else
			removeFromQueue = true
			moveToTransporter = false
		end
		if canLoadNow then
			customTransportLoad[transporterDefID](transporterID, 'PerformLoad', teeID)
		end
		if moveToTransporter then
			spSetUnitMoveGoal(teeID, terPosX, spGetGroundHeight(terPosX, terPosZ), terPosZ,64,nil, true) -- moves to the transport
		end
		if removeFromQueue then
			idsToRemove[teeID] = true
		end
	end
	if spValidUnitID(transporterClaims[transporterID][1]) then
		-- move to first in queue, not avg pos, in case of blocked or immobile tees
		local tee1x, tee1y, tee1z = spGetUnitPosition(transporterClaims[transporterID][1])
		spSetUnitMoveGoal(transporterID, tee1x, tee1y, tee1z)
	end
	-- remove invalidated/finished commands
	for teeID,v in pairs(idsToRemove) do
		releaseTransportee(teeID) -- release claim so it can be targeted by future loads
		for i = 1, #queue do
			if queue[i].id == CMD_LOAD_UNIT and queue[i].params[1] == teeID then -- find the corresponding command
				Spring.GiveOrderToUnit(transporterID, CMD.REMOVE, {queue[i].tag}, 0) -- consume the command so the transporter proceeds to the next
				break
			end
		end
	end
end

------------------
--Gadget Callins--
------------------

function gadget:Initialize()
	for _, unitID in pairs(spGetAllUnits()) do -- save/load compat
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
	end
	spSetCustomCommandDrawData(CMD_AREA_LOAD, CMD.LOAD_UNITS, {0.6, 0.6, 1, 0.5}, true)
	spSetCustomCommandDrawData(CMD_LOAD_UNIT, CMD.LOAD_UNITS, {0.6, 0.6, 1, 0.5}, true)

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
		local cmds = Spring.GetUnitCommands(unitID, 1)
		if not (cmds[1] and (cmds[1].id == CMD_AREA_LOAD or cmds[1].id == CMD.LOAD_UNITS)) then
			releaseAllClaims(unitID)
		end
	end
end

function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
	if transporterClaims[unitID] then
		local cmds = Spring.GetUnitCommands(unitID, 1)
		if not (cmds[1] and (cmds[1].id == CMD_AREA_LOAD or cmds[1].id == CMD.LOAD_UNITS)) then
			releaseAllClaims(unitID)
		end
	end
end

function gadget:UnitGiven(unitID, unitDefID, oldTeam, newTeam)
	releaseTransportee(unitID)
	releaseAllClaims(unitID)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	releaseTransportee(unitID)  -- no-op if not claimed
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
		local count = 0
		for transporterID, co in pairs(areaLoadCoroutines) do count = count + 1 end
		for transporterID, co in pairs(areaLoadCoroutines) do
			local status = coroutine.status(co)
			if status == "suspended" then
				local ok, err = coroutine.resume(co)
				if not ok then
					spEcho("Error in CMD_AREA_LOAD coroutine for transporter " .. transporterID .. ": " .. err)
					areaLoadCoroutines[transporterID] = nil
				end
			else
				areaLoadCoroutines[transporterID] = nil
			end
		end
		for transporterID, co in pairs(successiveLoadCoroutines) do
			local status = coroutine.status(co)
			if status == "suspended" then
				local ok, err = coroutine.resume(co)
				if not ok then
					spEcho("Error in CMD_LOAD_UNIT coroutine for transporter " .. transporterID .. ": " .. err)
					successiveLoadCoroutines[transporterID] = nil
				end
			else
				successiveLoadCoroutines[transporterID] = nil
			end
		end
end


-- CMD_AREA_LOAD lifecycle:
-- 1. On first CommandFallback, ExecuteAreaLoad runs: if no claimable units (or all are instantly loaded), the command finishes immediately with no coroutine.
-- 2. If there are claimable units, a coroutine is started to monitor the area and manage claiming/loading over time.
-- 3. The coroutine continues running until the command is either completed or removed from the queue.
-- 4. When all claims are resolved, a final CommandFallback call with finished = true is required to finish the command; the coroutine will then detect this and stop.

-- CMD_LOAD_UNIT lifecycle:
-- 1. On CommandFallback, ExecuteSuccessiveLoadUnits runs to update the queue and attempt to load units in order. If a CMD_LOAD_UNIT command is still in the queue after this, a coroutine is started to monitor the queue and manage claiming/loading over time.
-- 2. The coroutine continues running until the successive load commands are removed from the queue (either by being finished or by being invalidated), at which point it stops.

function gadget:CommandFallback(transporterID, transporterDefID, transporterTeam, cmdID, cmdParams, cmdOptions, cmdTag)
	if cmdID == CMD_LOAD_UNIT then
		ExecuteSuccessiveLoadUnits(transporterID, transporterDefID, transporterTeam)
		if not successiveLoadCoroutines[transporterID] then
			local co = coroutine.create(function()
					while true do
						coroutine.yield() -- ticked by GameFrame every frame
						local Q = spGetUnitCommands(transporterID, 1)
						local cmd = Q and Q[1]
						if not (cmd and cmd.id == CMD_LOAD_UNIT) then
							successiveLoadCoroutines[transporterID] = nil
							releaseAllClaims(transporterID)
							break
						end
						ExecuteSuccessiveLoadUnits(transporterID, transporterDefID, transporterTeam)
					end
			end)
			successiveLoadCoroutines[transporterID] = co
		end
		return true, false
	end
	if cmdID ~= CMD_AREA_LOAD then return false, false end -- we do not handle this command;
	local finished = ExecuteAreaLoad(transporterID, transporterDefID, transporterTeam, cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4])
	-- 1st pass of ExecuteAreaLoad: attempt to instantly finish cmd to avoid spawning a coroutine
	if finished and spGetUnitRulesParam(transporterID, "canLoad") == 0 then
		-- optional: if we're busy unloading, don't finish the command yet
		-- this enables overlapping area load/unload cycles
		finished = false
	end
	if not finished then
		if not areaLoadCoroutines[transporterID] then -- only start a coroutine if one doesn't already exist for this transporter.
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
						areaLoadCoroutines[transporterID] = nil
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
					ExecuteAreaLoad(transporterID, transporterDefID, transporterTeam, cx, cy, cz, radius)					
					-- Could Spring.UnitFinishCommand() here instead of waiting next CommandFallback if we need to stop the coroutine ASAP for perfs
				end
			end)
			areaLoadCoroutines[transporterID] = co
		end
		return true, false -- handled, but not finished; keep command in queue
	end
	return true, true -- handled and finished; remove command from queue
end

function gadget:AllowUnitTransport(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, fromAreaScan)
	--use our helper CanTransport
	--I separated both to avoid FindUnitToTransport calling gadget:AllowUnitTransportLoad with an additional arg
	return CanTransport(transporterID, transporteeID, transporterUnitDefID, false)
end

-- since the custom command is only CMD_AREA_LOAD
-- single targets CMD.LOAD_UNITS are handled from AllowUnitTransportLoad
-- which only fires during LOAD_UNITS cmds, once ter,tee dist is < Udef.loadingRadius
-- I guess at some point this should become its own custom command instead

--[[function gadget:AllowUnitTransportLoad(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, goalX, goalY, goalZ)
	if isUnderwater(transporteeID, goalY) then 
		releaseTransportee(transporteeID)
		return false 
	end
	if not isAirTransport[transporterUnitDefID] then return true end -- we're not handling this
	-- distance gate for individual load commands
	claimTransportee(transporterID, transporteeID, TransportAPI.GetTransporteeSize(transporteeID),true) -- claim the transportee for this load command; will be released in UnitLoaded or if the unit dies while claimed
	spSetUnitMoveGoal(transporterID, goalX, goalY, goalZ) -- move closer
	if not inRange(transporterID, goalX, goalY, goalZ) then -- not in range yet
		return false
	end
	-- make it harder to pull enemy units: velocity gate
	if not spAreTeamsAllied(spGetUnitTeam(transporterID), spGetUnitTeam(transporteeID))
	and select(4, spGetUnitVelocity(transporteeID)) >= 0.5 then
		return false
	end
	-- handle custom transports
	if customTransportLoad[transporterUnitDefID] then
		if spGetUnitRulesParam(transporterID, "canLoad") == 0 then return false end -- canLoad gate
		releaseTransportee(transporteeID) -- release the pre-queue claim; also done in UnitLoaded as a safety net
		customTransportLoad[transporterUnitDefID](transporterID, 'PerformLoad', transporteeID)
		spUnitFinishCommand(transporterID) -- consume the command so the transporter proceeds to the next
		return false
	end
	return true -- default for standard transports
end]]--

function gadget:AllowUnitTransportUnload(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, goalX, goalY, goalZ)
	if isUnderwater(transporteeID, goalY) then return false end
	if not isAirTransport[transporterUnitDefID] then return true end	
	spSetUnitMoveGoal(transporterID, goalX, goalY, goalZ) -- move closer
	-- distance gate for individual unload commands
	if not inRange(transporterID, goalX, goalY, goalZ) then
		return false
	end	
	-- handle custom transports
	if customTransportUnload[transporterUnitDefID] then
		if spGetUnitRulesParam(transporterID, "canUnload") == 0 then return false end
		local targets = TransportAPI.GetUnloadTargets(transporterID, transporteeID)
		for _, teeID in ipairs(targets) do
			customTransportUnload[transporterUnitDefID](transporterID, 'PerformUnload', teeID, goalX, goalY, goalZ)
		end
		spUnitFinishCommand(transporterID) -- consume the command so the transporter proceeds to the next
		return false
	end
	return true -- default for standard transports
end


function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdID == CMD.LOAD_ONTO then
		spEcho("Warning: CMD_LOAD_ONTO is deprecated and will be removed in a future update; use CMD.INSERT + CMD_LOAD_UNIT instead")
		spGiveOrderToUnit( cmdParams[1], CMD.INSERT, { 0, CMD_LOAD_UNIT, 0, unitID }, {"alt"}) -- insert in front of queue
		return false
	elseif cmdID == CMD.INSERT and cmdParams[2] == CMD.LOAD_ONTO then
		spEcho("Warning: CMD_LOAD_ONTO is deprecated and will be removed in a future update; this command will be ignored")
		return false
	end
	if not isAirTransport[unitDefID] then return true, true end
	if cmdID == CMD.LOAD_UNITS then
		if #cmdParams == 4 then
			spGiveOrderToUnit(unitID, CMD_AREA_LOAD, cmdParams, cmdOptions)
			return false
		elseif #cmdParams == 1 then
			spGiveOrderToUnit(unitID, CMD_LOAD_UNIT, cmdParams, cmdOptions)
			return false
		end
	end

	if cmdID == CMD.INSERT and cmdParams[2] == CMD.LOAD_UNITS then
		if #cmdParams - 3 == 4 then
			local newParams = { cmdParams[1], CMD_AREA_LOAD, cmdParams[3],
								cmdParams[4], cmdParams[5], cmdParams[6], cmdParams[7] }
			spGiveOrderToUnit(unitID, CMD.INSERT, newParams, cmdOptions)
			return false
		elseif #cmdParams - 3 == 1 then
			local newParams = { cmdParams[1], CMD_LOAD_UNIT, cmdParams[3], cmdParams[4] }
			spGiveOrderToUnit(unitID, CMD.INSERT, newParams, cmdOptions)
			return false
		end

	end
	return true, true
end