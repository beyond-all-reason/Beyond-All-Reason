local ret = {
	[0] = {
		nameLong = "Northwest",
		nameShort = "NW",
		startpoints = {
			{819,614},
		},
		boxes = {
			{
				{0,0},
				{1638,0},
				{1638,1229},
				{0,1229},
			},
		},
	},
	[1] = {
		nameLong = "Southeast",
		nameShort = "SE",
		startpoints = {
			{7373,5530},
		},
		boxes = {
			{
				{6554,4915},
				{8192,4915},
				{8192,6144},
				{6554,6144},
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
		{7373,614},
	},
	boxes = {
		{
			{6554,0},
			{8192,0},
			{8192,1229},
			{6554,1229},
		},
	},
}
ret[3] = {
	nameLong = "Southwest",
	nameShort = "SW",
	startpoints = {
		{3277,5530},
	},
	boxes = {
		{
			{0,4915},
			{6554,4915},
			{6554,6144},
			{0,6144},
		},
	},
}

return ret
