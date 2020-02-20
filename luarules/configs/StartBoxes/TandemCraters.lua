local ret = {
	[0] = {
		nameLong = "Northwest",
		nameShort = "NW",
		startpoints = {
			{1024,640},
		},
		boxes = {
			{
				{0,0},
				{2048,0},
				{2048,1280},
				{0,1280},
			},
		},
	},
	[1] = {
		nameLong = "Southeast",
		nameShort = "SE",
		startpoints = {
			{7168,4480},
		},
		boxes = {
			{
				{6144,3840},
				{8192,3840},
				{8192,5120},
				{6144,5120},
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
		{7168,640},
	},
	boxes = {
		{
			{6144,0},
			{8192,0},
			{8192,1280},
			{6144,1280},
		},
	},
}
ret[3] = {
	nameLong = "Southwest",
	nameShort = "SW",
	startpoints = {
		{3072,4480},
	},
	boxes = {
		{
			{0,3840},
			{6144,3840},
			{6144,5120},
			{0,5120},
		},
	},
}

return ret
