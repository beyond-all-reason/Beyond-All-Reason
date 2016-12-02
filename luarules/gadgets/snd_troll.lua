function gadget:GetInfo()
  return {
    name      = "Troll music",
    layer     = 0,
    enabled   = true,
  }
end
     
if (gadgetHandler:IsSyncedCode()) then
  return
end

local enabled = false
local soundfile = 'luarules/music/trollsong.ogg'
local dorepeat = false

function gadget:Initialize()
	local myPlayerName,_ = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
	if myPlayerName == "[AFUS]Ares" then
		enabled = true
		Spring.PlaySoundStream(soundfile)
		Spring.SetSoundStreamVolume(1)
		Spring.SetConfigInt("snd_volmaster", 100)
		Spring.SetConfigInt("snd_volmusic", 100)
	else
    gadgetHandler:RemoveGadget(self)
	end
end

function gadget:Update()
	if enabled then
		Spring.SetConfigInt("snd_volmaster", 100)
		Spring.SetConfigInt("snd_volmusic", 100)
		
		if dorepeat then
			local playedTime, totalTime = Spring.GetSoundStreamTime()
			if math.floor(playedTime) >= math.floor(totalTime) then	-- both zero means track stopped in 8
				Spring.StopSoundStream(soundfile)
				Spring.PlaySoundStream(soundfile)
				Spring.SetSoundStreamVolume(1)
			end
		end
	end
end

function gadget:Shutdown()
		Spring.StopSoundStream(soundfile)
end