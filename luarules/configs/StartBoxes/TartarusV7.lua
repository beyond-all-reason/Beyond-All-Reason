local ret = {
	[0] = {
		nameLong = "Northeast",
		nameShort = "NE",
		startpoints = {
			{3789,307},
		},
		boxes = {
			{
				{3482,0},
				{4096,0},
				{4096,614},
				{3482,614},
			},
		},
	},
	[1] = {
		nameLong = "Southwest",
		nameShort = "SW",
		startpoints = {
			{307,3789},
		},
		boxes = {
			{
				{0,3482},
				{614,3482},
				{614,4096},
				{0,4096},
			},
		},
	}
}

if Spring.Utilities.GetTeamCount() == 2 then
	return ret
end

ret[2] = {
	nameLong = "Northwest",
	nameShort = "NW",
	startpoints = {
		{307,307},
	},
	boxes = {
		{
			{0,0},
			{614,0},
			{614,614},
			{0,614},
		},
	},
}
ret[3] = {
	nameLong = "Southeast",
	nameShort = "SE",
	startpoints = {
		{3789,3789},
	},
	boxes = {
		{
			{3482,3482},
			{4096,3482},
			{4096,4096},
			{3482,4096},
		},
	},
}

return ret
