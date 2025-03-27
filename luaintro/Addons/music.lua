
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
		if originalSoundtrackEnabled == 1 then
			local musicDirOriginal 		= 'music/original'
			if Spring.GetConfigInt('UseSoundtrackAprilFools', 1) == 1 and ((tonumber(os.date("%m")) == 4 and tonumber(os.date("%d")) <= 3 and math.random() <= 0.25) or (tonumber(os.date("%m")) == 4 and tonumber(os.date("%d")) == 1)) then
				table.append(musicPlaylist, VFS.DirList(musicDirOriginal..'/events/aprilfools/loading', allowedExtensions))
			else
				table.append(musicPlaylist, VFS.DirList(musicDirOriginal..'/loading', allowedExtensions))
			end
		end

		-- Custom Soundtrack List
		if customSoundtrackEnabled == 1 then
			local musicDirCustom 		= 'music/custom'
			table.append(musicPlaylist, VFS.DirList(musicDirCustom..'/loading', allowedExtensions))
		end

		if #musicPlaylist == 0 then
			if originalSoundtrackEnabled == 1 then
				local musicDirOriginal 		= 'music/original'
				table.append(musicPlaylist, VFS.DirList(musicDirOriginal..'/peace', allowedExtensions))
			end
			if customSoundtrackEnabled == 1 then
				local musicDirCustom 		= 'music/custom'
				table.append(musicPlaylist, VFS.DirList(musicDirCustom..'/peace', allowedExtensions))
			end
		end

		local musicvolume = Spring.GetConfigInt("snd_volmusic", 50) * 0.01
		if #musicPlaylist > 1 then
			local pickedTrack = math.ceil(#musicPlaylist*math.random())
			Spring.PlaySoundStream(musicPlaylist[pickedTrack], 1)
			Spring.SetSoundStreamVolume(musicvolume)
			Spring.SetConfigString('music_loadscreen_track', musicPlaylist[pickedTrack])
		elseif #musicPlaylist == 1 then
			Spring.PlaySoundStream(musicPlaylist[1], 1)
			Spring.SetSoundStreamVolume(musicvolume)
			Spring.SetConfigString('music_loadscreen_track', musicPlaylist[1])
		end
	end
end
