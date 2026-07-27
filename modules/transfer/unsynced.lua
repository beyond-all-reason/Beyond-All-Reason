local ResourceShared = VFS.Include("modules/transfer/resource/shared.lua")
local UnitShared = VFS.Include("modules/transfer/unit/shared.lua")
local UnitUnsynced = VFS.Include("modules/transfer/unit/unsynced.lua")

local SharingUnsynced = {}

SharingUnsynced.Resources = ResourceShared
SharingUnsynced.Units = UnitShared
SharingUnsynced.Units.ShareUnits = UnitUnsynced.ShareUnits

return SharingUnsynced
