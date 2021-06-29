if not scavconfig.modules.factoryControllerModule then
	return {
		BuildUnit = function() end,
		CheckNewUnit = function() end,
	}
end

local factoryUnitList = VFS.Include("luarules/gadgets/scavengers/Configs/" .. Game.gameShortName .. "/UnitLists/factories.lua")

local function buildUnit(unitID, unitDefID)
	if not scavFactory[unitID] or #Spring.GetFullBuildQueue(unitID, 0) > 0 then
		return
	end

	local buildOptions = UnitDefs[unitDefID].buildOptions
	local buildUnit = buildOptions[math_random(1, #buildOptions)]
	local buildRange = UnitDefs[unitDefID].buildDistance or 0

	local x, y, z = Spring.GetUnitPosition(unitID)
	local buildVariance = (buildRange + 1) * 0.50
	local posx = x + math_random(-buildVariance, buildVariance)
	local posz = z + math_random(-buildVariance, buildVariance)
	local posy = Spring.GetGroundHeight(posx, posz)

	Spring.GiveOrderToUnit(unitID, -buildUnit, {posx, posy, posz, 0}, 0)
end

local function checkNewUnit(unitID, unitDefID)
	local unitName = UnitDefs[unitDefID].name
	for i = 1, #factoryUnitList.Factories do
		if string.sub(unitName, 1, string.len(unitName) - UnitSuffixLenght[unitID]) == factoryUnitList.Factories[i] then
			scavFactory[unitID] = true
		end
	end
end

return {
	BuildUnit = buildUnit,
	CheckNewUnit = checkNewUnit,
}