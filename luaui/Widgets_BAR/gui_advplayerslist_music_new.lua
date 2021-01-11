





local warMeter = 0

local musicDir = 'sounds/musicnew/'
local introTracks = VFS.DirList(musicDir..'intro', '*.ogg')
local peaceTracks = VFS.DirList(musicDir..'peace', '*.ogg')
local warhighTracks = VFS.DirList(musicDir..'warhigh', '*.ogg')
local warlowTracks = VFS.DirList(musicDir..'warlow', '*.ogg')
local victoryTracks = VFS.DirList(musicDir..'victory', '*.ogg')
local defeatTracks = VFS.DirList(musicDir..'defeat', '*.ogg')

local currentTrackList = introTracks

local gameOver = false
local silenceTimer = 0

local playedTime, totalTime = Spring.GetSoundStreamTime()

local curTrackName	= "no name"
local prevTrackName = "no name"
local appliedSilence = true
local minSilenceTime = 10
local maxSilenceTime = 180


--- config
local enableSilenceGaps = true
local musicVolume = Spring.GetConfigInt("snd_volmusic", 20)*0.02
---














function widget:GetInfo()
	return {
		name	= "Music Player New",
		desc	= "Plays music and offers volume controls",
		author	= "Damgam",
		date	= "2021",
		license	= "i don't care",
		layer	= -4,
		enabled	= false	--	loaded by default?
	}
end

function PlayNewTrack()
	appliedSilence = false
	prevTrack = curTrack
	curTrack = nil
	Spring.Echo("[NewMusicPlayer] Warmeter: "..warMeter)


	currentTrackList = nil
	if warMeter >= 50000 then
		currentTrackList = warhighTracks
		Spring.Echo("[NewMusicPlayer] Playing warhigh track")
	elseif warMeter >= 10000 then
		currentTrackList = warlowTracks
		Spring.Echo("[NewMusicPlayer] Playing warlow track")
	else
		currentTrackList = peaceTracks
		Spring.Echo("[NewMusicPlayer] Playing peace track")
	end

	if not currentTrackList  then
		Spring.Echo("[NewMusicPlayer] there is some issue with getting track list")
		return
	end

	if #currentTrackList > 1 then
		repeat 
			curTrack = currentTrackList[math.random(1,#currentTrackList)]
		until(curTrack ~= prevTrack)
	elseif #currentTrackList == 1 then
		curTrack = currentTrackList[1]
	elseif #currentTrackList == 0 then
		Spring.Echo("[NewMusicPlayer] empty track list")
		return
	end
		
	if curTrack then
		local musicVolume = (Spring.GetConfigInt("snd_volmusic", 20))*0.02
		Spring.PlaySoundStream(curTrack, musicVolume)
		Spring.SetSoundStreamVolume(musicVolume)
	end
	warMeter = 0
end


function widget:UnitDamaged(_,_,_,damage)
	if damage > 10 then
		warMeter = warMeter + damage
	end
end

function widget:GameFrame(n)
	if n == 1 then
		Spring.StopSoundStream()
	end
	if n%30 == 15 then
		playedTime, totalTime = Spring.GetSoundStreamTime()
		if playedTime > 0 and totalTime > 0 then -- music is playing
			local musicVolume = (Spring.GetConfigInt("snd_volmusic", 20))*0.02
			Spring.SetSoundStreamVolume(musicVolume)
			if warMeter >= 50 then
				warMeter = warMeter - 50
				Spring.Echo("[NewMusicPlayer] Warmeter: ".. warMeter)
			end
		elseif totalTime == 0 then -- there's no music
			if appliedSilence == true and silenceTimer <= 0 then
				PlayNewTrack()
			elseif appliedSilence == false and silenceTimer <= 0 then
				if enableSilenceGaps == true then
					silenceTimer = math.random(minSilenceTime,maxSilenceTime)
					Spring.Echo("[NewMusicPlayer] Silence Time: ".. silenceTimer)
				else
					silenceTimer = 1
				end
				appliedSilence = true
			elseif appliedSilence == true and silenceTimer > 0 then
				silenceTimer = silenceTimer - 1
				Spring.Echo("[NewMusicPlayer] Silence Time Left: ".. silenceTimer)
				if warMeter >= 50 then
					warMeter = warMeter - 50
					Spring.Echo("[NewMusicPlayer] Warmeter: ".. warMeter)
				end
			end
		end
	end
end




