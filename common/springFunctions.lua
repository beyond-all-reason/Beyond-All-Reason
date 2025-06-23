local utilitiesDirectory = 'common/springUtilities/'

local tga = VFS.Include(utilitiesDirectory .. 'image_tga.lua')
local team = VFS.Include(utilitiesDirectory .. 'teamFunctions.lua')
local syncFunctions = VFS.Include(utilitiesDirectory .. 'synced.lua')
local tableFunctions = VFS.Include(utilitiesDirectory .. 'tableFunctions.lua')
local colorFunctions = VFS.Include(utilitiesDirectory .. 'color.lua')

local utilities = {
	LoadTGA = tga.LoadTGA,
	SaveTGA = tga.SaveTGA,
	NewTGA = tga.NewTGA,

	MakeRealTable = syncFunctions.MakeRealTable,

	GetAllyTeamCount = team.GetAllyTeamCount,
	GetAllyTeamList = team.GetAllyTeamList,
	GetPlayerCount = team.GetPlayerCount,
	Gametype = team.Gametype,
	GetScavAllyTeamID = team.GetScavAllyTeamID,
	GetRaptorTeamID = team.GetRaptorTeamID,
	GetScavTeamID = team.GetScavTeamID,
	GetRaptorAllyTeamID = team.GetRaptorAllyTeamID,

	IsDevMode = function()
		local devMode = Spring.GetGameRulesParam('isDevMode')
		return (devMode and devMode > 0) and true or false
	end,

	ShowDevUI = function ()
		local devUI = Spring.GetConfigInt('DevUI', 0)
		return (devUI > 0) and true or false
	end,

	CustomKeyToUsefulTable = tableFunctions.CustomKeyToUsefulTable,

	Color = colorFunctions,
}

local debugUtilities = VFS.Include(utilitiesDirectory .. 'debug.lua')

local debugFuncs = {
	ParamsEcho = debugUtilities.ParamsEcho,
	TraceEcho = debugUtilities.TraceEcho,
	TraceFullEcho = debugUtilities.TraceFullEcho,
}

return {
	Utilities = utilities,
	Debug = debugFuncs,
}
