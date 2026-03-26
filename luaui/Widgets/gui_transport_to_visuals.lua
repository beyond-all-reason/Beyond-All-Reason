function widget:GetInfo()
    return {
        name = "Transport To Visuals",
        desc = "Registers Transport To cursor and command draw data",
        author = "IsaJoeFeat",
        layer = 1,
        enabled = true,
        handler = true,
    }
end

local customCommands = VFS.Include("modules/customcommands.lua")
local GameCMD = customCommands.GameCMD
local CMD_TRANSPORT_TO = GameCMD.TRANSPORT_TO

local CMD_TRANSPORT_TO_DESC = {
    id = CMD_TRANSPORT_TO,
    type = CMDTYPE.ICON_MAP,
    name = "Transport To",
    cursor = nil,
    action = "transport_to",
}

local function IsTransportableSelection()
    local selected = Spring.GetSelectedUnits()
    if #selected == 0 then
        return false
    end

    for i = 1, #selected do
        local unitID = selected[i]
        local defID = Spring.GetUnitDefID(unitID)
        if defID then
            local ud = UnitDefs[defID]
            if ud and (not ud.canFly) and ((ud.cantBeTransported == nil) or (ud.cantBeTransported == false)) then
                return true
            end
        end
    end

    return false
end

local function RegisterVisuals()
    Spring.AssignMouseCursor("transto", "cursortransport")
    Spring.SetCustomCommandDrawData(CMD_TRANSPORT_TO, "transto", { 1, 1, 1, 1 })
end

function widget:Initialize()
    RegisterVisuals()
end

function widget:CommandsChanged()
    RegisterVisuals()

    if not IsTransportableSelection() then
        return
    end

    local cc = widgetHandler.customCommands
    cc[#cc + 1] = CMD_TRANSPORT_TO_DESC
end