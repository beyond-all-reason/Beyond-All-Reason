function widget:GetInfo()
    return {
        name = "Transport To",
        desc = "Adds a map-click Transport To command and visuals",
        author = "IsaJoeFeat",
        layer = 1,
        enabled = true,
        handler = true,
    }
end

local GetSelectedUnits = Spring.GetSelectedUnits
local GetUnitDefID = Spring.GetUnitDefID
local AssignMouseCursor = Spring.AssignMouseCursor
local SetCustomCommandDrawData = Spring.SetCustomCommandDrawData

local customCommands = VFS.Include("modules/customcommands.lua")
local GameCMD = customCommands.GameCMD
local CMD_TRANSPORT_TO = GameCMD.TRANSPORT_TO

local CMD_TRANSPORT_TO_DESC = {
    id = CMD_TRANSPORT_TO,
    type = CMDTYPE.ICON_MAP,
    name = "Transport To",
    cursor = nil,
    action = "transport_to",
    tooltip = "Request the closest eligible transport to move this unit to the target location",
}

local function IsTransportableDef(defID)
    if not defID then
        return false
    end

    local ud = UnitDefs[defID]
    if not ud then
        return false
    end

    if ud.canFly then
        return false
    end

    if ud.cantBeTransported == true then
        return false
    end

    if ud.isTransport and (ud.transportCapacity or 0) > 0 then
        return false
    end

    return true
end

local function HasTransportableSelection()
    local selected = GetSelectedUnits()
    if #selected == 0 then
        return false
    end

    for i = 1, #selected do
        local defID = GetUnitDefID(selected[i])
        if IsTransportableDef(defID) then
            return true
        end
    end

    return false
end

local function RegisterVisuals()
    AssignMouseCursor("transto", "cursortransport")
    SetCustomCommandDrawData(CMD_TRANSPORT_TO, "transto", { 1, 1, 1, 1 })
end

function widget:Initialize()
    RegisterVisuals()
end

function widget:CommandsChanged()
    RegisterVisuals()

    if not HasTransportableSelection() then
        return
    end

    local cc = widgetHandler.customCommands
    cc[#cc + 1] = CMD_TRANSPORT_TO_DESC
end