
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

	local doCircle = locals.doCircle
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
	local circle
	if doCircle then
		-- when circle requested just return the targets center and radius
		local maxX = (coltargets*sep)/2.0
		local maxZ = (rowtargets*sep)/2.0
		local targetsCenter = {x-1500+maxX, z-maxZ}
		local radius = math.sqrt(maxX*maxX + maxZ*maxZ)
		circle = {targetsCenter[1], targetsCenter[2], radius}
	end

	createUnitAt(locals.radarDef, x-1000, z+300, team1)

	for i=0, colattackers-1 do
		for j=0, rowattackers-1 do
			currunit = createUnitAt(attackerDef, x+i*sep, z-j*sep, team1)
			attackers[#attackers+1] = currunit
		end
	end

	for i=0, coltargets-1 do
		for j=0, rowtargets-1 do
			createUnitAt(targetDef, x-1500+i*sep, z-j*sep, team2)
		end
	end
	-- make sure the attackers don't have other orders
	for _, unitID in pairs(attackers) do
		Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
	end
	return circle
end

function run_commands(nattackers, ntargets, attackerDef, targetDef)
	if type(nattackers) == 'table' then
		-- comes from SyncedRun
		locals = nattackers
		ntargets = locals.ntargets
		attackerDef = locals.attackerDef
		targetDef = locals.targetDef
		nattackers = locals.nattackers
	end
	local shiftOpts = {"shift"}
	local currOpt
	local CMD_ATTACK = CMD.ATTACK
	local spGiveOrderToUnit = Spring.GiveOrderToUnit
	local attackerTeam = 0
	local defenderTeam = 1

	-- get units
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitTeam = Spring.GetUnitTeam

	local attackers = table.new and table.new(nattackers) or {}
	local targets = table.new and table.new(ntargets) or {}
	local attackerDefID = UnitDefNames[attackerDef].id
	local targetDefID = UnitDefNames[targetDef].id

	local all_units = Spring.GetAllUnits()
	for _, unitID in ipairs(all_units) do
		local unitDefID = spGetUnitDefID(unitID)
		local unitTeamID = spGetUnitTeam(unitID)
		if unitDefID == attackerDefID and unitTeamID == attackerTeam then
			attackers[#attackers+1] = unitID
		elseif unitDefID == targetDefID and unitTeamID == defenderTeam then
			targets[#targets+1] = unitID
		end
	end

	-- give orders
	local arr = {}
	for _, unitID in pairs(attackers) do
		for idx, targetID in pairs(targets) do
			currOpt = (idx == 1) and opts or shiftOpts
			arr[1] = targetID
			spGiveOrderToUnit(unitID, CMD_ATTACK, arr, currOpt)
		end
	end
end

function test()
	local t0 = os.clock()

	local nattackers = 100*Scenario.stressLevel
	local ntargets = 100*Scenario.stressLevel
	local attackerDef = Scenario.attackerDef
	local targetDef = Scenario.targetDef
	local radarDef = Scenario.radarDef

	SyncedRun(synced_setup)
	Spring.Echo("init time preinit:", os.clock()-t0)

	Test.waitFrames(1)

	SyncedRun(run_commands)

	Spring.Echo("total time:", os.clock()-t0)
end

