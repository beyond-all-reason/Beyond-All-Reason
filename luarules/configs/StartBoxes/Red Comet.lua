local ret = {
	[0] = {
		nameLong = "West",
		nameShort = "W",
		startpoints = {
			{ 898, 3314},
			{ 677, 1922},
			{ 876,  411},
		},
		boxes = {
			{
				{0,0},
				{922,0},
				{922,4096},
				{0,4096},
			},
		},
	},
	[1] = {
		nameLong = "East",
		nameShort = "E",
		boxes = { },
		startpoints = { },
	},
}

-- mirror west into east
for i = 1, #ret[0].startpoints do
	ret[1].startpoints[i] = {Game.mapSizeX - ret[0].startpoints[i][1], Game.mapSizeZ - ret[0].startpoints[i][2]}
end
for i = 1, #ret[0].boxes do
	ret[1].boxes[i] = {}
	for j = 1, #ret[0].boxes[i] do
		ret[1].boxes[i][j] = {Game.mapSizeX - ret[0].boxes[i][j][1], Game.mapSizeZ - ret[0].boxes[i][j][2]}
	end
end

return ret
