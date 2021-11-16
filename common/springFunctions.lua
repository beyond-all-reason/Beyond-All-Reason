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

	IsDevMode = function()
		local devMode = Spring.GetGameRulesParam('isDevMode')
		return (devMode and devMode > 0) and true or false
	end
}

VFS.Include('common/luaUtilities/json.lua')

local debugUtilities = VFS.Include(utilitiesDirectory .. 'debug.lua')

Spring.Debug = {
	ParamsEcho = debugUtilities.ParamsEcho,
	TableEcho = debugUtilities.TableEcho,
}

if Spring.GetModOptions then
	local modOptions = Spring.GetModOptions()
	local modOptionsFile = VFS.Include('modoptions.lua')

	for _, modOption in ipairs(modOptionsFile) do
		local key = modOption.key

		if modOption.type ~= "section" then
			if modOptions[key] == nil then
				modOptions[key] = modOption.def
			end

			if (modOption.type == 'bool') and (type(modOptions[key]) ~= 'boolean') then
				local value = tonumber(modOptions[key])
				modOptions[key] = value == 1 and true or false
			end

			if modOption.type == 'number' then
				modOptions[key] = tonumber(modOptions[key])
			end
		end
	end

	Spring.GetModOptions = function ()
		-- Returning the table itself would allow callers to mutate the table
		-- Copying it ensures each caller gets its own copy
		return table.copy(modOptions)
	end
end
