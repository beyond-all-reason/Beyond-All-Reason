base, link0, link1, link2, link3, link4, arm1, arm2, arm3, arm4, thrust1, thrust2 = piece('base', 'link0', 'link1', 'link2', 'link3', 'link4', 'arm1', 'arm2', 'arm3', 'arm4', 'thrust1', 'thrust2')
local SIG_AIM = {}

-- state variables
isMoving = "isMoving"
terrainType = "terrainType"

function WatchLoad()
	while true do
	if surplus then -- Make sure there is no extra unit loaded, if there is one, unload it
		Spring.UnitDetach(surplus)
		surplus = nil
	end
	local unitsToDetach = Spring.GetUnitIsTransporting(unitID)
	if full == true then
		local cmd = Spring.GetUnitCommands(unitID, 1)
		if cmd[1] and cmd[1].id == CMD.LOAD_UNITS then
			Spring.GiveOrderToUnit(unitID, CMD.REMOVE, {CMD.LOAD_UNITS}, {"alt"})
		end
	end
	if #unitsToDetach and oldunitsToDetach then
		for ct, punitID in pairs(link) do
			if not Spring.ValidUnitID(punitID) then
				unitDied = true
				link[ct] = nil
				full = false -- we just unloaded one unit
			end
		end
		if (#unitsToDetach < oldunitsToDetach) and (not unitDied) then
			for ct, punitID in pairs (unitsToDetach) do
			Spring.UnitDetach(punitID)
			end
			for ct, punitID in pairs(link) do
				if Spring.ValidUnitID(punitID) then
				-- Spring.SetUnitRulesParam(punitID, "IsTranported", "false")
				end
			end
			link = {}
			Move(link0, y_axis, 0, 5000)
			Move(link1, y_axis, 0, 5000)
			Move(link2, y_axis, 0, 5000)
			Move(link3, y_axis, 0, 5000)
			Move(link4, y_axis, 0, 5000)
			full = false
			CloseHook()
		end
	end
	oldunitsToDetach = #unitsToDetach
	unitDied = nil
	Sleep(33)
	end
end

function SmokeUnit (smokePieces)
	local n = #smokePieces
	while (GetUnitValue(COB.BUILD_PERCENT_LEFT) ~= 0) do
		Sleep(1000)
	end
	while true do
		local health = GetUnitValue(COB.HEALTH)
		if (health <= 66) then -- only smoke if less then 2/3rd health left
			local x,y,z,dx,dy,dz = Spring.GetUnitPiecePosDir(unitID,smokePieces[math.random(1,n)])
			Spring.SpawnCEG("blacksmoke", x,y,z, dx, dy, dz)
		end
		Sleep(20*health + 200)
	end
end

function script.Create()
	StartThread(SmokeUnit, {base, thrust1, thrust2, arm1, arm2, arm3, arm4})
	StartThread(WatchLoad)
	Move(link0, y_axis, 0, 5000)
	Move(link1, y_axis, 0, 5000)
	Move(link2, y_axis, 0, 5000)
	Move(link3, y_axis, 0, 5000)
	Move(link4, y_axis, 0, 5000)
	-- Turn(link1, 2, -math.pi/2)
	-- Turn(link2, 2, math.pi/2)
	-- Turn(link3, 2, math.pi/2)
	-- Turn(link4, 2, -math.pi/2)
	link = {}
end

--This is unfortunately necessary due to the fact that the model is a 3do

function script.StartMoving()
   isMoving = true
end

function script.StopMoving()
   isMoving = false
end   

function OpenHook()
	Turn(arm1, 2, math.rad(50), 1)
	Turn(arm2, 2, math.rad(-50), 1)
	Turn(arm3, 2, math.rad(-50), 1)
	Turn(arm4, 2, math.rad(50), 1)
end

function CloseHook()
	Turn(arm1, 2, math.rad(0), 1)
	Turn(arm2, 2, math.rad(0), 1)
	Turn(arm3, 2, math.rad(0), 1)
	Turn(arm4, 2, math.rad(0), 1)
end

function script.QueryTransport ( passengerID )
	OpenHook()
	-- Spring.SetUnitRulesParam(passengerID, "IsTranported", "true")
	local fp = UnitDefs[Spring.GetUnitDefID(passengerID)].xsize
	local height = UnitDefs[Spring.GetUnitDefID(passengerID)].height
		if fp <= 4 then
			if not link[1] then
				link[1] = passengerID
				Move(link1, 2, -height + 4.5)
				return link1
			elseif not link[2] then
				link[2] = passengerID
				Move(link2, 2, -height+ 4.5)
				return link2
			elseif not link[3] then
				link[3] = passengerID
				Move(link3, 2, -height+ 4.5)
				return link3
			elseif not link[4] then
				link[4] = passengerID
				Move(link4, 2, -height+ 4.5)
				full = true
				return link4
			end
		elseif fp > 4 and (not link[1]) and (not link[2]) and not (link[3]) and not (link[4]) and (not link[0]) then
			link[0] = passengerID
			Move(link0, 2, -height)
			full = true
			return link0
		end
		if full == true then -- Transport is full, do not attemps to load more units
			local cmd = Spring.GetUnitCommands(unitID, 1)
			if cmd[1] and cmd[1].id == CMD.LOAD_UNITS then
				Spring.GiveOrderToUnit(unitID, CMD.REMOVE, {CMD.LOAD_UNITS}, {"alt"})
			end
		end
	surplus = passengerID
	return link0
end

function script.Killed()
		Explode(base, SFX.EXPLODE_ON_HIT + SFX.SMOKE + SFX.FIRE + SFX.FALL + SFX.NO_HEATCLOUD)
		Explode(thrust1, SFX.SHATTER + SFX.NO_HEATCLOUD)
		Explode(arm2, SFX.SHATTER + SFX.NO_HEATCLOUD)
		Explode(arm4, SFX.EXPLODE_ON_HIT + SFX.SMOKE + SFX.FIRE + SFX.FALL + SFX.NO_HEATCLOUD)
		Explode(arm1, SFX.EXPLODE_ON_HIT + SFX.SMOKE + SFX.FIRE + SFX.FALL + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end