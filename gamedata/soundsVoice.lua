local Sounds = {SoundItems = {}}

--Special handling of Voice files -- We need to do this in separate file so the notifications widget can load the custom modded ones.
local voiceAttributes = {
	gain = 1,
	pitchmod = 0,
	gainmod  = 0,
	dopplerscale = 0,
	maxconcurrent = 1,
	priority = 1000,
	rolloff = 0,
}

local function handleVoiceSoundFile(file) -- Creates a sound item that has the same name as the full path, for compatibility with existing solutions
    local eventName = string.gsub(file, "\\", "/")
    if not Sounds.SoundItems[eventName] then
	    Sounds.SoundItems[eventName] = {}
	    Sounds.SoundItems[eventName].file = file
	    for attribute, attributeValue in pairs(voiceAttributes) do
	    	Sounds.SoundItems[eventName][attribute] = attributeValue
	    end
	    --Spring.Echo(eventName)
        --for attribute2, value in pairs(Sounds.SoundItems[file]) do
	    --	Spring.Echo("attribute", attribute2, "value", value)
	    --end
    end
end

--local VoiceFilesLvl1Files = VFS.DirList("sounds/voice/")
local VoiceFilesLvl1SubDirs = VFS.SubDirs("sounds/voice/")
--Spring.Echo("VOICESOUNDEVENTSTABLE")
for _, a in pairs(VoiceFilesLvl1SubDirs) do -- languages
	local VoiceFilesLvl2SubDirs = VFS.SubDirs(a)
	--local VoiceFilesLvl2Files = VFS.DirList(a)
	for _, b in pairs(VoiceFilesLvl2SubDirs) do -- announcers in the language
		local VoiceFilesLvl3SubDirs = VFS.SubDirs(b)
		local VoiceFilesLvl3Files = VFS.DirList(b)
		for _, file in pairs(VoiceFilesLvl3Files) do -- files in main directory of the announcer
			handleVoiceSoundFile(file)
		end
		for _, c in pairs(VoiceFilesLvl3SubDirs) do -- announcer subdirs
			local VoiceFilesLvl4SubDirs = VFS.SubDirs(c)
			local VoiceFilesLvl4Files = VFS.DirList(c)
			for _, file in pairs(VoiceFilesLvl4Files) do -- files in the announcer subdir
				handleVoiceSoundFile(file)
			end
			for _, d in pairs(VoiceFilesLvl4SubDirs) do -- subdirs of the subdirs
				--local VoiceFilesLvl5SubDirs = VFS.SubDirs(d)
				local VoiceFilesLvl5Files = VFS.DirList(d)
				for _, file in pairs(VoiceFilesLvl5Files) do -- files in the subdir of the subdir
					handleVoiceSoundFile(file)
				end
			end -----------------------------------------------  In case deeper subdirs are made at some point, add another level here.
		end
	end
end

local voiceSoundEffectsAttributes = {
	gain = 1,
	pitchmod = 0,
	gainmod  = 0,
	dopplerscale = 0,
	maxconcurrent = 1,
	priority = 999,
	rolloff = 0,
}

local VoiceSoundEffectFiles = VFS.DirList("sounds/voice-soundeffects/")
for _, file in pairs(VoiceSoundEffectFiles) do -- files in the voice-soundeffects folder
	Sounds.SoundItems[file] = {}
	Sounds.SoundItems[file].file = file
	for attribute, attributeValue in pairs(voiceSoundEffectsAttributes) do
		Sounds.SoundItems[file][attribute] = attributeValue
	end
	--Spring.Echo(file)
	--for attribute2, value in pairs(Sounds.SoundItems[file]) do
	--	Spring.Echo("attribute", attribute2, "value", value)
	--end
end

return Sounds