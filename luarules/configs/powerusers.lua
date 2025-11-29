local everything = {
	give = true,
	undo = true,
	cmd = true,
	devhelpers = true,
	playerdata = true,
	waterlevel = true,
	sysinfo = true,
}
local moderator = {
	give = false,
	undo = true,
	cmd = false,
	devhelpers = false,
	playerdata = false,
	waterlevel = false,
	sysinfo = true,
}
local singleplayer = {		-- note: these permissions override others when singleplayer
	give = true,
	undo = true,
	cmd = true,
	devhelpers = true,
	waterlevel = true,
	playerdata = true,
	sysinfo = false,
}

return {
	[-1] = singleplayer,		-- SPECIAL NAME/ADDITION: dont change it

	[112] = everything,		-- [teh]Flow
	[4430] = everything,	-- Floris
	[2585] = everything,	-- IceXuick
	[1214] = everything,	-- [teh]Beherith
	[1172] = everything,	-- PtaQ
	[2260] = everything,	-- TarnishedKnight
	[84658] = everything,	-- OPman
	[51535] = everything,	-- Nightmare2512

	[3133] = moderator,		-- Lexon
	[258984] = moderator,	-- ScavengersOffenseAI
	[22297] = moderator,	-- Shadhunter
	[125301] = moderator,	-- DeviousNull
	[2401] = moderator,		-- Fire[Z]torm_
	[128743] = moderator,	-- Pooman
	[36669] = moderator,	-- Steel
	[57869] = moderator,	-- [BAC]SnekVonPess
	[21114] = moderator,	-- [FH]Amojini
	[168817] = moderator,	-- SongbirdOfChirping
	[57158] = moderator,	-- Endorphins
	[132545] = moderator,	-- Praedyth
	[88808] = moderator,	-- Shadowisperke
}
