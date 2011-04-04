-- $Id: lups_wrapper.lua 3171 2008-11-06 09:06:29Z det $
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
--
--  file:    lups_wrapper.lua
--  brief:   Lups (Lua Particle System) Widget Wrapper
--  authors: jK
--  last updated: 10 Nov. 2007
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

VFS.Include("lups/lups.lua")

--// auto install lups.cfg
if VFS.FileExists("lups/lups.cfg",VFS.ZIP) then
  local newFile = VFS.LoadFile("lups/lups.cfg",VFS.ZIP);

  if (not VFS.FileExists("lups.cfg",VFS.RAW_ONLY)) then
    local f=io.open("lups.cfg",'w+');
    if (f) then
      f:write(newFile);
    end
    f:close();
  end
end