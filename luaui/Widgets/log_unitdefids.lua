local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name         = "Log UnitDefIDs",
        desc         = "Send UnitDefIDs as LuaRules message for demo parsing",
        author       = "Jazcash",
        date         = "2021-05-23",
        license      = "GNU GPL, v2 or later",
        layer        = 0,
        enabled      = true
    }
end

function widget:Initialize()
    local result = {};
    for key, value in ipairs(UnitDefs) do
        result[key] = value.name
    end

    local json = Json.encode(result);

    Spring.SendLuaRulesMsg('unitdefs:' .. VFS.ZlibCompress(json))
end
