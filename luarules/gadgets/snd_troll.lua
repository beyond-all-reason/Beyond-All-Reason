function gadget:GetInfo()
  return {
    name      = "Troll music",
    author    = "Floris",
    layer     = 0,
	  license = "For use in Balanced Annihilation and non BA forks only (unless Floris permits)",
    enabled   = true,
  }
end
     
if (gadgetHandler:IsSyncedCode()) then
  return
end

local enabled = false
local soundfile = 'luarules/music/trollsong.ogg'
local dorepeat = true
local playernames = {"[AFUS]Ares", "Sprung"}
				
function gadget:Initialize()
	local myPlayerName,_ = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
  for _, cname in pairs(playernames) do
  	if cname == myPlayerName then found = true end
  end
	if found then
		enabled = true
		Spring.PlaySoundStream(soundfile)
		Spring.SetSoundStreamVolume(1)
		Spring.SetConfigInt("snd_volmaster", 99)
		Spring.SetConfigInt("snd_volmusic", 99)
	else
    gadgetHandler:RemoveGadget(self)
	end
end

function gadget:Update()
	if enabled then
		Spring.SetConfigInt("snd_volmaster", 99)
		Spring.SetConfigInt("snd_volmusic", 99)
		
		local playedTime, totalTime = Spring.GetSoundStreamTime()
		if playedTime > 1 and math.floor(playedTime) >= math.floor(totalTime) then	-- both zero means track stopped in 8
			Spring.StopSoundStream(soundfile)
			if dorepeat then
				Spring.PlaySoundStream(soundfile)
				Spring.SetSoundStreamVolume(1)
			else
    		gadgetHandler:RemoveGadget(self)
			end
		end
	end
end

function gadget:Shutdown()
		Spring.StopSoundStream(soundfile)
end
