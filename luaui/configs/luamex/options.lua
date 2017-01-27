options = {

	drawincome = {
		name = 'Should income be drawn below the mex spot?',
		type = 'bool',
		value = true,
		tooltip = "When disabled, this will prevent income from being drawn below the mex spot.",
		OnChange = function() updateMexDrawList() end
	},	
	drawcustomincomeamount = {
		name = 'Draw a custom mex income amount under each spot instead of the automatically calculated one?',
		type = 'bool',
		value = false,
		tooltip = "Enabled, this will allow you to draw a custom amount underneath each mex spot.",
		OnChange = function() updateMexDrawList() end
	},	
	drawicons = {
		name = 'Show Income as Icon',
		type = 'bool',
		value = false,
		tooltip = "When enabled income is shown pictorially. When disabled income is shown as a number.",
		OnChange = function() updateMexDrawList() end
	},
	size = {
		name = "Income Display Size", 
		type = "number", 
		value = 40, 
		min = 10,
		max = 150,
		step = 5,
		OnChange = function() updateMexDrawList() end
	},
	rounding = {
		name = "Display digits",
		type = "number",
		value = 1,
		min = 1,
		max = 4,
		advanced = true,
		OnChange = function() updateMexDrawList() end
	},
	multiplier = {
		name = "Multiplier used for base mex value",
		type = "number",
		value = 1, -- Most games will use 1 for this value as most games base mex income around a mex giving 2.0. Please not that changing this value only changes the number visually displayed underneath the mex spot. The actual multiplier is determined in the mex unitdef customparam "metal_extractor = <multiplier>,"
		min = 0,
		max = 100,
		OnChange = function() updateMexDrawList() end
	},
	customamount = {
		name = "Custom amount to be drawn under each mex",
		type = "number",
		value = 2.0,
		min = 0,
		max = 100,
		OnChange = function() updateMexDrawList() end
	},
	specPlayerColours = {
		name = "Use player colours when spectating",
		type = "bool",
		value = true,
		OnChange = function() updateMexDrawList() end
	}
}