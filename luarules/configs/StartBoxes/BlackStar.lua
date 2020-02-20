local starting_points = {
	{4161, 1161, "North", "N"},
	{5789, 6492, "South-East", "SE"},
	{ 942, 3374, "West", "W"},
	{7047, 3333, "East", "E"},
	{2216, 6469, "South-West", "SW"},
}
local radius = 256

local ret = {}
for i = 1, #starting_points do
	ret[i-1] = {
		nameLong  = starting_points[i][3],
		nameShort = starting_points[i][4],
		startpoints = { { starting_points[i][1], starting_points[i][2] } },
		boxes = { { } },
	}
	for j = 1, 10 do
		ret[i-1].boxes[1][j] = {
			starting_points[i][1] + radius * math.sin(j * math.pi / 5),
			starting_points[i][2] + radius * math.cos(j * math.pi / 5),
		}
	end
end

return ret
