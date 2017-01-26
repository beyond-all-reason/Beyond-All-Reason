-- $Id: loadConfig.lua 3171 2008-11-06 09:06:29Z det $
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
--
--  file:    loadConfig.lua
--  brief:   loads LUPS config files
--  authors: jK
--  last updated: Feb. 2008
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

function LoadConfig(configFile)
  if (VFS.FileExists(configFile)) then
    local fileStr = VFS.LoadFile(configFile):gsub("//","--")
    local func, message = loadstring(fileStr)
    if not func then print(PRIO_MAJOR,"LUPS: Can't parse config! Error is:\n" .. message) end

    local env = {}
    setfenv(func, env)

    --// fill the env table with user config
    local success = pcall(func)

    if success then
      local res = {}
      for i,v in pairs(env) do
        if (type(v)~="function") then 
          res[i:lower()] = v
        end
      end
      return res
    end
  end
  return {}
end