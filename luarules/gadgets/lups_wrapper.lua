-- $Id: lups_wrapper.lua 3171 2008-11-06 09:06:29Z det $
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
--
--  file:    lups.lua
--  brief:   Lups (Lua Particle System) Gadget Wrapper
--  authors: jK
--  last updated: 07 Nov. 2007
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  VFS.Include("lups/lups.lua",nil,VFS.ZIP_ONLY)
end