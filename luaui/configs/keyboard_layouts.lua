local keyLayouts = {
	qwerty = {
		[3] = {
			[1]  = "Q",
			[2]  = "W",
			[3]  = "E",
			[4]  = "R",
			[5]  = "T",
			[6]  = "Y",
			[7]  = "U",
			[8]  = "I",
			[9]  = "O",
			[10] = "P",
		},
		[2] = {
			[1] = "A",
			[2] = "S",
			[3] = "D",
			[4] = "F",
			[5] = "G",
			[6] = "H",
			[7] = "J",
			[8] = "K",
			[9] = "L",
		},
		[1] = {
			[1] = "Z",
			[2] = "X",
			[3] = "C",
			[4] = "V",
			[5] = "B",
			[6] = "N",
			[7] = "M",
		}
	},
	dvorak = {
		[3] = {
			[1] = "'",
			[2] = ",",
			[3] = ".",
			[4] = "P",
			[5] = "Y",
			[6] = "F",
			[7] = "G",
			[8] = "C",
			[9] = "R",
			[10] = "L",
		},
		[2] = {
			[1] = "A",
			[2] = "O",
			[3] = "E",
			[4] = "U",
			[5] = "I",
			[6] = "D",
			[7] = "H",
			[8] = "T",
			[9] = "N",
		},
		[1] = {
			[1] = ";",
			[2] = "Q",
			[3] = "J",
			[4] = "K",
			[5] = "X",
			[6] = "B",
			[7] = "M",
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
keyLayouts['qwertz'][3][6] = 'Z'

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
