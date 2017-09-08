
function gadget:GetInfo()
  return {
	name 	= "Scatter",
	desc	= "Forces Scattering by lowering units speed when clumping",
	author	= "Doo",
	date	= "05/09/2017",
	license	= "GNU GPL, v2 or later",
	layer	= 0,
	enabled = false,
  }
end
if (gadgetHandler:IsSyncedCode()) then --SYNCED
Units = {}

function gadget:Initialize()
	for _, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if UnitDefs[Spring.GetUnitDefID(unitID)].speed ~= nil and UnitDefs[Spring.GetUnitDefID(unitID)].speed ~= 0 then
	if Spring.ValidUnitID(unitID) then
		Units[unitID] = true
	end
	end
end

function gadget:UnitDestroyed(unitID)
	if Units[unitID] == true then
	Units[unitID] = nil
	end
end

function gadget:GameFrame(f)
	if f % 1 == 0 then
		for unitID, doesscatter in pairs (Units) do
			local posx, posy, posz = Spring.GetUnitPosition(unitID)
			local radius = Spring.GetUnitRadius(unitID) * 4
			local nearingUnits = {}
			local nearingUnits = Spring.GetUnitsInSphere(posx, posy, posz, radius)
			local morenearingUnits = Spring.GetUnitsInSphere(posx, posy, posz, radius/3)
			if nearingUnits[1] ~= nil then
			if morenearingUnits[1] ~= nil then
			-- Spring.Echo(#nearingUnits)
			SlowAmount = 1 * 0.95^(#nearingUnits - 1) * 0.3^(#morenearingUnits - 1)
			-- Spring.Echo(SlowAmount)
			vx, vy, vz, vw = Spring.GetUnitVelocity(unitID)
			-- Spring.Echo(vw)
			maxAllowedSpeed = UnitDefs[Spring.GetUnitDefID(unitID)].speed * SlowAmount * 1/30
if vw > maxAllowedSpeed then
			-- Spring.Echo(maxAllowedSpeed)
			-- Spring.Echo(SlowAmount)
vx, vy, vz = (maxAllowedSpeed/vw)*vx, (maxAllowedSpeed/vw)*vy, (maxAllowedSpeed/vw)*vz
Spring.SetUnitVelocity(unitID, vx, vy, vz)
			end
			end
			end
end
end
end
end