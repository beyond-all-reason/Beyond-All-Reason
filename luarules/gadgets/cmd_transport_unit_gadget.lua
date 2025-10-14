local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Transport To (Gadget)",
		desc = [[This gadget adds the CMD_AUTO_TRANSPORT, which determines if a transport can be used in the widget, 
                    it also allows the existance of CMD_TRANSPORT_TO in the queue in CommandFallback()
                    it also removes it once a unit has been loaded (not always the case, i think a weird race condition, but does´nt seem to change anything)]],
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

local CMDTYPE_ICON_MAP = CMDTYPE.ICON_MAP
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_STOP = CMD.STOP
local CMD_WAIT = CMD.WAIT
local CMD_INSERT = CMD.INSERT

-- ========= command id & description =========
local CMD_TRANSPORT_TO = GameCMD.TRANSPORT_TO
local CMD_AUTO_TRANSPORT = GameCMD.AUTO_TRANSPORT
local CMD_AUTO_TRANSPORT_DESC = {
	id = CMD_AUTO_TRANSPORT,
	type = CMDTYPE.ICON_MODE,
	name = "Auto Transport",
	cursor = nil,
	action = "auto_transport",
	params = { 0, "Ignore Orders", "Fullfill Orders" },
}

-- ========= classification thresholds =========
local HEAVY_TRANSPORT_MASS_THRESHOLD = 3000
local LIGHT_UNIT_SIZE_THRESHOLD = 6
local UNLOAD_RADIUS = 10
local TRANSPORT_COMMAND_COMPLETE_RADIUS = 20

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

function gadget:RecvLuaMsg(msg, playerID)
	-- Check if it's our message type
	if msg:sub(1, 4) == "POS|" then
		local _, unitID, x, y, z = msg:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)")
		unitID = tonumber(unitID)
		x, y, z = tonumber(x), tonumber(y), tonumber(z)

		if unitID and x and y and z then
			-- Echo("Setting move goal")
			-- Do something with the data here, e.g. issue orders, update state
			Spring.SetUnitMoveGoal(unitID, x, y, z)
		end
		return true -- handled
	elseif msg:sub(1, 4) == "TSTP" then
		-- Decode TSTP message
		local _, unitID = msg:match("([^|]+)|([^|]+)")
		unitID = tonumber(unitID)
		if unitID then
			-- Echo("Clearing move goal")
			local x, y, z = Spring.GetUnitPosition(unitID)
			-- Do something with the unitID
			Spring.ClearUnitGoal(unitID)
			Spring.SetUnitMoveGoal(unitID, x, y, z)
		end
		return true
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID) end

function gadget:Initialize()
	buildDefCaches()
	for _, unitID in ipairs(Spring.GetAllUnits()) do -- handle /luarules reload
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end
