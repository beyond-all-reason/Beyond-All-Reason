local ResourceShared = VFS.Include("modules/transfer/resource/shared.lua")
local UnitShared = VFS.Include("modules/transfer/unit/shared.lua")
local UnitUnsynced = VFS.Include("modules/transfer/unit/unsynced.lua")

local TransferUnsynced = {}

TransferUnsynced.Resources = ResourceShared
TransferUnsynced.Units = UnitShared
TransferUnsynced.Units.ShareUnits = UnitUnsynced.ShareUnits

return TransferUnsynced
