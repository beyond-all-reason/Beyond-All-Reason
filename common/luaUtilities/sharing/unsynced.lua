local ResourceShared = VFS.Include("common/luaUtilities/sharing/resource_transfer_shared.lua")
local UnitShared = VFS.Include("common/luaUtilities/sharing/unit_transfer_shared.lua")
local UnitUnsynced = VFS.Include("common/luaUtilities/sharing/unit_transfer_unsynced.lua")

local SharingUnsynced = {}

SharingUnsynced.Resources = ResourceShared
SharingUnsynced.Units = UnitShared
SharingUnsynced.Units.ShareUnits = UnitUnsynced.ShareUnits

return SharingUnsynced
