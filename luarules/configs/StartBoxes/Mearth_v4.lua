local supported_playercounts = {}
for i = 1, 33 do
	supported_playercounts[i] = i
end

local starting_triples = {
	{2355,  4241, "Shire", "Shire"},
	{9471, 11572, "Mordor", "Mordor"},
	{4380, 11300, "Gondor", "Gondor"},
	{5371,  9235, "Rohan", "Rohan"},
	{5810,  5333, "Moria", "Moria"},
	{9323,   963, "Withered Heath", "WHeath"},
	{3853,  2024, "Evendim Hills", "EHills"},
	{9543, 14740, "Khand", "Khand"},
	{5844, 14307, "Umbar", "Umbar"},
	{8100,  5400, "Dol Guldur", "Guldur"},
	{7340,  2830, "Mirkwood", "Mirkwd"},
	{4590,  3909, "Fornost", "Frnst"},
	{2994,  6392, "Minhiriath", "Mnhrth"},
	{8897,  8244, "Brown Lands", "BrnLnd"},
	{6500,   936, "Forodwaith", "Frdwth"},
	{ 3652, 13781, "Bay of Belfalas", "Bay"},
	{ 1924,  9348, "The Great Sea", "Sea"},
}

local starting_doubles = {
	{  877,  2613, "Forlindon", "Frlndn"},
	{ 3035,  2935, "Annuminas", "Annmns"},
	{ 4437,  3102, "North Downs", "NDowns"},
	{ 5040,  1190, "Angmar", "Angmar"},
	{ 6742,  1986, "Carrock", "Carrck"},
	{ 8048,   625, "North Rhun", "N Rhun"},
	{10100,  3587, "South Rhun", "S Rhun"},
	{ 8676,  2295, "Esgaroth", "Esgrth"},
	{ 3853,  5120, "South Downs", "SDowns"},
	{ 7569, 15015, "Harad", "Harad"},
	{ 6925, 12297, "Ithilien", "Ithln"},
	{ 7679,  9694, "Dead Marshes", "DMarsh"},
	{ 2795, 10859, "Druwaith Iaur", "Druwth"},
	{ 6743,  8087, "Rauros", "Rauros"},
	{ 4288,  7649, "Enedwaith", "Endwth"},
	{ 8326,  6765, "Emyn Muil", "EmynMl"},
}

-- there are 17 triple starts and 16 double starts
-- for now, we only use doubles if there are not enough triples, but they could sustain <=16 matches on their own
-- if we do that, randomly pick either set (cannot rely on mapoption since MM has no customizability)
local teams = Spring.Utilities.GetTeamCount()
if teams > 17 then
	for i = 1, #starting_doubles do
		starting_triples [#starting_triples + 1] = starting_doubles[i]
	end
end

-- convert the above to boxes (256 radius circles)
local ret = {}
for i = 1, #starting_triples do
	ret[i-1] = {
		nameLong  = starting_triples[i][3],
		nameShort = starting_triples[i][4],
		startpoints = { { starting_triples[i][1], starting_triples[i][2] } },
		boxes = { { } },
	}
	for j = 1, 10 do
		ret[i-1].boxes[1][j] = {
			starting_triples[i][1] + 256 * math.sin(j * math.pi / 5),
			starting_triples[i][2] + 256 * math.cos(j * math.pi / 5),
		}
	end
end

return ret, supported_playercounts
