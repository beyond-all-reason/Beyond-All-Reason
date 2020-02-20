local ret = {
	[0] = {
		nameLong = "West",
		nameShort = "W",
		startpoints = {
			{ 750, 2900},
			{1580, 4444},
			{ 557, 5189},
			{1764, 1707},
			{2040, 3516},
			{ 790,  530},
		},
		boxes = {
			{
				{0,0},
				{2048,0},
				{2048,7168},
				{0,7168},
			},
		},
	},
	[1] = {
		nameLong = "East",
		nameShort = "E",

		-- automirrored
		startpoints = { },
		boxes = { },
	},
}

-- mirror west into east
for i = 1, #ret[0].startpoints do
	ret[1].startpoints[i] = {Game.mapSizeX - ret[0].startpoints[i][1], ret[0].startpoints[i][2]}
end
for i = 1, #ret[0].boxes do
	ret[1].boxes[i] = {}
	for j = 1, #ret[0].boxes[i] do
		ret[1].boxes[i][j] = {Game.mapSizeX - ret[0].boxes[i][j][1], ret[0].boxes[i][j][2]}
	end
end

return ret
