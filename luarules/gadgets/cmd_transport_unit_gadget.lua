local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Transport To (Gadget)",
		desc = [[
        Allows the existance of CMD_TRANSPORT_TO in the queue in CommandFallback(),
        Removes it once a unit has been loaded]],
		author = "Silla Noble",
		date = "uhhhhh.....",
		license = "A what now?",
		layer = 1,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- ========= locals / engine aliases =========
local Echo = Spring.Echo
local GameFrame = Spring.GetGameFrame
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local GetUnitCommands = Spring.GetUnitCommands

local CMDTYPE_ICON_MAP = CMDTYPE.ICON_MAP
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_STOP = CMD.STOP
local CMD_WAIT = CMD.WAIT
local CMD_INSERT = CMD.INSERT

-- ========= command id & description =========
local CMD_TRANSPORT_TO = GameCMD.TRANSPORT_TO

-- ========= classification thresholds =========
local HEAVY_TRANSPORT_MASS_THRESHOLD = 3000
local LIGHT_UNIT_SIZE_THRESHOLD = 6
local UNLOAD_RADIUS = 10
local TRANSPORT_COMMAND_COMPLETE_RADIUS = 100

-- ========= def caches =========
local isFactoryDef = {}
local isNanoDef = {}
local isTransportDef = {}
local transportClass = {} -- "light" | "heavy"
local transportCapacityMass = {}
local transportSizeLimit = {}
local transportCapSlots = {}

local isTransportableDef = {}
local unitMass = {}
local unitXsize = {}

-- ========= UnitDef scanning =========
local function buildDefCaches()
	for defID, ud in pairs(UnitDefs) do
		-- transports
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

-- ========= gadget lifecycle =========
function gadget:Shutdown() end

local loadedUnits = {} --[unitID=boolean]
local function distanceSq(ax, az, bx, bz)
	local dx, dz = ax - bx, az - bz
	return dx * dx + dz * dz
end

function gadget:CommandFallback(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
	if cmdID == CMD_TRANSPORT_TO then
		--if the unit gets close enough to the target point, consider the command complete
		local ux, uy, uz = Spring.GetUnitPosition(unitID)
		local distance = distanceSq(ux, uz, cmdParams[1], cmdParams[3])
		if loadedUnits[unitID] or distance < TRANSPORT_COMMAND_COMPLETE_RADIUS then
			loadedUnits[unitID] = nil
			return true, true
		else
			return true, false
		end
	end
end

function gadget:UnitLoaded(unitID, unitDefID, teamID, transportID)
	loadedUnits[unitID] = true
end

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	loadedUnits[unitID] = nil
end

--this is here to expose TransportCMDContinue / TransportCMDHold for widgets to use
--only works if the units is executing a CMD_TRANSPORT_TO to prevent other widgets from abusing this for illegal unit control
function gadget:RecvLuaMsg(msg, playerID)
	local _, _, _, teamID = Spring.GetPlayerInfo(playerID)

	if msg:sub(1, 4) == "POS|" then
		local unitID = tonumber(msg:match("^POS|([^|]+)"))
		if unitID and Spring.GetUnitTeam(unitID) == teamID then
			-- BREAKCHECK: current command may be CMD_INSERT instead of CMD_TRANSPORT_TO when meta-inserted.
			-- BREAKCHECK: if the command queue advances before this message arrives, this becomes a no-op.
			local commandQueue = GetUnitCommands(unitID, -1) or {}
			local currentCommand = commandQueue[1]
			if currentCommand and currentCommand.id == CMD_TRANSPORT_TO then
				Spring.SetUnitMoveGoal(unitID, currentCommand.params[1], currentCommand.params[2], currentCommand.params[3])
			end
			return true
		end
	elseif msg:sub(1, 4) == "TSTP" then
		local unitID = tonumber(msg:match("^TSTP|([^|]+)"))
		if unitID and Spring.GetUnitTeam(unitID) == teamID then
			-- BREAKCHECK: same current-command race as above.
			-- BREAKCHECK: original TSTP also set move goal to current position to stop; kept here.
			local cmdID = GetUnitCurrentCommand(unitID)
			if cmdID == CMD_TRANSPORT_TO then
				local x, y, z = Spring.GetUnitPosition(unitID)
				Spring.ClearUnitGoal(unitID)
				Spring.SetUnitMoveGoal(unitID, x, y, z)
			end
			return true
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID) end

function gadget:AllowCommand(uID, uDefID, unitTeam, cmdID)
	if cmdID == CMD_TRANSPORT_TO then
		if not isTransportableDef[uDefID] then
			return false
		end
	end
	return true
end

function gadget:Initialize()
	buildDefCaches()
	for _, unitID in ipairs(Spring.GetAllUnits()) do -- handle /luarules reload
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end
