local ResourceShared = VFS.Include("modules/sharing/resource/shared.lua")
local UnitShared = VFS.Include("modules/sharing/unit/shared.lua")
local UnitUnsynced = VFS.Include("modules/sharing/unit/unsynced.lua")

local SharingUnsynced = {}

SharingUnsynced.Resources = ResourceShared
SharingUnsynced.Units = UnitShared
SharingUnsynced.Units.ShareUnits = UnitUnsynced.ShareUnits

return SharingUnsynced
