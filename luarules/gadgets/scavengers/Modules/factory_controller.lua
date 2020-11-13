VFS.Include("luarules/gadgets/scavengers/Configs/"..GameShortName.."/UnitLists/factories.lua")

function FactoryProduction(n, scav, scavDef)
	local buildOptions = UnitDefs[scavDef].buildOptions
	local buildUnit = buildOptions[math_random(1,#buildOptions)]
	local buildName = UnitDefs[buildUnit].name
	isExcluded = {}
	for i = 1,#FactoriesExcludedUnits do
		if string.find(buildName..scavconfig.unitnamesuffix, FactoriesExcludedUnits[i]) then
			isExcluded[scavDef] = true
		end
	end
	if not isExcluded[scavDef] then
		local range = UnitDefs[scavDef].buildDistance or 0
		local x,y,z = Spring.GetUnitPosition(scav)
		local posx = x+math_random(-((range+1)*0.50),(range+1)*0.50)
		local posz = z+math_random(-((range+1)*0.50),(range+1)*0.50)
		local posy = Spring.GetGroundHeight(posx, posz)
		--local a = math_random(3,10)
		--for a = 1,a do
			Spring.GiveOrderToUnit(scav, -buildUnit, {posx, posy, posz, 0}, 0)
		--end
	end
	isExcluded[scavDef] = nil
end
