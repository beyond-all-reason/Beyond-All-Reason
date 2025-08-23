local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Transport To (Gadget)",
        desc      = [[This gadget adds the CMD_AUTO_TRANSPORT, which determines if a transport can be used in the widget, 
                    it also allows the existance of CMD_TRANSPORT_TO in the queue in CommandFallback()
                    it also removes it once a unit has been loaded (not always the case, i think a weird race condition, but does´nt seem to change anything)]],
        author    = "Silla Noble",
        date      = "uhhhhh.....",
        license   = "A what now?",
        layer     = 1,
        enabled   = true
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
local CMD_LOAD_UNITS   = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_STOP         = CMD.STOP
local CMD_WAIT         = CMD.WAIT
local CMD_INSERT       = CMD.INSERT

-- ========= command id & description =========
local CMD_TRANSPORT_TO = GameCMD.TRANSPORT_TO
local CMD_TRANSPORT_WHO = GameCMD.TRANSPORT_WHO
local CMD_AUTO_TRANSPORT = GameCMD.AUTO_TRANSPORT
local CMD_AUTO_TRANSPORT_DESC = {
	id = CMD_AUTO_TRANSPORT,
	type = CMDTYPE.ICON_MODE,
	name = "Auto Transport",
	cursor = nil,
	action = "auto_transport",
	params 	= {0, 'Ignore Orders', 'Fullfill Orders'},
}

-- ========= classification thresholds =========
local HEAVY_TRANSPORT_MASS_THRESHOLD = 3000
local LIGHT_UNIT_SIZE_THRESHOLD = 6
local UNLOAD_RADIUS = 10

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
            transportClass[defID] = (transportCapacityMass[defID] >= HEAVY_TRANSPORT_MASS_THRESHOLD) and "heavy" or "light"
        end

        -- transportability (grounded, movable non-building, not explicitly excluded)
        local movable = (ud.speed or 0) > 0
        local grounded = not ud.canFly
        local notBuilding = not ud.isBuilding
        local notCantBeTransported = (ud.cantBeTransported == nil) or (ud.cantBeTransported == false)

        local isNano = ud.isBuilder and not ud.canMove and not ud.isFactory
        local isFactory = ud.isFactory

        if (grounded and notCantBeTransported) then
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
function gadget:Shutdown()
end

local loadedUnits = {} --[unitID=boolean]

function gadget:CommandFallback(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
    if cmdID == CMD_TRANSPORT_TO then
        if loadedUnits[unitID] then
            loadedUnits[unitID] = nil
            return true, true
        else
            return true, false
        end
    end
    if cmdID == CMD_TRANSPORT_WHO then
        if #cmdParams == 1 then
            --is icon_unit
            --if the unit the command was targeting is lifted, then we consider this command done
            if loadedUnits[cmdParams[1]]then
                return true, true
            else
                return true, false
            end
        end
    end
end

function gadget:UnitLoaded(unitID, unitDefID, teamID, transportID)
    loadedUnits[unitID] = true
end

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
    loadedUnits[unitID] = nil
end

function gadget:UnitCreated(unitID, unitDefID, _)
	if isTransportDef[unitDefID] then
		CMD_AUTO_TRANSPORT_DESC.params[1] = 0
		Spring.InsertUnitCmdDesc(unitID, CMD_AUTO_TRANSPORT_DESC)
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	-- accepts: CMD_QUOTA_BUILD_TOGGLE
    if not isTransportDef[unitDefID] and cmdID == CMD_TRANSPORT_WHO then
        --non transport units should´nt be able to have this command on their queue
        return false
    end
	if isTransportDef[unitDefID] then
        local cmdDescID = Spring.FindUnitCmdDesc(unitID, CMD_AUTO_TRANSPORT)
        if cmdDescID then
            CMD_AUTO_TRANSPORT_DESC.params[1] = cmdParams[1]
            Spring.EditUnitCmdDesc(unitID, cmdDescID, {params = CMD_AUTO_TRANSPORT_DESC.params})
        end
		return false  -- command was used
	end
	return true  -- command was not used
end

function gadget:Initialize()
    buildDefCaches()
    gadgetHandler:RegisterAllowCommand(CMD_AUTO_TRANSPORT)
	for _, unitID in ipairs(Spring.GetAllUnits()) do -- handle /luarules reload
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end