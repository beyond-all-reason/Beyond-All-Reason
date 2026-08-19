local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Attack Target List Scenario",
		desc = "Recreates the Fatboy, Tick, and Sheldon formation from save 20260819_214357",
		author = "local test setup",
		layer = 1000000,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local units = {
	-- Player team: Sheldons
	{ "cormort", 687.921, 237.938, 2223.893, 0 },
	{ "cormort", 669.510, 228.387, 2204.495, 0 },
	{ "cormort", 685.108, 225.179, 2180.946, 0 },
	{ "cormort", 662.220, 225.105, 2171.320, 0 },
	{ "cormort", 698.160, 226.486, 2201.629, 0 },

	-- Enemy team: Fatboys
	{ "armfboy", 707.070, 224.542, 2649.709, 1 },
	{ "armfboy", 934.079, 220.462, 2902.515, 1 },
	{ "armfboy", 822.687, 220.551, 2791.332, 1 },
	{ "armfboy", 1138.442, 218.324, 3042.212, 1 },

	-- Enemy team: Ticks
	{ "armflea", 866.013, 221.709, 2611.074, 1 },
	{ "armflea", 718.753, 225.932, 2606.819, 1 },
	{ "armflea", 655.294, 243.879, 2625.215, 1 },
	{ "armflea", 989.432, 220.519, 2703.996, 1 },
	{ "armflea", 1012.585, 220.619, 2614.458, 1 },
	{ "armflea", 1157.433, 220.462, 2612.061, 1 },
	{ "armflea", 919.839, 220.635, 2708.947, 1 },
	{ "armflea", 1185.007, 220.441, 2715.322, 1 },
	{ "armflea", 1053.609, 220.462, 2706.715, 1 },
	{ "armflea", 1122.463, 220.422, 2717.727, 1 },
}

function gadget:GameFrame(frame)
	if frame ~= 1 then
		return
	end
	if Spring.GetModOptions().attacktargetlistscenario ~= true then
		gadgetHandler:RemoveGadget(self)
		return
	end

	-- Keep the normal commanders alive outside the captured camera view: BAR's
	-- commander-death game rule would otherwise immediately end this test match.
	for _, unit in ipairs(units) do
		local name, x, y, z, teamID = unpack(unit)
		local unitID = Spring.CreateUnit(name, x, y, z, "south", teamID)
		if unitID then
			Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, 0) -- hold fire
			Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0) -- hold position
		end
	end
	Spring.Echo("ATTACK_TARGET_LIST_SCENARIO_READY units=" .. #units)

	gadgetHandler:RemoveGadget(self)
end
