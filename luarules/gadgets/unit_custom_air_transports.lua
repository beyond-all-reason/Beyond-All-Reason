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

-- Constants
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local alliedDist = mapSizeX * mapSizeZ          -- priority offset: own team < allied < enemy (never)
local maxDistSq = 2 * alliedDist               -- guaranteed > any real sq distance on the map
local LOAD_RADIUS = 128    -- elmos XZ; transporter must be within this range to fire PerformLoad
local CMD_AREA_LOAD = 39751 -- custom area-load command; needs to be logged in customcmds
local CMD_LOAD_UNIT = 39752 -- custom load-unit command; needs to be logged in customcmds

local customTransportLoad = {} -- terDefID → LUS function or COB script function
local customTransportUnload = {} -- terDefID → LUS function or COB script function
local claimedBy = {} -- teeID → terID;
local queuedSeats = {} -- terID → number seats
local transporterClaims = {} -- terID → { teeID, teeID, ... }
local areaLoadCoroutines = {} -- terID → coroutine
local successiveLoadCoroutines = {} -- terID → coroutine
local cylinderCache = {} -- [key] = { frame = N, units = {...} }
local isAirTransport = {} -- terDefID → bool;

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

---@param teeID number
---@param y number
---@return boolean isUnderwater

local function isUnderwater(teeID, y) -- i leave it hanging for now; TODOO: use engine's phys state bit or exact same calc to match
	local height = spGetUnitHeight(teeID)
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

---@param terID number
---@param goalX number
---@param goalY number
---@param goalZ number
---@return boolean inRange

local function inRange(terPosX, terPosY, terPosZ, goalX, goalY, goalZ)
	local dY = terPosY - goalY
	return dist2D(terPosX, terPosZ, goalX, goalZ) <= LOAD_RADIUS and dY >= 0
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


---
--- @param teeID number
--- @param teeDefID number
--- @param teePosY number
--- @param terID number
--- @param terAllyTeam number  -- transporter allyTeam (not teamID!)
--- @return boolean
local function CanBeTransportedStatic(teeID, teeDefID, terID) -- things that should cancel or deny queueing and are mostly immutable
	if not spValidUnitID(teeID) then
		return false
	end
	if teeID == terID then
		return false	
	end
	if UnitDefs[teeDefID].cantBeTransported then
		return false	
	end
	if spGetUnitIsBeingBuilt(teeID) then -- considered immutable; while it can become false, it can never become true again.
		return false	
	end
	return true
end

---
--- @param teeID number
--- @param teeDefID number
--- @param teePosY number
--- @param terID number
--- @param terAllyTeam number  -- transporter allyTeam (not teamID!)
--- @return boolean
local function CanBeTransportedDynamic(teeID, teeDefID, teePosY, terID, terAllyTeam)  -- things that might have changed since CanBeTransportedStatic and should cancel queue (lightweight check for dynamic conditions))
	if not spValidUnitID(teeID) then
		return false
	end
	if spGetUnitTransporter(teeID) ~= nil then
		return false	
	end
	local losState = spGetUnitLosState(teeID, terAllyTeam, false)
	if not losState or not (losState.los or losState.radar) then
		return false	
	end
	if isUnderwater(teeID, teePosY) then
		return false
	end
	if spGetUnitRulesParam(teeID, "inTransportAnim") == 1 then
		return false	
	end
	return true
end

---
--- @param teeID number
--- @param terAllyTeam number  -- transporter allyTeam (not teamID!)
--- @return boolean
local function CanBeAutoClaimed(teeID, terAllyTeam) -- things that should only deny queueing if within area cmds
	if not spValidUnitID(teeID) then
		return false
	end
	return not claimedBy[terAllyTeam][teeID]
end

---
--- @param terID number
--- @param teeID number
--- @param terDefID number
--- @param teeSize number
--- @param includeQueue boolean
--- @return boolean
local function CanTransporteeFitInTransporter(terID, teeID, terDefID, teeSize, includeQueue) -- size check, either including queue (if within area cmd) or ignoring it
	if not spValidUnitID(teeID) then
		return false
	end
	local nSeats    = spGetUnitRulesParam(terID, "nSeats")    or 0
	local usedSeats = spGetUnitRulesParam(terID, "usedSeats") or 0
	local queued    = includeQueue and (queuedSeats[terID] or 0) or 0
	if nSeats - usedSeats - queued < teeSize then
		return false
	end
	local slotSizesStr = spGetUnitRulesParam(terID, "slotSizes") or ""
	local foundSlot = false
	for sizeStr in slotSizesStr:gmatch("[^,]+") do
		if tonumber(sizeStr) == teeSize then foundSlot = true; break end
	end
	if not foundSlot then
		return false
	end
	return true
end

---
--- @param teeID number
--- @param teeTeamID number  -- transportee teamID
--- @param teePosX number
--- @param teePosY number
--- @param teePosZ number
--- @param terID number
--- @param terTeamID number  -- transporter teamID
--- @param terPosX number
--- @param terPosY number
--- @param terPosZ number
--- @return boolean
local function CanBeTransportedNow(teeID, teeTeamID, teePosX, teePosY, teePosZ, terID, terTeamID, terPosX, terPosY, terPosZ) -- things that should delay loading without removing from queue
	if not inRange(terPosX, terPosY, terPosZ, teePosX, teePosY, teePosZ) then
		return false
	end
	if not spAreTeamsAllied(teeTeamID, terTeamID) then
		local _,_,_,vw = spGetUnitVelocity(teeID)
		if vw > 0.5 then
			return false -- if it's moving too fast, we consider it as fleeing and don't load it.
		end
	end
	return true
end

---
--- @param teeID number
--- @param teeTeamID number  -- transportee teamID
--- @param terID number
--- @param terTeamID number  -- transporter teamID
--- @return boolean
local function CanMoveToTransporter(teeID, teeTeamID, terID, terTeamID) -- things that should allow moving towards transporter to facilitate loading
	if teeTeamID == terTeamID then
		return true -- if it's the same team, we can move it towards the transport to facilitate loading
	end
	if spAreTeamsAllied(teeTeamID, terTeamID) then
		local hasQ = Spring.GetUnitCommands(teeID, 0) >= 1
		return not hasQ -- if it's an allied unit, we only can if it's idling
	else
		return false -- if it's an enemy unit, we never can
	end
end

---
--- @param teeID number
--- @param terAllyTeam number  -- transporter allyTeam (not teamID!)
--- @return nil
local function releaseTransportee(teeID, terAllyTeam)
	local terID = claimedBy[terAllyTeam][teeID]
	if not terID then return end
	claimedBy[terAllyTeam][teeID] = nil
	if transporterClaims[terID] then
		local total = 0
		local resumeFrom = #transporterClaims[terID]
		for i = resumeFrom, 1, -1 do
			if transporterClaims[terID][i] == teeID then 
				table.remove(transporterClaims[terID], i) 
				resumeFrom = i - 1
				break
			end
			total = total + (TransportAPI.GetTransporteeSize(transporterClaims[terID][i]) or 0)
		end
		if resumeFrom > 0 then
			for i = resumeFrom, 1, -1 do
				total = total + (TransportAPI.GetTransporteeSize(transporterClaims[terID][i]) or 0)
			end
		end
		queuedSeats[terID] = total
	else
		queuedSeats[terID] = 0
	end
end

---
--- @param terID number
--- @param teeID number
--- @param teeSize number
--- @param manualClaim boolean
--- @return boolean claimSuccessful
local function claimTransportee(terID, teeID, teeSize, manualClaim)
	local terAllyTeam = spGetUnitAllyTeam(terID)
	if not manualClaim and claimedBy[terAllyTeam][teeID] then return false end -- already claimed by another transporter from the allyTeam, and this is not a manual claim (from CMD_LOAD_UNIT))
	if claimedBy[terAllyTeam][teeID] then 
		releaseTransportee(teeID, terAllyTeam) -- release previous claim
	end
	claimedBy[terAllyTeam][teeID] = terID
	transporterClaims[terID][#transporterClaims[terID] + 1] = teeID
	local total = 0
	local ct = 0
	for i = #transporterClaims[terID], 1, -1 do
		if transporterClaims[terID][i] == teeID then
			ct = ct + 1
			if ct > 1 then
				spEcho("Error: duplicate claim for transportee " .. teeID .. " in transporter " .. terID .. "'s claims list") -- debug kept for now to debug potential double claims
			end
		end
		total = total + (TransportAPI.GetTransporteeSize(transporterClaims[terID][i]) or 0)
	end
	queuedSeats[terID] = total
	return true
end

---
--- @param terID number
--- @return nil
local function releaseAllClaims(terID)
	local claims = transporterClaims[terID]
	if not claims then return end
	local terAllyTeam = spGetUnitAllyTeam(terID)
	for _, teeID in ipairs(claims) do
		claimedBy[terAllyTeam][teeID] = nil
	end
	transporterClaims[terID] = {}
	queuedSeats[terID] = 0
end

---
--- @param terID number
--- @param terDefID number
--- @param terTeamID number  -- transporter teamID
--- @param cx number
--- @param cz number
--- @param radius number
--- @return number|nil bestUnit
local function findUnitToTransport(terID, terDefID, terTeamID, cx, cz, radius)
	local terAllyTeam      = Spring.GetUnitAllyTeam(terID)
	local terPosX, terPosY, terPosZ = spGetUnitPosition(terID)
	local units = getCachedUnitsInCylinder(cx, cz, radius, terAllyTeam)
	local bestUnit = nil
	local bestDist = maxDistSq
	if spGetUnitRulesParam(terID, "nSeats") <= spGetUnitRulesParam(terID, "usedSeats") + (queuedSeats[terID] or 0) then
		-- early exit if no seats
		return nil
	end
	-- TODO: remove unclaimable units from cache at runtime
	for idx, teeID in ipairs(units) do
		repeat
			if not CanBeAutoClaimed(teeID, terAllyTeam) then break end
			local teeDefID = spGetUnitDefID(teeID)
			local teeTeamID = spGetUnitTeam(teeID)
			local teeSize = TransportAPI.GetTransporteeSize(teeID)
			if not CanBeTransportedStatic(teeID, teeDefID, terID) then break end
			local teePosX, teePosY, teePosZ = spGetUnitPosition(teeID)
			if not CanBeTransportedDynamic(teeID, teeDefID, teePosY, terID, terAllyTeam) then break end
			if not CanTransporteeFitInTransporter(terID, teeID, terDefID, teeSize, true) then break end
			local dx, dz    = teePosX - terPosX, teePosZ - terPosZ
			local rawDistSq = dx * dx + dz * dz
			-- alliedDist is the offset applied to allied units, by definition dist < alliedDist for all units (alliedDist = mapSizeX*mapSizeZ)
			local unitDist  = (teeTeamID == terTeamID) and rawDistSq or (rawDistSq + alliedDist)
			if unitDist >= bestDist then break end
			bestDist = unitDist
			bestUnit = teeID
		until true
	end
	return bestUnit
end

---
--- @param terID number
--- @param terDefID number
--- @param terTeamID number  -- transporter teamID
--- @param terPosX number
--- @param terPosY number
--- @param terPosZ number
--- @param cx number
--- @param cy number
--- @param cz number
--- @param radius number
--- @return nil
local function ExecuteLoadUnits(terID, terDefID, terTeamID, terPosX, terPosY, terPosZ, cx, cy, cz, radius)
	local terAllyTeam = spGetUnitAllyTeam(terID)
	local terTeamID = spGetUnitTeam(terID)
	for i = #transporterClaims[terID], 1, -1 do
		local teeID = transporterClaims[terID][i]
		local teePosX, teePosY, teePosZ = spGetUnitPosition(teeID)
		local teeDefID = spGetUnitDefID(teeID)
		local removalFlag = false
		local moveToTransporterFlag = false
		if claimedBy[terAllyTeam][teeID] ~= terID then -- keep it during test runs so we can debug if this ever happens
			spEcho("Error: claim inconsistency for transportee " .. teeID .. " in transporter " .. terID .. "'s claims list")
		end
		if not CanBeTransportedDynamic(teeID, teeDefID, teePosY, terID, terAllyTeam) then
			removalFlag = true
		end
		local teeSize = TransportAPI.GetTransporteeSize(teeID)
		if not CanTransporteeFitInTransporter(terID, teeID, terDefID, teeSize, false) then
			removalFlag = true
		end
		local teeTeamID = spGetUnitTeam(teeID)
		if removalFlag then
			releaseTransportee(teeID, terAllyTeam) -- release claim so it can be targeted by future loads
		elseif CanBeTransportedNow(teeID, teeTeamID, teePosX, teePosY, teePosZ, terID, terAllyTeam, terPosX, terPosY, terPosZ) then
			customTransportLoad[terDefID](terID, 'PerformLoad', teeID)
			removalFlag = true
		elseif dist2D(terPosX, terPosZ, cx, cz) < radius and CanMoveToTransporter(teeID, teeTeamID, terID, terTeamID) then
			moveToTransporterFlag = true
		end
		if moveToTransporterFlag then
			spSetUnitMoveGoal(teeID, terPosX, spGetGroundHeight(terPosX, terPosZ), terPosZ,64,nil, true) -- moves to the transport
		end
		if removalFlag then
			releaseTransportee(teeID, terAllyTeam) -- release claim so it can be targeted by future loads
		end
	end

	if spValidUnitID(transporterClaims[terID][1]) then -- because it might now be empty after releasing claims, check before trying to access
		-- move to first in queue, not avg pos, in case of blocked or immobile tees
		local tee1x, tee1y, tee1z = spGetUnitPosition(transporterClaims[terID][1])
		spSetUnitMoveGoal(terID, tee1x, tee1y, tee1z)
	end
end


---
--- @param terID number
--- @param terDefID number
--- @param terTeamID number  -- transporter teamID
--- @param cx number
--- @param cy number
--- @param cz number
--- @param radius number
--- @return boolean commandFinished
local function ExecuteAreaLoad(terID, terDefID, terTeamID, cx, cy, cz, radius)
	local teeID = findUnitToTransport(terID, terDefID, terTeamID, cx, cz, radius)
	
	-- OPTION: one per frame or until filled
	-- if perfs are a concern, or if you want units to be split among area-loading transports, use one per frame
	-- i personnally prefer in batch as it allows the commands to be instantly performed in some edge cases

	if teeID then
		claimTransportee(terID, teeID, TransportAPI.GetTransporteeSize(teeID), false)
	end
	--[[while teeID do
		claimTransportee(terID, teeID, TransportAPI.GetTransporteeSize(teeID), false)
		teeID = findUnitToTransport(terID, terDefID, terTeamID, cx, cz, radius)
	end]]--

	if queuedSeats[terID] == 0 then -- queuedSeats val ~= #transporterClaims but both are 0 when no queue.
		areaLoadCoroutines[terID] = nil
		return true -- either no claimable units, or all claims loaded, command is finished
	end
	local terPosX, terPosY, terPosZ = spGetUnitPosition(terID)
	local distToArea = dist2D(terPosX, terPosZ, cx, cz)
	if distToArea < radius then
		ExecuteLoadUnits(terID, terDefID, terTeamID, terPosX, terPosY, terPosZ, cx, cy, cz, radius)
	else
		spSetUnitMoveGoal(terID, cx, cy, cz, 64)
	end
	return false -- command is still in progress
end

---
--- @param terID number
--- @param terDefID number
--- @param terTeamID number  -- transporter teamID
--- @return nil
local function ExecuteSuccessiveLoadUnits(terID, terDefID, terTeamID)
	local idsToRemove = {}
	local terAllyTeam = spGetUnitAllyTeam(terID)
	-- 1: Get current queue, remove invalid units, claim valid ones
	local queue = spGetUnitCommands(terID,  Spring.GetUnitRulesParam(terID, "nSeats")) --  Spring.GetUnitRulesParam(terID, "nSeats") being the max number of units we can queue on a single transport
	local i = 1
	local cmd = queue and queue[i]
	if queuedSeats[terID] + Spring.GetUnitRulesParam(terID, "usedSeats") < Spring.GetUnitRulesParam(terID, "nSeats") then
		while cmd and cmd.id == CMD_LOAD_UNIT and (queuedSeats[terID] + Spring.GetUnitRulesParam(terID, "usedSeats") < Spring.GetUnitRulesParam(terID, "nSeats")) do
			local teeID = cmd.params[1]
			local teeDefID = spGetUnitDefID(teeID)
			local _, teePosY = spGetUnitPosition(teeID)
			if not CanBeTransportedStatic(teeID, teeDefID, terID) then
				idsToRemove[teeID] = true -- can't be transported, mark for removal
			elseif not CanBeTransportedDynamic(teeID, teeDefID, teePosY, terID, terAllyTeam) then
				idsToRemove[teeID] = true -- can't be transported right now, mark for removal
			elseif terID ~= claimedBy[terAllyTeam][teeID] then
				claimTransportee(terID, teeID, TransportAPI.GetTransporteeSize(teeID), true) -- force claim for ourselves if not already claimed
			end
			i = i + 1
			cmd = queue and queue[i]
		end
	elseif (Spring.GetUnitRulesParam(terID, "usedSeats") >= Spring.GetUnitRulesParam(terID, "nSeats")) then -- we still have queued commands despite being full, they can't be performed
		while cmd and cmd.id == CMD_LOAD_UNIT do
			local teeID = cmd.params[1]
			idsToRemove[teeID] = true -- mark command for removal
			i = i + 1
			cmd = queue and queue[i]
		end
	end

	-- 2: proceed to loading all units in queue
	local terPosX, terPosY, terPosZ = spGetUnitPosition(terID)
	local terTeamID = spGetUnitTeam(terID)
	for i = #transporterClaims[terID], 1, -1 do
		local teeID = transporterClaims[terID][i]
		local teeDefID = spGetUnitDefID(teeID)
		local teePosX, teePosY, teePosZ = spGetUnitPosition(teeID)
		local removalFlag = false
		local moveToTransporterFlag = false
		if claimedBy[terAllyTeam][teeID] ~= terID then -- keep it during test runs so we can debug if this ever happens
			spEcho("Error: claim inconsistency for transportee " .. teeID .. " in transporter " .. terID .. "'s claims list")
		end
		if not CanBeTransportedDynamic(teeID, teeDefID, teePosY, terID, terAllyTeam) then
			removalFlag = true
		end
		local teeSize = TransportAPI.GetTransporteeSize(teeID)
		if not CanTransporteeFitInTransporter(terID, teeID, terDefID, teeSize, false) then
			removalFlag = true
		end
		local teeTeamID = spGetUnitTeam(teeID)
		if removalFlag then
			idsToRemove[teeID] = true
		elseif CanBeTransportedNow(teeID, teeTeamID, teePosX, teePosY, teePosZ, terID, terAllyTeam, terPosX, terPosY, terPosZ) then
			customTransportLoad[terDefID](terID, 'PerformLoad', teeID)
			removalFlag = true
		elseif dist2D(terPosX, terPosZ, teePosX, teePosZ) < 512  and CanMoveToTransporter(teeID, teeTeamID, terID, terTeamID) then
			moveToTransporterFlag = true
		end
		if moveToTransporterFlag then -- do not order skipped transportees
			spSetUnitMoveGoal(teeID, terPosX, spGetGroundHeight(terPosX, terPosZ), terPosZ,64,nil, true) -- moves to the transport
		end
		if removalFlag then
			idsToRemove[teeID] = true
		end
	end
	-- remove invalidated/finished commands before giving a move goal, making sure don't accidently movegoal to a skipped unit
	for teeID,v in pairs(idsToRemove) do
		releaseTransportee(teeID, terAllyTeam) -- release claim so it can be targeted by future loads
		for i = 1, #queue do
			if queue[i].id == CMD_LOAD_UNIT and queue[i].params[1] == teeID then -- find the corresponding command
				spGiveOrderToUnit(terID, CMD.REMOVE, {queue[i].tag}, 0) -- consume the command so the transporter proceeds to the next
				break
			end
		end
	end
	if spValidUnitID(transporterClaims[terID][1]) then --it could have been loaded
		-- move to first in queue, not avg pos, in case of blocked or immobile tees
		local tee1x, tee1y, tee1z = spGetUnitPosition(transporterClaims[terID][1])
		spSetUnitMoveGoal(terID, tee1x, tee1y, tee1z)
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
	gadgetHandler:RegisterAllowCommand(CMD.LOAD_UNITS)
	gadgetHandler:RegisterAllowCommand(CMD.LOAD_ONTO)
	local allyTeams = Spring.GetAllyTeamList()
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
	local terAllyTeam = spGetUnitAllyTeam(unitID)
	releaseTransportee(unitID, terAllyTeam)
	releaseAllClaims(unitID)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local terAllyTeam = spGetUnitAllyTeam(unitID)
	releaseTransportee(unitID, terAllyTeam)  -- no-op if not claimed
	releaseAllClaims(unitID)    -- no-op if not a transporter with claims
	local terID = spGetUnitTransporter(unitID)
	if not terID then return end
	local terDefID = spGetUnitDefID(terID)
	if customTransportUnload[terDefID] then
		local gx, gy, gz = spGetUnitPosition(terID)
		customTransportUnload[terDefID](terID, 'PerformUnload', unitID, gx, gy, gz)
	end
end

function gadget:GameFrame(frame)
	for terID, co in pairs(areaLoadCoroutines) do
		local status = coroutine.status(co)
		if status == "suspended" then
			local ok, err = coroutine.resume(co)
			if not ok then
				spEcho("Error in CMD_AREA_LOAD coroutine for transporter " .. terID .. ": " .. err)
				areaLoadCoroutines[terID] = nil
			end
		else
			areaLoadCoroutines[terID] = nil
		end
	end
	for terID, co in pairs(successiveLoadCoroutines) do
		local status = coroutine.status(co)
		if status == "suspended" then
			local ok, err = coroutine.resume(co)
			if not ok then
				spEcho("Error in CMD_LOAD_UNIT coroutine for transporter " .. terID .. ": " .. err)
				successiveLoadCoroutines[terID] = nil
			end
		else
			successiveLoadCoroutines[terID] = nil
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

function gadget:CommandFallback(terID, terDefID, terTeamID, cmdID, cmdParams, cmdOptions, cmdTag)
	if cmdID == CMD_LOAD_UNIT then
		ExecuteSuccessiveLoadUnits(terID, terDefID, terTeamID)
		if not successiveLoadCoroutines[terID] then
			local co = coroutine.create(function()
					while true do
						coroutine.yield() -- ticked by GameFrame every frame
						local Q = spGetUnitCommands(terID, 1)
						local cmd = Q and Q[1]
						if not (cmd and cmd.id == CMD_LOAD_UNIT) then
							successiveLoadCoroutines[terID] = nil
							releaseAllClaims(terID)
							break
						end
						ExecuteSuccessiveLoadUnits(terID, terDefID, terTeamID)
					end
			end)
			successiveLoadCoroutines[terID] = co
		end
		return true, false
	end
	if cmdID ~= CMD_AREA_LOAD then return false, false end -- we do not handle this command;
	local finished = ExecuteAreaLoad(terID, terDefID, terTeamID, cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4])
	-- 1st pass of ExecuteAreaLoad: attempt to instantly finish cmd to avoid spawning a coroutine
	if finished and spGetUnitRulesParam(terID, "canLoad") == 0 then
		-- optional: if we're busy unloading, don't finish the command yet
		-- this enables overlapping area load/unload cycles
		finished = false
	end
	if not finished then
		if not areaLoadCoroutines[terID] then -- only start a coroutine if one doesn't already exist for this transporter.
			local cx, cy, cz, radius = cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4]
			-- coroutine params on start
			local co = coroutine.create(function()
				while true do
					coroutine.yield() -- ticked by GameFrame every frame
					coroutine.lastKnownParams = { cx, cy, cz, radius }
					-- update the coroutine's last known params 
					-- so we can detect mid-coroutine changes, instead of exiting + recreating
					local Q = spGetUnitCommands(terID, 1)
					local cmd = Q and Q[1]
					-- are we still performing a CMD_AREA_LOAD ?
					if not (cmd and cmd.id == CMD_AREA_LOAD) then
						-- exit coroutine and clean up if command is finished or removed from queue
						areaLoadCoroutines[terID] = nil
						releaseAllClaims(terID)
						break
					-- have our params changed mid-coroutine ?
					elseif coroutine.lastKnownParams[1] ~= cmd.params[1] or coroutine.lastKnownParams[2] ~= cmd.params[2] or coroutine.lastKnownParams[3] ~= cmd.params[3] or coroutine.lastKnownParams[4] ~= cmd.params[4] then
						-- release all claims but keep the coroutine alive
						releaseAllClaims(terID)
						coroutine.lastKnownParams = cmd.params
						cx, cy, cz, radius = cmd.params[1], cmd.params[2], cmd.params[3], cmd.params[4]
					end
					-- Execute our command logic every tick
					ExecuteAreaLoad(terID, terDefID, terTeamID, cx, cy, cz, radius)					
					-- Could Spring.UnitFinishCommand() here instead of waiting next CommandFallback if we need to stop the coroutine ASAP for perfs
				end
			end)
			areaLoadCoroutines[terID] = co
		end
		return true, false -- handled, but not finished; keep command in queue
	end
	return true, true -- handled and finished; remove command from queue
end

-- still recquired for defaultCommand to work
function gadget:AllowUnitTransport(terID, terDefID, terTeamID, teeID, teeDefID, teeTeamID)
	--use our helper CanTransport
	--I separated both to avoid FindUnitToTransport calling gadget:AllowUnitTransportLoad with an additional arg
	local terAllyTeam = spGetUnitAllyTeam(terID)
	local teePosX, teePosY, teePosZ = spGetUnitPosition(teeID)
	return CanBeTransportedStatic(teeID, teeDefID, terID) and CanBeTransportedDynamic(teeID, teeDefID, teePosY, terID, terAllyTeam) and CanTransporteeFitInTransporter(terID, teeID, terDefID, TransportAPI.GetTransporteeSize(teeID), false)
end

-- unload commands haven't been changed (yet?)
function gadget:AllowUnitTransportUnload(terID, terDefID, terTeamID, teeID, teeDefID, teeTeamID, goalX, goalY, goalZ)
	if isUnderwater(teeID, goalY) then return false end
	if not isAirTransport[terDefID] then return true end	
	spSetUnitMoveGoal(terID, goalX, goalY, goalZ) -- move closer
	-- distance gate for individual unload commands
	local terPosX, terPosY, terPosZ = spGetUnitPosition(terID)
	if not inRange(terPosX, terPosY, terPosZ, goalX, goalY, goalZ) then
		return false
	end	
	-- handle custom transports
	if customTransportUnload[terDefID] then
		if spGetUnitRulesParam(terID, "canUnload") == 0 then return false end
		local targets = TransportAPI.GetUnloadTargets(terID, teeID)
		for _, teeID in ipairs(targets) do
			customTransportUnload[terDefID](terID, 'PerformUnload', teeID, goalX, goalY, goalZ)
		end
		spUnitFinishCommand(terID) -- consume the command so the transporter proceeds to the next
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
	return true, true
end