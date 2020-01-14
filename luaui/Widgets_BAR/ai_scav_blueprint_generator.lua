function widget:GetInfo()
	return {
	name      = "Scavenger Blueprint Generator",
	desc      = "AAA",
	author    = "Damgam",
	date      = "2020",
	license   = "who cares?",
	layer     = 0,
	enabled   = true, --enabled by default
	}
end

function widget:RecvLuaMsg(msg)
	if msg == "scavblueprint constructor" then 
		Spring.Echo("Hello World!") 
	end 
end