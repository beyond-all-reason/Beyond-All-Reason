include("keysym.h.lua")

local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name         = "Line-Build Hotkey Ignore",
        desc         = "Ignores keypresses when building lines",
        author       = "[teh]Teddy",
        date         = "May 2021",
        layer        = 0,
        enabled      = true
    }
end

function widget:KeyPress(key, mods, isRepeat)

    if not mods.alt and mods.shift then
    
        if key ~= KEYSYMS['UP'] and key ~= KEYSYMS['DOWN'] and key ~= KEYSYMS['LEFT'] and key ~= KEYSYMS['RIGHT'] then -- Don't ignore arrow keys
        
            local x, y, leftPressed, middlePressed, rightPressed, offscreen = Spring.GetMouseState()
            if leftPressed then
            
                local idx, cmd_id, cmd_type, cmd_name = Spring.GetActiveCommand()
                if cmd_id and cmd_id < 0 then
                    return true
                end
            end
        end
    end
end
