function widget:GetInfo()
	return {
		name      = "Take Command",
		desc      = "Catches /take and forwards to synced gadget",
		author    = "Antigravity",
		date      = "2024",
		license   = "GPL-v2",
		layer     = 0,
		enabled   = true,
	}
end

function widget:TextCommand(command)
	if command:lower() == "take" then
		Spring.SendLuaRulesMsg("take_cmd")
		return true
	end
end





