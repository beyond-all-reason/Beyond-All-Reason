local ret = {
	[0] = {
		nameLong = "Northwest",
		nameShort = "NW",
		startpoints = {
			{1751,1167},
		},
		boxes = {
			{
				{0,0},
				{3502,0},
				{3502,2335},
				{0,2335},
			},
		},
	},
	[1] = {
		nameLong = "Southeast",
		nameShort = "SE",
		startpoints = {
			{7465,4977},
		},
		boxes = {
			{
				{5714,3809},
				{9216,3809},
				{9216,6144},
				{5714,6144},
			},
		},
	}
}

if Spring.Utilities.GetTeamCount() == 2 then
	return ret
end

ret[2] = {
	nameLong = "Northeast",
	nameShort = "NE",
	startpoints = {
		{7465,1167},
	},
	boxes = {
		{
			{5714,0},
			{9216,0},
			{9216,2335},
			{5714,2335},
		},
	},
}
ret[3] = {
	nameLong = "Southwest",
	nameShort = "SW",
	startpoints = {
		{2857,4977},
	},
	boxes = {
		{
			{0,3809},
			{5714,3809},
			{5714,6144},
			{0,6144},
		},
	},
}

return ret
