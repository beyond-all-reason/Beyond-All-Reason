-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
--
-- A collection of some useful functions 
--
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

Spring.Utilities = Spring.Utilities or {}

local SCRIPT_DIR = Script.GetName() .. '/'
local utilFiles = VFS.DirList(SCRIPT_DIR .. 'Utilities/', "*.lua")
for i=1,#utilFiles do
  VFS.Include(utilFiles[i])
end