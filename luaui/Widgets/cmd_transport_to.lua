---@diagnostic disable: param-type-mismatch, duplicate-set-field, need-check-nil, assign-type-mismatch, inject-field

function widget:GetInfo()
	return {
		name = "Transport To",
		desc = "Adds a map-click Transport To command and auto-assigns transports",
		author = "Silla Noble, IsaJoeFeat",
		license = "GNU GPL v2 or later",
		layer = 1,
		enabled = true,
		handler = true,
	}
end

--------------------------------------------------------------------------------
-- Overview
--
-- This widget owns the unsynced Transport To user experience:
--   * exposes the custom command button
--   * assigns cursor / command draw visuals
--   * tracks available transports and waiting units
--   * reacts to player-issued orders and custom formation orders
--   * requests synced move-goal changes through LuaRules messages
--
-- The synced gadget counterpart:
--   * validates the command
--   * marks Transport To complete once loaded or once destination is reached
--   * receives POS / TSTP LuaRules messages and applies synced move-goal changes
--------------------------------------------------------------------------------

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

local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitDefID = Spring.GetUnitDefID

local CMDTYPE_ICON_MAP = CMDTYPE.ICON_MAP
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNIT
local CMD_STOP = CMD.STOP
local CMD_INSERT = CMD.INSERT
local CMD_MOVE = CMD.MOVE

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

local isTransportableDef = {}
local unitMass = {}
local unitXsize = {}

--------------------------------------------------------------------------------
-- UnitDef caches
--------------------------------------------------------------------------------

local function buildDefCaches()
	for defID, ud in pairs(UnitDefs) do
		if ud.isTransport and ud.canFly and (ud.transportCapacity or 0) > 0 then
			isTransportDef[defID] = true
			transportCapacityMass[defID] = ud.transportMass or 0
			transportSizeLimit[defID] = ud.transportSize or 0
			transportClass[defID] = (transportCapacityMass[defID] >= HEAVY_TRANSPORT_MASS_THRESHOLD) and "heavy" or "light"
		end

		local grounded = not ud.canFly
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

--------------------------------------------------------------------------------
-- Transport matching helpers
--------------------------------------------------------------------------------

local function CanTransport(transportID, transportDefID, unitID, unitDefID)
	local transporting = GetUnitIsTransporting(transportID)
	if not transporting then
		return false, ""
	end
	if #transporting > 0 then
		return false, ""
	end

	local maxSize = transportSizeLimit[transportDefID] or 0
	local unitSize = unitXsize[unitDefID] or 0
	if maxSize > 0 and (unitSize > maxSize * 2) then
		return false, ""
	end

	local capacityMass = transportCapacityMass[transportDefID] or 0
	local mass = unitMass[unitDefID] or 0
	if capacityMass > 0 and mass > capacityMass then
		return false, ""
	end

	return true, ""
end

local function GetUnitTransportType(unitDefID)
	local size = unitXsize[unitDefID] or 0
	local mass = unitMass[unitDefID] or 0
	if size <= LIGHT_UNIT_SIZE_THRESHOLD and mass < HEAVY_TRANSPORT_MASS_THRESHOLD then
		return "light"
	end
	return "heavy"
end

local function PickBestTransport(unitID, ux, uz, unitDefID)
	local wantedType = GetUnitTransportType(unitDefID)
	local bestLight, bestLightDist
	local bestHeavy, bestHeavyDist

	for transportID in pairs(knownTransports) do
		local transportDefID = GetUnitDefID(transportID)
		if transportDefID then
			local transportState = Get_transport_state(transportID)
			local ok = CanTransport(transportID, transportDefID, unitID, unitDefID)
				and transportState
				and (transportState.state == "idle" or transportState.state == "available")

			if ok then
				local tx, _, tz = GetUnitPosition(transportID)
				if tx and tz and ux and uz then
					local dist = distanceSq(tx, tz, ux, uz)
					local class = transportClass[transportDefID]

					if class == "light" then
						if not bestLight or dist < bestLightDist then
							bestLight, bestLightDist = transportID, dist
						end
					else
						if not bestHeavy or dist < bestHeavyDist then
							bestHeavy, bestHeavyDist = transportID, dist
						end
					end
				end
			end
		end
	end

	if wantedType == "light" and bestLight then
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

local function dictLength(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

local function SetTransportAvailable(transportState)
	if not transportState then
		return
	end

	transportState.state = "available"
	transportState.isLoaded = false
	transportState.transporteeID = nil
end

local function ReleaseCompetingTransports(unitID, winningTransportID)
	for transportID in pairs(knownTransports) do
		if transportID ~= winningTransportID then
			local transportState = Get_transport_state(transportID)
			if transportState
				and transportState.transporteeID == unitID
				and transportState.state == "coupled"
				and not transportState.isLoaded
			then
				GiveOrderToUnit(transportID, CMD_STOP, {}, {})
				if transportState.homePosition then
					SetUnitMoveGoal(
						transportID,
						transportState.homePosition.x,
						transportState.homePosition.y,
						transportState.homePosition.z
					)
				end
				SetTransportAvailable(transportState)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

--[[
Transport states:
  idle       = transport is not currently used by the widget
  available  = transport can be reused by the widget and is returning home
  used       = transport is under explicit player control
  coupled    = widget has assigned the transport to a passenger
  decoupled  = transport has unloaded and is retracing / returning
]]
---@class TransportState
---@field state '"idle"' | '"available"' | '"used"' | '"coupled"' | '"decoupled"'
---@field transportID integer|nil
---@field transporteeID integer|nil
---@field homePosition {x:number, y:number, z:number}|nil
---@field isLoaded boolean
---@type table<integer, TransportState>
local transport_states = {}

--[[
Per-unit state used by the widget:
  outshared             = unit was shared out from our team
  inshared              = unit was shared into our team
  transport_state       = currently linked widget-owned transport state
  isWaitingForTransport = unit is walking toward its destination while waiting
]]
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
local pendingClearMoveGoal = {}

---@type table<integer, boolean>
local outSharedUnits = {}

function Get_transport_state(transportID)
	if not ValidUnitID(transportID) then
		return nil
	end

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
	if not ValidUnitID(unitID) then
		return nil
	end

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

local function unitRequestedType(unitDefID)
	local size = unitXsize[unitDefID] or 0
	local mass = unitMass[unitDefID] or 0
	if size <= LIGHT_UNIT_SIZE_THRESHOLD and mass < HEAVY_TRANSPORT_MASS_THRESHOLD then
		return "light"
	end
	return "heavy"
end

---@return CreateCommand[]
function Transform_transportTo_commands(_, unitID)
	local chainedTargets = {}

	for _, cmd in pairs(GetUnitCommands(unitID, -1)) do
		if cmd.id == CMD_TRANSPORT_TO then
			table.insert(chainedTargets, cmd)
		else
			break
		end
	end

	local orders = {}

	-- Follow chained Transport To points and unload only at the final target.
	for index, cmd in pairs(chainedTargets) do
		if index == #chainedTargets then
			table.insert(orders, {
				CMD_INSERT,
				{ index, CMD_UNLOAD_UNITS, CMD.OPT_SHIFT, cmd.params[1], cmd.params[2], cmd.params[3] },
				{ "alt" },
			})
		else
			table.insert(orders, {
				CMD_INSERT,
				{ index, CMD_MOVE, CMD.OPT_SHIFT, cmd.params[1], cmd.params[2], cmd.params[3] },
				{ "alt" },
			})
		end
	end

	-- Return by retracing the same path.
	for i = #chainedTargets, 1, -1 do
		local cmd = chainedTargets[i]
		table.insert(orders, {
			CMD_INSERT,
			{
				#chainedTargets + (#chainedTargets - i),
				CMD_MOVE,
				CMD.OPT_SHIFT,
				cmd.params[1],
				cmd.params[2],
				cmd.params[3],
			},
			{ "alt" },
		})
	end

	return orders
end

local function refreshKnownTransports()
	knownTransports = setmetatable({}, { __mode = "k" })

	local units = GetTeamUnits(myTeamID)
	for i = 1, #units do
		local unitID = units[i]
		local defID = GetUnitDefID(unitID)

		if defID and isTransportDef[defID] then
			knownTransports[unitID] = true

			local transportState = Get_transport_state(unitID)
			if transportState and not transportState.homePosition then
				local x, y, z = GetUnitPosition(unitID)
				transportState.homePosition = { x = x, y = y, z = z }
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Widget lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
	local _, _, _, teamID = GetPlayerInfo(GetMyPlayerID(), false)
	myTeamID = teamID

	buildDefCaches()
	refreshKnownTransports()

	Spring.SetCustomCommandDrawData(CMD_TRANSPORT_TO, "transto", { 1, 1, 1, 1 })
end

function widget:PlayerChanged()
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget()
		return
	end

	local _, _, _, teamID = GetPlayerInfo(GetMyPlayerID(), false)
	myTeamID = teamID
	refreshKnownTransports()
end

--------------------------------------------------------------------------------
-- Transport discovery / ownership bookkeeping
--------------------------------------------------------------------------------

function widget:UnitGiven(unitID, unitDefID, unitTeam, newTeam)
	if isTransportableDef[unitDefID] then
		if newTeam == myTeamID then
			local unitState = Get_unit_state(unitID)
			if unitState then
				unitState.inshared = true
			end
		elseif unitTeam == myTeamID then
			local unitState = Get_unit_state(unitID)
			if unitState then
				unitState.outshared = true
				outSharedUnits[unitID] = true
			end
		end
	end
end

function widget:MetaUnitRemoved(unitID)
	knownTransports[unitID] = false
end

function widget:MetaUnitAdded(unitID, unitDefID, teamID)
	if teamID ~= myTeamID then
		return
	end

	if isTransportDef[unitDefID] then
		knownTransports[unitID] = true

		local transportState = Get_transport_state(unitID)
		if transportState then
			transportState.state = "idle"

			local x, y, z = Spring.GetUnitPosition(unitID)
			transportState.homePosition = { x = x, y = y, z = z }
		end
	end

	if isTransportableDef[unitDefID] then
		local unitState = Get_unit_state(unitID)
		if unitState then
			unitState.outshared = false
			outSharedUnits[unitID] = nil
		end
	end
end

function widget:UnitFromFactory(unitID, unitDefID)
	if isTransportDef[unitDefID] then
		Check_try_to_transport_waiting(unitID, unitDefID)
	end
end

function On_tstate_becameAvalible(transportState)
	if transportState and transportState.transportID then
		Check_try_to_transport_waiting(transportState.transportID, GetUnitDefID(transportState.transportID))
	end
end

function Check_try_to_pick_transport(unitID, unitDefID)
	local unitState = Get_unit_state(unitID)
	if not unitState or not unitState.isWaitingForTransport then
		return
	end

	-- Already linked to a transport; do not assign another.
	if unitState.transport_state ~= nil then
		return
	end

	local foundTransport = PickBestTransport(unitID, GetUnitPosition(unitID), unitDefID)
	if foundTransport then
		GiveOrderToUnit(foundTransport, CMD_LOAD_UNITS, { unitID }, {})

		local transportState = Get_transport_state(foundTransport)
		if not transportState then
			return
		end

		transportState.state = "coupled"
		transportState.transportID = foundTransport
		transportState.transporteeID = unitID

		unitState.transport_state = transportState
		unitState.isWaitingForTransport = false
		unitsWaitingForTransport[unitID] = false

		ClearUnitMoveGoal(unitID)
		pendingClearMoveGoal[unitID] = true

		ReleaseCompetingTransports(unitID, foundTransport)

		return foundTransport
	end
end

local function distance_between_units(unitID, otherUnitID)
	local ux, _, uz = GetUnitPosition(unitID)
	local vx, _, vz = GetUnitPosition(otherUnitID)
	return distanceSq(ux, uz, vx, vz)
end

function Check_try_to_transport_waiting(transportID, unitDefID)
	if not ValidUnitID(transportID) then
		return
	end

	for unitID, active in pairs(table.merge(unitsWaitingForTransport, outSharedUnits)) do
		if active then
			local unitState = Get_unit_state(unitID)

			-- Skip units that are already linked to another transport.
			if unitState and unitState.transport_state == nil then
				local canTransport = CanTransport(transportID, GetUnitDefID(transportID), unitID, unitDefID)
				local transporteeType = unitRequestedType(unitDefID)
				local transportType = transportClass[GetUnitDefID(transportID)]

				if canTransport then
					local score = 0
					local ownDistance = distance_between_units(unitID, transportID)
					local ownIsMatch = (transportType == transporteeType)
					local availableCount = 0

					for otherTransportID, present in pairs(knownTransports) do
						local otherState = Get_transport_state(otherTransportID)
						if present and otherTransportID ~= transportID and otherState
							and (otherState.state == "available" or otherState.state == "idle")
						then
							availableCount = availableCount + 1

							local otherDistance = distance_between_units(unitID, otherTransportID)
							local isMatch = (transportClass[GetUnitDefID(otherTransportID)] == transporteeType)

							if ownDistance < otherDistance then
								score = score + 1
							end
							if ownIsMatch and not isMatch then
								score = score + 0.5
							end
						elseif availableCount == 0 or not (otherState and (otherState.state == "available" or otherState.state == "idle")) then
							score = score + 1
						end
					end

					if dictLength(knownTransports) == 1 or (score > dictLength(knownTransports) / 2) then
						GiveOrderToUnit(transportID, CMD_LOAD_UNITS, { unitID }, {})

						local transportState = Get_transport_state(transportID)
						if not transportState then
							return
						end

						transportState.state = "coupled"
						transportState.transportID = transportID
						transportState.transporteeID = unitID

						unitState.transport_state = transportState
						unitState.isWaitingForTransport = false
						unitsWaitingForTransport[unitID] = false
						pendingClearMoveGoal[unitID] = true

						ReleaseCompetingTransports(unitID, transportID)
						break
					end
				end
			end
		end
	end
end

function Check_transport_out_off_commision(transportID)
	local transportState = Get_transport_state(transportID)
	if not transportState then
		return
	end

	local passengerID = transportState.transporteeID
	local unitState = passengerID and Get_unit_state(passengerID) or nil

	if transportState.isLoaded and unitState then
		unitState.transport_state = nil
		unitState.isWaitingForTransport = false
		unitsWaitingForTransport[passengerID] = false

		transportState.transporteeID = nil
		transportState.isLoaded = false

	elseif unitState then
		local commandQueue = GetUnitCommands(passengerID, -1) or {}
		local nextCommand = commandQueue[1]
		local cmdParams = nextCommand and nextCommand.params or {}

		unitState.transport_state = nil
		transportState.transporteeID = nil
		transportState.isLoaded = false

		unitState.isWaitingForTransport = true
		unitsWaitingForTransport[passengerID] = true

		if cmdParams[1] and cmdParams[2] and cmdParams[3] then
			SetUnitMoveGoal(passengerID, cmdParams[1], cmdParams[2], cmdParams[3])
		end

		Check_try_to_pick_transport(passengerID, GetUnitDefID(passengerID))
	end
end

--------------------------------------------------------------------------------
-- Widget callins
--------------------------------------------------------------------------------

function widget:UnitIdle(unitID, unitDefID, unitTeam)
	if isTransportDef[unitDefID] and unitTeam == myTeamID then
		local transportState = Get_transport_state(unitID)
		if transportState and transportState.state == "used" then
			transportState.state = "idle"
			transportState.transporteeID = nil
			Check_try_to_transport_waiting(unitID, unitDefID)
		end
	end
end

function widget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if transportTeam ~= myTeamID then
		return
	end

	local transportState = Get_transport_state(transportID)
	if not transportState then
		return
	end

	if transportState.state == "coupled" then
		local orders = Transform_transportTo_commands(transportID, unitID)
		Spring.GiveOrderArrayToUnit(transportID, orders)
	end

	transportState.isLoaded = true
	transportState.transporteeID = unitID

	local unitState = Get_unit_state(unitID)
	if unitState then
		unitState.transport_state = transportState
		unitState.isWaitingForTransport = false
	end
	unitsWaitingForTransport[unitID] = false

	ReleaseCompetingTransports(unitID, transportID)
end

function widget:UnitUnloaded(unitID, _, _, transportID)
	local transportState = Get_transport_state(transportID)
	if not transportState then
		return
	end

	if transportState.state == "coupled" then
		local unitState = Get_unit_state(unitID)
		if unitState then
			unitState.transport_state = nil
		end
		transportState.state = "decoupled"
	end

	transportState.isLoaded = false
	transportState.transporteeID = nil
end

function widget:UnitDestroyed(unitID, unitDefID)
	if isTransportDef[unitDefID] then
		Check_transport_out_off_commision(unitID)
	end

	Remove_transport_state(unitID)
	Remove_unit_state(unitID)
	unitsWaitingForTransport[unitID] = nil
	pendingClearMoveGoal[unitID] = nil
	outSharedUnits[unitID] = nil
end

function Check_setMoveGoal(unitID, x, y, z, unitTeam)
	local commandQueue = GetUnitCommands(unitID, -1) or {}
	local nextCommand = commandQueue[1]
	local actualUnitTeam = unitTeam or GetUnitTeam(unitID)
	local isOwnTeam = actualUnitTeam == myTeamID
	local unitDefID = GetUnitDefID(unitID)

	if unitDefID and isTransportableDef[unitDefID] then
		local unitState = Get_unit_state(unitID)
		if unitState and unitState.isWaitingForTransport and isOwnTeam then
			if nextCommand and nextCommand.id ~= CMD_TRANSPORT_TO then
				unitState.isWaitingForTransport = false
				unitsWaitingForTransport[unitID] = false

				local transportState = unitState.transport_state
				if transportState and transportState.state == "coupled" then
					transportState.state = "available"
					On_tstate_becameAvalible(transportState)
					if transportState.homePosition then
						SetUnitMoveGoal(unitID, transportState.homePosition.x, transportState.homePosition.y, transportState.homePosition.z)
					end
					transportState.transporteeID = nil
					Check_try_to_pick_transport(unitID, unitDefID)
				end
			else
				SetUnitMoveGoal(unitID, x, y, z)
			end
		end
	end
end

function widget:UnitCmdDone(unitID, unitDefID, unitTeam, _, cmdParams, cmdOpts)
	if isFactoryDef[unitDefID] then
		return
	end

	local commandQueue = GetUnitCommands(unitID, -1) or {}
	local currentCommand = spGetUnitCurrentCommand(unitID)
	local nextCommand = commandQueue[1]
	local isLastInQueue = currentCommand == nil
	local isOwnTeam = unitTeam == myTeamID

	-- Detect engine-generated completion from CMD.INSERT expansion.
	local comesFromEngine = cmdOpts and cmdOpts.coded == 16

	if isTransportDef[unitDefID] then
		local transportState = Get_transport_state(unitID)
		if transportState and transportState.state == "decoupled" and isOwnTeam and isLastInQueue then
			transportState.state = "available"
			On_tstate_becameAvalible(transportState)
			if transportState.homePosition then
				SetUnitMoveGoal(unitID, transportState.homePosition.x, transportState.homePosition.y, transportState.homePosition.z)
			end
			transportState.transporteeID = nil
		end
	end

	if nextCommand and nextCommand.id == CMD_TRANSPORT_TO and isTransportableDef[unitDefID] then
		local nextParams = nextCommand.params
		local unitState = Get_unit_state(unitID)
		local transportState = unitState and unitState.transport_state or nil

		if unitState and not transportState then
			local foundTransport = PickBestTransport(unitID, cmdParams[1], cmdParams[3], unitDefID)
			if foundTransport then
				local pickedState = Get_transport_state(foundTransport)
				if pickedState then
					GiveOrderToUnit(foundTransport, CMD_LOAD_UNITS, { unitID }, {})
					pickedState.state = "coupled"
					pickedState.transportID = foundTransport
					pickedState.transporteeID = unitID
					unitState.transport_state = pickedState
					unitState.isWaitingForTransport = false
					unitsWaitingForTransport[unitID] = false

					ReleaseCompetingTransports(unitID, foundTransport)
				end
			else
				unitState.isWaitingForTransport = true
				unitsWaitingForTransport[unitID] = true
				SetUnitMoveGoal(unitID, nextParams[1], nextParams[2], nextParams[3])
			end
		end
	elseif isTransportableDef[unitDefID] and not comesFromEngine then
		local unitState = Get_unit_state(unitID)
		local transportState = unitState and unitState.transport_state or nil

		if transportState and transportState.state == "coupled" then
			transportState.state = "available"
			On_tstate_becameAvalible(transportState)
			transportState.transporteeID = nil
			GiveOrderToUnit(transportState.transportID, CMD_STOP, {}, {})
			if transportState.homePosition then
				SetUnitMoveGoal(
					transportState.transportID,
					transportState.homePosition.x,
					transportState.homePosition.y,
					transportState.homePosition.z
				)
			end
		end

		if unitState then
			unitState.isWaitingForTransport = false
			unitsWaitingForTransport[unitID] = false
		end
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts)
	if isFactoryDef[unitDefID] then
		return
	end

	if isTransportableDef[unitDefID] then
		local unitState = Get_unit_state(unitID)
		if not unitState then
			return
		end

		local commandQueue = GetUnitCommands(unitID, -1) or {}
		local isFirstInQueue = cmdOpts.shift == false or (#commandQueue == 0)

		if cmdID == CMD_INSERT then
			local insertIsTransportTo = cmdParams[2] == CMD_TRANSPORT_TO
			if insertIsTransportTo then
				cmdID = CMD_TRANSPORT_TO
				cmdOpts = cmdParams[3]
				cmdParams = { cmdParams[4], cmdParams[5], cmdParams[6] }
				isFirstInQueue = true
			end
		end

		local isOwnTeam = unitTeam == myTeamID
		local _, _, _, _, buildProgress = Spring.GetUnitHealth(unitID)
		local isNanoFrame = buildProgress < 1.0

		if
			cmdID == CMD_TRANSPORT_TO
			and isFirstInQueue
			and isOwnTeam
			and not isNanoFrame
			and unitState.transport_state == nil
		then
			local ux, _, uz = GetUnitPosition(unitID)
			local foundTransport = PickBestTransport(unitID, ux, uz, unitDefID)

			if foundTransport then
				local transportState = Get_transport_state(foundTransport)
				if not transportState then
					return
				end

				GiveOrderToUnit(foundTransport, CMD_LOAD_UNITS, { unitID }, {})
				transportState.state = "coupled"
				transportState.transportID = foundTransport
				transportState.transporteeID = unitID
				unitState.transport_state = transportState
				unitState.isWaitingForTransport = false
				unitsWaitingForTransport[unitID] = false

				ReleaseCompetingTransports(unitID, foundTransport)
			else
				unitState.isWaitingForTransport = true
				unitsWaitingForTransport[unitID] = true
				SetUnitMoveGoal(unitID, cmdParams[1], 0, cmdParams[3])
			end
		end
	end
end

function widget:Update()
	for unitID, active in pairs(pendingClearMoveGoal) do
		if active then
			ClearUnitMoveGoal(unitID)
			pendingClearMoveGoal[unitID] = false
		end
	end
end

function widget:DrawWorld()
end

function widget:CommandsChanged()
	local selected = Spring.GetSelectedUnits()
	local customCommands = widgetHandler.customCommands

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
		customCommands[#customCommands + 1] = CMD_TRANSPORT_TO_DESC
	end
end

--------------------------------------------------------------------------------
-- Player-issued order notifications
--------------------------------------------------------------------------------

local function cmd_notify(unitID, cmdID, cmdParams, cmdOpts)
	local unitDefID = spGetUnitDefID(unitID)
	if not unitDefID then
		return
	end

	if isFactoryDef[unitDefID] then
		return
	end

	if isTransportDef[unitDefID] then
		local transportState = Get_transport_state(unitID)
		if transportState then
			Check_transport_out_off_commision(unitID)
			transportState.state = "used"

			if cmdID == CMD_MOVE then
				transportState = Get_transport_state(unitID)
				if transportState then
					transportState.homePosition = { x = cmdParams[1], y = cmdParams[2], z = cmdParams[3] }
				end
			end
		end
	end

	if isTransportableDef[unitDefID] and cmdID ~= CMD_TRANSPORT_TO and cmdOpts.shift == false then
		local unitState = Get_unit_state(unitID)
		if not unitState then
			return
		end

		unitState.isWaitingForTransport = false
		unitsWaitingForTransport[unitID] = false

		local transportState = unitState.transport_state
		if transportState and transportState.state == "coupled" and transportState.isLoaded == false then
			transportState.state = "available"
			On_tstate_becameAvalible(transportState)
			GiveOrderToUnit(transportState.transportID, CMD_STOP, {}, {})
			if transportState.homePosition then
				SetUnitMoveGoal(transportState.transportID, transportState.homePosition.x, transportState.homePosition.y, transportState.homePosition.z)
			end
			transportState.transporteeID = nil
		end

		unitState.transport_state = nil
	end
end

function widget:CommandNotify(cmdID, params, opts)
	local selectedUnits = Spring.GetSelectedUnits()

	for _, unitID in ipairs(selectedUnits) do
		if not opts.shift then
			local unitState = Get_unit_state(unitID)
			if unitState and unitState.inshared then
				unitState.inshared = false
			end
		end

		cmd_notify(unitID, cmdID, params, opts)
	end
end

function widget:UnitCommandNotify(unitID, cmdID, cmdParams, cmdOpts)
	if not cmdOpts.shift then
		local unitState = Get_unit_state(unitID)
		if unitState and unitState.inshared then
			unitState.inshared = false
		end
	end

	-- Custom formations routes through UnitCommandNotify.
	-- Run the same assignment logic as a normal unit command first.
	local unitDefID = spGetUnitDefID(unitID)
	local unitTeam = GetUnitTeam(unitID)
	if unitDefID and unitTeam then
		widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts)
	end

	cmd_notify(unitID, cmdID, cmdParams, cmdOpts)
end

--------------------------------------------------------------------------------
-- Widget -> gadget move-goal bridge
--------------------------------------------------------------------------------

function SetUnitMoveGoal(unitID, x, y, z)
	if not unitID or not x or not y or not z then
		return
	end

	local msg = string.format("POS|%d|%f|%f|%f", unitID, x, y, z)
	Spring.SendLuaRulesMsg(msg)
end

function ClearUnitMoveGoal(unitID)
	if not unitID then
		return
	end

	local msg = string.format("TSTP|%d", unitID)
	Spring.SendLuaRulesMsg(msg)
end

function widget:Shutdown()
end
