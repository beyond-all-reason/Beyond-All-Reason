
function skip()
	return Spring.GetGameFrame() <= 0
end

function scenario_arguments()
	return {{stressLevel = 1}, {attackerDef = "armpw"}, {targetDef = "armwin"}, {radarDef = "armarad"}}
end

function setup()
	-- test on quicksilver remake 1.24
	Test.clearMap()

	Spring.SetCameraTarget(Game.mapSizeX/2, 50, Game.mapSizeZ / 2 - 500, 0.5)
end

function synced_setup(locals)
	local function createUnitAt(unitdefname, x, z, teamID)
		local y = Spring.GetGroundHeight(x, z)
		return Spring.CreateUnit(unitdefname, x, y, z, 1, teamID)
	end

	local colattackers = 10
	local coltargets = 20
	local rowattackers = math.floor(locals.nattackers/colattackers)
	local rowtargets = math.floor(locals.ntargets/coltargets)
	local attackerDef = locals.attackerDef
	local targetDef = locals.targetDef

	local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	x = x+450

	local team1 = 0
	local team2 = 1
	local sep = 40
	local currunit
	local attackers = {}
	local targets = {}
	createUnitAt(locals.radarDef, x-1000, z+300, team1)
	for i=0, colattackers-1 do
		for j=0, rowattackers-1 do
			currunit = createUnitAt(attackerDef, x+i*sep, z-j*sep, team1)
			attackers[#attackers+1] = currunit
		end
	end

	for i=0, coltargets-1 do
		for j=0, rowtargets-1 do
			currunit = createUnitAt(targetDef, x-1500+i*sep, z-j*sep, team2)
			targets[#targets+1] = currunit
		end
	end
	-- make sure the attackers don't have other orders
	for _, unitID in pairs(attackers) do
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
	end

	return attackers, targets
end

function synced_commands(locals)
	local attackers = locals.attackers
	local targets = locals.targets
	local shiftOpts = {"shift"}
	local currOpt
	local CMD_ATTACK = CMD.ATTACK
	local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit

	local orders = {}
	for idx, targetID in pairs(targets) do
		currOpt = (idx == 1) and 0 or shiftOpts
		orders[#orders+1] = {CMD_ATTACK, {targetID}, currOpt}
	end

	for _, unitID in pairs(attackers) do
		currOpt = (idx == 1) and opts or shiftOpts
		spGiveOrderArrayToUnit(unitID, orders)
	end
end

function test()
	local t0 = os.clock()

	local nattackers = 100*Scenario.stressLevel
	local ntargets = 100*Scenario.stressLevel
	local attackerDef = Scenario.attackerDef
	local targetDef = Scenario.targetDef
	local radarDef = Scenario.radarDef

	local attackers, targets = SyncedRun(synced_setup)

	Test.waitFrames(1)

	SyncedRun(synced_commands)

	Spring.Echo("total time:", os.clock()-t0)
end

