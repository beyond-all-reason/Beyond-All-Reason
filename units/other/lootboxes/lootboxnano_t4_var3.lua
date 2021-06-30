local unitName = "lootboxnano_t4_var3"

local nanoDefCreator= VFS.Include("unitbasedefs/lootboxes/lootboxnano.lua")
local tiers = nanoDefCreator.Tiers
local unitDef = nanoDefCreator.CreateNanoUnitDef(tiers.T4)

return lowerkeys({ [unitName] = unitDef })