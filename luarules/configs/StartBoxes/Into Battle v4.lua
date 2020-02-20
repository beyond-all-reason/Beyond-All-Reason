local duelbox = {
	[0] = {
		nameLong = "West",
		nameShort = "W",
		startpoints = {
			{1250,4800},
		},
		boxes = {
			{
				{800,5030},
				{1320,4360},
				{1470,4420},
				{1635,5055},
				{900,5140},
			},
		},
	},
	[1] = {
		nameLong = "East",
		nameShort = "E",
		startpoints = {
			{6144-1250,6144-4800},
		},
		boxes = {
			{
				{6144-800,6144-5030},
				{6144-1320,6144-4360},
				{6144-1470,6144-4420},
				{6144-1635,6144-5055},
				{6144-900,6144-5140},
			},
		},
	},
}

local teamsbox = {
	[0] = {
		nameLong = "West",
		nameShort = "W",
		startpoints = {
			{768,3072},
		},
		boxes = {
			{
				{0,0},
				{1536,0},
				{1536,6144},
				{0,6144},
			},
		},
	},
	[1] = {
		nameLong = "East",
		nameShort = "E",
		startpoints = {
			{6144-768,6144-3072},
		},
		boxes = {
			{
				{6144-0,6144-0},
				{6144-1536,6144-0},
				{6144-1536,6144-6144},
				{6144-0,6144-6144},
			},
		},
	},
}

if #Spring.GetTeamList() == 3 and #Spring.GetTeamList(0) == 1 and #Spring.GetTeamList(1) == 1 then
	return duelbox
end
return teamsbox
