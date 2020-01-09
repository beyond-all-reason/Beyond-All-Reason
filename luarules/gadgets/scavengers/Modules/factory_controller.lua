VFS.Include("luarules/gadgets/scavengers/Configs/"..GameShortName.."/UnitLists/factories.lua")

function FactoryProduction(n, scav, scavDef)
	local buildOptions = UnitDefs[scavDef].buildOptions
	local buildUnit = buildOptions[math.random(1,#buildOptions)]
	local buildName = UnitDefs[buildUnit].name
	isExcluded = {}
	for i = 1,#FactoriesExcludedUnits do
		if string.find(buildName..scavconfig.unitnamesuffix, FactoriesExcludedUnits[i]) then
			isExcluded[scavDef] = true
		end
	end
	if not isExcluded[scavDef] then
		local x,y,z = Spring.GetUnitPosition(scav)
		Spring.GiveOrderToUnit(scav, -buildUnit, {x, y, z, 0}, {"shift"})
	end
	isExcluded[scavDef] = nil
end