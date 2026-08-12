-- Team color palettes, used by:
--  - luarules/gadgets/game_autocolors.lua to assign team colors
--  - luaui/Widgets/gui_advplayerslist.lua to describe colors by name (colorblind accessibility)
-- colorNames maps every declared color to an I18N key ('ui.playersList.color.<key>'),
-- so keep it in sync when editing the palettes. UI code falls back to a perceptual
-- nearest-match for colors not listed here (host-defined colors, anonymous mode).

-- Special colors
local specialColors = {
	armBlue = "#004DFF", -- Armada Blue
	corRed = "#FF1005", -- Cortex Red
	scavPurp = "#6809A1", -- Scav Purple
	raptorOrange = "#CC8914", -- Raptor Orange
	gaiaGray = "#7F7F7F", -- Gaia Grey
	legGreen = "#0CE818", -- Legion Green
}

-- NEW IceXuick Colors V6
local ffaColors = {
	"#004DFF", -- 1
	"#FF1005", -- 2
	"#0CE908", -- 3
	"#FFD200", -- 4
	"#F80889", -- 5
	"#09F5F5", -- 6
	"#FF6107", -- 7
	"#F190B3", -- 8
	"#097E1C", -- 9
	"#C88B2F", -- 10
	"#7CA1FF", -- 11
	"#9F0D05", -- 12
	"#3EFFA2", -- 13
	"#F5A200", -- 14
	"#C4A9FF", -- 15
	"#0B849B", -- 16
	"#B4FF39", -- 17
	"#FF68EA", -- 18
	"#D8EEFF", -- 19
	"#689E3D", -- 20
	"#B04523", -- 21
	"#FFBB7C", -- 22
	"#3475FF", -- 23
	"#DD783F", -- 24
	"#FFAAF3", -- 25
	"#4A4376", -- 26
	"#773A01", -- 27
	"#B7EA63", -- 28
	"#9F0D05", -- 29
	"#7EB900", -- 30
}

local survivalColors = {
	"#0B3EF3", -- 1
	"#FF1005", -- 2
	"#0CE908", -- 3
	"#FFAB8C", -- 4
	"#09F5F5", -- 5
	"#FCEEA4", -- 6
	"#097E1C", -- 7
	"#F190B3", -- 8
	"#F80889", -- 9
	"#3EFFA2", -- 10
	"#911806", -- 11
	"#7CA1FF", -- 12
	"#3C7A74", -- 13
	"#B04523", -- 14
	"#B4FF39", -- 15
	"#773A01", -- 16
	"#D8EEFF", -- 17
	"#689E3D", -- 18
	"#0B849B", -- 19
	"#FFD200", -- 20
	"#971C48", -- 21
	"#4A4376", -- 22
	"#764A4A", -- 23
	"#4F2684", -- 24
}

local teamColors = {
	{ -- One Team (not possible)
		{ -- First Team
			"#004DFF", -- Armada Blue
		},
	},

	{ -- Two Teams
		{ -- First Team (Cool)
			"#0B3EF3", --1
			"#0CE908", --2
			"#00F5E5", --3
			"#6941F2", --4
			"#8FFF94", --5
			"#1B702F", --6
			"#7CC2FF", --7
			"#A294FF", --8
			"#0B849B", --9
			"#689E3D", --10
			"#4F2684", --11
			"#2C32AC", --12
			"#6968A0", --13
			"#D8EEFF", --14
			"#3475FF", --15
			"#7EB900", --16
			"#4A4376", --17
			"#B7EA63", --18
			"#C4A9FF", --19
			"#37713A", --20
		},
		{ -- Second Team (Warm)
			"#FF1005", --1
			"#FFD200", --2
			"#FF6107", --3
			"#F80889", --4
			"#FCEEA4", --5
			"#8A2828", --6
			"#F190B3", --7
			"#C88B2F", --8
			"#B04523", --9
			"#FFBB7C", --10
			"#A35274", --11
			"#773A01", --12
			"#F5A200", --13
			"#BBA28B", --14
			"#971C48", --15
			"#FF68EA", --16
			"#DD783F", --17
			"#FFAAF3", --18
			"#764A4A", --19
			"#9F0D05", --20
		},
	},

	{ -- Three Teams
		{ -- First Team (Blue)
			"#004DFF", -- 1
			"#09F5F5", -- 2
			"#7CA1FF", -- 3
			"#2C32AC", -- 4
			"#D8EEFF", -- 5
			"#0B849B", -- 6
			"#3C7AFF", -- 7
			"#5F6492", -- 8
		},
		{ -- Second Team (Red)
			"#FF1005", -- 1
			"#FF6107", -- 2
			"#FFD200", -- 3
			"#FF6058", -- 4
			"#FFBB7C", -- 5
			"#C88B2F", -- 6
			"#F5A200", -- 7
			"#9F0D05", -- 8
		},
		{ -- Third Team (Green)
			"#0CE818", -- 1
			"#B4FF39", -- 2
			"#097E1C", -- 3
			"#3EFFA2", -- 4
			"#689E3D", -- 5
			"#7EB900", -- 6
			"#B7EA63", -- 7
			"#37713A", -- 8
		},
	},

	{ -- Four Teams
		{ -- First Team (Blue)
			"#004DFF", -- 1
			"#7CA1FF", -- 2
			"#D8EEFF", -- 3
			"#09F5F5", -- 4
			"#3475FF", -- 5
			"#0B849B", -- 6
		},
		{ -- Second Team (Red)
			"#FF1005", -- 1
			"#FF6107", -- 2
			"#FF6058", -- 3
			"#B04523", -- 4
			"#F80889", -- 5
			"#971C48", -- 6
		},
		{ -- Third Team (Green)
			"#0CE818", -- 1
			"#B4FF39", -- 2
			"#097E1C", -- 3
			"#3EFFA2", -- 4
			"#689E3D", -- 5
			"#7EB900", -- 6
		},
		{ -- Fourth Team (Yellow)
			"#FFD200", -- 1
			"#F5A200", -- 2
			"#FCEEA4", -- 3
			"#FFBB7C", -- 4
			"#BBA28B", -- 5
			"#C88B2F", -- 6
		},
	},

	{ -- Five Teams
		{ -- First Team (Blue)
			"#004DFF", -- 1
			"#7CA1FF", -- 2
			"#D8EEFF", -- 3
			"#09F5F5", -- 4
			"#3475FF", -- 5
		},
		{ -- Second Team (Red)
			"#FF1005", -- 1
			"#FF6107", -- 2
			"#FF6058", -- 3
			"#B04523", -- 4
			"#9F0D05", -- 5
		},
		{ -- Third Team (Green)
			"#0CE818", -- 1
			"#B4FF39", -- 2
			"#097E1C", -- 3
			"#3EFFA2", -- 4
			"#689E3D", -- 5
		},
		{ -- Fourth Team (Yellow)
			"#FFD200", -- 1
			"#F5A200", -- 2
			"#FCEEA4", -- 3
			"#FFBB7C", -- 4
			"#C88B2F", -- 5
		},
		{ -- Fifth Team (Fuchsia)
			"#F80889", -- 1
			"#FF68EA", -- 2
			"#FFAAF3", -- 3
			"#AA0092", -- 4
			"#701162", -- 5
		},
	},

	{ -- Six Teams
		{ -- First Team (Blue)
			"#004DFF", -- 1
			"#7CA1FF", -- 2
			"#D8EEFF", -- 3
			"#2C32AC", -- 4
		},
		{ -- Second Team (Red)
			"#FF1005", -- 1
			"#FF6058", -- 2
			"#B04523", -- 3
			"#9F0D05", -- 4
		},
		{ -- Third Team (Green)
			"#0CE818", -- 1
			"#B4FF39", -- 2
			"#097E1C", -- 3
			"#3EFFA2", -- 4
		},
		{ -- Fourth Team (Yellow)
			"#FFD200", -- 1
			"#F5A200", -- 2
			"#FCEEA4", -- 3
			"#9B6408", -- 4
		},
		{ -- Fifth Team (Fuchsia)
			"#F80889", -- 1
			"#FF68EA", -- 2
			"#FFAAF3", -- 3
			"#971C48", -- 4
		},
		{ -- Sixth Team (Orange)
			"#FF6107", -- 1
			"#FFBB7C", -- 2
			"#DD783F", -- 3
			"#773A01", -- 4
		},
	},

	{ -- Seven Teams
		{ -- First Team (Blue)
			"#004DFF", -- 1
			"#7CA1FF", -- 2
			"#2C32AC", -- 3
		},
		{ -- Second Team (Red)
			"#FF1005", -- 1
			"#FF6058", -- 2
			"#9F0D05", -- 3
		},
		{ -- Third Team (Green)
			"#0CE818", -- 1
			"#B4FF39", -- 2
			"#097E1C", -- 3
		},
		{ -- Fourth Team (Yellow)
			"#FFD200", -- 1
			"#F5A200", -- 2
			"#FCEEA4", -- 3
		},
		{ -- Fifth Team (Fuchsia)
			"#F80889", -- 1
			"#FF68EA", -- 2
			"#FFAAF3", -- 3
		},
		{ -- Sixth Team (Orange)
			"#FF6107", -- 1
			"#FFBB7C", -- 2
			"#DD783F", -- 3
		},
		{ -- Seventh Team (Cyan)
			"#09F5F5", -- 1
			"#0B849B", -- 2
			"#D8EEFF", -- 3
		},
	},

	{ -- Eight Teams
		{ -- First Team (Blue)
			"#004DFF", -- 1
			"#7CA1FF", -- 2
			"#2C32AC", -- 3
		},
		{ -- Second Team (Red)
			"#FF1005", -- 1
			"#FF6058", -- 2
			"#9F0D05", -- 3
		},
		{ -- Third Team (Green)
			"#0CE818", -- 1
			"#B4FF39", -- 2
			"#097E1C", -- 3
		},
		{ -- Fourth Team (Yellow)
			"#FFD200", -- 1
			"#F5A200", -- 2
			"#FCEEA4", -- 3
		},
		{ -- Fifth Team (Fuchsia)
			"#F80889", -- 1
			"#FF68EA", -- 2
			"#971C48", -- 3
		},
		{ -- Sixth Team (Orange)
			"#FF6107", -- 1
			"#FFBB7C", -- 2
			"#DD783F", -- 3
		},
		{ -- Seventh Team (Cyan)
			"#09F5F5", -- 1
			"#0B849B", -- 2
			"#D8EEFF", -- 3
		},
		{ -- Eigth Team (Purple)
			"#872DFA", -- 1
			"#6809A1", -- 2
			"#C4A9FF", -- 3
		},
	},
}

-- I18N name key for every color declared above ('ui.playersList.color.<key>')
local colorNames = {
	-- blues
	["#004DFF"] = "blue",
	["#0B3EF3"] = "blue",
	["#3475FF"] = "azure",
	["#3C7AFF"] = "azure",
	["#2C32AC"] = "navy",
	["#7CC2FF"] = "lightBlue",
	["#7CA1FF"] = "lightBlue",
	["#D8EEFF"] = "paleBlue",
	["#6968A0"] = "slate",
	["#5F6492"] = "slate",
	-- cyans
	["#00F5E5"] = "cyan",
	["#09F5F5"] = "cyan",
	["#0B849B"] = "teal",
	["#3C7A74"] = "teal",
	-- greens
	["#0CE908"] = "green",
	["#0CE818"] = "green",
	["#097E1C"] = "darkGreen",
	["#1B702F"] = "darkGreen",
	["#37713A"] = "darkGreen",
	["#689E3D"] = "moss",
	["#7EB900"] = "appleGreen",
	["#B4FF39"] = "lime",
	["#B7EA63"] = "paleLime",
	["#8FFF94"] = "mint",
	["#3EFFA2"] = "seaGreen",
	-- purples
	["#6941F2"] = "purple",
	["#872DFA"] = "purple",
	["#4F2684"] = "darkPurple",
	["#6809A1"] = "darkPurple",
	["#4A4376"] = "slatePurple",
	["#A294FF"] = "lavender",
	["#C4A9FF"] = "lilac",
	-- reds
	["#FF1005"] = "red",
	["#9F0D05"] = "darkRed",
	["#911806"] = "darkRed",
	["#FF6058"] = "coral",
	["#8A2828"] = "maroon",
	["#971C48"] = "wine",
	["#B04523"] = "rust",
	-- oranges / yellows / browns
	["#FF6107"] = "orange",
	["#F5A200"] = "amber",
	["#CC8914"] = "ochre",
	["#FFD200"] = "yellow",
	["#FCEEA4"] = "cream",
	["#FFBB7C"] = "peach",
	["#FFAB8C"] = "salmon",
	["#DD783F"] = "copper",
	["#C88B2F"] = "bronze",
	["#9B6408"] = "bronze",
	["#773A01"] = "brown",
	["#BBA28B"] = "tan",
	["#764A4A"] = "cocoa",
	-- pinks / magentas
	["#F80889"] = "magenta",
	["#AA0092"] = "magenta",
	["#701162"] = "darkMagenta",
	["#F190B3"] = "pink",
	["#FF68EA"] = "hotPink",
	["#FFAAF3"] = "palePink",
	["#A35274"] = "mauve",
	-- grays
	["#7F7F7F"] = "gray",
}

return {
	specialColors = specialColors,
	ffaColors = ffaColors,
	survivalColors = survivalColors,
	teamColors = teamColors,
	colorNames = colorNames,
}
