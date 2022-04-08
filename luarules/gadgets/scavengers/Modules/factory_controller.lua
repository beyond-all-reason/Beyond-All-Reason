if not scavconfig.modules.factoryControllerModule then
	return {
		BuildUnit = function() end,
		CheckNewUnit = function() end,
	}
end

local function buildUnit(unitID, unitDefID)
	if not scavFactory[unitID] or #Spring.GetFullBuildQueue(unitID, 0) > 0 then
		return
	end

	local buildOptions = UnitDefs[unitDefID].buildOptions
	local unitToBuild = buildOptions[math.random(1, #buildOptions)]
	for i = 1,#factoryUnitList.FactoryBannedUnits do
		if unitToBuild == UnitDefNames[factoryUnitList.FactoryBannedUnits[i]].id then
			return
		end
	end
	local buildRange = UnitDefs[unitDefID].buildDistance or 0

	local x, y, z = Spring.GetUnitPosition(unitID)
	local buildVariance = (buildRange + 1) * 0.50
	local posx = x + math.random(-buildVariance, buildVariance)
	local posz = z + math.random(-buildVariance, buildVariance)
	local posy = Spring.GetGroundHeight(posx, posz)

	Spring.GiveOrderToUnit(unitID, -unitToBuild, {posx, posy, posz, 0}, 0)
end

local function checkNewUnit(unitID, unitDefID)
	if factoryUnitList.FactoriesID[unitDefID] then
		scavFactory[unitID] = true
	end
end

return {
	BuildUnit = buildUnit,
	CheckNewUnit = checkNewUnit,
}