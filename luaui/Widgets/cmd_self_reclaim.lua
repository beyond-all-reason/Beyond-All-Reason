local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Self Reclaim",
		desc = "Adds a command(action handler) to all units that makes all construnction turrets in range reclaim that unit. Keybind to self_reclaim.",
		author = "hihoman23",
		date = "January 2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

include("keysym.h.lua")

local constructors = {} -- will get filled up with each constructor in the form of {unitID, buildRange^2}

local GetSpectatingState = Spring.GetSpectatingState
local GetUnitPosition = Spring.GetUnitPosition
local GiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local GetSelectedUnits = Spring.GetSelectedUnits
local myTeam = Spring.GetMyTeamID()

local CMD_INSERT = CMD.INSERT

local function getValidCons(x, z, target)
    local validCons = {}

    -- dist: build range 
    for con, dist in pairs(constructors) do
        local conX, _, conZ = GetUnitPosition(con)
        if (math.diag(conX - x, conZ - z) <= dist) and (target ~= con) then
            validCons[#validCons+1] = con
        end
    end
    return validCons
end

local function reclaimSelectedUnits()
    for _, unitID in pairs(GetSelectedUnits()) do
        local ux, _, uz = GetUnitPosition(unitID)
        GiveOrderToUnitArray(
            getValidCons(ux, uz),
            CMD_INSERT,
            {0,CMD.RECLAIM, CMD.OPT_SHIFT,unitID},
            CMD.OPT_ALT
        )
    end
    return true
end

local function InitUnit(unitID, unitDefID, unitTeam)
    if unitTeam == myTeam then
        local def = UnitDefs[unitDefID]
        if def.isStaticBuilder and not def.isFactory then
            constructors[unitID] = def.buildDistance
        end
    end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, bID)
    InitUnit(unitID, unitDefID, unitTeam)
end

function widget:UnitGiven(unitID, unitDefID, unitTeam)
    InitUnit(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
    constructors[unitID] = nil
end

function widget:Initialize()

    widgetHandler:AddAction("self_reclaim", reclaimSelectedUnits, nil, "p")

    if GetSpectatingState() then
        widgetHandler:RemoveWidget()
        return
    end
    -- initialize units when /luaui reload
    for _, unitID in pairs(Spring.GetTeamUnits(myTeam)) do
        InitUnit(unitID, Spring.GetUnitDefID(unitID), myTeam)
    end
end

function widget:PlayerChanged(playerID)
    if GetSpectatingState() then
        widgetHandler:RemoveWidget()
    end
end

function widget:MousePress(_,_,button)
    if button == 2 then
        Spring.Echo(constructors)
    end
end