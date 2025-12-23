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
local ValidUnitID = Spring.ValidUnitID

local CMDTYPE_ICON_MAP = CMDTYPE.ICON_MAP
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_STOP = CMD.STOP
local CMD_WAIT = CMD.WAIT
local CMD_INSERT = CMD.INSERT

-- ========= command id & description =========
local CMD_TRANSPORT_TO = GameCMD.TRANSPORT_TO
local CMD_AUTO_TRANSPORT = GameCMD.AUTO_TRANSPORT

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

--this is here to expose setgoal and cleargoal for widgets to use
function gadget:RecvLuaMsg(msg, playerID)
	local _, _, _, teamID = Spring.GetPlayerInfo(playerID)
	if msg:sub(1, 4) == "POS|" then
		local _, unitID, x, y, z = msg:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)")

		unitID = tonumber(unitID)
		if unitID and ValidUnitID(unitID) and Spring.GetUnitTeam(unitID) == teamID then
			x, y, z = tonumber(x), tonumber(y), tonumber(z)

			if unitID and x and y and z then
				Spring.SetUnitMoveGoal(unitID, x, y, z)
			end
			return true
		end
	elseif msg:sub(1, 4) == "TSTP" then
		local _, unitID = msg:match("([^|]+)|([^|]+)")

		unitID = tonumber(unitID)
		if unitID and ValidUnitID(unitID) and Spring.GetUnitTeam(unitID) == teamID then
			if unitID then
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
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end
