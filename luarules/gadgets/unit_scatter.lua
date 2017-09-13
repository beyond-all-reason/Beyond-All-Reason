
function gadget:GetInfo()
  return {
	name 	= "Scatter",
	desc	= "Forces Scattering by lowering units speed when clumping",
	author	= "Doo",
	date	= "05/09/2017",
	license	= "GNU GPL, v2 or later",
	layer	= 0,
	enabled = true,
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

function GetMassRatio(unitID1, unitID2)
mass1 = UnitDefs[Spring.GetUnitDefID(unitID1)].mass
mass2 = UnitDefs[Spring.GetUnitDefID(unitID2)].mass
ratio1 = mass1/(mass2+mass1)
ratio2 = mass2/(mass2+mass1)
-- Spring.Echo(ratio1)
return ratio1, ratio2
end

function SetSpeed(unitID, vx, vy,vz)
vux, vuy, vuz = Spring.GetUnitVelocity(unitID)
if vx < vux then
vx = vux 
-- Spring.Echo("Slowing x")
 end
if vy < vuy then 
vy = vuy 
-- Spring.Echo("Slowing y")
end
if vz < vuz then 
vz = vuz 
-- Spring.Echo("Slowing z")
end
Spring.SetUnitVelocity(unitID, vx, vy, vz)
end

function gadget:GameFrame(f)
		for unitID, doesscatter in pairs (Units) do
		if Spring.ValiedUnitID(unitID) then
			local posx, posy, posz = Spring.GetUnitPosition(unitID)
			local radius = Spring.GetUnitRadius(unitID) * 3
			local nearingUnits = {}
			vx, vy, vz, vw = Spring.GetUnitVelocity(unitID)
			dirx, diry, dirz = math.abs(vx)/vx, math.abs(vy)/vy, math.abs(vz)/vz
			vnx, vny, vnz = math.abs(vx), math.abs(vy), math.abs(vz)
			local nearingUnits = Spring.GetUnitsInSphere(posx+vx*radius/vw, posy+vy*radius/vw, posz+vz*radius/vw, radius/vw)
			local morenearingUnits = Spring.GetUnitsInSphere(posx+vx*radius/vw*2, posy+vy*radius/vw*2, posz+vz*radius/vw*2, radius/2)
			if morenearingUnits[2] ~= nil then
				for i = 2, #morenearingUnits do
				local v2x, v2y, v2z, v2w = Spring.GetUnitVelocity(morenearingUnits[i])
				if lowestv2x == nil and lowestv2y == nil and lowestv2z == nil then
				lowestv2x, lowestv2y, lowestv2z = vx, vy, vz
				Slowestx = morenearingUnits[i]
				Slowesty = morenearingUnits[i]
				Slowestz = morenearingUnits[i]
				end
				--x
				if v2x*dirx < lowestv2x*dirx then
				lowestv2x = v2x
				Slowestx = morenearingUnits[i]
				end
				--y
				if v2x*diry < lowestv2x*diry then
				lowestv2y = v2y
				Slowesty = morenearingUnits[i]
				end
				--z
				if v2z*dirz < lowestv2z*dirz then
				lowestv2z = v2y
				Slowestz = morenearingUnits[i]
				end
				end

			if lowestv2x*dirx < vx*dirx then
			ratio1, ratio2 = GetMassRatio(unitID, Slowestx)
			vx = vx*(ratio1) + lowestv2x*(ratio2)			
			end
			if lowestv2y*diry < vy*diry then 			
			ratio1, ratio2 = GetMassRatio(unitID, Slowesty)
			vy = vy*(ratio1) + lowestv2y*(ratio2)		
			end					
			if lowestv2z*dirz < vz*dirz then 			
			ratio1, ratio2 = GetMassRatio(unitID, Slowestz)
			vz = vz*(ratio1) + lowestv2z*(ratio2)		 
			end
			SetSpeed(unitID, vx, vy, vz)
			Slowestz = nil
			Slowestx = nil
			Slowesty = nil		
			lowestv2x = nil
			lowestv2y = nil
			lowestv2z = nil			
			if nearingUnits[2] ~= nil then
			SlowAmount = 0.95^(#nearingUnits-1)
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