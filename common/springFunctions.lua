local utilitiesDirectory = 'common/springUtilities/'

local tga = VFS.Include(utilitiesDirectory .. 'image_tga.lua')
local team = VFS.Include(utilitiesDirectory .. 'teamFunctions.lua')
local syncFunctions = VFS.Include(utilitiesDirectory .. 'synced.lua')
local tableFunctions = VFS.Include(utilitiesDirectory .. 'tableFunctions.lua')
local colorFunctions = VFS.Include(utilitiesDirectory .. 'color.lua')
local safeLuaTableParser = VFS.Include(utilitiesDirectory .. 'safeluaparser.lua')

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

	--- Cached variant of IsDevMode, refreshed per call but avoids repeated lookups
	--- within the same frame when multiple widgets query it.
	_devModeCache = nil,
	_devModeCacheFrame = -1,
	IsDevModeCached = function()
		local frame = Spring.GetGameFrame()
		if frame ~= utilities._devModeCacheFrame then
			local devMode = Spring.GetGameRulesParam('isDevMode')
			utilities._devModeCache = (devMode and devMode > 0) and true or false
			utilities._devModeCacheFrame = frame
		end
		return utilities._devModeCache
	end,

	CustomKeyToUsefulTable = tableFunctions.CustomKeyToUsefulTable,
	SafeLuaTableParser = safeLuaTableParser.SafeLuaTableParser,

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
