-- The audio tab's settings. model.lua says what a row can hold.

local soundDevices, soundDevicesByName

return function(model)
	local types = model.types
	local init = model.init

	if not soundDevices then
		soundDevices = { "default" }
		soundDevicesByName = { [""] = 1 }
		-- SDL plays the sound by default and only opens its own names, which older engines list with OpenAL's prefix
		local sdlAudio = Spring.GetConfigInt("UseSDLAudio", 1) ~= 0
		for _, device in ipairs(Spring.GetSoundDevices()) do
			local name = sdlAudio and device.name:gsub("^OpenAL Soft on ", "") or device.name
			if not soundDevicesByName[name] then
				soundDevices[#soundDevices + 1] = name
				soundDevicesByName[name] = #soundDevices
			end
		end
		-- a device saved with that prefix still shows as selected
		local savedDevice = Spring.GetConfigString("snd_device", "") or ""
		soundDevicesByName[savedDevice] = soundDevicesByName[savedDevice]
			or soundDevicesByName[(savedDevice:gsub("^OpenAL Soft on ", ""))]
	end
	local holidays = BAR.Utilities.Gametype.GetCurrentHolidays()

	return {
		-- SOUND
		{
			id = "snddevice",
			group = "sound",
			category = types.advanced,
			available = soundDevices[2] ~= nil,
			name = BAR.I18N("ui.settings.option.snddevice"),
			type = "select",
			-- the engine switches the device in game while SDL plays the sound
			restart = not (Engine.FeatureSupport.liveConfigChanges and Spring.GetConfigInt("UseSDLAudio", 1) ~= 0),
			options = soundDevices,
			value = soundDevicesByName[Spring.GetConfigString("snd_device")],
			description = BAR.I18N("ui.settings.option.snddevice_descr"),
			onchange = function(option, value)
				if option.options[option.value] == "default" then
					Spring.SetConfigString("snd_device", "")
				else
					Spring.SetConfigString("snd_device", option.options[option.value])
				end
			end,
		},

		{
			id = "sndvolmaster",
			group = "sound",
			category = types.basic,
			prefix = BAR.I18N("ui.settings.option.volume"),
			name = BAR.I18N("ui.settings.option.sndvolmaster"),
			type = "slider",
			min = 0,
			max = 80,
			step = 2,
			value = 1,
			configInt = "snd_volmaster",
		},
		{
			id = "sndvolgeneral",
			parent = "sndvolmaster",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.sndvolgeneral"),
			type = "slider",
			min = 0,
			max = 100,
			step = 2,
			value = 1,
			configInt = "snd_volgeneral",
		},
		{
			id = "sndvolbattle",
			parent = "sndvolmaster",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.sndvolbattle"),
			type = "slider",
			min = 0,
			max = 100,
			step = 2,
			value = 100,
			configInt = "snd_volbattle_options",
		},
		{
			id = "sndvolui",
			parent = "sndvolmaster",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.sndvolui"),
			type = "slider",
			min = 0,
			max = 100,
			step = 2,
			value = 1,
			configInt = "snd_volui",
		},
		--{ id = "sndambient", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sndvolambient'), type = "slider", min = 0, max = 100, step = 2, value = tonumber(Spring.GetConfigInt("snd_volambient", 1) or 100),
		--  onload = function(option)
		--  end,
		--  onchange = function(option, value)
		--	  Spring.SetConfigInt("snd_volambient", value)
		--  end,
		--},
		--{ id = "sndvolunitreply", group = "sound", category = types.basic, name = widgetOptionColor .. "   " .. Spring.I18N('ui.settings.option.sndvolunitreply'), type = "slider", min = 0, max = 100, step = 2, value = tonumber(Spring.GetConfigInt("snd_volunitreply", 1) or 100),
		--  onload = function(option)
		--  end,
		--  onchange = function(option, value)
		--	  Spring.SetConfigInt("snd_volunitreply", value)
		--  end,
		--},
		{
			id = "console_chatvolume",
			parent = "sndvolmaster",
			group = "sound",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.console_chatvolume"),
			type = "slider",
			min = 0,
			max = 1,
			step = 0.01,
			value = 0,
			description = BAR.I18N("ui.settings.option.console_chatvolume_descr"),
			widgetConfig = { "Chat", "sndChatFileVolume", api = "chat", get = "getChatVolume", set = "setChatVolume" },
		},
		{
			id = "mapmarkvolume",
			parent = "sndvolmaster",
			group = "sound",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.console_mapmarkvolume"),
			type = "slider",
			min = 0,
			max = 1,
			step = 0.01,
			value = 0.6,
			description = BAR.I18N("ui.settings.option.console_mapmarkvolume_descr"),
			widgetConfig = {
				"Mapmark Ping",
				"volume",
				api = "mapmarkping",
				get = "getMapmarkVolume",
				set = "setMapmarkVolume",
			},
		},
		{
			id = "sndvolmusic",
			parent = "sndvolmaster",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.sndvolmusic"),
			type = "slider",
			min = 0,
			max = 99,
			step = 1,
			value = tonumber(Spring.GetConfigInt("snd_volmusic", 50) or 50),
			onchange = function(option, value)
				if WG.music and WG.music.SetMusicVolume then
					WG.music.SetMusicVolume(value)
				else
					Spring.SetConfigInt("snd_volmusic", value)
				end
			end,
		},

		{
			id = "sndunitsound",
			group = "sound",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sndunitsound"),
			type = "bool",
			value = true,
			description = BAR.I18N("ui.settings.option.sndunitsound_desc"),
			configInt = "snd_unitsound",
		},

		{
			id = "sndairabsorption",
			group = "sound",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sndairabsorption"),
			type = "slider",
			min = 0,
			max = 0.4,
			step = 0.01,
			value = 0.35,
			description = BAR.I18N("ui.settings.option.sndairabsorption_descr"),
			configFloat = "snd_airAbsorption",
		},

		{
			id = "sndzoomvolume",
			group = "sound",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.sndzoomvolume"),
			type = "slider",
			min = 0,
			max = 3,
			step = 0.01,
			value = 1.00,
			description = BAR.I18N("ui.settings.option.sndzoomvolume_descr"),
			configFloat = "snd_zoomVolume",
		},

		{
			id = "muteoffscreen",
			group = "sound",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.muteoffscreen"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.muteoffscreen_descr"),
			configInt = "muteOffscreen",
		},

		{
			id = "soundtrack",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.label_soundtrack"),
		},

		{
			id = "soundtrackNew",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.soundtracknew"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackNew", 1) == 1,
			description = BAR.I18N("ui.settings.option.soundtracknew_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackNew", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackRaptors",
			parent = "soundtrackNew",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.soundtrackraptors"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackRaptors", 0) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackraptors_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackRaptors", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackScavengers",
			parent = "soundtrackNew",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.soundtrackscavengers"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackScavengers", 0) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackscavengers_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackScavengers", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackAprilFools",
			parent = "soundtrackNew",
			group = "sound",
			category = types.basic,
			available = holidays.aprilfools == true,
			name = BAR.I18N("ui.settings.option.soundtrackaprilfools"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackAprilFools", 1) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackaprilfools_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackAprilFools", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackAprilFoolsPostEvent",
			parent = "soundtrackNew",
			group = "sound",
			category = types.basic,
			available = not holidays.aprilfools,
			name = BAR.I18N("ui.settings.option.soundtrackaprilfoolspostevent"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackAprilFoolsPostEvent", 0) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackaprilfoolspostevent_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackAprilFoolsPostEvent", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackHalloween",
			parent = "soundtrackNew",
			group = "sound",
			category = types.basic,
			available = holidays.halloween == true,
			name = BAR.I18N("ui.settings.option.soundtrackhalloween"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackHalloween", 1) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackhalloween_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackHalloween", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackHalloweenPostEvent",
			parent = "soundtrackNew",
			group = "sound",
			category = types.basic,
			available = not holidays.halloween,
			name = BAR.I18N("ui.settings.option.soundtrackhalloweenpostevent"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackHalloweenPostEvent", 0) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackhalloweenpostevent_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackHalloweenPostEvent", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackXmas",
			parent = "soundtrackNew",
			group = "sound",
			category = types.basic,
			available = holidays.xmas == true,
			name = BAR.I18N("ui.settings.option.soundtrackxmas"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackXmas", 1) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackxmas_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackXmas", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackXmasPostEvent",
			parent = "soundtrackNew",
			group = "sound",
			category = types.basic,
			available = not holidays.xmas,
			name = BAR.I18N("ui.settings.option.soundtrackxmaspostevent"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackXmasPostEvent", 0) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackxmaspostevent_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackXmasPostEvent", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackCustom",
			group = "sound",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.soundtrackcustom"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackCustom", 1) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackcustom_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackCustom", value and 1 or 0)
				if WG.music and WG.music.RefreshTrackList then
					WG.music.RefreshTrackList()
					init()
				end
			end,
		},
		{
			id = "soundtrackInterruption",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.soundtrackinterruption"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackInterruption", 1) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackinterruption_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackInterruption", value and 1 or 0)
				if WG.music and WG.music.RefreshSettings then
					WG.music.RefreshSettings()
				end
			end,
		},
		{
			id = "soundtrackFades",
			group = "sound",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.soundtrackfades"),
			type = "bool",
			value = Spring.GetConfigInt("UseSoundtrackFades", 1) == 1,
			description = BAR.I18N("ui.settings.option.soundtrackfades_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("UseSoundtrackFades", value and 1 or 0)
				if WG.music and WG.music.RefreshSettings then
					WG.music.RefreshSettings()
				end
			end,
		},
	}
end
