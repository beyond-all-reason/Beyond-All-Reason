
function gadget:GetInfo()
	return {
		name		= "Tombstones",
		desc		= "Adds a tombstone next to commander wreck",
		author		= "Floris",
		date		= "December 2021",
		license		= "",
		layer		= 0,
		enabled		= true,
	}
end

local isTombstone = {}
local isCommander = {}
for defID, def in ipairs(UnitDefs) do
	if string.find(def.name, "stone") then
		isTombstone[defID] = def.name
	end
	if def.customParams.iscommander ~= nil then
		isCommander[defID] = def.name == 'armcom' and UnitDefNames.armstone.id or UnitDefNames.corstone.id
	end
end

if gadgetHandler:IsSyncedCode() then

	local function setGaiaUnitSpecifics(unitID)
		Spring.SetUnitNeutral(unitID, true)
		Spring.SetUnitNoSelect(unitID, true)
		Spring.SetUnitStealth(unitID, true)
		Spring.SetUnitNoMinimap(unitID, true)
		Spring.SetUnitBlocking(unitID, true, true, false, false, true, false, false)
		Spring.SetUnitSensorRadius(unitID, 'los', 0)
		Spring.SetUnitSensorRadius(unitID, 'airLos', 0)
		Spring.SetUnitSensorRadius(unitID, 'radar', 0)
		Spring.SetUnitSensorRadius(unitID, 'sonar', 0)
		for weaponID, _ in pairs(UnitDefs[Spring.GetUnitDefID(unitID)].weapons) do
			Spring.UnitWeaponHoldFire(unitID, weaponID)
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
		if isCommander[unitDefID] then
			local px,py,pz = Spring.GetUnitPosition(unitID)
			pz = pz - 40
			local tombstoneID = Spring.CreateUnit(isCommander[unitDefID], px, Spring.GetGroundHeight(px,pz), pz, 0, teamID)
			if tombstoneID then
				local rx,ry,rz = Spring.GetUnitRotation(tombstoneID)
				rx = rx + 0.18 + (math.random(0, 6) / 50)
				rz = rz - 0.12 + (math.random(0, 12) / 50)
				ry = ry - 0.12 + (math.random(0, 12) / 50)
				Spring.SetUnitRotation(tombstoneID, rx,ry,rz)
				setGaiaUnitSpecifics(tombstoneID)
			end
		end
	end


else


	local drawTombstones = Spring.GetConfigInt("tombstones", 1) == 1
	local updateTimer = 0
	local tombstones = {}

	function gadget:Initialize()
		local allUnits = Spring.GetAllUnits()
		for i = 1, #allUnits do
			local unitID = allUnits[i]
			gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
		end
	end

	function gadget:Shutdown()
		for unitID, v in pairs(tombstones) do
			Spring.UnitRendering.SetUnitLuaDraw(unitID, not drawTombstones)
		end
	end

	function gadget:Update()
		updateTimer = updateTimer + Spring.GetLastUpdateSeconds()
		if updateTimer > 0.7 then
			updateTimer = 0
			local prevDrawTombstones = drawTombstones
			drawTombstones = Spring.GetConfigInt("tombstones", 1) == 1
			if drawTombstones ~= prevDrawTombstones then
				for unitID, v in pairs(tombstones) do
					Spring.UnitRendering.SetUnitLuaDraw(unitID, not drawTombstones)
				end
			end
		end
	end

	function gadget:UnitCreated(unitID, unitDefID, team)
		if isTombstone[unitDefID] then
			tombstones[unitID] = true
			if not drawTombstones then
				Spring.UnitRendering.SetUnitLuaDraw(unitID, true)
			end
		end
	end

	function gadget:DrawUnit(unitID, drawMode)
		if isTombstone[Spring.GetUnitDefID(unitID)] then
			gl.Scale( 0, 0, 0 )
			return false
		end
	end
end
