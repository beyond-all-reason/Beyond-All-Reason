
local utilitiesDirectory = 'common/springUtilities/'

local tga = VFS.Include(utilitiesDirectory .. 'image_tga.lua')
local table = VFS.Include('common/tablefunctions.lua')
local team = VFS.Include(utilitiesDirectory .. 'teamFunctions.lua')

Spring.Utilities = {
	LoadTGA = tga.LoadTGA,
	SaveTGA = tga.SaveTGA,
	NewTGA = tga.NewTGA,

	MakeRealTable = table.MakeRealTable,

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
