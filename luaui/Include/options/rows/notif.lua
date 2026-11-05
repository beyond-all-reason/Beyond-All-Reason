-- The notifications tab's settings. model.lua says what a row can hold.
return function(model)
	local types = model.types
	local init = model.init
	return {
		--{ id = "loadscreen_music", group = "sound", category = types.basic, name = Spring.I18N('ui.settings.option.loadscreen_music'), type = "bool", value = (Spring.GetConfigInt("music_loadscreen", 1) == 1), description = Spring.I18N('ui.settings.option.loadscreen_music_descr'),
		--  onchange = function(option, value)
		--	  Spring.SetConfigInt("music_loadscreen", (value and 1 or 0))
		--  end,
		--},

		{
			id = "notifications_set",
			group = "notif",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.notifications_set"),
			type = "select",
			options = {},
			value = 1,
			onchange = function(option, value)
				Spring.SetConfigString("voiceset", option.options[option.value])
				if widgetHandler.orderList.Notifications ~= nil then
					widgetHandler:DisableWidget("Notifications")
					widgetHandler:EnableWidget("Notifications")
					init()
				end
			end,
		},

		--{ id = "notifications_tutorial", group = "notif", name = Spring.I18N('ui.settings.option.notifications_tutorial'), category = types.basic, type = "bool", value = (WG['notifications'] ~= nil and WG['notifications'].getTutorial()), description = Spring.I18N('ui.settings.option.notifications_tutorial_descr'),
		--  onload = function(option)
		--	  loadWidgetData("Notifications", "notifications_tutorial", { 'tutorialMode' })
		--  end,
		--  onchange = function(option, value)
		--	  saveOptionValue('Notifications', 'notifications', 'setTutorial', { 'tutorialMode' }, value)
		--  end,
		--},
		{
			id = "notifications_messages",
			group = "notif",
			name = BAR.I18N("ui.settings.option.notifications_messages"),
			category = types.basic,
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.notifications_messages_descr"),
			widgetConfig = {
				"Notifications",
				"displayMessages",
				api = "notifications",
				get = "getMessages",
				set = "setMessages",
			},
		},
		{
			id = "notifications_spoken",
			group = "notif",
			name = BAR.I18N("ui.settings.option.notifications_spoken"),
			category = types.basic,
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.notifications_spoken_descr"),
			widgetConfig = { "Notifications", "spoken", api = "notifications", get = "getSpoken", set = "setSpoken" },
		},
		{
			id = "notifications_volume",
			group = "notif",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.notifications_volume"),
			type = "slider",
			min = 0.05,
			max = 1,
			step = 0.05,
			value = 0.7,
			description = BAR.I18N("ui.settings.option.notifications_volume_descr"),
			widgetConfig = { "Notifications", "globalVolume", api = "notifications", set = "setVolume" },
		},
		{
			id = "notifications_substitute",
			group = "notif",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.notifications_substitute"),
			type = "bool",
			value = Spring.GetConfigInt("NotificationsSubstitute", 0) == 1,
			description = BAR.I18N("ui.settings.option.notifications_substitute_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("NotificationsSubstitute", value and 1 or 0)
				widgetHandler:DisableWidget("Notifications")
				widgetHandler:EnableWidget("Notifications")
				init()
			end,
		},
		{
			id = "notifications_refresh",
			group = "notif",
			category = types.advanced,
			name = BAR.I18N("ui.settings.option.notifications_refresh"),
			type = "bool",
			value = false,
			description = BAR.I18N("ui.settings.option.notifications_refresh_descr"),
			onchange = function(option, value)
				widgetHandler:DisableWidget("Notifications")
				widgetHandler:EnableWidget("Notifications")
				init()
			end,
		},

		{
			id = "label_notif_messages",
			group = "notif",
			name = BAR.I18N("ui.settings.option.label_messages"),
			category = types.basic,
		},
	}
end
