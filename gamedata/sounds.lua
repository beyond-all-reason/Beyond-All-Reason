local Sounds = {
	SoundItems = {
		IncomingChat = {
			file = "sounds/ui/chat.wav",
			in3d = "false",
		},
		MultiSelect = {
			file = "sounds/ui/multiselect.wav",
			in3d = "false",
		},
		MapPoint = {
			file = "sounds/ui/mappoint.wav",
			--rolloff = 0.1,
			--dopplerscale = 0,
			in3d = "false",       
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
		--priority = 1,
		rolloff = 0,
	}
end

local files = VFS.DirList("sounds/uw/")
local t = Sounds.SoundItems
for i=1,#files do
	local fileName = files[i]
	fileNames = string.sub(fileName, 11, string.find(fileName, ".wav") -1)
	t[fileNames] = {
		file     = fileName;
		gain = 1.2*0.3,
		pitchmod = 0.17,
        gainmod  = 0.2*0.3,
		dopplerscale = 0,
		maxconcurrent = 8,
		--priority = 1,
		rolloff = 0.1,
	}
end

--VOICE MESSAGES
-- local files = VFS.DirList("sounds/voice/")
-- local t = Sounds.SoundItems
-- for i=1,#files do
	-- local fileName = files[i]
	-- fileNames = string.sub(fileName, 14, string.find(fileName, ".wav") -1)
	-- t[fileNames] = {
		-- file     = fileName;
		-- gain = 0.8,
		-- pitchmod = 0.1,
		-- gainmod  = 0,
		-- dopplerscale = 0,
		-- maxconcurrent = 1,
		-- priority = 2,
		-- rolloff = 0,
	-- }
-- end

-- local files = VFS.DirList("sounds/voice/scavengers/")
-- local t = Sounds.SoundItems
-- for i=1,#files do
	-- local fileName = files[i]
	-- fileNames = string.sub(fileName, 25, string.find(fileName, ".wav") -1)
	-- t[fileNames] = {
		-- file     = fileName;
		-- gain = 0.8,
		-- pitchmod = 0.1,
		-- gainmod  = 0,
		-- dopplerscale = 0,
		-- maxconcurrent = 1,
		-- priority = 2,
		-- rolloff = 0,
	-- }
-- end

-- local files = VFS.DirList("sounds/voice/tutorial/")
-- local t = Sounds.SoundItems
-- for i=1,#files do
	-- local fileName = files[i]
	-- fileNames = string.sub(fileName, 23, string.find(fileName, ".wav") -1)
	-- t[fileNames] = {
		-- file     = fileName;
		-- gain = 0.8,
		-- pitchmod = 0.1,
		-- gainmod  = 0,
		-- dopplerscale = 0,
		-- maxconcurrent = 1,
		-- priority = 2,
		-- rolloff = 0,
	-- }
-- end

-- WEAPON SOUNDS
local files = VFS.DirList("sounds/weapons/")
local t = Sounds.SoundItems
for i=1,#files do
   local fileName = files[i]
   fileNames = string.sub(fileName, 16, string.find(fileName, ".wav") -1)
   t[fileNames] = {
      file     = fileName;
      gain = 1.2*0.3,
      pitchmod = 0.17,
      gainmod  = 0.2*0.3,
      dopplerscale = 1.0,
      maxconcurrent = 8,
      rolloff = 1.0,
   }
   
   if fileNames == "disigun1" then
    t[fileNames].gain = 0.075*0.3
    end
   if fileNames == "xplomas2" then
    t[fileNames].gain = 0.225*0.3
    end
   -- if fileNames == "newboom" then
   --  t[fileNames].gain = 0.045*0.3
   --  end
    if fileNames == "beamershot2" then 
    t[fileNames].gain = 0.5*0.3
    t[fileNames].pitchmod = 0.04
    end
   if fileNames == "lasfirerc" then
    t[fileNames].pitchmod = 0.06
    end
   if string.sub(fileNames, 1, 8) == "lrpcshot" then
    t[fileNames].pitchmod = 0.12
    end 
   if string.sub(fileNames, 1, 7) == "heatray" then
    t[fileNames].pitchmod = 0
    end
   if string.sub(fileNames, 1, 4) == "lasr" then
    t[fileNames].pitchmod = 0
    end
   if string.sub(fileNames, 1, 6) == "mavgun" then
    t[fileNames].pitchmod = 0.06
    end 
   if string.sub(fileNames, 1, 7) == "nanlath" then
    t[fileNames].pitchmod = 0.02
    end 
   if string.sub(fileNames, 1, 4) == "mgun" then
    t[fileNames].pitchmod = 0.08
    end 
   if string.sub(fileNames, 1, 7) == "xplolrg" then
    t[fileNames].pitchmod = 0.3
    end
   if string.sub(fileNames, 1, 7) == "xplomed" then
    t[fileNames].pitchmod = 0.25
    end
   if string.sub(fileNames, 1, 7) == "xplosml" then
    t[fileNames].pitchmod = 0.22
    end
end

-- CHICKEN SOUNDS
local files = VFS.DirList("sounds/chickens/")
local t = Sounds.SoundItems
for i=1,#files do
	local fileName = files[i]
	fileNames = string.sub(fileName, 17, string.find(fileName, ".wav") -1)
	t[fileNames] = {
    	file     = fileName;
		gain = 1.0,
    	pitchmod = 0.23,
    	gainmod  = 0.2*0.3,
		dopplerscale = 1.0,
    	maxconcurrent = 6,
		rolloff = 1.1,
	}
	
	if fileNames == "talonattack" then
    t[fileNames].pitchmod = 0.07
    end
end

-- BOMB SOUNDS / More maxconcurrent
local files = VFS.DirList("sounds/bombs/")
local t = Sounds.SoundItems
for i=1,#files do
	local fileName = files[i]
	fileNames = string.sub(fileName, 14, string.find(fileName, ".wav") -1)
	t[fileNames] = {
		file     = fileName;
		gain = 1.2*0.3,
		pitchmod = 0.27,
		gainmod  = 0.2*0.3,
		dopplerscale = 1.0,
		maxconcurrent = 18,
		rolloff = 0.9,
	}
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
		pitchmod = 0.02,
		gainmod  = 0.2*0.3,
		dopplerscale = 0,
		maxconcurrent = 32,
		rolloff = 0.05,
		priority = 1,
		--in3d = false,
	}
end

-- LAND UNIT MOVEMENT SOUNDS
local files = VFS.DirList("sounds/movement/")
local t = Sounds.SoundItems
for i=1,#files do
	local fileName = files[i]
	fileNames = string.sub(fileName, 17, string.find(fileName, ".wav") -1)
	t[fileNames] = {
		file     = fileName;
		gain = 1.2*0.3,
		pitchmod = 0.062,
		gainmod  = 0.2*0.3,
		dopplerscale = 0,
		maxconcurrent = 2,
		rolloff = 0.05,
		priority = 1,
		--in3d = false,
	}
end

-- AIR UNIT MOVEMENT SOUNDS
local files = VFS.DirList("sounds/movement-air/")
local t = Sounds.SoundItems
for i=1,#files do
	local fileName = files[i]
	fileNames = string.sub(fileName, 21, string.find(fileName, ".wav") -1)
	t[fileNames] = {
		file     = fileName;
		gain = 1.2*0.3,
		pitchmod = 0.02,
		gainmod  = 0.2*0.3,
		dopplerscale = 0,
		maxconcurrent = 2,
		rolloff = 0.05,
		priority = 1,
		--in3d = false,
	}
end

-- UNIT FUNCTION/WEAPON SOUNDS
local files = VFS.DirList("sounds/function/")
local t = Sounds.SoundItems
for i=1,#files do
	local fileName = files[i]
	fileNames = string.sub(fileName, 17, string.find(fileName, ".wav") -1)
	t[fileNames] = {
		file     = fileName;
		gain = 1.2*0.3,
		pitchmod = 0.02,
		gainmod  = 0.2*0.3,
		dopplerscale = 0,
		maxconcurrent = 7,
		rolloff = 0.1,
		priority = 1,
		--in3d = false,
	}
end

-- BUILDING FUNCTION/WEAPON SOUNDS
local files = VFS.DirList("sounds/buildings/")
local t = Sounds.SoundItems
for i=1,#files do
	local fileName = files[i]
	fileNames = string.sub(fileName, 18, string.find(fileName, ".wav") -1)
	t[fileNames] = {
		file     = fileName;
		gain = 1.2*0.3,
		pitchmod = 0.03,
		gainmod  = 0.2*0.3,
		dopplerscale = 0,
		maxconcurrent = 2,
		rolloff = 0.1,
		priority = 1,
		--in3d = false,
	}
end

-- UI COMMANDS SOUNDS
local files = VFS.DirList("sounds/commands/")
local t = Sounds.SoundItems
for i=1,#files do
	local fileName = files[i]
	fileNames = string.sub(fileName, 17, string.find(fileName, ".wav") -1)
	t[fileNames] = {
		file     = fileName;
		gain = 1.2*0.3,
		pitchmod = 0.02,
		gainmod  = 0.2*0.3,
		dopplerscale = 0,
		maxconcurrent = 32,
		rolloff = 0,
		priority = 1,
		--in3d = false,
	}
end

-- CRITTER SOUNDS
local files = VFS.DirList("sounds/critters/")
local t = Sounds.SoundItems
for i=1,#files do
   local fileName = files[i]
   fileNames = string.sub(fileName, 17, string.find(fileName, ".wav") -1)
   t[fileNames] = {
      	file     = fileName;
	    gain = 1.1*0.3,
      	pitchmod = 0.01,
      	gainmod  = 0.15*0.3,
	    dopplerscale = 1.0,
      	maxconcurrent = 4,
	    rolloff = 0.7,
   }
end

-- SCAVENGER SOUNDS not in use currently
local files = VFS.DirList("sounds/scavengers/")
local t = Sounds.SoundItems
for i=1,#files do
	local fileName = files[i]
	fileNames = string.sub(fileName, 19, string.find(fileName, ".wav") -1)
	t[fileNames] = {
  		file     = fileName;
  		gain = 1.0*0.3,
  		pitchmod = 0.33,
  		gainmod  = 0.1*0.3,
  		dopplerscale = 1.0,
  		maxconcurrent = 8,
  		rolloff = 0.2,
	}
end

-- AMBIENCE
local files = VFS.DirList("sounds/atmos/")
local t = Sounds.SoundItems
for i=1,#files do
  local fileName = files[i]
  fileNames = string.sub(fileName, 14, string.find(fileName, ".wav") -1)
  t[fileNames] = {
      file     = fileName;
      gain = 0.8,
      pitchmod = 0.22,
      gainmod  = 0.2*0.3,
      dopplerscale = 1.0,
      maxconcurrent = 6,
      rolloff = 0.5,
  }
end

-- AMBIENCE LOCAL
local files = VFS.DirList("sounds/atmoslocal/")
local t = Sounds.SoundItems
for i=1,#files do
  local fileName = files[i]
  fileNames = string.sub(fileName, 19, string.find(fileName, ".wav") -1)
  t[fileNames] = {
      file     = fileName;
      gain = 0.9,
      pitchmod = 0.11,
      gainmod  = 0.2*0.3,
      dopplerscale = 1.0,
      maxconcurrent = 12,
      rolloff = 1.4,
  }
end

return Sounds

