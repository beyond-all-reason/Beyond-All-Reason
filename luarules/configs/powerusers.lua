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
	playerdata = false,
	sysinfo = false,
}

return {
	['   '] = singleplayer,		-- SPECIAL NAME/ADDITION: dont change it

	['[teh]Flow'] = everything,
	['IceXuick'] = everything,
	['[teh]Beherith'] = everything,
	['PtaQ'] = everything,
	['TarnishedKnight'] = everything,
	['OPman'] = everything
}
