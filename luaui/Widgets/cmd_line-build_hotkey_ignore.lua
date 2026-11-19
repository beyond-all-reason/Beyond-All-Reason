local KEY_UP = Spring.GetKeyCode("up")
local KEY_DOWN = Spring.GetKeyCode("down")
local KEY_LEFT = Spring.GetKeyCode("left")
local KEY_RIGHT = Spring.GetKeyCode("right")

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Line-Build Hotkey Ignore",
		desc = "Ignores keypresses when building lines",
		author = "[teh]Teddy",
		date = "May 2021",
		layer = 0,
		enabled = true,
	}
end

function widget:KeyPress(key, mods, isRepeat)
	if not mods.alt and mods.shift then
		if key ~= KEY_UP and key ~= KEY_DOWN and key ~= KEY_LEFT and key ~= KEY_RIGHT then -- Don't ignore arrow keys
			local _, _, leftPressed, _, _, _ = Spring.GetMouseState()
			if leftPressed then
				local _, cmd_id, _, _ = Spring.GetActiveCommand()
				if cmd_id and cmd_id < 0 then
					return true
				end
			end
		end
	end
end
