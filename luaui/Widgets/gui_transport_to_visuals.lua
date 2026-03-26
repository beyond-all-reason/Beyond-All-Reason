function widget:GetInfo()
    return {
        name = "Transport To Visuals",
        desc = "Visual setup for the Transport To command cursor and draw data",
        author = "IsaJoeFeat",
        layer = 0,
        enabled = true,
    }
end

local CMD_TRANSPORT_TO = GameCMD.TRANSPORT_TO

function widget:Initialize()
    Spring.AssignMouseCursor("transto", "cursortransport")
    Spring.SetCustomCommandDrawData(CMD_TRANSPORT_TO, "transto", { 1, 1, 1, 1 })
end
