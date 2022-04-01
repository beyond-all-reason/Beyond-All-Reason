local keyLayouts = {
	qwerty = {
		[3] = {
			[1] = "Q",
			[2] = "W",
			[3] = "E",
			[4] = "R",
		},
		[2] = {
			[1] = "A",
			[2] = "S",
			[3] = "D",
			[4] = "F",
		},
		[1] = {
			[1] = "Z",
			[2] = "X",
			[3] = "C",
			[4] = "V",
			[5] = "B",
			[6] = "N",
		}
	},
	dvorak = {
		[3] = {
			[1] = "QUOTE",
			[2] = "COMMA",
			[3] = "PERIOD",
			[4] = "P",
		},
		[2] = {
			[1] = "A",
			[2] = "O",
			[3] = "E",
			[4] = "U",
		},
		[1] = {
			[1] = "SEMICOLON",
			[2] = "Q",
			[3] = "J",
			[4] = "K",
			[5] = "X",
			[6] = "B",
		}
	},
}

local function copyKeyLayout(layoutFrom)
	local layoutTo = {}
	for rowIndex, rowKeySet in pairs(keyLayouts[layoutFrom]) do
		layoutTo[rowIndex] = {}

		for colIndex, key in pairs(rowKeySet) do
			layoutTo[rowIndex][colIndex] = key
		end
	end

	return layoutTo
end

keyLayouts['qwertz'] = copyKeyLayout('qwerty')
keyLayouts['qwertz'][1][1] = 'Y'

keyLayouts['azerty'] = copyKeyLayout('qwerty')
keyLayouts['azerty'][1][1] = 'W'
keyLayouts['azerty'][2][1] = 'Q'
keyLayouts['azerty'][3][1] = 'A'
keyLayouts['azerty'][3][2] = 'Z'

local layouts = { 'qwerty', 'qwertz', 'azerty', 'dvorak' }

return {
	copyKeyLayout = copyKeyLayout,
	layouts = layouts,
	keyLayouts = keyLayouts,
}
