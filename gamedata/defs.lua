--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    defs.lua
--  brief:   entry point for unitdefs, featuredefs, and weapondefs parsing
--  author:  Dave Rodgers
--  notes:   Spring.GetModOptions() is available
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

VFS.Include('init.lua')

DEFS = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local section='defs.lua'

VFS_MODES = VFS.MAP .. VFS.MOD .. VFS.BASE

local function LoadDefs(name)
	local filename = 'gamedata/' .. name .. '.lua'
	local success, result = pcall(VFS.Include, filename, nil, VFS_MODES)

	if (not success) then
		Spring.Log(section, LOG.ERROR, 'Failed to load ' .. name)
		error(result)
	end

	if (result == nil) then
		error('Missing lua table for ' .. name)
	end

	return result
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

Spring.TimeCheck('Loading all definitions: ', function()
	DEFS.unitDefs    = LoadDefs('unitDefs')
	DEFS.featureDefs = LoadDefs('featureDefs')
	DEFS.weaponDefs  = LoadDefs('weaponDefs')
	DEFS.armorDefs   = LoadDefs('armorDefs')
	DEFS.moveDefs    = LoadDefs('moveDefs')
end)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  NOTE: the keys have to be lower case
--

return {
	unitdefs    = DEFS.unitDefs,
	featuredefs = DEFS.featureDefs,
	weapondefs  = DEFS.weaponDefs,
	armordefs   = DEFS.armorDefs,
	movedefs    = DEFS.moveDefs,
}
