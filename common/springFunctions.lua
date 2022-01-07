local utilitiesDirectory = 'common/springUtilities/'

local tga = VFS.Include(utilitiesDirectory .. 'image_tga.lua')
local team = VFS.Include(utilitiesDirectory .. 'teamFunctions.lua')
local syncFunctions = VFS.Include(utilitiesDirectory .. 'synced.lua')

local utilities = {
	LoadTGA = tga.LoadTGA,
	SaveTGA = tga.SaveTGA,
	NewTGA = tga.NewTGA,

	MakeRealTable = syncFunctions.MakeRealTable,

	GetTeamCount = team.GetTeamCount,
	GetPlayerCount = team.GetPlayerCount,
	Gametype = team.Gametype,

	IsDevMode = function()
		local devMode = Spring.GetGameRulesParam('isDevMode')
		return (devMode and devMode > 0) and true or false
	end,

	ShowDevUI = function ()
		local devUI = Spring.GetConfigInt('DevUI', 0)
		return (devUI > 0) and true or false
	end,
}

local debugUtilities = VFS.Include(utilitiesDirectory .. 'debug.lua')

local debug = {
	ParamsEcho = debugUtilities.ParamsEcho,
	TableEcho = debugUtilities.TableEcho,
	TraceEcho = debugUtilities.TraceEcho,
}

return {
	Utilities = utilities,
	Debug = debug,
}