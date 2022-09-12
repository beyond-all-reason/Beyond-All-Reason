function widget:GetInfo()
	return {
	name      = "Scavenger Audio Reciever",
	desc      = "AAA",
	author    = "Damgam",
	date      = "2020",
	license   = "GNU GPL, v2 or later",
	layer     = 30000,
	enabled   = true, --enabled by default
	}
end


function widget:Initialize()
	Spring.SetConfigInt("scavaudiomessages", 1)
end

function widget:Shutdown()
	Spring.SetConfigInt("scavaudiomessages", 0)
end

function widget:TextCommand(msg)
	if string.sub(msg,1, 17) == "scavplaysoundfile" then
		Spring.PlaySoundFile(string.sub(msg, 19), 0.85, 'ui')
	end
end
