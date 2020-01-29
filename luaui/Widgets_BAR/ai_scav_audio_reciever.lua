function widget:GetInfo()
	return {
	name      = "Scavenger Audio Reciever",
	desc      = "AAA",
	author    = "Damgam",
	date      = "2020",
	license   = "who cares?",
	layer     = 30000,
	enabled   = true, --enabled by default
	}
end


function widget:TextCommand(msg)
	--Spring.Echo(msg)
	if string.sub(msg,1, 17) == "scavplaysoundfile" then 
		Spring.PlaySoundFile(string.sub(msg, 19),0.5,'ui')
	end
end

