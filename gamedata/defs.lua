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

DEFS = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local section='defs.lua'

-- https://springrts.com/mantis/view.php?id=6088, remove this when no longer needed!
if not VFS.BASE then
  VFS.BASE = "b"
  VFS.MOD = "M"
  VFS.MAP = "m"
end

vfs_modes = VFS.MOD .. VFS.BASE
allow_map_mutators = (Spring.GetModOptions and tonumber(Spring.GetModOptions().allowmapmutators) or 1) ~= 0 
if allow_map_mutators then
  vfs_modes = VFS.MAP .. vfs_modes
end

local function LoadDefs(name)
  local filename = 'gamedata/' .. name .. '.lua'
  local success, result = pcall(VFS.Include, filename, nil, vfs_modes)
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

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
