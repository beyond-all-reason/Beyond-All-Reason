local center = {Game.mapSizeX / 2, Game.mapSizeZ / 2}
local radius = 2340
local teams = Spring.Utilities.GetTeamCount()
local slice = 2 * math.pi / teams

local layout = {}
for i = 1, teams do
	layout[i-1] = {
		boxes = {
			{
				{center[1], center[2]}
			}
		},
	}
	for j = 0, 10 do
		layout[i-1].boxes[1][j+2] = {
			center[1] + radius * math.sin((i-(j * 0.1)) * slice),
			center[2] + radius * math.cos((i-(j * 0.1)) * slice)
		}
	end
	layout[i-1].startpoints = {{
		center[1] + radius * math.sin((i-0.5) * slice) * 0.5,
		center[2] + radius * math.cos((i-0.5) * slice) * 0.5
	}}
end

local supported_teams = {}
for i = 1, 16 do supported_teams[i] = i end

return layout, supported_teams
