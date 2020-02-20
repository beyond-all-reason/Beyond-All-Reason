local starting_points = {
	{ 340, 2215, "West", "W"},
	{3728, 2107, "East", "E"},
}
local radius = 275

local ret = {}
for i = 1, #starting_points do
	ret[i-1] = {
		nameLong  = starting_points[i][3],
		nameShort = starting_points[i][4],
		startpoints = { { starting_points[i][1], starting_points[i][2] } },
		boxes = { { } },
	}
	for j = 1, 16 do
		ret[i-1].boxes[1][j] = {
			starting_points[i][1] + radius * math.sin(j * math.pi / 8),
			starting_points[i][2] + radius * math.cos(j * math.pi / 8),
		}
	end
end

return ret
