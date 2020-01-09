VFS.Include("luarules/gadgets/scavengers/Configs/"..GameShortName.."/UnitLists/factories.lua")

function FactoryProduction(n, scav, scavDef)
local buildOptions = UnitDefs[scavDef].buildOptions
local x,y,z = Spring.GetUnitPosition(scav)
Spring.GiveOrderToUnit(scav, -buildOptions[math.random(1,#buildOptions)], {x, y, z, 0}, {"shift"})
end