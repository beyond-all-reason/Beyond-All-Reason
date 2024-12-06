
function skip()
	return Spring.GetGameFrame() <= 0
end

function scenario_arguments()
	return {{stressLevel = 1}, {builderDef = "armnanotc"}, {targetDef = "armwin"}}
end

function setup()
	-- test on quicksilver remake 1.24
	Test.clearMap()

	Spring.SetCameraTarget(Game.mapSizeX/2 + 500, 50, Game.mapSizeZ / 2 - 500, 0.5)
end

function synced_nano_setup(locals)
	local function createUnitAt(unitdefname, x, z, teamID)
		local y = Spring.GetGroundHeight(x, z)
		return Spring.CreateUnit(unitdefname, x, y, z, 1, teamID)
	end

	local colturrets = 5
	local coltargets = 8
	local rowturrets = math.floor(locals.nturrets/colturrets)
	local rowtargets = math.floor(locals.ntargets/coltargets)
	local turretDef = locals.turretDef
	local targetDef = locals.targetDef

	local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	x = x+450

	local team1 = 0
	local sep = 50
	local currunit
	local nanoturrets = {}
	local targets = {}
	for i=0, colturrets-1 do
		for j=0, rowturrets-1 do
			currunit = createUnitAt(turretDef, x+i*sep-100, z-j*sep, team1)
			nanoturrets[#nanoturrets+1] = currunit
		end
	end

	for i=0, coltargets-1 do
		for j=0, rowtargets-1 do
			currunit = createUnitAt(targetDef, x+350+i*sep, z-j*sep, team1)
			targets[#targets+1] = currunit
		end
	end
	-- make sure the turrets don't have other orders
	for _, unitID in pairs(nanoturrets) do
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
	end

	return nanoturrets, targets
end

function synced_nano_commands(locals)
	local nanoturrets = locals.nanoturrets
	local targets = locals.targets
	local shiftOpts = {"shift"}
	local currOpt
	local CMD_RECLAIM = CMD.RECLAIM
	local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit

	local orders = {}
	for idx, targetID in pairs(targets) do
		currOpt = (idx == 1) and 0 or shiftOpts
		orders[#orders+1] = {CMD_RECLAIM, {targetID}, currOpt}
	end

	for _, unitID in pairs(nanoturrets) do
		spGiveOrderArrayToUnit(unitID, orders)
	end
end

function test()
	local t0 = os.clock()

	local nturrets = 50*Scenario.stressLevel
	local ntargets = 50*Scenario.stressLevel
	local turretDef = Scenario.builderDef
	local targetDef = Scenario.targetDef

	local nanoturrets, targets = SyncedRun(synced_nano_setup)

	Test.waitFrames(1)

	SyncedRun(synced_nano_commands)

	Spring.Echo("total time:", os.clock()-t0)
end

