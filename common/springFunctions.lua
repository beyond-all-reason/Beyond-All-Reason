local utilitiesDirectory = 'common/springUtilities/'

local tga = VFS.Include(utilitiesDirectory .. 'image_tga.lua')
local team = VFS.Include(utilitiesDirectory .. 'teamFunctions.lua')
local syncFunctions = VFS.Include(utilitiesDirectory .. 'synced.lua')
local tableFunctions = VFS.Include(utilitiesDirectory .. 'tableFunctions.lua')
local debugUtilities = VFS.Include(utilitiesDirectory .. 'debug.lua')

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
	EngineVersionAtLeast = function(major, medor, minor, build)
		local engineVersion = Engine.versionFull
		local versionComponents = {}
		for component in string.gmatch(engineVersion, "%d+") do
			table.insert(versionComponents, tonumber(component))
		end
		if #versionComponents == 4 then
			local mymajor, mymedor, myminor, mybuild = unpack(versionComponents)
			if major > mymajor then
				return true
			elseif major == mymajor then
				if mymedor > medor then
					return true
				elseif mymedor == medor then
					if myminor > minor then
						return true
					elseif myminor == minor then
						if mybuild >= build then
							return true
						end
					end
				end
			end
		end
		return false
	end,
	CustomKeyToUsefulTable = tableFunctions.CustomKeyToUsefulTable,
}

local debugFuncs = {
	ParamsEcho = debugUtilities.ParamsEcho,
	TableEcho = debugUtilities.TableEcho,
	TraceEcho = debugUtilities.TraceEcho,
	TraceFullEcho = debugUtilities.TraceFullEcho,
}

return {
	Utilities = utilities,
	Debug = debugFuncs,
}
