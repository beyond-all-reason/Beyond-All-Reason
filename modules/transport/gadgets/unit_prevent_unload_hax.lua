local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Prevent Unload Hax",
		desc = "removes unit velocity on unload (and prevents firing units across the map with 'stored' impulse)",
		author = "Bluestone",
		date = "12/08/2013",
		license = "GNU GPL, v2 or later, horses",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local frameMargin = 10

-- paradropped units (customparams.paratrooper) keep the transport's momentum on unload
local isParatrooper = {}
for udid, ud in pairs(UnitDefs) do
	if ud.customParams.paratrooper then
		isParatrooper[udid] = true
	end
end

-- carriers release their own drones
local isCarrierDrone = {}
for _, wd in pairs(WeaponDefs) do
	if wd.customParams.carried_unit then
		for name in wd.customParams.carried_unit:gmatch("%S+") do
			if UnitDefNames[name] then
				isCarrierDrone[UnitDefNames[name].id] = true
			end
		end
	end
end

local SpSetUnitVelocity = Spring.SetUnitVelocity
local SpGetUnitVelocity = Spring.GetUnitVelocity
local SpGetGroundHeight = Spring.GetGroundHeight
local SpGetUnitPosition = Spring.GetUnitPosition
local SpGetUnitDirection = Spring.GetUnitDirection
local SpGetGameFrame = Spring.GetGameFrame
local SpSetUnitPhysics = Spring.SetUnitPhysics
local SpSetUnitDirection = Spring.SetUnitDirection

local unloadedUnits = {}

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	if unitID == nil or unitDefID == nil or transportID == nil or isCarrierDrone[unitDefID] then
		return
	end
	if isParatrooper[unitDefID] then
		local x, y, z = SpGetUnitVelocity(transportID)
		if x > 10 then
			x = 10
		elseif x < -10 then
			x = -10
		end -- 10 is well above 'normal' air-trans velocity
		if z > 10 then
			z = 10
		elseif z < -10 then
			z = -10
		end
		local bx, by, bz = SpGetUnitPosition(unitID)
		if by - SpGetGroundHeight(bx, bz) < 5 then
			x = 0
			y = 0
			z = 0 --in particular, don't give any velocity if the transport has placed the unit slightly underground (or weirdness...)
		end
		SpSetUnitVelocity(unitID, x, y, z)
	else
		-- prevent unloaded units from sliding across the map
		local px, py, pz = SpGetUnitPosition(unitID)
		local dx, dy, dz, rx, ry, rz = SpGetUnitDirection(unitID)
		unloadedUnits[unitID] = {
			px = px,
			py = py,
			pz = pz,
			dx = dx,
			dy = dy,
			dz = dz,
			rx = rx,
			ry = ry,
			rz = rz,
			frame = SpGetGameFrame() + frameMargin,
		}

		SpSetUnitVelocity(unitID, 0, 0, 0)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	unloadedUnits[unitID] = nil
end

function gadget:GameFrame(frame)
	-- prevent unloaded units from sliding across the map
	for unitID, data in pairs(unloadedUnits) do
		if data.frame <= frame then
			SpSetUnitPhysics(unitID, data.px, data.py, data.pz, 0, 0, 0, 0, 0, 0, 0, 0, 0)
			SpSetUnitDirection(unitID, data.dx, data.dy, data.dz, data.rx, data.ry, data.rz)
			unloadedUnits[unitID] = nil
		end
	end
end
