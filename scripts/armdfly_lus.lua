base, patch, link0, link1, link2, link3, link4, jets, jet2, jet1, leg6, leg5, leg4, leg3, leg2, leg1, wing2, wing1, flare = piece('base', 'patch', 'link0', 'link1', 'link2', 'link3', 'link4', 'jets', 'jet2', 'jet1', 'leg6', 'leg5', 'leg4', 'leg3', 'leg2', 'leg1', 'wing2', 'wing1', 'flare')
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
	local unitsToDetach = Spring.GetUnitIsTransporting(unitID) -- Get currently transported untits
	if full == true then -- Transport is full, do not attemps to load more units
		local cmd = Spring.GetUnitCommands(unitID, 1)
		if cmd[1] and cmd[1].id == CMD.LOAD_UNITS then
			Spring.GiveOrderToUnit(unitID, CMD.REMOVE, {CMD.LOAD_UNITS}, {"alt"})
		end
	end
	if #unitsToDetach and oldunitsToDetach then
		for ct, punitID in pairs(link) do -- Did one of the transported unit die ?
			if not Spring.ValidUnitID(punitID) then
				unitDied = true
				link[ct] = nil
				full = false -- we just unloaded one unit
			end
		end
		if (#unitsToDetach < oldunitsToDetach) and (not unitDied) then -- Is the current load < to the load 1 frame ago (= unload because unitdeath is filtered out)
			for ct, punitID in pairs (unitsToDetach) do -- force detach all other units aswell
				Spring.UnitDetach(punitID)
			end
			for ct, punitID in pairs(link) do
				if Spring.ValidUnitID(punitID) then
				-- Spring.SetUnitRulesParam(punitID, "IsTranported", "false")
				end
			end
			link = {} -- empty table, reposition links
			Move(link0, y_axis, 0, 5000)
			Move(link1, y_axis, 0, 5000)
			Move(link2, y_axis, 0, 5000)
			Move(link3, y_axis, 0, 5000)
			Move(link4, y_axis, 0, 5000)
			full = false
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
	StartThread(SmokeUnit, {base, patch, jets, link0, wing2, wing1})
	StartThread(WatchLoad)
	StartThread(MoveRate)
	Hide(flare)
	Move(link0, y_axis, 0, 5000)
	Move(link1, y_axis, 0, 5000)
	Move(link2, y_axis, 0, 5000)
	Move(link3, y_axis, 0, 5000)
	Move(link4, y_axis, 0, 5000)
	-- Turn(link1, 2, -math.pi/2)
	-- Turn(link2, 2, math.pi/2)
	-- Turn(link3, 2, math.pi/2)
	-- Turn(link4, 2, -math.pi/2)
	script.CloseWingsInstantly()
	link = {}
end

--This is unfortunately necessary due to the fact that the model is a 3do
function script.CloseWingsInstantly()
	Turn(jets, 1, math.rad(-90), 20)
end

function script.CloseWings()
	Turn(jets, 1, math.rad(-90), 1)
end

function script.OpenWingsPartially()
	Turn(jets, 1, math.rad(-45), 1)
	
end

function script.OpenWings()
	Turn(jets, 1, math.rad(0), 1)
end


function script.StartMoving()
   isMoving = true
end

function script.StopMoving()
   isMoving = false
end   

function MoveRate()
	while true do
		gravity = (Game.gravity)/900 -- -> elmos/(frame²)
		vx,vy,vz,vw = Spring.GetUnitVelocity(unitID)
		if vx < 0.5 and vx > -0.5 then vx = 0 end
		if vy < 0.5 and vy > -0.5 then vy = 0 end
		if vz < 0.5 and vz > -0.5 then vz = 0 end
		
		local dx, dy, dz = Spring.GetUnitDirection(unitID)
		local rx, ry, rz = Spring.GetUnitRotation(unitID)
		if isMoving and vx and vy and vz and vw and vx0 and vy0 and vz0 and vw0 then
			ax = (vx - vx0) + vx/200 -- elmos/frame²
			ay = (vy - vy0 + gravity) --> Always fighting gravity -> elmos/frame²
			az = (vz - vz0) + vz/200 --> elmos/frame²
			if (dx*vx + dz*vz) > 0 then
				aZu = math.sqrt(ax^2 + az^2) --> unit's Z axis
			else
				aZu = -math.sqrt(ax^2 + az^2) --> unit's Z axis
			end
		else
			ax = 0
			ay = 0
			az = 0
			aYu = 0
			aZu = 0
		end
			if aZu ~= 0 then
				angle = math.atan(ay/aZu) - math.pi/2 - rz
			else
				angle = -math.pi/2 - rz
			end
		Turn(jets, 1, angle,3)	
		vx0, vy0, vz0, vw0 = vx, vy, vz, vw
		Sleep(1)
	end
end


function script.QueryTransport ( passengerID )
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




local function RestoreAfterDelay()
	Sleep(2000)
end		

function script.AimFromWeapon(weaponID)
	--Spring.Echo("AimFromWeapon: FireWeapon")
	return base
end

function script.QueryWeapon(weaponID)
	--Spring.Echo("QueryWeapon: FireWeapon")
	return flare
end

function script.AimWeapon(weaponID, heading, pitch)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	StartThread(RestoreAfterDelay)
	--Spring.Echo("AimWeapon: FireWeapon")
	return true
end

function script.FireWeapon(weaponID)
	--Spring.Echo("FireWeapon: FireWeapon")
	--EmitSfx (firepoint1, 1024)
end

function script.Killed()
		Explode(base, SFX.EXPLODE_ON_HIT + SFX.SMOKE + SFX.FIRE + SFX.FALL + SFX.NO_HEATCLOUD)
		Explode(jets, SFX.SHATTER + SFX.NO_HEATCLOUD)
		Explode(patch, SFX.SHATTER + SFX.NO_HEATCLOUD)
		Explode(leg1, SFX.EXPLODE_ON_HIT + SFX.SMOKE + SFX.FIRE + SFX.FALL + SFX.NO_HEATCLOUD)
		Explode(leg3, SFX.EXPLODE_ON_HIT + SFX.SMOKE + SFX.FIRE + SFX.FALL + SFX.NO_HEATCLOUD)
		return 1   -- spawn ARMSTUMP_DEAD corpse / This is the equivalent of corpsetype = 1; in bos
end