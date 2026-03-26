local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name = "Command Dance",
        desc = "Adds /dance command for selected commander dance animation",
        author = "PtaQ",
        date = "2026",
        license = "GNU GPL v2 or later",
        layer = 0,
        enabled = true,
    }
end

local REQUEST_HEADER = "$dance$"

local commanderDefs = {}

function widget:Initialize()
    for udefID, udef in pairs(UnitDefs) do
        if udef.customParams and udef.customParams.iscommander then
            commanderDefs[udefID] = true
        end
    end
    widgetHandler:AddAction("dance", function()
        local selected = Spring.GetSelectedUnits()
        local ids = {}
        for i = 1, #selected do
            local unitDefID = Spring.GetUnitDefID(selected[i])
            if unitDefID and commanderDefs[unitDefID] then
                ids[#ids + 1] = selected[i]
            end
        end

        if #ids == 0 then
            Spring.Echo("[Dance] Select a commander first!")
            return true
        end

        Spring.SendLuaRulesMsg(REQUEST_HEADER .. table.concat(ids, ","))
        return true
    end, nil, "t")
end

function widget:Shutdown()
    widgetHandler:RemoveAction("dance")
end
