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

-- ========= debug toggles =========
local LOG_VERBOSE = true -- general lifecycle logging
local LOG_DETAIL = false -- per-candidate evaluation spam

-- ========= locals / engine aliases =========
local Echo = Spring.Echo
local GetMyPlayerID = Spring.GetMyPlayerID
local GetPlayerInfo = Spring.GetPlayerInfo
local GetTeamUnits = Spring.GetTeamUnits
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitCommands = Spring.GetUnitCommands
local GetUnitIsTransporting = Spring.GetUnitIsTransporting
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitTeam = Spring.GetUnitTeam
local GiveOrderToUnit = Spring.GiveOrderToUnit
local ValidUnitID = Spring.ValidUnitID
local AreTeamsAllied = Spring.AreTeamsAllied
local GameFrame = Spring.GetGameFrame

local CMDTYPE_ICON_MAP = CMDTYPE.ICON_MAP
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_STOP = CMD.STOP
local CMD_WAIT = CMD.WAIT
local CMD_INSERT = CMD.INSERT

-- ========= helpers =========
local function unameByDef(defID)
	local ud = defID and UnitDefs[defID]
	return (ud and ud.name) or ("def:" .. tostring(defID))
end

local function uname(unitID)
	local defID = GetUnitDefID(unitID)
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

-- Optional: expose globally
-- debug_tostring = debug_tostring

-- ========= command id & description =========
local CMD_TRANSPORT_TO = GameCMD.TRANSPORT_TO
local CMD_TRANSPORT_TO_DESC = {
	id = CMD_TRANSPORT_TO,
	type = CMDTYPE_ICON_MAP,
	name = "Transport To",
	cursor = nil,
	action = "transport_to",
}

-- ========= classification thresholds =========
local HEAVY_TRANSPORT_MASS_THRESHOLD = 3000
local LIGHT_UNIT_SIZE_THRESHOLD = 6
local UNLOAD_RADIUS = 10

-- ========= sets and helpers =========
local function distanceSq(ax, az, bx, bz)
	local dx, dz = ax - bx, az - bz
	return dx * dx + dz * dz
end

-- ========= team & caches =========
local myTeamID = nil

local isFactoryDef = {}
local isNanoDef = {}
local isTransportDef = {}
local transportClass = {} -- "light"|"heavy"
local transportCapacityMass = {}
local transportSizeLimit = {}
local transportCapSlots = {}

local isTransportableDef = {}
local unitMass = {}
local unitXsize = {}

local knownTransports = setmetatable({}, { __mode = "k" })
local busyTransport = {}
local pendingRequests = {} -- [unitID] = { x,y,z, requestedGF, unitDefID, transportee_queue }
local transportOrders = {} -- [transportID] = { unitID, target={x,y,z}, stage, createdGF, transportee_queue}

local UPDATE_PERIOD = 0.25
local updateTimer = 0

-- ========= UnitDef scanning =========
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
		local notBuilding = not ud.isBuilding
		local notCantBeTransported = (ud.cantBeTransported == nil) or (ud.cantBeTransported == false)
		-- local isNano = ud.movementclass == "NANO"
		-- local isNano = ud.isBuilding and notCantBeTransported
		local isNano = ud.isBuilder and not ud.canMove and not ud.isFactory
		local isFactory = ud.isFactory
		if (movable and grounded and notBuilding and notCantBeTransported)then
			isTransportableDef[defID] = true
		end
		if isNano then
			E("nano spotted, %s", defID)
			isNanoDef[defID] = true
			isTransportableDef[defID] = true
		end
		if isFactory then
			isFactoryDef[defID] = true
			isTransportableDef[defID] = true
		end
		unitMass[defID] = ud.mass or 0
		unitXsize[defID] = ud.xsize or 0
	end
end

-- ========= capability checks with reasons =========
local function canTransportWithReason(transportID, transportDefID, unitID, unitDefID)
	local tName = uname(transportID)
	local uName = uname(unitID)

	local trans = GetUnitIsTransporting(transportID)
	if not trans then
		return false, string.format("%s has no transport state", tName)
	end
	if #trans > 0 then
		return false, string.format("%s already carrying cargo (#%d)", tName, #trans)
	end

	local maxSize = transportSizeLimit[transportDefID] or 0
	local uSize = unitXsize[unitDefID] or 0
	if maxSize > 0 and (uSize > maxSize * 2) then
		return false, string.format("%s size too big for %s (uSize=%d > limit*2=%d)", uName, tName, uSize, maxSize * 2)
	end

	local capacityMass = transportCapacityMass[transportDefID] or 0
	local uMass = unitMass[unitDefID] or 0
	if capacityMass > 0 and uMass > capacityMass then
		return false, string.format("%s mass too high for %s (uMass=%d > cap=%d)", uName, tName, uMass, capacityMass)
	end

	local q = GetUnitCommands(transportID, 5) or {}
	if #q > 0 then
		for i = 1, #q do
			if q[i].id == CMD_WAIT then
				return false, string.format("%s is waiting", tName)
			end
		end
		return false, string.format("%s has non-empty queue (#%d)", tName, #q)
	end

	return true, "ok"
end

local function unitRequestedType(unitDefID)
	local size = unitXsize[unitDefID] or 0
	local mass = unitMass[unitDefID] or 0
	if size <= LIGHT_UNIT_SIZE_THRESHOLD and mass < HEAVY_TRANSPORT_MASS_THRESHOLD then
		return "light"
	end
	return "heavy"
end

-- determine if current queue has a LOAD_UNITS order for our cargo
local function hasPickupCommand(tID, cargoID)
	local q = Spring.GetUnitCommands(tID, 5) or {}
	for i = 1, #q do
		local c = q[i]
		if c.id == CMD_LOAD_UNITS then
			if not cargoID or (c.params[1] == cargoID) then
				return true
			end
		end
	end
	return false
end

-- helper: find transport currently assigned to pick up a given cargo unit
local function findTransportByCargo(cargoID)
	for tID, ord in pairs(transportOrders) do
		if ord.unitID == cargoID then
			return tID, ord
		end
	end
end

local function isValidAndMine(unitID)
	if not ValidUnitID(unitID) then
		return false
	end
	local team = GetUnitTeam(unitID)
	return team and AreTeamsAllied(team, myTeamID)
end

-- ========= discover current team transports =========
local function refreshKnownTransports()
	knownTransports = setmetatable({}, { __mode = "k" })
	local units = GetTeamUnits(myTeamID)
	for i = 1, #units do
		local u = units[i]
		local defID = GetUnitDefID(u)
		if defID and isTransportDef[defID] then
			knownTransports[u] = true
		end
	end
	E("[TransportTo] %s refreshed transports: %d found", gf(), (units and #units) or 0)
end

-- ========= assignment =========
local function pickBestTransport(unitID, ux, uz, unitDefID)
	local wantType = unitRequestedType(unitDefID)
	local bestLight, bestLightD, bestHeavy, bestHeavyD

	for transportID in pairs(knownTransports) do
		if not busyTransport[transportID] then
			local tDefID = GetUnitDefID(transportID)
			if tDefID then
				local ok, reason = canTransportWithReason(transportID, tDefID, unitID, unitDefID)
				if ok then
					local tx, _, tz = GetUnitPosition(transportID)
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
						Ed(
							"[TransportTo:Pick] %s candidate %s (%s) dist2=%.0f",
							gf(),
							uname(transportID),
							cls or "?",
							d
						)
					end
				else
					Ed("[TransportTo:Pick] %s reject %s -> %s", gf(), uname(transportID), reason)
				end
			end
		else
			Ed("[TransportTo:Pick] %s skip %s (busy)", gf(), uname(transportID))
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
	E(
		"[TransportTo:Queue] %s pickup %s then drop at (%.1f,%.1f,%.1f) %s",
		gf(),
		uname(unitID),
		target[1],
		target[2],
		target[3],
		uname(transportID)
	)
	GiveOrderToUnit(transportID, CMD_LOAD_UNITS, { unitID }, 0)
	GiveOrderToUnit(transportID, CMD_UNLOAD_UNITS, { target[1], target[2], target[3], UNLOAD_RADIUS }, { "shift" })
end

-- ========= widget plumbing =========
local function reloadBindings() end

function widget:Initialize()
	local _, _, _, teamID = GetPlayerInfo(GetMyPlayerID(), false)
	myTeamID = teamID
	buildDefCaches()
	refreshKnownTransports()
	reloadBindings()
	E(
		"[TransportTo] %s init complete, nanoDefs %s transportableDefs %s",
		gf(),
		debug_tostring(isNanoDef),
		debug_tostring(isTransportableDef)
	)
end

function widget:PlayerChanged(playerID)
	if Spring.GetSpectatingState() then
		E("[TransportTo] %s removed (spectator)", gf())
		widgetHandler:RemoveWidget()
		return
	end
	local _, _, _, teamID = GetPlayerInfo(GetMyPlayerID(), false)
	myTeamID = teamID
	refreshKnownTransports()
end

function widget:UnitCreated(unitID, unitDefID, teamID)
	if teamID ~= myTeamID then
		return
	end
	if isTransportDef[unitDefID] then
		knownTransports[unitID] = true
		E("[TransportTo] %s transport spawned: %s", gf(), uname(unitID))
	end
end

local function clearOrderForTransport(tID, reason)
	busyTransport[tID] = nil
	if transportOrders[tID] then
		E("[TransportTo:Abort] %s %s aborted: %s", gf(), uname(tID), reason or "unknown")
	end
	transportOrders[tID] = nil
end

function widget:UnitDestroyed(unitID, unitDefID, teamID)
	if transportOrders[unitID] then
		clearOrderForTransport(unitID, "transport destroyed")
	end
	for tID, ord in pairs(transportOrders) do
		if ord.unitID == unitID then
			clearOrderForTransport(tID, "cargo destroyed")
			if ValidUnitID(tID) then
				GiveOrderToUnit(tID, CMD_STOP, {}, 0)
			end
		end
	end
	knownTransports[unitID] = nil
	if pendingRequests[unitID] then
		E("[TransportTo:Abort] %s pending request dropped: %s destroyed", gf(), uname(unitID))
		pendingRequests[unitID] = nil
	end
end

function widget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	local ord = transportOrders[transportID]
	if ord and ord.unitID == unitID then
		local ordersToGive = ord.transportee_queue or {}
		local r = {}
		for i, order in pairs(ordersToGive) do
			local g = { order.id, order.params, order.options }
			r[#r + 1] = g
		end
		E(
			"[TransportTo:LoadQueue] giving back queue for unit %s, orginal queue is %s, formated queue %s",
			uname(ord.unitID),
			debug_tostring(ordersToGive),
			debug_tostring(r)
		)
		Spring.GiveOrderArrayToUnitArray({ ord.unitID }, r)
		E("[TransportTo:Evt] %s unloaded %s from %s", gf(), uname(unitID), uname(transportID))
		busyTransport[transportID] = nil
		transportOrders[transportID] = nil
		E("[TransportTo:Done] %s finished order for %s", gf(), uname(transportID))
	end
end
-- end

-- 	local ord = transportOrders[transportID]
-- 	if ord and ord.unitID == unitID then
-- 		ord.stage = "loaded"
-- 		E("[TransportTo:Evt] %s loaded %s into %s", gf(), uname(unitID), uname(transportID))
-- 	end
-- end

-- ========= Command wiring =========
function widget:CommandsChanged()
	local selected = Spring.GetSelectedUnits()
	if #selected == 0 then
		return
	end
	local addCustom = false
	for i = 1, #selected do
		local defID = GetUnitDefID(selected[i])
		if defID and isTransportableDef[defID] then
			addCustom = true
			-- E("NANO NOT SELECTED")
			break
		end
		if defID and isNanoDef[defID] then
			addCustom = true
			-- E("NANO SELECTED")
			break
		end
		if defID and isFactoryDef[defID] then
			addCustom = true
			break
		end
	end
	if addCustom then
		local cc = widgetHandler.customCommands
		cc[#cc + 1] = CMD_TRANSPORT_TO_DESC
	end
end

function widget:CommandNotify(cmdID, params, opts)
	local units = Spring.GetSelectedUnits()
	if cmdID == CMD_TRANSPORT_TO and #units < 2 then
		return false
	end
	if cmdID == CMD_TRANSPORT_TO then
		return true
	end
	for i = 1, #units do
		local unitID = units[i]
		-- 1) Transportee (cargo) issued a different command: abort pickup (pending or assigned)
		local pending = pendingRequests[unitID]
		local assignedTID, assignedOrd = findTransportByCargo(unitID)
		local ord = transportOrders[unitID]
		if pending then
			if pending then
				E(
					"[TransportTo:Abort] %s %s new cmd (%s) -> cancel pending request",
					gf(),
					uname(unitID),
					tostring(cmdID)
				)
				pendingRequests[unitID] = nil
			end
		-- if assignedTID then
		--   E("[TransportTo:Abort] %s %s new cmd (%s) -> abort assigned transport %s",
		--     gf(), uname(unitID), tostring(cmdID), uname(assignedTID))
		--   clearOrderForTransport(assignedTID, "transportee issued new command")
		--   if ValidUnitID(assignedTID) then
		--     GiveOrderToUnit(assignedTID, CMD_STOP, {}, 0)
		--   end
		-- end
		elseif ord then
			-- 2) Transport itself issued a different command: abort this transport, requeue cargo’s request

			local cargoID = ord.unitID
			local cargoDefID = GetUnitDefID(cargoID)
			if cargoDefID and isValidAndMine(cargoID) then
				-- pendingRequests[cargoID] = {
				-- 	ord.target[1],
				-- 	ord.target[2],
				-- 	ord.target[3],
				-- 	requestedGF = GameFrame(),
				-- 	unitDefID = cargoDefID,
				-- 	transportee_queue = ord.transportee_queue,
				-- }
			--   E("[TransportTo] %s new cmd (%s) -> requeue %s to (%.1f,%.1f,%.1f)",
			--     gf(), uname(unitID), tostring(cmdID), uname(cargoID),
			--     ord.target[1], ord.target[2], ord.target[3])
			else
				E(
					"[TransportTo:Abort] %s new cmd (%s) -> cargo invalid, drop order",
					gf(),
					uname(unitID),
					tostring(cmdID)
				)
			end

			clearOrderForTransport(unitID, "transport received new command")
		end
	end
	-- local sel = Spring.GetSelectedUnits()
	-- if #sel == 0 then
	-- 	return true
	-- end

	-- local x, y, z = params[1], params[2], params[3]
	-- if not (x and y and z) then
	-- 	return true
	-- end

	-- for i = 1, #sel do
	-- 	local unitID = sel[i]
	-- 	local defID = GetUnitDefID(unitID)
	-- 	if defID and isTransportableDef[defID] then
	-- 		pendingRequests[unitID] = { x, y, z, requestedGF = GameFrame(), unitDefID = defID }
	-- 		E(
	-- 			"[TransportTo] %s added to pending: %s -> (%.1f,%.1f,%.1f) type=%s",
	-- 			gf(),
	-- 			uname(unitID),
	-- 			x,
	-- 			y,
	-- 			z,
	-- 			unitRequestedType(defID)
	-- 		)
	-- 	end
	-- end
	-- return true
	return false
end

-- ========= Update loop =========
local function ensurePickupQueued(transportID, unitID)
	local q = GetUnitCommands(transportID, 10) or {}
	for i = 1, #q do
		if q[i].id == CMD_LOAD_UNITS then
			return true
		end
	end
	E("[TransportTo:Queue] %s enqueue pickup %s", gf(), uname(unitID))
	GiveOrderToUnit(transportID, CMD_LOAD_UNITS, { unitID }, 0)
	return false
end

local function ensureDropQueued(transportID, target)
	local q = GetUnitCommands(transportID, 10) or {}
	for i = 1, #q do
		if q[i].id == CMD_UNLOAD_UNITS then
			return true
		end
	end
	E("[TransportTo:Queue] %s enqueue drop at (%.1f,%.1f,%.1f)", gf(), target[1], target[2], target[3])
	GiveOrderToUnit(transportID, CMD_UNLOAD_UNITS, { target[1], target[2], target[3], UNLOAD_RADIUS }, { "shift" })
	return false
end

function widget:Update(dt)
	updateTimer = updateTimer + dt
	if updateTimer < UPDATE_PERIOD then
		return
	end
	updateTimer = 0

	-- Try to assign pending
	for unitID, req in pairs(pendingRequests) do
		if not isValidAndMine(unitID) then
			E("[TransportTo:Abort] %s pending invalid: %s (unit invalid)", gf(), uname(unitID))
			pendingRequests[unitID] = nil
		else
			local ux, uy, uz = GetUnitPosition(unitID)
			local tID, cls = pickBestTransport(unitID, ux, uz, req.unitDefID)
			if tID and isValidAndMine(tID) then
				busyTransport[tID] = true
				local target = { req[1], req[2], req[3] }
				E("[TransportTo:Pick] %s assigned %s (%s) -> %s", gf(), uname(tID), cls or "?", uname(unitID))
				issuePickupAndDrop(tID, unitID, target)
				transportOrders[tID] = {
					unitID = unitID,
					target = target,
					stage = "assigned",
					createdGF = GameFrame(),
					transportee_queue = req.transportee_queue,
				}
				E("[TransportTo] %s pending fulfilled: %s by %s", gf(), uname(unitID), uname(tID))
				pendingRequests[unitID] = nil
			else
				-- leave pending; optional: echo once per few seconds to avoid spam
				Ed("[TransportTo:Pick] %s no match yet for %s", gf(), uname(unitID))
			end
		end
	end

	-- Maintain active orders
	for tID, ord in pairs(transportOrders) do
		if not (isValidAndMine(tID) and isValidAndMine(ord.unitID)) then
			clearOrderForTransport(tID, "transport or cargo invalid")
			if ValidUnitID(tID) then
				GiveOrderToUnit(tID, CMD_STOP, {}, 0)
			end
		else
			local carrying = GetUnitIsTransporting(tID) or {}
			local carryingCargo = false
			for i = 1, #carrying do
				if carrying[i] == ord.unitID then
					carryingCargo = true
					break
				end
			end

			-- in the Update loop, replace your simple check with this:
			if not carryingCargo then
				if not hasPickupCommand(tID, ord.unitID) then
					ensurePickupQueued(tID, ord.unitID)
				else
					E("[TransportTo:Stage] %s still en route to pick up %s", gf(), uname(ord.unitID))
				end
			else
				-- only go to drop if LOAD is no longer in queue
				if not hasPickupCommand(tID, ord.unitID) then
					ensureDropQueued(tID, ord.target)
				else
					E("[TransportTo:Stage] %s has cargo but still has pickup cmd queued (likely mid‑load)", gf())
				end
			end

			local q = GetUnitCommands(tID, 2) or {}
			local still = GetUnitIsTransporting(tID)
			if (#q == 0) and still and #still == 0 and ord.createdGF - 1 > GameFrame() then
				E("[TransportTo:Done] %s finished (empty queue and no cargo) for %s", gf(), uname(tID))
				busyTransport[tID] = nil
				transportOrders[tID] = nil
			end
		end
	end
end

-- shared UnitCommand handler for both addon and widget callins
local function handleTransportToUnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if cmdID ~= CMD_TRANSPORT_TO then
		return
	end
	-- only handle our own / allied units
	if not unitTeam or not AreTeamsAllied(unitTeam, myTeamID) then
		return
	end
	if not unitID or not unitDefID or not isTransportableDef[unitDefID] then
		return
	end

	local x, y, z = cmdParams[1], cmdParams[2], cmdParams[3]
	if not (x and y and z) then
		E("[TransportTo] %s UnitCommand missing coords for %s", gf(), uname(unitID))
		return
	end

	-- Register this unit's pending transport request (per-unit, not per-selection)
	if not pendingRequests[unitID] then
		pendingRequests[unitID] = {
			x,
			y,
			z,
			requestedGF = GameFrame(),
			unitDefID = unitDefID,
			transportee_queue = GetUnitCommands(unitID, -1) or {},
		}
		E(
			"[TransportTo:LoadQueue] saving queue for unit %s, queue is %s",
			uname(unitID),
			debug_tostring(pendingRequests[unitID].transportee_queue)
		)
	else
		-- GiveOrderToUnit(unitID, CMD_TRANSPORT_TO, cmdParams, cmdOpts)
	end
	-- Rich debug trail
	local t = unitRequestedType(unitDefID)
	E(
		"[TransportTo] %s pending (UnitCommand): %s -> (%.1f,%.1f,%.1f) type=%s tag=%s shift=%s ctrl=%s alt=%s",
		gf(),
		uname(unitID),
		x,
		y,
		z,
		t,
		tostring(cmdTag),
		cmdOpts and tostring(cmdOpts.shift) or "nil",
		cmdOpts and tostring(cmdOpts.ctrl) or "nil",
		cmdOpts and tostring(cmdOpts.alt) or "nil"
	)
end

-- BAR often forwards via addon.UnitCommand; wire it
-- addon = addon or {}
-- function addon.UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
--   handleTransportToUnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
-- end

-- Also wire vanilla widget callin just in case
function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	handleTransportToUnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
end

-- abort/requeue policy:
-- - If a transportee (cargo) gets any non-transport_to command: abort pending/assigned pickup.
-- - If a transport gets any non-transport_to command: abort its current order but requeue the cargo’s request.
function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if not unitTeam or not AreTeamsAllied(unitTeam, myTeamID) then
		return
	end
	if cmdOpts and cmdOpts.internal then
		return
	end -- ignore engine-internal orders

	-- Keep your existing UnitCommand registration for CMD_TRANSPORT_TO if you want; we only handle non-transport_to here
	if cmdID == CMD_TRANSPORT_TO then
		-- optional: register pending here if you stop consuming in CommandNotify
		-- handleTransportToUnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
		-- GiveOrderToUnit(unitID, CMD_INSERT, {insertIndex, CMD_WAIT, nil, nil}, {})
		if not isNanoDef[unitDefID] or not isFactoryDef[unitDefID] then
			GiveOrderToUnit(unitID, CMD_WAIT, {}, { "shift" })
			E("[TransportTo] %s inserted WAIT after CMD_TRANSPORT_TO at queue pos", gf())
		end
		return
	end
	if cmdID == CMD_WAIT then
		-- WAIT is explicitly ignored for abort logic
		return
	end
end

function widget:Shutdown()
	for tID, _ in pairs(transportOrders) do
		if ValidUnitID(tID) then
			GiveOrderToUnit(tID, CMD_STOP, {}, 0)
		end
	end
	transportOrders = {}
	busyTransport = {}
	pendingRequests = {}
	E("[TransportTo] %s shutdown", gf())
end
