-- The accessibility tab's settings. model.lua says what a row can hold.
return function(model)
	local types = model.types
	local getOption = model.getOption

	local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode

	return {
		-- ACCESSIBILITY

		{
			id = "label_teamcolors",
			group = "accessibility",
			name = BAR.I18N("ui.settings.option.label_teamcolors"),
			category = types.basic,
		},

		{
			id = "anonymous_color",
			parent = "label_teamcolors",
			group = "accessibility",
			category = types.basic,
			available = anonymousMode ~= "disabled",
			name = BAR.I18N("ui.settings.option.anonymous_color"),
			type = "color",
			max = 255,
			step = 1,
			value = { 255, 0, 0 },
			configInt = { "anonymousColorR", "anonymousColorG", "anonymousColorB" },
			description = BAR.I18N("ui.settings.option.anonymous_descr"),
			onchange = function(option, value, force)
				if force then
					Spring.SendCommands("luarules reloadluaui")
				else
					model.scheduledApply = { os.clock() + 1.5, "anonymous_color" }
				end
			end,
		},

		{
			id = "simpleteamcolors",
			group = "accessibility",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.playercolors"),
			type = "bool",
			value = tonumber(Spring.GetConfigInt("SimpleTeamColors", 0) or 0) == 1,
			description = BAR.I18N("ui.settings.option.simpleteamcolors_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("SimpleTeamColors", (value and 1 or 0))
				Spring.SetConfigInt("UpdateTeamColors", 1)
			end,
		},

		{
			id = "simpleteamcolors_reset",
			parent = "simpleteamcolors",
			group = "accessibility",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.simpleteamcolors_reset"),
			type = "bool",
			value = false,
			onchange = function(option, value)
				Spring.SetConfigInt("SimpleTeamColorsUseGradient", 0)
				getOption("simpleteamcolors_use_gradient").value = false
				for id, default in pairs({
					simpleteamcolors_player = { 0, 77, 255 },
					simpleteamcolors_ally = { 0, 255, 0 },
					simpleteamcolors_enemy = { 255, 16, 5 },
				}) do
					local color = getOption(id)
					for i, key in ipairs(color.configInt) do
						Spring.SetConfigInt(key, default[i])
					end
					color.value = default
				end
				option.value = false -- a button, not a setting
				Spring.SetConfigInt("UpdateTeamColors", 1)
			end,
		},
		{
			id = "simpleteamcolors_use_gradient",
			parent = "simpleteamcolors",
			group = "accessibility",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.simpleteamcolors_use_gradient"),
			type = "bool",
			value = tonumber(Spring.GetConfigInt("SimpleTeamColorsUseGradient", 0) or 0) == 1,
			onchange = function(option, value)
				Spring.SetConfigInt("SimpleTeamColorsUseGradient", (value and 1 or 0))
				Spring.SetConfigInt("UpdateTeamColors", 1)
			end,
		},
		{
			id = "simpleteamcolorsfactionspecific",
			parent = "simpleteamcolors",
			group = "accessibility",
			category = types.dev,
			name = BAR.I18N("ui.settings.option.simpleteamcolorsfactionspecific"),
			type = "bool",
			value = tonumber(Spring.GetConfigInt("SimpleTeamColorsFactionSpecific", 0) or 0) == 1,
			description = BAR.I18N("ui.settings.option.simpleteamcolorsfactionspecific_descr"),
			onchange = function(option, value)
				Spring.SetConfigInt("SimpleTeamColorsFactionSpecific", (value and 1 or 0))
				Spring.SetConfigInt("UpdateTeamColors", 1)
			end,
		},
		{
			id = "simpleteamcolors_player",
			parent = "simpleteamcolors",
			group = "accessibility",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.simpleteamcolors_player"),
			type = "color",
			max = 255,
			step = 1,
			value = { 0, 77, 255 },
			configInt = { "SimpleTeamColorsPlayerR", "SimpleTeamColorsPlayerG", "SimpleTeamColorsPlayerB" },
			onchange = function()
				Spring.SetConfigInt("UpdateTeamColors", 1)
			end,
		},
		{
			id = "simpleteamcolors_ally",
			parent = "simpleteamcolors",
			group = "accessibility",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.simpleteamcolors_ally"),
			type = "color",
			max = 255,
			step = 1,
			value = { 0, 255, 0 },
			configInt = { "SimpleTeamColorsAllyR", "SimpleTeamColorsAllyG", "SimpleTeamColorsAllyB" },
			onchange = function()
				Spring.SetConfigInt("UpdateTeamColors", 1)
			end,
		},
		{
			id = "simpleteamcolors_enemy",
			parent = "simpleteamcolors",
			group = "accessibility",
			category = types.basic,
			name = BAR.I18N("ui.settings.option.simpleteamcolors_enemy"),
			type = "color",
			max = 255,
			step = 1,
			value = { 255, 16, 5 },
			configInt = { "SimpleTeamColorsEnemyR", "SimpleTeamColorsEnemyG", "SimpleTeamColorsEnemyB" },
			onchange = function()
				Spring.SetConfigInt("UpdateTeamColors", 1)
			end,
		},
	}
end
