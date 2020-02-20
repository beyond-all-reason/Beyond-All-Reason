local WIDTH = 2400

return {
	[0] = {
		nameLong = "North",
		nameShort = "N",
		startpoints = {
			{3072, WIDTH/2},
		},
		boxes = {
			{
				{0, 0},
				{6144, 0},
				{6144, WIDTH},
				{0, WIDTH},
			},
		},
	},
	[1] = {
		nameLong = "South",
		nameShort = "S",
		startpoints = {
			{3072, 8192 - WIDTH/2},
		},
		boxes = {
			{
				{0, 8192 - WIDTH},
				{6144, 8192 - WIDTH},
				{6144, 8192},
				{0, 8192},
			},
		},
	},
}
