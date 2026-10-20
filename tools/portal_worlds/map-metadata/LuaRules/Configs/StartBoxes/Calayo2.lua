local nw = {
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
}
local se = {
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

local ne = {
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
local sw = {
	nameLong = "Southwest",
	nameShort = "SW",
	startpoints = {
		{205,3891},
	},
	boxes = {
		{
			{0,3686},
			{410,3686},
			{410,4096},
			{0,4096},
		},
	},
}

-- note, the map is not actually 4-way symmetrical (due to center mexes)
if Spring.Utilities.GetTeamCount() ~= 2 then
	return {nw, se, ne, sw}
elseif math.random() < 0.5 then
	return {nw, se}
else
	return {ne, sw}
end
