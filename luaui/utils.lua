--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    utils.lua
--  brief:   utility routines
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (UtilsGuard) then
  return
end
UtilsGuard = true


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function Say(msg)
  Spring.SendCommands({'say ' .. msg})
end


function SendCommand(msg)
  Spring.SendCommands({msg})
end


--------------------------------------------------------------------------------
--
--  returns:  basename, dirname
--

function Basename(fullpath)
  local _,_,base = string.find(fullpath, "([^\\/:]*)$")
  local _,_,path = string.find(fullpath, "(.*[\\/:])[^\\/:]*$")
  if (path == nil) then path = "" end
  return base, path
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function include(filename, envTable)
  if (string.find(filename, '.h.lua', 1, true)) then
    filename = 'Headers/' .. filename
  end
  return VFS.Include(LUAUI_DIRNAME .. filename, envTable)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
