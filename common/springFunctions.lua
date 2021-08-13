
local utilitiesDirectory = 'common/springUtilities/'

local tga = VFS.Include(utilitiesDirectory .. 'image_tga.lua')
local team = VFS.Include(utilitiesDirectory .. 'teamFunctions.lua')
local syncFunctions = VFS.Include(utilitiesDirectory .. 'synced.lua')

Spring.Utilities = {
	LoadTGA = tga.LoadTGA,
	SaveTGA = tga.SaveTGA,
	NewTGA = tga.NewTGA,

	MakeRealTable = syncFunctions.MakeRealTable,

	GetTeamCount = team.GetTeamCount,
	GetPlayerCount = team.GetPlayerCount,
	Gametype = team.Gametype,
}

VFS.Include('common/luaUtilities/json.lua')

local debugUtilities = VFS.Include(utilitiesDirectory .. 'debug.lua')

Spring.Debug = {
	ParamsEcho = debugUtilities.ParamsEcho,
	TableEcho = debugUtilities.TableEcho,
}
