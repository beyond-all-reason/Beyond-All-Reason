
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
	for uDid, uDef in pairs(UnitDefs) do
		Script.SetWatchUnit(uDid, true)
	end
	for fid, fdef in pairs(FeatureDefs) do
		Script.SetWatchFeature(fid, true)	
	end		
end

function gadget:UnitUnitCollision(unitID1, unitID2)
-- Spring.Echo('col')
vx1,vy1,vz1 = Spring.GetUnitVelocity(unitID1)
vx2,vy2,vz2 = Spring.GetUnitVelocity(unitID2)
dx1, dy1, dz1 = Spring.GetUnitDirection(unitID1)
dx2, dy2, dz2 = Spring.GetUnitDirection(unitID2)
scalar2d = math.abs(dx1*dx2 + dz1*dz2)
mass1, mass2 = UnitDefs[Spring.GetUnitDefID(unitID1)].mass*scalar2d*5, UnitDefs[Spring.GetUnitDefID(unitID2)].mass
if not (UnitDefs[Spring.GetUnitDefID(unitID1)].isBuilding == true or UnitDefs[Spring.GetUnitDefID(unitID1)].name == "armnanotc" or UnitDefs[Spring.GetUnitDefID(unitID1)].name == "cornanotc") then
if (UnitDefs[Spring.GetUnitDefID(unitID2)].isFactory == true and Spring.AreTeamsAllied(Spring.GetUnitTeam(unitID1),Spring.GetUnitTeam(unitID2)) == false) or not UnitDefs[Spring.GetUnitDefID(unitID2)].isFactory == true then
Spring.SetUnitVelocity(unitID1, vx1*(mass1/(mass1+mass2))+vx2*(mass2/(mass1+mass2)),vy1*(mass1/(mass1+mass2))+vy2*(mass2/(mass1+mass2)),vz1*(mass1/(mass1+mass2))+vz2*(mass2/(mass1+mass2)))
end
end
if not (UnitDefs[Spring.GetUnitDefID(unitID2)].isBuilding == true or UnitDefs[Spring.GetUnitDefID(unitID2)].name == "armnanotc" or UnitDefs[Spring.GetUnitDefID(unitID2)].name == "cornanotc") then
if (UnitDefs[Spring.GetUnitDefID(unitID1)].isFactory == true and Spring.AreTeamsAllied(Spring.GetUnitTeam(unitID1),Spring.GetUnitTeam(unitID2)) == false) or not UnitDefs[Spring.GetUnitDefID(unitID1)].isFactory == true then
Spring.SetUnitVelocity(unitID2, vx1*(mass1/(mass1+mass2))+vx2*(mass2/(mass1+mass2)),vy1*(mass1/(mass1+mass2))+vy2*(mass2/(mass1+mass2)),vz1*(mass1/(mass1+mass2))+vz2*(mass2/(mass1+mass2)))
end
end
end

function gadget:UnitFeatureCollision(unitID1, unitID2)
-- Spring.Echo('col')
vx1,vy1,vz1 = Spring.GetUnitVelocity(unitID1)
vx2,vy2,vz2 = 0,0,0
mass1, mass2 = UnitDefs[Spring.GetUnitDefID(unitID1)].mass, 500
Spring.SetUnitVelocity(unitID1, vx1*(mass1/(mass1+mass2))+vx2*(mass2/(mass1+mass2)),vy1*(mass1/(mass1+mass2))+vy2*(mass2/(mass1+mass2)),vz1*(mass1/(mass1+mass2))+vz2*(mass2/(mass1+mass2)))
-- Spring.SetUnitVelocity(unitID2, vx1*(mass1/(mass1+mass2))+vx2*(mass2/(mass1+mass2)),vy1*(mass1/(mass1+mass2))+vy2*(mass2/(mass1+mass2)),vz1*(mass1/(mass1+mass2))+vz2*(mass2/(mass1+mass2)))
end

end