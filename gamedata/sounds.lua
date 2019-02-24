local Sounds = {
	SoundItems = {
		IncomingChat = {
			file = "sounds/ui/blank.wav",
			in3d = "false",
		},
		MultiSelect = {
			file = "sounds/ui/button9.wav",
			in3d = "false",
		},
		MapPoint = {
			file = "sounds/ui/beep6.wav",
			rolloff = 0.3,
			dopplerscale = 0,       
		},
		FailedCommand = {
			file = "sounds/replies/cantdo4.wav",       
		},
	},
}


-- UI SOUNDS
local files = VFS.DirList("sounds/ui/")
local t = Sounds.SoundItems
for i=1,#files do
	local fileName = files[i]
	fileNames = string.sub(fileName, 11, string.find(fileName, ".wav") -1)
	t[fileNames] = {
		file     = fileName;
		gain = 0.8,
		pitchmod = 0,
		gainmod  = 0,
		dopplerscale = 0,
		maxconcurrent = 1,
		rolloff = 0,
	}
end

-- WEAPON SOUNDS
local files = VFS.DirList("sounds/weapons/")
local t = Sounds.SoundItems
for i=1,#files do
   local fileName = files[i]
   fileNames = string.sub(fileName, 16, string.find(fileName, ".wav") -1)
   t[fileNames] = {
      file     = fileName;
	  gain = 1.2*0.3,
      pitchmod = 0.01,
      gainmod  = 0.2*0.3,
	  dopplerscale = 1.0,
      maxconcurrent = 4,
	  rolloff = 0.5,
   }
   
   if fileNames == "disigun1" then
	t[fileNames].gain = 0.075*0.3
	end
   if fileNames == "xplomas2" then
	t[fileNames].gain = 0.225*0.3
	end
   if fileNames == "newboom" then
	t[fileNames].gain = 0.045*0.3
	end
end

-- REPLY SOUNDS
local files = VFS.DirList("sounds/replies/")
local t = Sounds.SoundItems
for i=1,#files do
	local fileName = files[i]
	fileNames = string.sub(fileName, 16, string.find(fileName, ".wav") -1)
	t[fileNames] = {
		file     = fileName;
		gain = 1.2*0.3,
		pitchmod = 0.01,
		gainmod  = 0.2*0.3,
		dopplerscale = 1.0,
		maxconcurrent = 2,
		rolloff = 0.2,
	}
end

local files = VFS.DirList("sounds/chickens/")
local t = Sounds.SoundItems
for i=1,#files do
   local fileName = files[i]
   fileNames = string.sub(fileName, 16, string.find(fileName, ".wav") -1)
   t[fileNames] = {
      file     = fileName;
	  gain = 1.2*0.3,
      pitchmod = 0.01,
      gainmod  = 0.2*0.3,
	  dopplerscale = 1.0,
      maxconcurrent = 4,
	  rolloff = 0.2,
   }
end

local files = VFS.DirList("sounds/critters/")
local t = Sounds.SoundItems
for i=1,#files do
   local fileName = files[i]
   fileNames = string.sub(fileName, 16, string.find(fileName, ".wav") -1)
   t[fileNames] = {
      file     = fileName;
	  gain = 1.2*0.3,
      pitchmod = 0.01,
      gainmod  = 0.2*0.3,
	  dopplerscale = 1.0,
      maxconcurrent = 4,
	  rolloff = 0.2,
   }
end

return Sounds

