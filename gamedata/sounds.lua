local Sounds = {
	SoundItems = {
		--IncomingChat = {
		--	file = "sounds/ui/beep4.wav",
		--	in3d = "false",
		--},
		MultiSelect = {
			file = "sounds/ui/multiselect.wav",
			in3d = "false",
		},
		MapPoint = {
			file = "sounds/ui/mappoint.wav",	-- file now equal as blank.wav, is being called by chat ui widget now (so users can adjust its volume)
			--rolloff = 0.1,
			--dopplerscale = 0,
			in3d = "false",
		},
		FailedCommand = {
			file = "sounds/replies/cantdo4.wav",
		},
	},
}

--[[ Add sound entries for directory sounds/some-directory/ using the following format:
	['some-directory'] = {
		gain = 0.8,
		maxconcurrent = 1,
		rolloff = 0,
	},

	Compound directories can be used e.g. sound/some-directory/other-directory
	['some-directory/other-directory'] = {

	For attributes that use custom values per sound file:
	gain = {
		default = 0.5,
		custom = {
			['^beamershot2$'] = 0.4,
			['^lasr'] = 0.1,
		},
	},

	Key name is used in string:match for sound file name
	^example$	- exact match whole file name
	^exam		- match any file starting with "exam"
]]
local soundData = {
	-- UI SOUNDS
	['ui'] = {
		gain = 0.8,
		pitchmod = 0,
		gainmod  = 0,
		dopplerscale = 0,
		maxconcurrent = 1,
		--priority = 1,
		rolloff = 0,
	},

	['uw'] = {
		gain = 1.2 * 0.3,
		pitchmod = 0.17,
		gainmod  = 0.2 * 0.3,
		dopplerscale = 0,
		maxconcurrent = 8,
		--priority = 1,
		rolloff = 0.1,
	},

	--[[
	--VOICE MESSAGES
	['voice'] = {
		gain = 0.8,
		pitchmod = 0.1,
		gainmod  = 0,
		dopplerscale = 0,
		maxconcurrent = 1,
		priority = 2,
		rolloff = 0,
	},

	['voice/scavengers'] = {
		gain = 0.8,
		pitchmod = 0.1,
		gainmod  = 0,
		dopplerscale = 0,
		maxconcurrent = 1,
		priority = 2,
		rolloff = 0,
	},

	['voice/tutorial'] = {
		gain = 0.8,
		pitchmod = 0.1,
		gainmod  = 0,
		dopplerscale = 0,
		maxconcurrent = 1,
		priority = 2,
		rolloff = 0,
	},
]]

	-- WEAPON SOUNDS
	['weapons'] = {
		gain = {
			default = 1.2 * 0.3,
			custom = {
				['^beamershot2$'] = 0.5 * 0.3,
				['^disigun1$'] = 0.075 * 0.3,
				-- ['^newboom$'] = 0.045 * 0.3,
				['^xplomas2$'] = 0.225 * 0.3,
			},
		},
		pitchmod = {
			default = 0.17,
			custom = {
				['^heliosfire$'] = 0.03,
				['^beamershot2$'] = 0.04,
				['^lasfirerc$'] = 0.06,
				['^heatray'] = 0,
				['^lasr'] = 0,
				['^nanlath'] = 0.02,
				['^mavgun'] = 0.06,
				['^mgun'] = 0.08,
				['^minigun'] = 0.09,
				['^lrpcshot'] = 0.12,
				['^raptorlaser$'] = 0.04,
				['^heatray3'] = 0.04,
				['^xplosml'] = 0.22,
				['^xplomed'] = 0.25,
				['^xplolrg'] = 0.3,
				['^nukelaunch$'] = 0.08,
				['^nukelaunchalarm$'] = 0,
			},
		},
		gainmod  = 0.2 * 0.3,
		maxconcurrent = {
			default = 7,
			custom = {
				['^minigun'] = 12,
			},
		},
		dopplerscale = 1.0,
		rolloff = 1.4,
	},

	-- WEAPON SOUNDS MULTI (more concurrent)
	['weapons-mult'] = {
		gain = 1.2 * 0.3,
		pitchmod = {
			default = 0.17,
			custom = {
				['^lasr'] = 0.03,
				['^mgun'] = 0.02,
			},
		},
		gainmod  = 0.2 * 0.3,
		dopplerscale = 1.0,
		maxconcurrent = 15,
		rolloff = 1.5,
	},

	-- RAPTOR SOUNDS
	['raptors'] = {
		gain = 1.2 * 0.5,
		pitchmod = {
			default = 0.23,
			custom = {
				['^talonattack$'] = 0.07
			},
		},
		gainmod  = 0.2 * 0.3,
		dopplerscale = 1.0,
		maxconcurrent = 6,
		rolloff = 1.1,
	},

	-- GLOBAL EVENTS not in use currently
	['global-events'] = {
		gain = 1.0 * 0.3,
		pitchmod = 0.33,
		gainmod  = 0.1 * 0.3,
		dopplerscale = 1.0,
		maxconcurrent = 8,
		rolloff = 0.2,
	},

	-- BOMB SOUNDS / More maxconcurrent
	['bombs'] = {
		gain = 1.2 * 0.3,
		pitchmod = 0.27,
		gainmod  = 0.2 * 0.3,
		dopplerscale = 1.0,
		maxconcurrent = 32,
		rolloff = 1.1,
	},

	-- REPLY SOUNDS
	['replies'] = {
		gain = 1.2 * 0.3,
		pitchmod = 0.02,
		gainmod  = 0.2 * 0.3,
		dopplerscale = 0,
		maxconcurrent = 32,
		rolloff = 0.05,
		priority = 1,
		--in3d = false,
	},

	-- LAND UNIT MOVEMENT SOUNDS
	['movement'] = {
		gain = 1.2 * 0.3,
		pitchmod = 0.062,
		gainmod  = 0.2 * 0.3,
		dopplerscale = 0,
		maxconcurrent = 2,
		rolloff = 0.1,
		priority = 1,
		--in3d = false,
	},

	-- AIR UNIT MOVEMENT SOUNDS
	['movement-air'] = {
		gain = 1.2 * 0.3,
		pitchmod = 0.02,
		gainmod  = 0.2 * 0.3,
		dopplerscale = 0,
		maxconcurrent = 2,
		rolloff = 0.1,
		priority = 1,
		--in3d = false,
	},

	-- UNIT FOOTSTEPS SOUNDS // high pitch-mod
	['unit'] = {
		gain = 1.2 * 0.3,
		pitchmod = 0.33,
		gainmod  = 0.2 * 0.3,
		dopplerscale = 0.5,
		maxconcurrent = 6,
		rolloff = 1.1,
		priority = 1,
		--in3d = false,
	},

	-- UNIT MOVEMENT SOUNDS // local low pitch-mod
	['unit-local'] = {
		gain = 1.2 * 0.5,
		pitchmod = 0.03,
		gainmod  = 0.2 * 0.3,
		dopplerscale = 0,
		maxconcurrent = 2,
		rolloff = 1.3,
		priority = 1,
		--in3d = false,
	},

	-- UNIT FUNCTION/WEAPON SOUNDS
	['function'] = {
		gain = 1.2 * 0.3,
		pitchmod = 0.02,
		gainmod  = 0.2 * 0.3,
		dopplerscale = 0,
		maxconcurrent = 7,
		rolloff = 0.1,
		priority = 1,
		--in3d = false,
	},

	-- BUILDING FUNCTION/WEAPON SOUNDS
	['buildings'] = {
		gain = 1.2 * 0.3,
		pitchmod = 0.03,
		gainmod  = 0.2 * 0.3,
		dopplerscale = 0,
		maxconcurrent = 2,
		rolloff = 0.1,
		priority = 1,
		--in3d = false,
	},

	-- UI COMMANDS SOUNDS
	['commands'] = {
		gain = 1.2 * 0.3,
		pitchmod = 0.02,
		gainmod  = 0.2 * 0.3,
		dopplerscale = 0,
		maxconcurrent = 32,
		rolloff = 0,
		priority = 1,
		--in3d = false,
	},

	-- CRITTER SOUNDS
	['critters'] = {
		gain = 1.1 * 0.3,
		pitchmod = 0.01,
		gainmod  = 0.15 * 0.3,
		dopplerscale = 1.0,
		maxconcurrent = 4,
		rolloff = 0.7,
	},

--[[
	-- SCAVENGER SOUNDS not in use currently
	['scavengers'] = {
		gain = 1.0 * 0.3,
		pitchmod = 0.33,
		gainmod  = 0.1 * 0.3,
		dopplerscale = 1.0,
		maxconcurrent = 8,
		rolloff = 0.2,
	},
]]

	-- AMBIENCE
	['atmos'] = {
		gain = 1.2 * 0.3,
		priority = -10,
		pitchmod = 0.22,
		gainmod  = 0,
		dopplerscale = 8.0,
		maxconcurrent = 10,
		rolloff = 0.7,
		in3d = true,
		maxdist = 5000, --was disabled and 10000
	},

	-- AMBIENCE LOCAL
	['atmos-local'] = {
		gain = 1.2 * 0.3,
		priority = -5,
		pitchmod = 0.22,
		gainmod  = 0,
		dopplerscale = 4.0,
		maxconcurrent = 10,
		rolloff = 1.5,
		maxdist = 2500, --was 5000
		in3d = true,
	},

	-- AMBIENCE GEOVENTS
	['atmos-geovents'] = {
		gain = 0.8,
		priority = -3,
		pitchmod = 0.06,
		gainmod  = 0,
		dopplerscale = 2.0,
		maxconcurrent = 10,
		rolloff = 3,
		maxdist = 2000, --was 3000
	},
}

local function loadSoundFiles(directory, soundAttributes)
	local soundFiles = VFS.DirList(directory)

	for _, fileName in ipairs(soundFiles) do
		local soundName = string.sub(fileName, string.len(directory) + 1, string.find(fileName, ".wav") -1)
		Sounds.SoundItems[soundName] = {}
		Sounds.SoundItems[soundName].file = fileName

		local value
		for attribute, attributeValue in pairs(soundAttributes) do
			if type(attributeValue) ~= "table" then
				value = attributeValue
			else
				value = attributeValue.default

				for soundMatchPattern, customValue in pairs(attributeValue.custom) do
					if soundName:match(soundMatchPattern) then
						value = customValue
					end
				end
			end

			Sounds.SoundItems[soundName][attribute] = value
		end
	end
end

for directory, attributes in pairs(soundData) do
	loadSoundFiles('sounds/' .. directory .. '/', attributes)
end

return Sounds
