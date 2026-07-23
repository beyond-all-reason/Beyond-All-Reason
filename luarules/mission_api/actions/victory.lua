local Types = GG['MissionAPI'].Modules.ParameterTypes.Types

local function victory(winningAllyTeamIDs)
	Spring.GameOver({ unpack(winningAllyTeamIDs) })
end

return {
	type = 'Victory',
	parameters = {
		{ name = 'allyTeamIDs', required = true, type = Types.AllyTeamIDs },
	},
	actionFunction = victory,
}
