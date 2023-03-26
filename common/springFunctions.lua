local utilitiesDirectory = 'common/springUtilities/'

local tga = VFS.Include(utilitiesDirectory .. 'image_tga.lua')
local team = VFS.Include(utilitiesDirectory .. 'teamFunctions.lua')
local syncFunctions = VFS.Include(utilitiesDirectory .. 'synced.lua')
local tableFunctions = VFS.Include(utilitiesDirectory .. 'tableFunctions.lua')

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
	
	-- Compares engine version to see if it is at least --e.g. 105.1.1-1392-g5fb0c97 BAR105
	EngineVersionAtLeast = function (major,medor,minor,build)
		-- split along dots
		local v = Engine.versionFull
		local dotsplit = string.split(Engine.versionFull,'.')
		local dashsplit = string.split(dotsplit[3],'-')
		local mymajor = tonumber(dotsplit[1]) --tonumber(string.sub(v, 1, string.find(v, '.',nil, true) -1))
		local mymedor = tonumber(dotsplit[2])
		local myminor = tonumber(dashsplit[1]) 
		local mybuild = tonumber(dashsplit[2])
		if major > mymajor 
			then return true 
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
		return false
	end,

	CustomKeyToUsefulTable = tableFunctions.CustomKeyToUsefulTable,
}

local debugUtilities = VFS.Include(utilitiesDirectory .. 'debug.lua')

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
