
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
	local originalSoundtrackEnabled = true
	local legacySoundtrackEnabled 	= false
	local customSoundtrackEnabled	= false
	
	
	local musicPlaylist = {}
	if originalSoundtrackEnabled then
		local musicDirOriginal 		= 'music/original'
		table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirOriginal..'/warhigh', '*.ogg'))
		table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirOriginal..'/warlow', '*.ogg'))
	end

	-- Legacy Soundtrack List
	if legacySoundtrackEnabled then
		local musicDirLegacy 		= 'music/legacy'
		table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirLegacy..'/war', '*.ogg'))
	end

	-- Custom Soundtrack List
	if customSoundtrackEnabled then
		local musicDirCustom 		= 'music/custom'
		table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirCustom, '*.ogg'))
		table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirCustom..'/warhigh', '*.ogg'))
		table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirCustom..'/warlow', '*.ogg'))
		table.mergeInPlace(musicPlaylist, VFS.DirList(musicDirCustom..'/war', '*.ogg'))
	end

	math.randomseed( os.clock() )
	math.random(); math.random(); math.random()

	local musicvolume = Spring.GetConfigInt("snd_volmusic", 50) * 0.01
	if #musicPlaylist > 1 then
		local pickedTrack = math.ceil(#musicPlaylist*math.random())
		Spring.PlaySoundStream(musicPlaylist[pickedTrack], 0.5)
		Spring.SetSoundStreamVolume(musicvolume)
	elseif #musicPlaylist == 1 then
		Spring.PlaySoundStream(musicPlaylist[1], 0.5)
		Spring.SetSoundStreamVolume(musicvolume)
	end
end
