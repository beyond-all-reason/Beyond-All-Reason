---@diagnostic disable: param-type-mismatch, duplicate-set-field
function widget:GetInfo()
	return {
		name = "Transport To",
		desc = "Adds a map-click Transport To command and auto-assigns transports",
		author = "Silla Noble",
		license = "A what now?",
		layer = 1,
		enabled = true,
		handler = true,
	}
end

local Echo = Spring.Echo
local GetMyPlayerID = Spring.GetMyPlayerID
local GetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitCommands = Spring.GetUnitCommands
local GetUnitIsTransporting = Spring.GetUnitIsTransporting
local spGetUnitPosition = Spring.GetUnitPosition
local GetUnitTeam = Spring.GetUnitTeam
local GiveOrderToUnit = Spring.GiveOrderToUnit
local ValidUnitID = Spring.ValidUnitID
local AreTeamsAllied = Spring.AreTeamsAllied
local GameFrame = Spring.GetGameFrame
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spGetUnitCmdDescs = Spring.GetUnitCmdDescs

-- ========= debug toggles =========
local LOG_VERBOSE = true -- general lifecycle logging
local LOG_DETAIL = false -- per-candidate evaluation spam

-- Pretty, cycle-safe table -> string for debugging.
-- Usage:
--   Echo(debug_tostring(myTable))
--   Echo(debug_tostring(myTable, { maxDepth = 4, sortKeys = true }))
local function debug_tostring(value, opts, _depth, _seen, _label)
	opts = opts or {}
	local indentStr = opts.indent or "  "
	local maxDepth = opts.maxDepth or 3
	local sortKeys = (opts.sortKeys ~= false)
	local maxItems = opts.maxItems or 200
	local showMeta = opts.showMetatable or false
	local compact = opts.compact or false -- compact: fewer newlines/spaces
	local showFuncs = (opts.showFunctions ~= false)

	_depth = _depth or 0
	_seen = _seen or {}

	local function indent(n)
		if compact then
			return ""
		end
		return string.rep(indentStr, n)
	end

	local function asKey(k)
		if type(k) == "string" and k:match("^[_%a][_%w]*$") then
			return k
		else
			return "[" .. debug_tostring(k, opts, _depth + 1, _seen) .. "]"
		end
	end

	local function escapeStr(s)
		return string.format("%q", s)
	end

	local t = type(value)

	if t == "nil" or t == "number" or t == "boolean" then
		return tostring(value)
	elseif t == "string" then
		return escapeStr(value)
	elseif t ~= "table" then
		-- function, userdata, thread
		if showFuncs or t ~= "function" then
			return string.format("<%s:%s>", t, tostring(value))
		else
			return "<function>"
		end
	end

	-- table
	if _seen[value] then
		return string.format("<ref#%d>", _seen[value].id)
	end

	if _depth >= maxDepth then
		return string.format("<table %d items>", (next(value) and #value) or 0)
	end

	local id = 0
	do
		local c = 0
		for _ in pairs(_seen) do
			c = c + 1
		end
		id = c + 1
	end
	_seen[value] = { id = id }

	-- separate array-like and map-like keys
	local arrMax = 0
	local count = 0
	for k, _ in pairs(value) do
		count = count + 1
		if type(k) == "number" and k > 0 and math.floor(k) == k then
			if k > arrMax then
				arrMax = k
			end
		end
	end

	local isArray = true
	do
		local seenCount = 0
		for i = 1, arrMax do
			if value[i] == nil then
				isArray = false
				break
			end
			seenCount = seenCount + 1
		end
		if seenCount ~= count then
			isArray = false
		end
	end

	local pieces = {}
	local openBrace = "{"
	local closeBrace = "}"
	local sep = compact and "," or ","

	if isArray then
		local items = {}
		for i = 1, arrMax do
			if #items >= maxItems then
				items[#items + 1] = "...(truncated)"
				break
			end
			items[#items + 1] = debug_tostring(value[i], opts, _depth + 1, _seen)
		end
		if compact then
			return openBrace .. table.concat(items, ",") .. closeBrace
		else
			local pad = indent(_depth + 1)
			return openBrace
				.. (#items > 0 and ("\n" .. pad .. table.concat(items, ",\n" .. pad) .. "\n" .. indent(_depth)) or "")
				.. closeBrace
		end
	else
		-- collect keys
		local keys = {}
		for k in pairs(value) do
			keys[#keys + 1] = k
		end
		if sortKeys then
			table.sort(keys, function(a, b)
				local ta, tb = type(a), type(b)
				if ta == tb then
					if ta == "string" or ta == "number" then
						return a < b
					end
					return tostring(a) < tostring(b)
				end
				return ta < tb
			end)
		end

		local emitted = 0
		for _, k in ipairs(keys) do
			emitted = emitted + 1
			if emitted > maxItems then
				pieces[#pieces + 1] = compact and "...(truncated)" or (indent(_depth + 1) .. "...(truncated)")
				break
			end
			local v = value[k]
			local kv
			if type(k) == "string" and k:match("^[_%a][_%w]*$") then
				kv = string.format("%s = %s", k, debug_tostring(v, opts, _depth + 1, _seen))
			else
				kv = string.format(
					"[%s] = %s",
					debug_tostring(k, opts, _depth + 1, _seen),
					debug_tostring(v, opts, _depth + 1, _seen)
				)
			end
			if compact then
				pieces[#pieces + 1] = kv
			else
				pieces[#pieces + 1] = indent(_depth + 1) .. kv
			end
		end

		if showMeta then
			local mt = getmetatable(value)
			if mt then
				local mtStr = debug_tostring(mt, opts, _depth + 1, _seen, "metatable")
				local line = compact and ("<metatable>=" .. mtStr) or (indent(_depth + 1) .. "<metatable> = " .. mtStr)
				pieces[#pieces + 1] = line
			end
		end

		if compact then
			return openBrace .. table.concat(pieces, ",") .. closeBrace
		else
			local inner = table.concat(pieces, ",\n")
			if inner == "" then
				return openBrace .. closeBrace
			else
				return openBrace .. "\n" .. inner .. "\n" .. indent(_depth) .. closeBrace
			end
		end
	end
end

local CMDTYPE_ICON_MAP = CMDTYPE.ICON_MAP
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_STOP = CMD.STOP
local CMD_WAIT = CMD.WAIT
local CMD_INSERT = CMD.INSERT
local CMD_MOVE = CMD.MOVE
local CMD_FIGHT = CMD.FIGHT

local CMD_TRANSPORT_TO = GameCMD.TRANSPORT_TO
local CMD_TRANSPORT_TO_DESC = {
	id = CMD_TRANSPORT_TO,
	type = CMDTYPE_ICON_MAP,
	name = "Transport To",
	cursor = nil,
	action = "transport_to",
}

local CMD_AUTO_TRANSPORT = GameCMD.AUTO_TRANSPORT

local MOVE_IF_NONE_FOUND = true
local RETURN_TO_START_POS = true
local HEAVY_TRANSPORT_MASS_THRESHOLD = 3000
local LIGHT_UNIT_SIZE_THRESHOLD = 6
local UNLOAD_RADIUS = 10

local function distanceSq(ax, az, bx, bz)
	local dx, dz = ax - bx, az - bz
	return dx * dx + dz * dz
end

local myTeamID = nil

local isFactoryDef = {}
local isNanoDef = {}
local isBuildingDef = {}
local isCanMoveDef = {}
local isTransportDef = {}
local transportClass = {}
local transportCapacityMass = {}
local transportSizeLimit = {}
local transportCapSlots = {}

local isTransportableDef = {}
local unitMass = {}
local unitXsize = {}

local knownTransports = setmetatable({}, { __mode = "k" })
local busyTransport = {}
--since threads cant yield, we use this to solve requests in the next update
local pendingRequests = {}
--keeps track of which transport is handling which transportee
local transport_jobs = {}

local UPDATE_PERIOD = 0.25
local updateTimer = 0

local function unameByDef(defID)
	local ud = defID and UnitDefs[defID]
	return (ud and ud.name) or ("def:" .. tostring(defID))
end

local function uname(unitID)
	local defID = spGetUnitDefID(unitID)
	return string.format("%s#%d", unameByDef(defID), unitID or -1)
end

local function gf()
	return string.format("gf=%d", GameFrame())
end

local function E(fmt, ...)
	if LOG_VERBOSE then
		Echo(string.format(fmt, ...))
	end
end

local function Ed(fmt, ...)
	if LOG_DETAIL then
		Echo(string.format(fmt, ...))
	end
end

local function buildDefCaches()
	for defID, ud in pairs(UnitDefs) do
		if ud.isTransport and ud.canFly and (ud.transportCapacity or 0) > 0 then
			isTransportDef[defID] = true
			transportCapacityMass[defID] = ud.transportMass or 0
			transportSizeLimit[defID] = ud.transportSize or 0
			transportCapSlots[defID] = ud.transportCapacity or 0
			transportClass[defID] = (transportCapacityMass[defID] >= HEAVY_TRANSPORT_MASS_THRESHOLD) and "heavy"
				or "light"
		end

		local movable = (ud.speed or 0) > 0
		local grounded = not ud.canFly
		local building = ud.isBuilding
		local notCantBeTransported = (ud.cantBeTransported == nil) or (ud.cantBeTransported == false)
		local isNano = ud.isBuilder and not ud.canMove and not ud.isFactory
		local isFactory = ud.isFactory

		if grounded and notCantBeTransported then
			isTransportableDef[defID] = true
		end
		if isNano then
			isNanoDef[defID] = true
			isTransportableDef[defID] = true
		end
		if isFactory then
			isFactoryDef[defID] = true
			isTransportableDef[defID] = true
		end
		if building then
			isBuildingDef[defID] = true
		end
		if movable then
			isCanMoveDef[defID] = true
		end

		unitMass[defID] = ud.mass or 0
		unitXsize[defID] = ud.xsize or 0
	end
end

local function canTransportWithReason(transportID, transportDefID, unitID, unitDefID)
	local trans = GetUnitIsTransporting(transportID)
	if not trans then
		return false, ""
	end
	if #trans > 0 then
		return false, ""
	end

	local maxSize = transportSizeLimit[transportDefID] or 0
	local uSize = unitXsize[unitDefID] or 0
	if maxSize > 0 and (uSize > maxSize * 2) then
		return false, ""
	end

	local capacityMass = transportCapacityMass[transportDefID] or 0
	local uMass = unitMass[unitDefID] or 0
	if capacityMass > 0 and uMass > capacityMass then
		return false, ""
	end

	local q = spGetUnitCommands(transportID, 5) or {}
	if #q > 0 then
		for i = 1, #q do
			if q[i].id == CMD_WAIT then
				return false, ""
			end
		end
		return false, ""
	end

	return true, ""
end

local function unitRequestedType(unitDefID)
	local size = unitXsize[unitDefID] or 0
	local mass = unitMass[unitDefID] or 0
	if size <= LIGHT_UNIT_SIZE_THRESHOLD and mass < HEAVY_TRANSPORT_MASS_THRESHOLD then
		return "light"
	end
	return "heavy"
end

local function isValidAndMine(unitID)
	if not ValidUnitID(unitID) then
		return false
	end
	local team = GetUnitTeam(unitID)
	return team and AreTeamsAllied(team, myTeamID)
end

local function refreshKnownTransports()
	knownTransports = setmetatable({}, { __mode = "k" })
	local units = spGetTeamUnits(myTeamID)
	for i = 1, #units do
		local u = units[i]
		local defID = spGetUnitDefID(u)
		if defID and isTransportDef[defID] then
			knownTransports[u] = true
		end
	end
end

local function pickBestTransport(unitID, ux, uz, unitDefID)
	local wantType = unitRequestedType(unitDefID)
	local bestLight, bestLightD, bestHeavy, bestHeavyD
	for transportID in pairs(knownTransports) do
		if not busyTransport[transportID] then
			local tDefID = spGetUnitDefID(transportID)
			if tDefID then
				local ok, reason = canTransportWithReason(transportID, tDefID, unitID, unitDefID)
				if ok then
					local tx, _, tz = spGetUnitPosition(transportID)
					if tx and tz and ux and uz then
						local d = distanceSq(tx, tz, ux, uz)
						local cls = transportClass[tDefID]
						if cls == "light" then
							if not bestLight or d < bestLightD then
								bestLight, bestLightD = transportID, d
							end
						else
							if not bestHeavy or d < bestHeavyD then
								bestHeavy, bestHeavyD = transportID, d
							end
						end
					end
				end
			end
		end
	end

	if wantType == "light" and bestLight then
		return bestLight, "light"
	end
	if bestLight then
		return bestLight, "light"
	end
	if bestHeavy then
		return bestHeavy, "heavy"
	end
	return nil, nil
end

local function issuePickupAndDrop(transportID, unitID, target)
	local chainedTargets = {}
	local ux, uy, uz = spGetUnitPosition(transportID)
	local chainLenght = 0
	for _, cmd in ipairs(spGetUnitCommands(unitID, -1)) do
		if cmd.id == CMD_TRANSPORT_TO then
			chainLenght = chainLenght + 1
			table.insert(chainedTargets, cmd)
		else
			break
		end
	end
	GiveOrderToUnit(transportID, CMD_LOAD_UNITS, { unitID }, 0)
	for index, cmd in ipairs(chainedTargets) do
		if index == #chainedTargets then
			E("!ts:issuePickupAndDrop unloading %s to %s %s", uname(transportID), debug_tostring(target), gf())
			GiveOrderToUnit(
				transportID,
				CMD_UNLOAD_UNITS,
				{ cmd.params[1], cmd.params[2], cmd.params[3], UNLOAD_RADIUS },
				{ "shift" }
			)
		else
			GiveOrderToUnit(transportID, CMD_MOVE, { cmd.params[1], cmd.params[2], cmd.params[3] }, { "shift" })
		end
	end
	-- GiveOrderToUnit(transportID, CMD_MOVE, { ux, uy, uz }, { "shift" })
end

local function reloadBindings() end

function widget:Initialize()
	local _, _, _, teamID = GetPlayerInfo(GetMyPlayerID(), false)
	myTeamID = teamID
	buildDefCaches()
	refreshKnownTransports()
	reloadBindings()
	Spring.AssignMouseCursor("transto", "cursortransport")
	Spring.SetCustomCommandDrawData(CMD_TRANSPORT_TO, "transto", { 1, 1, 1, 1 })

	widgetHandler.actionHandler:AddAction(self, "blueprint_create", handleCMDTRANSPORT_TO_ACTION, nil, "p")
end

function widget:PlayerChanged(playerID)
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
		return
	end
	local _, _, _, teamID = GetPlayerInfo(GetMyPlayerID(), false)
	myTeamID = teamID
	refreshKnownTransports()
end

function widget:MetaUnitAdded(unitID, unitDefID, teamID)
	if teamID ~= myTeamID then
		return
	end
	if isTransportDef[unitDefID] then
		knownTransports[unitID] = true
	end
end

function widget:UnitIdle(unitID, unitDefID, unitTeam)
	if unitTeam ~= myTeamID then
		return
	end
	if not isTransportDef[unitDefID] then
		return
	end
	busyTransport[unitID] = nil
end

function widget:MetaUnitRemoved(unitID, unitDefID, teamID)
	knownTransports[unitID] = nil
	local i = does_unitHaveTransportJob(unitID)
	if i then
		remove_transport_job(i)
	end
	remove_transport_job(unitID)
end

function widget:CommandsChanged()
	local selected = Spring.GetSelectedUnits()
	local cc = widgetHandler.customCommands
	if #selected == 0 then
		return
	end
	local addCustom = false
	for i = 1, #selected do
		local defID = spGetUnitDefID(selected[i])
		if defID and (isTransportableDef[defID] or isNanoDef[defID] or isFactoryDef[defID]) then
			addCustom = true
			break
		end
	end
	if addCustom then
		cc[#cc + 1] = CMD_TRANSPORT_TO_DESC
	end
end

function widget:CommandNotify(cmdID, params, opts)
	local selected = Spring.GetSelectedUnits()
	--if multiple units are selected, then let customFormations2 handle the command,
	--else both left and right click give the command, which is not how it works with the rest of commands handled by customFormations2
	if cmdID == CMD_TRANSPORT_TO then
		if #selected > 1 then
			-- return true
		end
	end

	if cmdID ~= CMD_TRANSPORT_TO then
		for index, uID in pairs(selected) do
			local i = does_unitHaveTransportJob(uID)
			if i then
				remove_transport_job(i)
			end
		end
	end

	return false
end

function widget:UnitCommandNotify(uID, cmdID, cmdParams, cmdOpts)
	local queue = spGetUnitCommands(uID, -1)
	if cmdID ~= CMD_TRANSPORT_TO then
		local i = does_unitHaveTransportJob(uID)
		if i then
			remove_transport_job(i)
		end
	end
end

function does_unitHaveTransportJob(unitID)
	for index, pair in pairs(transport_jobs) do
		if pair.transport == unitID then
			return index, true
		end
		if pair.transportee == unitID then
			return index, false
		end
	end
	return false, nil
end

function widget:Update(dt)
	updateTimer = updateTimer + dt
	if updateTimer < UPDATE_PERIOD then
		return
	end
	updateTimer = 0

	for index, pair in pairs(pendingRequests) do
		local transporteeID = pair.transporteeID
		local transporteeDefID = spGetUnitDefID(transporteeID)
		local params = pair.params
		local tID, cls = solveTransportee(transporteeID, params)
		if tID and isValidAndMine(tID) then
			Ed("!ts:solvingTransportee picked %s for %s %s", uname(tID), uname(transporteeID), gf())
			pendingRequests[index] = nil
			local tx, ty, tz = spGetUnitPosition(tID)
			busyTransport[tID] = true
			transport_jobs[transporteeID] = {
				transport = tID,
				transportee = transporteeID,
				target = params,
				pos = { ux, uy, uz },
				tpos = { tx, ty, tz },
			}
			issuePickupAndDrop(tID, transporteeID, params)
		else
			if MOVE_IF_NONE_FOUND and isCanMoveDef[transporteeDefID] then
				pendingRequests[index] = nil
				local queue = spGetUnitCommands(transporteeID, -1)
				transportee_skip_transport_to(transporteeID)
				E("!ts:move_if_none_found moving and removing from pendingRequests %s", uname(transporteeID))
			else
				E("!ts:no transport found for %s, keeping in pendingRequests", uname(transporteeID))
			end
		end
	end
end

function remove_transport_job(index, gracefull)
	E("%s !ts:removingTransportJob: %s", gf(), debug_tostring(transport_jobs[index]))
	local transport = transport_jobs[index].transport
	if isValidAndMine(transport) and RETURN_TO_START_POS then
		local tpos = transport_jobs[index].tpos
		GiveOrderToUnit(transport, CMD_MOVE, tpos, 0)
		-- GiveOrderToUnit(transport, CMD_STOP, {}, 0)
	end
	local transportee = transport_jobs[index].transportee
	if isValidAndMine(transportee) and MOVE_IF_NONE_FOUND and not gracefull then
		transportee_skip_transport_to(transportee)
	end
	busyTransport[transport] = nil
	transport_jobs[index] = nil
end

function transportee_skip_transport_to(unitID)
	local queue = spGetUnitCommands(unitID, -1)
	if queue[1] and queue[1].id == CMD_TRANSPORT_TO then
		local params = queue[1].params
		local target = { params[1], params[2], params[3] }
		local newOrders = {}
		local skip = true
		for index, command in ipairs(queue) do
			if skip and command.id == CMD_TRANSPORT_TO then
			--skip
			else
				skip = false
				table.insert(newOrders, { command.id, command.params, command.options })
			end
		end
		GiveOrderToUnit(unitID, CMD_MOVE, target, 0)
		Spring.GiveOrderArrayToUnit(unitID, newOrders)
	end
end

-- function transportee_skip_transport_to(unitID)
-- 	local queue = spGetUnitCommands(transportee, -1)
-- 	if queue[1] and queue[1].id == CMD_TRANSPORT_TO then
-- 		local params = queue[1].params
-- 		local target = { params[1], params[2], params[3] }
-- 		local newOrders = {}
-- 		-- GiveOrderToUnit(transportee, CMD_MOVE, target, 0)
-- 		local chain = true

-- 		for index, command in ipairs(queue) do
-- 			if chain then
-- 				if command.id ~= CMD_TRANSPORT_TO then
-- 					chain = false
-- 				end
-- 			else
-- 				-- GiveOrderToUnit(transportee, pair.id, pair.params or {}, pair.options or {})
-- 				table.insert(newOrders, { command.id, command.params, command.options })
-- 			end
-- 		end

-- 		Spring.GiveOrderArrayToUnit(transportee, newOrders)
-- 	end
-- end

function pend_solveTransportee(transporteeID, params)
	table.insert(pendingRequests, { transporteeID = transporteeID, params = params, requestedGF = GameFrame() })
end

function solveTransportee(transporteeID, params)
	E("!ts:solvingTransportee %s %s, params: %s", gf(), uname(transporteeID), debug_tostring(params))
	if not isValidAndMine(transporteeID) then
		return
	end
	local uDefID = spGetUnitDefID(transporteeID)
	if not uDefID or not isTransportableDef[uDefID] then
		return
	end
	if does_unitHaveTransportJob(transporteeID) then
		E("!ts:solvingTransportee already has a job %s", gf())
		return
	end
	local queue = spGetUnitCommands(transporteeID, 1)
	--we yielded last time, so we need to get these again
	if not (queue[1] and queue[1].id == CMD_TRANSPORT_TO) then
		E("!ts:solvingTransportee no transport command found %s", gf())
		return
	end
	local params = queue[1].params
	local ux, uy, uz = spGetUnitPosition(transporteeID)
	local tID, cls = pickBestTransport(transporteeID, ux, uz, uDefID)
	-- E("!ts:solvingTransportee no transport found %s", gf())
	return tID, cls
end

local function handleTransportToUnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag, bypass)
	local commandQueue = spGetUnitCommands(unitID, -1)
	local currentCmd, options = spGetUnitCurrentCommand(unitID)

	if not unitTeam or not AreTeamsAllied(unitTeam, myTeamID) then
		return
	end
	if not unitID or not unitDefID or not isTransportableDef[unitDefID] then
		return
	end

	if not bypass then
		if commandQueue[1] then
			if commandQueue[1].id ~= CMD_TRANSPORT_TO then
				return
			else
				cmdParams = commandQueue[1].params
				cmdOpts = commandQueue[1].options
			end
		else
			return
		end
	end

	local x, y, z = cmdParams[1], cmdParams[2], cmdParams[3]
	if not (x and y and z) then
		return
	end

	-- pendingRequests[unitID] = { x, y, z, requestedGF = GameFrame(), unitDefID = unitDefID }
	--we need to yield, otherwise the commands will not be in the queue and the rest of the logic will fail
	if isFactoryDef[unitDefID] then
		E("!ts:handleTransportToUnitCommand ignoring factory %s %s", uname(unitID), gf())
		return
	end
	local tID, cls = pend_solveTransportee(unitID, cmdParams)

	local t = unitRequestedType(unitDefID)
end

function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	handleTransportToUnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag, false)
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if not unitTeam or not AreTeamsAllied(unitTeam, myTeamID) then
		return
	end
	local currentCmd, options = spGetUnitCurrentCommand(unitID)
	local commandQueue = spGetUnitCommands(unitID, -1)
	if cmdID == CMD_TRANSPORT_TO and isTransportableDef[unitDefID] then
		--haha if statement goes brrrrr, since unitCommand is called when ever a unit accepts a command, we need to check the queue
		if
			(
				commandQueue[1] --this one is here so when a unit has currently a move command, and a transportto is added after it, it will not be ignored and the unit wont just keep going forwards
				and not (
					commandQueue[1].id == CMD_MOVE
					or commandQueue[1].id == CMD_FIGHT
					or commandQueue[1].id == CMD.PATROL
					or commandQueue[1].id == CMD_WAIT
				)

			)
			or (currentCmd and (currentCmd == CMD_WAIT and cmdOpts.shift)) --this on is here so if a unit currently has a wait command, it wont handle it if its being shift
		then
			return
		else
			E("!ts:UnitCommand got transportto %s %s", uname(unitID), gf())
			handleTransportToUnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag, true)
		end
		-- if currentCmd and currentCmd ~= CMD_TRANSPORT_TO then
		-- 	return
		-- else
		-- 	E("!ts:UnitCommand got transportto %s %s", uname(unitID), gf())
		-- 	handleTransportToUnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag, true)
		-- end
	end
	if
		cmdID == CMD_WAIT
		and currentCmd
		and currentCmd == CMD_WAIT
		and commandQueue[2]
		and commandQueue[2].id == CMD_TRANSPORT_TO
	then
		E("!ts:UnitCommand got wait before transportto %s %s", uname(unitID), gf())
		handleTransportToUnitCommand(
			unitID,
			unitDefID,
			unitTeam,
			commandQueue[2].id,
			commandQueue[2].params,
			commandQueue[2].options,
			cmdTag,
			true
		)
	end
	if cmdID == CMD_WAIT and currentCmd and currentCmd == CMD_WAIT then
		E("command at 0: %s", debug_tostring(commandQueue[2]))
	end
end

function widget:UnitUnloaded(uID, uDefID, teamID, transportID)
	local i = does_unitHaveTransportJob(transportID)
	if i then
		remove_transport_job(i, true)
	end
end

function handleCMDTRANSPORT_TO_ACTION() end

function widget:Shutdown()
	busyTransport = {}
	pendingRequests = {}
	transport_jobs = {}
	knownTransports = {}
end
