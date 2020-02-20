local ret = {
	[0] = {
		nameLong = "Northwest",
		nameShort = "NW",
		startpoints = {
			{205,205},
		},
		boxes = {
			{
				{0,0},
				{410,0},
				{410,410},
				{0,410},
			},
		},
	},
	[1] = {
		nameLong = "Southeast",
		nameShort = "SE",
		startpoints = {
			{3891,3891},
		},
		boxes = {
			{
				{3686,3686},
				{4096,3686},
				{4096,4096},
				{3686,4096},
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
		{3891,205},
	},
	boxes = {
		{
			{3686,0},
			{4096,0},
			{4096,410},
			{3686,410},
		},
	},
}
ret[3] = {
	nameLong = "Southwest",
	nameShort = "SW",
	startpoints = {
		{1843,3891},
	},
	boxes = {
		{
			{0,3686},
			{3686,3686},
			{3686,4096},
			{0,4096},
		},
	},
}

return ret
