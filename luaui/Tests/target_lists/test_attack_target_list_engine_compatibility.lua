---@diagnostic disable: need-check-nil

function setup()
	Test.clearMap()
end

function cleanup()
	Test.clearMap()
end

local function createUnits()
	local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local firstID = assert(Spring.CreateUnit("armfav", x, Spring.GetGroundHeight(x, z), z, 0, 0))
	local secondID = assert(Spring.CreateUnit("armfav", x + 100, Spring.GetGroundHeight(x + 100, z), z, 0, 0))
	return firstID, secondID
end

function test()
	local firstID, secondID = SyncedRun(createUnits)
	for _, unitID in ipairs({ firstID, secondID }) do
		-- Movement is registered globally; descriptions need no engine-specific field.
		local controllerIndex = assert(Spring.FindUnitCmdDesc(unitID, GameCMD.ATTACK_TARGETS))
		local controllerDescription = Spring.GetUnitCmdDescs(unitID, controllerIndex, controllerIndex)[1]
		assertEqual(controllerDescription.id, GameCMD.ATTACK_TARGETS)
		assertEqual(controllerDescription.moveCommand, nil, "controller description has no movement flag")
	end
end

return {
	setup = setup,
	test = test,
	cleanup = cleanup,
}
