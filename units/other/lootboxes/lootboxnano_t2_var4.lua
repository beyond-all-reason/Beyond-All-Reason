local unitName = "lootboxnano_t2_var4"

local nanoDefCreator= VFS.Include("unitbasedefs/lootboxes/lootboxnano.lua")
local tiers = nanoDefCreator.Tiers
local unitDef = nanoDefCreator.CreateNanoUnitDef(tiers.T2)

return lowerkeys({ [unitName] = unitDef })