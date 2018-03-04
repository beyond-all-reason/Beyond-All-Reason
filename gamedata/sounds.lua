local Sounds = {
	SoundItems = {
		IncomingChat = {
			file = "sounds/blank.wav",
			in3d = "false",
		},
		MultiSelect = {
			file = "sounds/button9.wav",
			in3d = "false",
		},
		MapPoint = {
			file = "sounds/beep6.wav",
			rolloff = 0.3,
			dopplerscale = 0,       
		},
		FailedCommand = {
			file = "sounds/cantdo4.wav",       
		},
		warning2 = {
			file = "sounds/warning2.wav",
			rolloff = 0.2,
			dopplerscale = 0,      
		},
		lasrfir1 = {
			file = "sounds/lasrfir1.wav",
			pitch = 1,
			pitchmod = 0.05,
		},
		uwlasrfir1 = {
			file = "sounds/uwlasrfir1.wav",
			pitch = 1,
			pitchmod = 0.05,
		},
		lasrfir2 = {
			file = "sounds/lasrfir2.wav",
			pitch = 1,
			pitchmod = 0.05,
		},
		lasrfir3 = {
			file = "sounds/lasrfir3.wav",
			pitch = 1,
			pitchmod = 0.05,
		},
		bertha1 = {
			file = "sounds/bertha1.wav",
			pitch = 1,
			pitchmod = 0.025,
		},
		bertha6 = {
			file = "sounds/bertha6.wav",
			pitch = 1,
			pitchmod = 0.025,
		},
		flakhit = {
			file = "sounds/flakhit.wav",
			pitch = 1,
			pitchmod = 0.075,
		},
		flakfire = {
			file = "sounds/flakfire.wav",
			gainmod = 0.1,
		},
		canlite3 = {
			file = "sounds/canlite3.wav",
			pitch = 1,
			pitchmod = 0.05,
		},
		xplosml3 = {
			file = "sounds/xplosml3.wav",
			pitch = 1,
			pitchmod = 0.05,
		},
		servlrg3 = {
			file = "sounds/servlrg3.wav",
			pitch = 1,
			pitchmod = 0.025,
		},
		servlrg4 = {
			file = "sounds/servlrg4.wav",
			pitch = 1,
			pitchmod = 0.025,
		},
		servmed1 = {
			file = "sounds/servmed1.wav",
			pitch = 1,
			pitchmod = 0.025,
		},
		servmed2 = {
			file = "sounds/servmed2.wav",
			pitch = 1,
			pitchmod = 0.025,
		},
		servroc1 = {
			file = "sounds/servroc1.wav",
			pitch = 1,
			pitchmod = 0.025,
		},
		servsml5 = {
			file = "sounds/servsml5.wav",
			pitch = 1,
			pitchmod = 0.025,
		},
		servsml6 = {
			file = "sounds/servsml6.wav",
			pitch = 1,
			pitchmod = 0.025,
		},
		servtny1 = {
			file = "sounds/servtny1.wav",
			pitch = 1,
			pitchmod = 0.025,
		},
		servtny2 = {
			file = "sounds/servtny2.wav",
			pitch = 1,
			pitchmod = 0.025,
		},
		xplomas2 = {
			file = "sounds/xplomas2.wav",
			pitch = 1,
			pitchmod = 0.05,
			maxconcurrent = 3,	   
		},
		hackshot = {
			file = "sounds/hackshot.wav",
			pitch = 1,
			pitchmod = 0.02,
			maxconcurrent = 5,	   
		},
		kroggie2 = {
			file = "sounds/kroggie2.wav",
			maxconcurrent = 1,	  
		},
		xplomed2 = {
			file = "sounds/xplomed2.wav",
			pitch = 1,
			pitchmod = 0.05,
			maxconcurrent = 4,	  
		},
	},
}


-- replace with BAR alternatives
if Spring.GetModOptions and (tonumber(Spring.GetModOptions().barmodels) or 0) ~= 0 then
	function getBarSound(name)
		if name == nil or name == '' then
			return name
		end
		local filename = string.gsub(name, ".wav", "")
		filename = string.gsub(name, ".ogg", "")
		if VFS.FileExists('sounds/BAR/'..filename..".wav") then
			return 'sounds/BAR/'..filename
		elseif VFS.FileExists('sounds/BAR/'..filename..".ogg") then
			return 'sounds/BAR/'..filename..".ogg"
		else
			return name
		end
	end

	for sound, soundParams in pairs(Sounds.SoundItems) do
		if type(soundParams.file) == 'string' then
			Sounds.SoundItems[sound][soundParams.file] = getBarSound(Sounds.SoundItems[sound][soundParams.file])
		end
	end
end


return Sounds

