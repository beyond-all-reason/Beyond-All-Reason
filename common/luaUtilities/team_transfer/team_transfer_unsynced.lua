local SharedEnums = VFS.Include("common/luaUtilities/team_transfer/shared_enums.lua")
local UnitShared = VFS.Include("common/luaUtilities/team_transfer/unit_transfer_shared.lua")
local ResourceShared = VFS.Include("common/luaUtilities/team_transfer/resource_transfer_shared.lua")

local TeamTransfer = {}

TeamTransfer.Units = UnitShared
TeamTransfer.Resources = ResourceShared

return TeamTransfer
