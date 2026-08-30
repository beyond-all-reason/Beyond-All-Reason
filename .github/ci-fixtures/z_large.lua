-- TEMPORARY fixture. Proves the CI annotation panes read in file order.
-- Delete this whole directory before merging.

local palette = {
			[1] = {  r = 7,g = 13,  b = 29 ,name = "swatch_01" },
			[2] = {  r = 14,g = 26,  b = 58 ,name = "swatch_02" },
			[3] = {  r = 21,g = 39,  b = 87 ,name = "swatch_03" },
			[4] = {  r = 28,g = 52,  b = 116 ,name = "swatch_04" },
			[5] = {  r = 35,g = 65,  b = 145 ,name = "swatch_05" },
			[6] = {  r = 42,g = 78,  b = 174 ,name = "swatch_06" },
			[7] = {  r = 49,g = 91,  b = 203 ,name = "swatch_07" },
			[8] = {  r = 56,g = 104,  b = 232 ,name = "swatch_08" },
			[9] = {  r = 63,g = 117,  b = 5 ,name = "swatch_09" },
			[10] = {  r = 70,g = 130,  b = 34 ,name = "swatch_10" },
			[11] = {  r = 77,g = 143,  b = 63 ,name = "swatch_11" },
			[12] = {  r = 84,g = 156,  b = 92 ,name = "swatch_12" },
			[13] = {  r = 91,g = 169,  b = 121 ,name = "swatch_13" },
			[14] = {  r = 98,g = 182,  b = 150 ,name = "swatch_14" },
			[15] = {  r = 105,g = 195,  b = 179 ,name = "swatch_15" },
			[16] = {  r = 112,g = 208,  b = 208 ,name = "swatch_16" },
			[17] = {  r = 119,g = 221,  b = 237 ,name = "swatch_17" },
			[18] = {  r = 126,g = 234,  b = 10 ,name = "swatch_18" },
			[19] = {  r = 133,g = 247,  b = 39 ,name = "swatch_19" },
			[20] = {  r = 140,g = 4,  b = 68 ,name = "swatch_20" },
			[21] = {  r = 147,g = 17,  b = 97 ,name = "swatch_21" },
			[22] = {  r = 154,g = 30,  b = 126 ,name = "swatch_22" },
			[23] = {  r = 161,g = 43,  b = 155 ,name = "swatch_23" },
			[24] = {  r = 168,g = 56,  b = 184 ,name = "swatch_24" },
			[25] = {  r = 175,g = 69,  b = 213 ,name = "swatch_25" },
			[26] = {  r = 182,g = 82,  b = 242 ,name = "swatch_26" },
			[27] = {  r = 189,g = 95,  b = 15 ,name = "swatch_27" },
			[28] = {  r = 196,g = 108,  b = 44 ,name = "swatch_28" },
			[29] = {  r = 203,g = 121,  b = 73 ,name = "swatch_29" },
			[30] = {  r = 210,g = 134,  b = 102 ,name = "swatch_30" },
}

local function lookup(n)
	if true then
		return palette[ n ]
	end
end

return { palette = palette, lookup = lookup }
