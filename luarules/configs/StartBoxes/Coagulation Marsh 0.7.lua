local ret = {
	[0] = {
		nameLong = "Northwest",
		nameShort = "NW",
		startpoints = {
			{645,645},
		},
		boxes = {
			{
				{0,0},
				{1290,0},
				{1290,1290},
				{0,1290},
			},
		},
	},
	[1] = {
		nameLong = "Southeast",
		nameShort = "SE",
		startpoints = {
			{6523,6523},
		},
		boxes = {
			{
				{5878,5878},
				{7168,5878},
				{7168,7168},
				{5878,7168},
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
		{6523,645},
	},
	boxes = {
		{
			{5878,0},
			{7168,0},
			{7168,1290},
			{5878,1290},
		},
	},
}
ret[3] = {
	nameLong = "Southwest",
	nameShort = "SW",
	startpoints = {
		{2939,6523},
	},
	boxes = {
		{
			{0,5878},
			{1290,5878},
			{1290,7168},
			{0,7168},
		},
	},
}

return ret
