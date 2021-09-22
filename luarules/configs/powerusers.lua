local everything = {
	give = true,
	undo = true,
	cmd = true,
	devhelpers = true,
	playerdata = true,
	waterlevel = true,
}
local moderator = {
	give = false,
	undo = true,
	cmd = false,
	devhelpers = false,
	playerdata = false,
	waterlevel = false,
}

return {
	['[teh]Flow'] = everything,
	['IceXuick'] = everything,
	['[teh]Beherith'] = everything,
	['PtaQ'] = everything,

	['Teifion'] = moderator,
	['[Fx]Jazcash'] = moderator,
	['Damgam98'] = moderator,
	['[Z]ecrus'] = moderator,
	['Fire[Z]torm_'] = moderator,
	['Flaka'] = moderator,
	['WatchTheFort'] = moderator,
}
