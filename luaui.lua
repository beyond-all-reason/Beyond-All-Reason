--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    luaui.lua
--  brief:   entry point for LuaUI
--  author:  Dave Rodgers
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

LUAUI_VERSION = "LuaUI v0.3"
LUAUI_DIRNAME = 'LuaUI/'
VFS.DEF_MODE = VFS.RAW_FIRST
local STARTUP_FILENAME = LUAUI_DIRNAME .. 'main.lua'


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

do
  -- use a versionned directory name if it exists
  local sansslash = string.sub(LUAUI_DIRNAME, 1, -2)
  local versiondir = sansslash .. '-' .. ((Game and Game.version) or (Engine and Engine.version) or "Engine version error") .. '/'
  if (VFS.FileExists(versiondir  .. 'main.lua', VFS.ZIP)) then
    LUAUI_DIRNAME = versiondir
  end
end

Spring.Echo('Using LUAUI_DIRNAME = ' .. LUAUI_DIRNAME)


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- load the user's UI
--

do
  local text = VFS.LoadFile(STARTUP_FILENAME, VFS.ZIP)
  if (text == nil) then
    Script.Kill('Failed to load ' .. STARTUP_FILENAME)
  end
  local chunk, err = loadstring(text)
  if (chunk == nil) then
    Script.Kill('Failed to load ' .. STARTUP_FILENAME .. ' (' .. err .. ')')
  else
    chunk()
    return
  end
end


-------------------------------------------------------------------------------- 
-------------------------------------------------------------------------------- 
