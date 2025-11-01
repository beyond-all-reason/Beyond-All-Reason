local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")
local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")
local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")

local TeamTransfer = {}

TeamTransfer.Resources = ResourceShared
TeamTransfer.Units = UnitShared

return TeamTransfer
