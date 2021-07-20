
local utilitiesDirectory = 'common/Utilities/'

local base64 = VFS.Include(utilitiesDirectory .. 'base64.lua')
local tga = VFS.Include(utilitiesDirectory .. 'image_tga.lua')
local table = VFS.Include(utilitiesDirectory .. 'tablefunctions.lua')
local team = VFS.Include(utilitiesDirectory .. 'teamFunctions.lua')

Spring.Utilities = {
	Base64Encode = base64.Base64Encode,
	Base64Decode = base64.Base64Decode,

	LoadTGA = tga.LoadTGA,
	SaveTGA = tga.SaveTGA,
	NewTGA = tga.NewTGA,

	CopyTable = table.CopyTable,
	MergeTable = table.MergeTable,
	OverwriteTableInplace = table.OverwriteTableInplace,
	MergeWithDefault = table.MergeWithDefault,
	TableToString = table.TableToString,
	MakeRealTable = table.MakeRealTable,
	TableEcho = table.TableEcho,
	ExplodeString = table.ExplodeString,

	GetTeamCount = team.GetTeamCount,
	GetPlayerCount = team.GetPlayerCount,
	Gametype = team.Gametype,
}

VFS.Include(utilitiesDirectory .. 'json.lua')
