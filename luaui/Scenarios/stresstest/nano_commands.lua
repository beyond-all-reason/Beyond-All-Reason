
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
	local turrets = {}
	for i=0, colturrets-1 do
		for j=0, rowturrets-1 do
			currunit = createUnitAt(turretDef, x+i*sep-100, z-j*sep, team1)
			turrets[#turrets+1] = currunit
		end
	end

	for i=0, coltargets-1 do
		for j=0, rowtargets-1 do
			createUnitAt(targetDef, x+350+i*sep, z-j*sep, team1)
		end
	end
	-- make sure the turrets don't have other orders
	for _, unitID in pairs(turrets) do
		Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
	end
end

function run_nano_commands(nturrets, ntargets, turretDef, targetDef)
	if type(nturrets) == 'table' then
		local locals = nturrets
		ntargets = locals.ntargets
		turretDef = locals.turretDef
		targetDef = locals.targetDef
		nturrets = locals.nturrets
	end
	local shiftOpts = {"shift"}
	local currOpt
	local CMD_RECLAIM = CMD.RECLAIM
	local spGiveOrderToUnit = Spring.GiveOrderToUnit

	-- get units
	local spGetUnitDefID = Spring.GetUnitDefID

	local turrets = table.new and table.new(nturrets) or {}
	local targets = table.new and table.new(ntargets) or {}
	local turretDefID = UnitDefNames[turretDef].id
	local targetDefID = UnitDefNames[targetDef].id

	local all_units = Spring.GetAllUnits()
	for _, unitID in ipairs(all_units) do
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID == turretDefID then
			turrets[#turrets+1] = unitID
		elseif unitDefID == targetDefID then
			targets[#targets+1] = unitID
		end
	end

	-- give orders
	local arr = {}
	for _, unitID in pairs(turrets) do
		for idx, targetID in pairs(targets) do
			currOpt = (idx == 1) and opts or shiftOpts
			arr[1] = targetID
			spGiveOrderToUnit(unitID, CMD_RECLAIM, arr, currOpt)
		end
	end
end

function test()
	local t0 = os.clock()

	local nturrets = 50*Scenario.stressLevel
	local ntargets = 50*Scenario.stressLevel
	local turretDef = Scenario.builderDef
	local targetDef = Scenario.targetDef

	SyncedRun(synced_nano_setup)
	Spring.Echo("init time preinit:", os.clock()-t0)

	Test.waitFrames(1)

	SyncedRun(run_nano_commands)

	Spring.Echo("total time:", os.clock()-t0)
end


