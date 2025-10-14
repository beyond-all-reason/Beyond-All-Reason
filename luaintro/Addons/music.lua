
if addon.InGetInfo then
	return {
		name    = "Music",
		desc    = "plays music",
		author  = "jK",
		date    = "2012,2013",
		license = "GPL2",
		layer   = 0,
		--depend  = {"LoadProgress"},
		enabled = true, -- loading makes it choppy towards the end; also, volume cannot be adjusted
	}
end

function addon.DrawLoadScreen()
	-- local loadProgress = SG.GetLoadProgress()

	-- -- fade in & out music with progress
	-- if (loadProgress > 0.9) then
		-- Spring.SetSoundStreamVolume(1 - ((loadProgress - 0.9) * 10))
	-- end
end

function addon.Shutdown()
	--Spring.SetSoundStreamVolume(1)
end

function addon.Initialize()
	--if Spring.GetConfigInt('music', 1) == 0 then
	--	return
	--end
	if Spring.GetConfigInt('music_loadscreen', 1) == 1 then
		local originalSoundtrackEnabled = Spring.GetConfigInt('UseSoundtrackNew', 1)
		local customSoundtrackEnabled	= Spring.GetConfigInt('UseSoundtrackCustom', 1)
		local allowedExtensions = "{*.ogg,*.mp3}"
		local musicPlaylist = {}
		local musicPlaylistEvent = {}
		local musicDirCustom 		= 'music/custom'
		local musicDirOriginal 		= 'music/original'

		if originalSoundtrackEnabled == 1 then
			-- Events ----------------------------------------------------------------------------------------------------------------------

			-- Raptors
			if Spring.Utilities.Gametype.IsRaptors() then
				table.append(musicPlaylistEvent, VFS.DirList(musicDirOriginal..'/events/raptors/loading', allowedExtensions))
			end

			-- Scavengers
			if Spring.Utilities.Gametype.IsScavengers() then
				table.append(musicPlaylistEvent, VFS.DirList(musicDirOriginal..'/events/scavengers/loading', allowedExtensions))
			end

			-- April Fools
			---- Day 1 - 100% chance
			if Spring.GetConfigInt('UseSoundtrackAprilFools', 1) == 1 and (tonumber(os.date("%m")) == 4 and tonumber(os.date("%d")) == 1) then
				table.append(musicPlaylistEvent, VFS.DirList(musicDirOriginal..'/events/aprilfools/loading', allowedExtensions))
			---- Day 2-7 - 50% chance
			elseif Spring.GetConfigInt('UseSoundtrackAprilFools', 1) == 1 and (tonumber(os.date("%m")) == 4 and tonumber(os.date("%d")) <= 7 and math.random() <= 0.5) then
				table.append(musicPlaylistEvent, VFS.DirList(musicDirOriginal..'/events/aprilfools/loading', allowedExtensions))
			---- Post Event - Add to regular playlist
			elseif Spring.GetConfigInt('UseSoundtrackAprilFoolsPostEvent', 0) == 1 and ((not (tonumber(os.date("%m")) == 4 and tonumber(os.date("%d")) <= 7))) then
				table.append(musicPlaylist, VFS.DirList(musicDirOriginal..'/events/aprilfools/loading', allowedExtensions))
			end

			-- Spooktober
			---- Halloween Day - 100% chance
			if Spring.GetConfigInt('UseSoundtrackSpooktober', 1) == 1 and (tonumber(os.date("%m")) == 10 and tonumber(os.date("%d")) == 31) then
				table.append(musicPlaylistEvent, VFS.DirList(musicDirOriginal..'/events/spooktober/loading', allowedExtensions))
			---- 2 Weeks Before Halloween - 50% chance
			elseif Spring.GetConfigInt('UseSoundtrackSpooktober', 1) == 1 and (tonumber(os.date("%m")) == 10 and tonumber(os.date("%d")) >= 17 and math.random() <= 0.5) then
				table.append(musicPlaylistEvent, VFS.DirList(musicDirOriginal..'/events/spooktober/loading', allowedExtensions))
			---- Post Event - Add to regular playlist
			elseif Spring.GetConfigInt('UseSoundtrackSpooktoberPostEvent', 0) == 1 and ((not (tonumber(os.date("%m")) == 10 and tonumber(os.date("%d")) >= 17))) then
				table.append(musicPlaylist, VFS.DirList(musicDirOriginal..'/events/spooktober/loading', allowedExtensions))
			end

			-- Xmas
			---- Christmas Days - 100% chance
			if Spring.GetConfigInt('UseSoundtrackXmas', 1) == 1 and (tonumber(os.date("%m")) == 12 and tonumber(os.date("%d")) >= 24 and tonumber(os.date("%d")) <= 26) then
				table.append(musicPlaylistEvent, VFS.DirList(musicDirOriginal..'/events/xmas/loading', allowedExtensions))
			---- The Rest of the event - 50% chance
			elseif Spring.GetConfigInt('UseSoundtrackXmas', 1) == 1 and (tonumber(os.date("%m")) == 12 and tonumber(os.date("%d")) >= 12 and math.random() <= 0.5) then
				table.append(musicPlaylistEvent, VFS.DirList(musicDirOriginal..'/events/xmas/loading', allowedExtensions))
			---- Post Event - Add to regular playlist
			elseif Spring.GetConfigInt('UseSoundtrackXmasPostEvent', 0) == 1 and ((not (tonumber(os.date("%m")) == 12 and tonumber(os.date("%d")) >= 12))) then
				table.append(musicPlaylist, VFS.DirList(musicDirOriginal..'/events/xmas/loading', allowedExtensions))
			end

			-- Map Music
			table.append(musicPlaylistEvent, VFS.DirList('music/map/loading', allowedExtensions))

			-------------------------------------------------------------------------------------------------------------------------------
			
			-- Regular Music
			table.append(musicPlaylist, VFS.DirList(musicDirOriginal..'/loading', allowedExtensions))
		end

		-- Custom Soundtrack List
		if customSoundtrackEnabled == 1 then
			table.append(musicPlaylist, VFS.DirList(musicDirCustom..'/loading', allowedExtensions))
		end

		if #musicPlaylist == 0 then
			if originalSoundtrackEnabled == 1 then
				table.append(musicPlaylist, VFS.DirList(musicDirOriginal..'/peace', allowedExtensions))
			end
			if customSoundtrackEnabled == 1 then
				table.append(musicPlaylist, VFS.DirList(musicDirCustom..'/peace', allowedExtensions))
			end
		end

		local musicvolume = Spring.GetConfigInt("snd_volmusic", 50) * 0.01
		if #musicPlaylistEvent > 0 then
			local pickedTrack = musicPlaylistEvent[math.random(1, #musicPlaylistEvent)]
			Spring.PlaySoundStream(pickedTrack, 1)
			Spring.SetSoundStreamVolume(musicvolume)
			Spring.SetConfigString('music_loadscreen_track', pickedTrack)
		elseif #musicPlaylist > 0 then
			local pickedTrack = musicPlaylist[math.random(1, #musicPlaylist)]
			Spring.PlaySoundStream(pickedTrack, 1)
			Spring.SetSoundStreamVolume(musicvolume)
			Spring.SetConfigString('music_loadscreen_track', pickedTrack)
		end
	end
end
