
if addon.InGetInfo then
	return {
		name    = "Music",
		desc    = "plays music",
		author  = "jK",
		date    = "2012,2013",
		license = "GPL2",
		layer   = 0,
		depend  = {"LoadProgress"},
		enabled = false, -- loading makes it choppy towards the end; also, volume cannot be adjusted
	}
end

function addon.DrawLoadScreen()
	local loadProgress = SG.GetLoadProgress()

	-- fade in & out music with progress
	if (loadProgress > 0.9) then
		Spring.SetSoundStreamVolume(1 - ((loadProgress - 0.9) * 10))
	end
end

function addon.Shutdown()
	Spring.StopSoundStream()
	Spring.SetSoundStreamVolume(1)
end

function addon.Initialize()
	Spring.SetSoundStreamVolume(1)
	local musicfiles = VFS.DirList("sounds/music/loading", "*.ogg")
	Spring.Echo("musicfiles", #musicfiles)
	if (#musicfiles > 0) then
		Spring.PlaySoundStream(musicfiles[ math.random(#musicfiles) ], 1)
		Spring.SetSoundStreamVolume(1)
	end
end