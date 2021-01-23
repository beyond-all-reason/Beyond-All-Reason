



local defaultMusicVolume = 50

local warMeter = 0

local musicDir = 'sounds/musicnew/'
local introTracks = VFS.DirList(musicDir..'intro', '*.ogg')
local peaceTracks = VFS.DirList(musicDir..'peace', '*.ogg')
local warhighTracks = VFS.DirList(musicDir..'warhigh', '*.ogg')
local warlowTracks = VFS.DirList(musicDir..'warlow', '*.ogg')
local victoryTracks = VFS.DirList(musicDir..'victory', '*.ogg')
local defeatTracks = VFS.DirList(musicDir..'defeat', '*.ogg')
if #victoryTracks == 0 then victoryTracks = introTracks end
if #defeatTracks == 0 then defeatTracks = introTracks end

local currentTrackList = introTracks

local gameOver = false
local playedGameOverTrack = false
local silenceTimer = 0

local playedTime, totalTime = Spring.GetSoundStreamTime()

local curTrackName	= "no name"
local prevTrackName = "no name"
local appliedSilence = true
local minSilenceTime = 10
local maxSilenceTime = 60


--- config
local enableSilenceGaps = true
local musicVolume = Spring.GetConfigInt("snd_volmusic", defaultMusicVolume)*0.01
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

function widget:Initialize()
	Spring.StopSoundStream() -- only for testing purposes
end

function PlayNewTrack()
	Spring.StopSoundStream()
	appliedSilence = false
	prevTrack = curTrack
	curTrack = nil
	Spring.Echo("[NewMusicPlayer] Warmeter: "..warMeter)

	currentTrackList = nil
	if gameOver == true then
		if VictoryMusic == true then
			currentTrackList = victoryTracks
			playedGameOverTrack = true
		else
			currentTrackList = defeatTracks
			playedGameOverTrack = true
		end
	elseif warMeter >= 20000 then
		currentTrackList = warhighTracks
		Spring.Echo("[NewMusicPlayer] Playing warhigh track")
	elseif warMeter >= 1000 then
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
		local musicVolume = (Spring.GetConfigInt("snd_volmusic", defaultMusicVolume))*0.01
		Spring.PlaySoundStream(curTrack, 1)
		Spring.SetSoundStreamVolume(musicVolume)
	end
	warMeter = 0
end


function widget:UnitDamaged(unitID,unitDefID,_,damage)
	if damage > 1 then
		local curHealth, maxHealth = Spring.GetUnitHealth(unitID)
		if damage > maxHealth then
			local damage = maxHealth
			warMeter = math.ceil(warMeter + damage)
		else
			warMeter = math.ceil(warMeter + damage)
		end
	end
end

function widget:GameFrame(n)
	if n == 1 then
		Spring.StopSoundStream()
	end
	if n%30 == 15 then
		if gameOver == true and playedGameOverTrack == false then
			PlayNewTrack()
		end
		playedTime, totalTime = Spring.GetSoundStreamTime()
		if playedTime > 0 and totalTime > 0 then -- music is playing
			local musicVolume = (Spring.GetConfigInt("snd_volmusic", defaultMusicVolume))*0.01
			Spring.SetSoundStreamVolume(musicVolume)
			if warMeter > 0 then
				warMeter = math.floor(warMeter - (warMeter*0.02))
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
				if warMeter > 0 then
					warMeter = math.floor(warMeter - (warMeter*0.02))
					Spring.Echo("[NewMusicPlayer] Warmeter: ".. warMeter)
				end
			end
		end
	end
end

function widget:GameOver(winningAllyTeams)
	gameOver = true
	local myTeamID = Spring.GetMyTeamID()
	local myTeamUnits = Spring.GetTeamUnits(myTeamID)
	if #myTeamUnits > 0 then
		VictoryMusic = true
	elseif #myTeamUnits == 0 then
		VictoryMusic = false
	end
end



