
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
	if Spring.GetConfigInt('music_loadscreen', 1) == 1 then
		local originalSoundtrackEnabled = Spring.GetConfigInt('UseSoundtrackNew', 1)
		local legacySoundtrackEnabled 	= Spring.GetConfigInt('UseSoundtrackOld', 0)
		local customSoundtrackEnabled	= Spring.GetConfigInt('UseSoundtrackCustom', 1)


		local musicPlaylist = {}
		if originalSoundtrackEnabled == 1 then
			local musicDirOriginal 		= 'music/original'
			table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirOriginal..'/loading', '*.ogg'))
		end

		-- Legacy Soundtrack List
		if legacySoundtrackEnabled == 1 then
			local musicDirLegacy 		= 'music/legacy'
			table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirLegacy..'/loading', '*.ogg'))
		end

		-- Custom Soundtrack List
		if customSoundtrackEnabled == 1 then
			local musicDirCustom 		= 'music/custom'
			table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirCustom..'/loading', '*.ogg'))
		end

		if #musicPlaylist == 0 then
			if originalSoundtrackEnabled == 1 then
				local musicDirOriginal 		= 'music/original'
				table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirOriginal..'/warhigh', '*.ogg'))
				table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirOriginal..'/warlow', '*.ogg'))
			end

			-- Legacy Soundtrack List
			if legacySoundtrackEnabled == 1 then
				local musicDirLegacy 		= 'music/legacy'
				table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirLegacy..'/war', '*.ogg'))
			end

			-- Custom Soundtrack List
			if customSoundtrackEnabled == 1 then
				local musicDirCustom 		= 'music/custom'
				table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirCustom, '*.ogg'))
				table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirCustom..'/warhigh', '*.ogg'))
				table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirCustom..'/warlow', '*.ogg'))
				table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirCustom..'/war', '*.ogg'))
			end
		end

		local musicvolume = Spring.GetConfigInt("snd_volmusic", 50) * 0.02
		if #musicPlaylist > 1 then
			local pickedTrack = math.ceil(#musicPlaylist*math.random())
			Spring.PlaySoundStream(musicPlaylist[pickedTrack], 1)
			Spring.SetSoundStreamVolume(musicvolume)
		elseif #musicPlaylist == 1 then
			Spring.PlaySoundStream(musicPlaylist[1], 1)
			Spring.SetSoundStreamVolume(musicvolume)
		end
	end
end
