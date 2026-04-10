local everything = {
	give = true,
	undo = true,
	cmd = true,
	devhelpers = true, -- catch-all for all dev helper commands
	-- granular devhelper sub-permissions (checked when devhelpers is false):
	-- devhelpers_units = true,	-- givecat, xpunits, destroyunits, removeunits, reclaimunits, transferunits, wreckunits, spawnceg, spawnunitexplosion, removeunitdef
	-- devhelpers_teams = true,	-- playertoteam, killteam
	-- devhelpers_terrain = true,	-- fightertest, globallos, clearwrecks, reducewrecks
	-- devhelpers_test = true,	-- desync
	playerdata = true,
	waterlevel = true,
	sysinfo = true,
	volcano = true,
}
local moderator = {
	give = false,
	undo = true,
	cmd = false,
	devhelpers = false,
	playerdata = false,
	waterlevel = false,
	sysinfo = true,
	volcano = true,
}
local eventmanager = {
	give = true,
	undo = true,
	cmd = false,
	devhelpers = false,
	devhelpers_units = true, -- givecat, xpunits, destroyunits, removeunits, reclaimunits, transferunits, wreckunits, spawnceg, spawnunitexplosion, removeunitdef
	devhelpers_teams = true, -- playertoteam, killteam
	playerdata = false,
	waterlevel = true,
	sysinfo = false,
	volcano = true,
}
local singleplayer = { -- note: these permissions override others when singleplayer
	give = true,
	undo = true,
	cmd = true,
	devhelpers = true,
	waterlevel = true,
	playerdata = true,
	sysinfo = false,
	volcano = true,
}

-- Trusted playernames as fallback when accountID is unavailable (-1) This occurs when joining an already running game.
-- Only applied when no accountID-based entry already exists for the player.
local trustedNames = {
	["[teh]Flow"] = everything,
	["Floris"] = everything,
	["PtaQ"] = everything,
}

return {
	trustedNames = trustedNames,
	[-1] = singleplayer, -- SPECIAL NAME/ADDITION: dont change it

	-- admins
	--[112] = everything,		-- [teh]Flow
	[4430] = everything, -- Floris
	[2585] = everything, -- IceXuick
	[1214] = everything, -- [teh]Beherith
	--[1172] = everything,	-- PtaQ
	[2260] = everything, -- TarnishedKnight
	[84658] = everything, -- OPman
	[51535] = everything, -- Nightmare2512
	[130329] = everything, -- SethDGamre
	[36669] = everything, -- Steel

	-- moderator
	[3133] = moderator, -- Lexon
	[258984] = moderator, -- ScavengersOffenseAI
	[22297] = moderator, -- Shadhunter
	[125301] = moderator, -- DeviousNull
	[128743] = moderator, -- Pooman
	[57869] = moderator, -- [BAC]SnekVonPess
	[21114] = moderator, -- [FH]Amojini
	[168817] = moderator, -- SongbirdOfChirping
	[57158] = moderator, -- Endorphins
	[88808] = moderator, -- Shadowisperke

	-- event manager
	[132545] = eventmanager, -- Praedyth (KOTH organizer)
	[136110] = eventmanager, -- TANKTOM (KOTH organizer)
	[78506] = eventmanager, -- Twig (KOTH organizer)
}
