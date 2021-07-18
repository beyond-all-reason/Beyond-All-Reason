local unitName = "lootboxnano_t3_var4"

local nanoDefCreator= VFS.Include("unitbasedefs/lootboxes/lootboxnano.lua")
local tiers = nanoDefCreator.Tiers
local unitDef = nanoDefCreator.CreateNanoUnitDef(tiers.T3)

return lowerkeys({ [unitName] = unitDef })