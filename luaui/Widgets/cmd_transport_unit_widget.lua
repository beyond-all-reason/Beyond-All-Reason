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

local f = string.format
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
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spGetUnitCmdDescs = Spring.GetUnitCmdDescs
local spGetUnitDefID = Spring.GetUnitDefID

-- ========= helpers =========
local function unameByDef(defID)
	local ud = defID and UnitDefs[defID]
	return (ud and ud.name) or ("def:" .. tostring(defID))
end

local function uname(unitID)
	local defID = GetUnitDefID(unitID)
	return string.format("%s#%d", unameByDef(defID), unitID or -1)
end

function gf()
	return tostring(GameFrame())
end

-- Pretty, cycle-safe table -> string for debugging.
local function debug_tostring(value, opts, _depth, _seen)
	opts = opts or {}
	local indentStr = opts.indent or "  "
	local maxDepth = opts.maxDepth or 3
	local sortKeys = (opts.sortKeys ~= false)
	local maxItems = opts.maxItems or 200
	local showMeta = opts.showMetatable or false
	local compact = opts.compact or false
	local showFuncs = (opts.showFunctions ~= false)

	_depth = _depth or 0
	_seen = _seen or {}

	local t = type(value)
	if t == "nil" or t == "number" or t == "boolean" then
		return tostring(value)
	elseif t == "string" then
		return string.format("%q", value)
	elseif t ~= "table" then
		if showFuncs or t ~= "function" then
			return string.format("<%s:%s>", t, tostring(value))
		else
			return "<function>"
		end
	end

	if _seen[value] then
		return string.format("<ref#%d>", _seen[value].id)
	end
	if _depth >= maxDepth then
		return "<table ...>"
	end

	local id = 1 + (function()
		local c = 0
		for _ in pairs(_seen) do
			c = c + 1
		end
		return c
	end)()
	_seen[value] = { id = id }

	local function indent(n)
		return compact and "" or string.rep(indentStr, n)
	end

	-- detect array
	local arrMax, count = 0, 0
	for k, _ in pairs(value) do
		count = count + 1
		if type(k) == "number" and k > 0 and math.floor(k) == k then
			if k > arrMax then
				arrMax = k
			end
		end
	end
	local isArray = true
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
			return "{" .. table.concat(items, ",") .. "}"
		else
			local pad = indent(_depth + 1)
			return "{"
				.. (#items > 0 and ("\n" .. pad .. table.concat(items, ",\n" .. pad) .. "\n" .. indent(_depth)) or "")
				.. "}"
		end
	else
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
		local pieces, emitted = {}, 0
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
				local mtStr = debug_tostring(mt, opts, _depth + 1, _seen)
				local line = compact and ("<metatable>=" .. mtStr) or (indent(_depth + 1) .. "<metatable> = " .. mtStr)
				pieces[#pieces + 1] = line
			end
		end
		if compact then
			return "{" .. table.concat(pieces, ",") .. "}"
		else
			local inner = table.concat(pieces, ",\n")
			return inner == "" and "{}" or ("{\n" .. inner .. "\n" .. indent(_depth) .. "}")
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

local HEAVY_TRANSPORT_MASS_THRESHOLD = 3000
local LIGHT_UNIT_SIZE_THRESHOLD = 6
--using transports in repeat breaks this widget, so we are not going to consider them
local CONSIDER_TRANSPORTS_IN_REPEAT = false
local MAX_UNITS_PER_UPDATE = 5

local function distanceSq(ax, az, bx, bz)
	local dx, dz = ax - bx, az - bz
	return dx * dx + dz * dz
end

local myTeamID = nil
local knownTransports = {}

local isFactoryDef = {}
local isNanoDef = {}
local isTransportDef = {}
local transportClass = {}
local transportCapacityMass = {}
local transportSizeLimit = {}
local transportCapSlots = {}

local isTransportableDef = {}
local unitMass = {}
local unitXsize = {}

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

		unitMass[defID] = ud.mass or 0
		unitXsize[defID] = ud.xsize or 0
	end
end

function Can_transport(transportID, transportDefID, unitID, unitDefID)
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

	return true, ""
end

function Get_unit_transport_type(unitDefID)
	local size = unitXsize[unitDefID] or 0
	local mass = unitMass[unitDefID] or 0
	if size <= LIGHT_UNIT_SIZE_THRESHOLD and mass < HEAVY_TRANSPORT_MASS_THRESHOLD then
		return "light"
	end
	return "heavy"
end

function Pick_best_transport(unitID, ux, uz, unitDefID)
	local wantType = Get_unit_transport_type(unitDefID)
	local bestLight, bestLightD, bestHeavy, bestHeavyD
	for transportID in pairs(knownTransports) do
		local tDefID = GetUnitDefID(transportID)
		if tDefID then
			local tstate = Get_transport_state(transportID)
			local ok = CanTransport(transportID, tDefID, unitID, unitDefID)
				and (tstate.state == "idle" or tstate.state == "available")
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

--[[ 	idle; the transport is just idle (no commands)
	available; the transport has finished unloading a unit or has been interrupted and its returning to its home
	used; the transport is being used by the player
	coupled; the transport is being used by the widget
	decoupled; the transport is returning by the same path it took (aka before becoming available) ]]
---@class TransportState
---@field state '"idle"' | '"available"' | '"used"' | '"coupled"' | '"decoupled"'  -- enum-like string
---@field transportID integer|nil
---@field transporteeID integer|nil
---@field homePosition {x:number, y:number, z:number}|nil
---@field isLoaded boolean
---@type table<integer, TransportState>
local transport_states = {}

--[[ if a transport is about to pick a unit, and said unit is shared then;
	The unit has been shared to our player; flag that unit as "inshared", our transport wont ever try to transport a "inshared" unit, only if the player overrides the first/current command on the queue the unit will stop being flagged as shared
	If our player shared the unit; flag the unit a "outshared", proceed as normal, ONLY interrupt if either the transport or transportee are dead and do not retry to transport it, a unit will be unflagged if its shared back to our player ]]
---@class T_UnitState
---@field outshared boolean
---@field inshared boolean
---@field transport_state TransportState|nil
---@field isWaitingForTransport boolean
---@type table<integer, T_UnitState>
local unit_states = {}

---@type table<integer, boolean>
local unitsWaitingForTransport = {}
---@type table<integer, boolean>
local Pend_clear_movegoal = {}

function Get_transport_state(transportID)
	if not transport_states[transportID] then
		transport_states[transportID] = {
			state = "idle",
			transportID = transportID,
			transporteeID = nil,
			homePosition = nil,
			isLoaded = false,
		}
	end
	return transport_states[transportID]
end

function Get_unit_state(unitID)
	if not unit_states[unitID] then
		unit_states[unitID] = {
			outshared = false,
			inshared = false,
			isWaitingForTransport = false,
		}
	end
	return unit_states[unitID]
end

function Remove_transport_state(transportID)
	transport_states[transportID] = nil
end

function Remove_unit_state(unitID)
	unit_states[unitID] = nil
end

function CanTransport(transportID, transportDefID, unitID, unitDefID)
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

	-- local q = GetUnitCommands(transportID, 5) or {}
	-- if #q > 0 then
	-- 	for i = 1, #q do
	-- 		if q[i].id == CMD_TRANSPORT_WHO then
	-- 			return true, ""
	-- 		end
	-- 	end
	-- 	return false, ""
	-- end

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

---@return Command
local function Create_move_command(x, y, z)
	---@type Command
	return {
		id = CMD_MOVE,
		params = { x, y, z },
		options = {
			shift = false,
			coded = 0,
			alt = false,
			ctrl = false,
			right = false,
			meta = false,
			internal = false,
		},
	}
end

---@return Command
local function Create_unload_command(x, y, z)
	---@type Command
	return {
		id = CMD_UNLOAD_UNITS,
		params = { x, y, z },
		options = {
			shift = false,
			coded = 0,
			alt = false,
			ctrl = false,
			right = false,
			meta = false,
			internal = false,
		},
	}
end

---@return table<integer, Command>
function Transform_transportTo_commands(transportID, unitID, target)
	---@type table<integer, Command>
	local chainedTargets = {}
	local chainLenght = 0
	for _, cmd in ipairs(GetUnitCommands(unitID, -1)) do
		if cmd.id == CMD_TRANSPORT_TO then
			chainLenght = chainLenght + 1
			table.insert(chainedTargets, cmd)
		else
			break
		end
	end

	---@type table<integer, Command>
	local r = {}
	--follow the path the transport_to command make and in the end unload the unit
	for index, cmd in ipairs(chainedTargets) do
		local x = cmd.params[1]
		local z = cmd.params[3]
		if index == chainLenght then
			table.insert(r, Create_unload_command(x, 0, z))
		else
			table.insert(r, Create_move_command(x, 0, z))
		end
	end
	--follow the same path back to the start
	for i = #chainedTargets, 1, -1 do
		local cmd = chainedTargets[i]
		local x = cmd.params[1]
		local z = cmd.params[3]
		table.insert(r, 1, Create_move_command(x, 0, z))
	end

	return r
end

local function refreshKnownTransports()
	knownTransports = setmetatable({}, { __mode = "k" })
	local units = GetTeamUnits(myTeamID)
	for i = 1, #units do
		local u = units[i]
		local defID = GetUnitDefID(u)
		if defID and isTransportDef[defID] then
			knownTransports[u] = true
			local tstate = Get_transport_state(u)
			if not tstate.homePosition then
				local x, y, z = GetUnitPosition(u)
				tstate.homePosition = { x = x, y = y, z = z }
			end
		end
	end
end

function widget:Initialize()
	local _, _, _, teamID = GetPlayerInfo(GetMyPlayerID(), false)
	myTeamID = teamID
	buildDefCaches()
	refreshKnownTransports()
	Spring.AssignMouseCursor("transto", "cursortransport")
	Spring.SetCustomCommandDrawData(CMD_TRANSPORT_TO, "transto", { 1, 1, 1, 1 })

	-- WG.on_custom_formations_command_given = on_custom_formations_command_given
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

function widget:UnitGiven(unitID, unitDefID, unitTeam, newTeam)
	if newTeam == myTeamID then
		local ustate = Get_unit_state(unitID)
		ustate.inshared = true
	elseif unitTeam == myTeamID then
		local ustate = Get_unit_state(unitID)
		ustate.outshared = true
	end
end

function widget:MetaUnitAdded(unitID, unitDefID, teamID)
	if teamID ~= myTeamID then
		return
	end
	if isTransportDef[unitDefID] then
		knownTransports[unitID] = true
		local tstate = Get_transport_state(unitID)
		tstate.state = "idle"
		local x, y, z = Spring.GetUnitPosition(unitID)
		tstate.homePosition = { x = x, y = y, z = z }
	end
	local ustate = Get_unit_state(unitID)
	ustate.outshared = false
end

function Check_try_to_pick_transport(unitID, unitDefID)
	local ustate = Get_unit_state(unitID)
	if ustate.isWaitingForTransport then
		local foundTransport, transportType = Pick_best_transport(unitID, GetUnitPosition(unitID), unitDefID)
		if foundTransport then
			GiveOrderToUnit(foundTransport, CMD_LOAD_UNITS, { unitID }, {})
			local tstate = Get_transport_state(foundTransport)
			tstate.state = "coupled"
			tstate.transportID = foundTransport
			tstate.transporteeID = unitID
			ustate.transport_state = tstate
			ustate.isWaitingForTransport = false
			unitsWaitingForTransport[unitID] = false
			-- local treeX, treeY, treeZ = GetUnitPosition(foundTransport)
			ClearUnitMoveGoal(unitID)
			-- SetUnitMoveGoal(unitID, treeX, treeY, treeZ)
			Pend_clear_movegoal[unitID] = true
			return foundTransport, transportType
		end
	end
end

function Check_try_to_transport_waiting(tID, unitDefID)
	--loop over every waiting unit
	for index, pair in pairs(unitsWaitingForTransport) do
		if pair then
			local ustate = Get_unit_state(index)
			local canTransport, reason = CanTransport(tID, GetUnitDefID(tID), index, unitDefID)
			local transporteeType = unitRequestedType(unitDefID)
			local transportType = transportClass[GetUnitDefID(tID)]
			if canTransport then
				local score = 0
				local own_distance = distanceSq(GetUnitPosition(index), GetUnitPosition(tID))
				local own_isMatch = (transportType == transporteeType)
				--compare with other known transports
				for comp_transportID, pair in pairs(knownTransports) do
					local tstate = Get_transport_state(comp_transportID)
					if pair and comp_transportID ~= tID and (tstate.state == "available" or tstate.state == "idle") then
						local distance = distanceSq(GetUnitPosition(index), GetUnitPosition(comp_transportID))
						local isMatch = (transportClass[GetUnitDefID(comp_transportID)] == transporteeType)
						if own_distance < distance then
							score = score + 1
						end
						if own_isMatch and not isMatch then
							score = score + 0.5
						end
					elseif not (tstate.state == "available" or tstate.state == "idle") then
						score = score + 1
					end
				end
				--if you are better than 50% of them then pick you
				if score > #knownTransports / 2 then
					GiveOrderToUnit(tID, CMD_LOAD_UNITS, { index }, {})
					local tstate = Get_transport_state(tID)
					tstate.state = "coupled"
					tstate.transportID = tID
					tstate.transporteeID = index
					ustate.transport_state = tstate
					ustate.isWaitingForTransport = false
					unitsWaitingForTransport[index] = false
					break
				end
			end
		end
	end
end

function Check_transport_out_off_commision(tID)
	local tstate = Get_transport_state(tID)
	local ustate
	if tstate.transporteeID then
		ustate = Get_unit_state(tstate.transporteeID)
	end
	if tstate.isLoaded and ustate then
		ustate.transport_state = nil
		ustate.isWaitingForTransport = false
		unitsWaitingForTransport[tstate.transporteeID] = false
	elseif ustate then
		local commandQueue = GetUnitCommands(tstate.transporteeID, -1) or {}
		local nextCommand = commandQueue[1]
		local cmdParams = nextCommand and nextCommand.params or {}
		--if the unit was not loaded, then continue moving towards next command
		ustate.isWaitingForTransport = true
		unitsWaitingForTransport[tstate.transporteeID] = true
		Check_setMoveGoal(tstate.transporteeID, cmdParams[1], 0, cmdParams[3], GetUnitTeam(tstate.transporteeID))
		local tID, tType = Check_try_to_pick_transport(tstate.transporteeID, GetUnitDefID(tstate.transporteeID))
	end
end

function widget:UnitIdle(unitID, unitDefID, unitTeam)
	if isTransportDef[unitDefID] and unitTeam == myTeamID then
		local tstate = Get_transport_state(unitID)
		if tstate.state == "used" then
			tstate.state = "idle"
			tstate.transporteeID = nil
			Check_try_to_transport_waiting(unitID, unitDefID)
		end
	end
end

function widget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	local tstate = Get_transport_state(transportID)
	if tstate.state == "coupled" then
		local r = Transform_transportTo_commands(transportID, unitID)
		for i = 1, #r do
			local cmd = r[i]
			GiveOrderToUnit(transportID, cmd.id, cmd.params, cmd.options)
		end
	end
	tstate.isLoaded = true
	tstate.transporteeID = unitID
end

function widget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	local tstate = Get_transport_state(transportID)
	if tstate.state == "coupled" then
		local ustate = Get_unit_state(unitID)
		ustate.transport_state = nil
		tstate.state = "decoupled"
	end
	tstate.isLoaded = false
	tstate.transporteeID = nil
end

function widget:UnitDestroyed(unitID, unitDefID, teamID)
	if isTransportDef[unitDefID] then
		Check_transport_out_off_commision(unitID)
	end
	Remove_transport_state(unitID)
	Remove_unit_state(unitID)
end

function Check_setMoveGoal(unitID, x, y, z, unitTeam)
	local commandQueue = GetUnitCommands(unitID, -1) or {}
	local nextCommand = commandQueue[1]
	local unitTeam = unitTeam or GetUnitTeam(unitID)
	local isOwnTeam = unitTeam == myTeamID

	local ustate = Get_unit_state(unitID)
	if ustate and ustate.isWaitingForTransport and isOwnTeam then
		if nextCommand and nextCommand.id ~= CMD_TRANSPORT_TO then
			ustate.isWaitingForTransport = false
			unitsWaitingForTransport[unitID] = false
			local tstate = ustate.transport_state
			--if the transport was about to pick up the unit but it ran out of transport-to commands on the queue then abort
			if tstate and tstate.state == "coupled" then
				tstate.state = "available"
				SetUnitMoveGoal(unitID, tstate.homePosition.x, tstate.homePosition.y, tstate.homePosition.z)
				tstate.transporteeID = nil
				--once you become available, try to pick a waiting unit
				Check_try_to_pick_transport(unitID, unitDefID)
			end
		elseif nextCommand and nextCommand.id == CMD_TRANSPORT_TO then
			--still waiting for transport
			local cmdParams = nextCommand.params
			SetUnitMoveGoal(unitID, cmdParams[1], 0, cmdParams[3])
		end
	end
end

function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	local commandQueue = GetUnitCommands(unitID, -1) or {}
	local nextCommand = commandQueue[1]
	local isLastInQueue = #commandQueue == 1
	local isOwnTeam = unitTeam == myTeamID

	--if the transport reached the end of its queue, then return to home point
	if isTransportDef[unitDefID] then
		local tstate = Get_transport_state(unitID)
		if tstate.state == "decoupled" and isOwnTeam and isLastInQueue then
			tstate.state = "available"
			SetUnitMoveGoal(unitID, tstate.homePosition.x, tstate.homePosition.y, tstate.homePosition.z)
			tstate.transporteeID = nil
		end
	end

	if nextCommand and nextCommand.id == CMD_TRANSPORT_TO then
		local ustate = Get_unit_state(unitID)
		local tstate = ustate.transport_state
		if not tstate then
			local foundTransport, transportType = Pick_best_transport(unitID, cmdParams[1], cmdParams[3], unitDefID)
			if foundTransport then
				local tstate = Get_transport_state(foundTransport)
				GiveOrderToUnit(foundTransport, CMD_LOAD_UNITS, { unitID }, {})
				tstate.state = "coupled"
				tstate.transportID = foundTransport
				tstate.transporteeID = unitID
				ustate.transport_state = tstate
				ustate.isWaitingForTransport = false
				unitsWaitingForTransport[unitID] = false
			else
				ustate.isWaitingForTransport = true
				unitsWaitingForTransport[unitID] = true
				SetUnitMoveGoal(unitID, cmdParams[1], 0, cmdParams[3])
			end
		end
	end
	-- Check_setMoveGoal(unitID, cmdParams[1], cmdParams[2], cmdParams[3], unitTeam)
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	local commandQueue = GetUnitCommands(unitID, -1) or {}
	local isFirstInQueue = cmdOpts.shift == false or cmdOpts.meta == true or (#commandQueue == 0)
	local isOwnTeam = unitTeam == myTeamID
	local ustate = Get_unit_state(unitID)
	--if the command is transport to and its the first in the queue, try to pick a transport and give it the load order
	if cmdID == CMD_TRANSPORT_TO and isFirstInQueue and isOwnTeam then
		local foundTransport, transportType = Pick_best_transport(unitID, cmdParams[1], cmdParams[3], unitDefID)
		if foundTransport then
			local tstate = Get_transport_state(foundTransport)
			GiveOrderToUnit(foundTransport, CMD_LOAD_UNITS, { unitID }, {})
			tstate.state = "coupled"
			tstate.transportID = foundTransport
			tstate.transporteeID = unitID
			ustate.transport_state = tstate
			ustate.isWaitingForTransport = false
			unitsWaitingForTransport[unitID] = false
		else
			ustate.isWaitingForTransport = true
			unitsWaitingForTransport[unitID] = true
			SetUnitMoveGoal(unitID, cmdParams[1], 0, cmdParams[3])
		end
	end
	--if the unit was loaded and the command is transport to, give the transport the follow up commands
	--mostly for; if the transport picked the unit but the player did not finish queueing commands
	if
		ustate
		and ustate.transport_state
		and ustate.transport_state.isLoaded == true
		and cmdID == CMD_TRANSPORT_TO
		and isOwnTeam
	then
		local r = Transform_transportTo_commands(ustate.transport_state.transportID, unitID)
		for i = 1, #r do
			local cmd = r[i]
			GiveOrderToUnit(ustate.transport_state.transportID, cmd.id, cmd.params, cmd.options)
		end
	end
end

function widget:Update(dt)
	for index, pair in pairs(Pend_clear_movegoal) do
		if pair then
			ClearUnitMoveGoal(index)
			Pend_clear_movegoal[index] = false
		end
	end
end

function widget:DrawWorld()
	gl.Texture(0, "anims/cursortransport_0.png")

	for unitID in pairs(unitsWaitingForTransport) do
		if unitsWaitingForTransport[unitID] then
			local x, y, z = GetUnitPosition(unitID)
			if x and y and z then
				gl.PushMatrix()
				gl.Translate(x, y + 30, z)
				gl.Billboard()

				-- Draw a textured quad (billboarded)
				-- TexRect defines the rectangle in local billboard space
				local size = 16
				gl.TexRect(-size, -size, size, size)

				gl.PopMatrix()
			end
		end
	end

	gl.Texture(0, false) -- unbind texture
	-- gl.Color(1, 1, 0, 1) -- yellow text
	for unitID in pairs(knownTransports) do
		local tstate = Get_transport_state(unitID)
		local x, y, z = GetUnitPosition(unitID)
		local entry = string.format("%s", debug_tostring(tstate))

		local transporteeID = tstate.transporteeID
		local ustate
		if transporteeID then
			ustate = Get_unit_state(transporteeID)
			local treeX, treeY, treeZ = GetUnitPosition(transporteeID)
			local transporteeEntry = string.format("%s", debug_tostring(ustate))
			--[[ 			gl.Color(0, 1, 0, 1) -- green text
			gl.PushMatrix()
			gl.Translate(treeX, treeY + 40, treeZ)
			gl.Billboard()
			gl.text(transporteeEntry, 0, 0, 16, "c")
			gl.PopMatrix() ]]
			gl.PushPopMatrix(function()
				gl.Color(0, 1, 0, 1) -- green text
				gl.Translate(treeX, treeY + 40, treeZ)
				gl.Billboard()
				gl.Text(transporteeEntry, 0, 0, 16, "c")
			 end)
		end
		gl.Color(1, 1, 0, 1) -- yellow text
		gl.PushMatrix()
		gl.Translate(x, y + 40, z)
		gl.Billboard()
		gl.Text(entry, 0, 0, 16, "c")
		gl.PopMatrix()
	end
	gl.Color(1, 1, 1, 1) -- reset color
end

function widget:CommandsChanged()
	local selected = Spring.GetSelectedUnits()
	local cc = widgetHandler.customCommands
	if #selected == 0 then
		return
	end
	local addCustom = false
	for i = 1, #selected do
		local defID = GetUnitDefID(selected[i])
		if defID and (isTransportableDef[defID] or isNanoDef[defID] or isFactoryDef[defID]) then
			addCustom = true
		end
	end
	if addCustom then
		cc[#cc + 1] = CMD_TRANSPORT_TO_DESC
	end
end

local function cmd_notify(uID, cmdID, cmdParams, cmdOpts)
	if isTransportDef[spGetUnitDefID(uID)] then
		local tstate = Get_transport_state(uID)
		local ustate
		if tstate.transporteeID then
			ustate = Get_unit_state(tstate.transporteeID)
		end
		Check_transport_out_off_commision(uID)
		tstate.state = "used"
		-- tstate.isLoaded = false
		-- tstate.transporteeID = nil

		if cmdID == CMD_MOVE then
			tstate = Get_transport_state(uID)
			tstate.homePosition = { x = cmdParams[1], y = cmdParams[2], z = cmdParams[3] }
		end
	end
	if
		isTransportableDef[spGetUnitDefID(uID)]
		and cmdID ~= CMD_TRANSPORT_TO
		and (cmdOpts.shift == false or cmdOpts.meta == false)
	then
		local ustate = Get_unit_state(uID)
		ustate.isWaitingForTransport = false
		unitsWaitingForTransport[uID] = false
		local tstate = ustate.transport_state
		if tstate and tstate.state == "coupled" and tstate.isLoaded == false then
			tstate.state = "available"
			GiveOrderToUnit(tstate.transportID, CMD_STOP, {}, {})
			SetUnitMoveGoal(tstate.transportID, tstate.homePosition.x, tstate.homePosition.y, tstate.homePosition.z)
			tstate.transporteeID = nil
		end
	end
end

function widget:CommandNotify(cmdID, params, opts)
	-- local commandQueue = GetUnitCommands(unitID, -1) or {}
	local selectedUnits = Spring.GetSelectedUnits()
	--if the unit was shared, but the player gave new orders to it, then unflag it as shared
	for _, uID in ipairs(selectedUnits) do
		if not opts.shift then
			local ustate = Get_unit_state(uID)
			if ustate.inshared then
				ustate.inshared = false
			end
		end

		cmd_notify(uID, cmdID, params, opts)
	end
end

--this comes from custom formations 2
--seem to be the same as CommandNotify, but from custom formations 2
function widget:UnitCommandNotify(uID, cmdID, cmdParams, cmdOpts)
	-- local commandQueue = GetUnitCommands(uID, -1) or {}
	--if the unit was shared, but the player gave new orders to it, then unflag it as shared
	if not cmdOpts.shift then
		local ustate = Get_unit_state(uID)
		if ustate.inshared then
			ustate.inshared = false
		end
	end

	cmd_notify(uID, cmdID, cmdParams, cmdOpts)
end

--this comes from custom formations 2 (added by the PR that also added this widget)
--its called before custom formations 2 gives orders
function widget:OrderGivenToUnitsArr(uArr, oArr)
	-- 	local transport_to_command_found = false
	-- 	for index, order in ipairs(oArr) do
	-- 		cmdID = order[1]
	-- 		params = order[2]
	-- 		options = order[3]

	-- 		if cmdID == CMD_TRANSPORT_TO then
	-- 			transport_to_command_found = true
	-- 		end
	-- 	end
	-- 	--fuck it, just go back to where ever the player left u
	-- 	local unitDefID = spGetUnitDefID(uID)
	-- 	if isTransportDef[unitDefID] and cmdID == CMD_MOVE then
	-- --[[ 		Echo("updating start position, notify")
	-- 		transportStartPosition[uID] = cmdParams ]]
	-- 		local tstate = Get_transport_state(uID)
	-- 	end
end

--Widgets cant call these functions, so we need the gadget to do it
function SetUnitMoveGoal(unitID, x, y, z)
	local msg = string.format("POS|%d|%f|%f|%f", unitID, x, y, z)
	Spring.SendLuaRulesMsg(msg)
end

function ClearUnitMoveGoal(UnitID)
	local msg = string.format("TSTP|%d", UnitID)
	Spring.SendLuaRulesMsg(msg)
end

function widget:Shutdown() end
