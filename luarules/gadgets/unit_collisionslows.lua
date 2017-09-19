
function gadget:GetInfo()
  return {
	name 	= "CollisionSlows",
	desc	= "Apllies slows on unit-unit and unit-feature collisions",
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

local dx1, dy1, dz1 = Spring.GetUnitDirection(unitID1)
local dx2, dy2, dz2 = Spring.GetUnitDirection(unitID2)
local x2,y2,z2 = Spring.GetUnitPosition(unitID2)
local x1,y1,z1 = Spring.GetUnitPosition(unitID1)
local dirx1 = (math.abs(x2 - x1)/(x2 - x1))*(math.sqrt((x2 - x1)^2/((x2 - x1)^2+(z2 - z1)^2)))
local dirz1 = (math.abs(z2 - z1)/(z2 - z1))*(math.sqrt((x2 - x1)^2/((x2 - x1)^2+(z2 - z1)^2)))
local ddotdir1 = (dx1 * dirx1 + dz1 * dirz1)

local dirx2 = -dirx1
local dirz2 = -dirz1
local ddotdir2 = (dx2 * dirx2 + dz2 * dirz2)

if ddotdir1 > 0 then
if not (UnitDefs[Spring.GetUnitDefID(unitID1)].isBuilding == true or UnitDefs[Spring.GetUnitDefID(unitID1)].name == "armnanotc" or UnitDefs[Spring.GetUnitDefID(unitID1)].name == "cornanotc") then
if (UnitDefs[Spring.GetUnitDefID(unitID2)].isFactory == true and Spring.AreTeamsAllied(Spring.GetUnitTeam(unitID1),Spring.GetUnitTeam(unitID2)) == false) or not UnitDefs[Spring.GetUnitDefID(unitID2)].isFactory == true then
local vx1,vy1,vz1 = Spring.GetUnitVelocity(unitID1)
local vx2,vy2,vz2 = Spring.GetUnitVelocity(unitID2)
local scalar2d = math.abs(dx1*dx2 + dz1*dz2)
local mass1, mass2 = UnitDefs[Spring.GetUnitDefID(unitID1)].mass*scalar2d*5, UnitDefs[Spring.GetUnitDefID(unitID2)].mass
local rspeedx = vx1*(1-ddotdir1) + (vx1*(mass1/(mass1+mass2))+vx2*(mass2/(mass1+mass2)))*(ddotdir1)
local rspeedy = vy1*(1-ddotdir1) + (vy1*(mass1/(mass1+mass2))+vy2*(mass2/(mass1+mass2)))*(ddotdir1)
local rspeedz = vz1*(1-ddotdir1) + (vz1*(mass1/(mass1+mass2))+vz2*(mass2/(mass1+mass2)))*(ddotdir1)
Spring.SetUnitVelocity(unitID1, rspeedx, rspeedy, rspeedz)
if UnitDefs[Spring.GetUnitDefID(unitID2)].isBuilding == true or UnitDefs[Spring.GetUnitDefID(unitID2)].name == "armnanotc" then
Spring.GiveOrderToUnit(unitID1, CMD.INSERT, {0, CMD.MOVE, CMD.OPT_ALT, x1 - 24*dirx1, Spring.GetGroundHeight(x1 - 24*dirx1,z1 - 24*dirz1), z1 - 24*dirz1},{"alt"})
end
end
end
end
if ddotdir2 > 0 then
if not (UnitDefs[Spring.GetUnitDefID(unitID2)].isBuilding == true or UnitDefs[Spring.GetUnitDefID(unitID2)].name == "armnanotc" or UnitDefs[Spring.GetUnitDefID(unitID2)].name == "cornanotc") then
if (UnitDefs[Spring.GetUnitDefID(unitID1)].isFactory == true and Spring.AreTeamsAllied(Spring.GetUnitTeam(unitID2),Spring.GetUnitTeam(unitID1)) == false) or not UnitDefs[Spring.GetUnitDefID(unitID1)].isFactory == true then
local vx1,vy1,vz1 = Spring.GetUnitVelocity(unitID2)
local vx2,vy2,vz2 = Spring.GetUnitVelocity(unitID1)
local scalar2d = math.abs(dx1*dx2 + dz1*dz2)
local mass1, mass2 = UnitDefs[Spring.GetUnitDefID(unitID2)].mass*scalar2d*5, UnitDefs[Spring.GetUnitDefID(unitID1)].mass
local rspeedx = vx1*(1-ddotdir2) + (vx1*(mass1/(mass1+mass2))+vx2*(mass2/(mass1+mass2)))*(ddotdir2)
local rspeedy = vy1*(1-ddotdir2) + (vy1*(mass1/(mass1+mass2))+vy2*(mass2/(mass1+mass2)))*(ddotdir2)
local rspeedz = vz1*(1-ddotdir2) + (vz1*(mass1/(mass1+mass2))+vz2*(mass2/(mass1+mass2)))*(ddotdir2)
Spring.SetUnitVelocity(unitID2, rspeedx, rspeedy, rspeedz)
if UnitDefs[Spring.GetUnitDefID(unitID1)].isBuilding == true or UnitDefs[Spring.GetUnitDefID(unitID1)].name == "armnanotc" then
Spring.GiveOrderToUnit(unitID2, CMD.INSERT, {0, CMD.MOVE,CMD.OPT_ALT, x2 - 24*dirx2, Spring.GetGroundHeight(x2 - 24*dirx2,z2 - 24*dirz2), z2 - 24*dirz2},{"alt"})
end
end
end
end

end

function gadget:UnitFeatureCollision(ID1, ID2)
if Spring.ValidUnitID(ID1) then
local unitID1 = ID1
local unitID2 = ID2
local dx1, dy1, dz1 = Spring.GetUnitDirection(unitID1)
local x2,y2,z2 = Spring.GetFeaturePosition(unitID2)
local x1,y1,z1 = Spring.GetUnitPosition(unitID1)
local dirx = (math.abs(x2 - x1)/(x2 - x1))*(math.sqrt((x2 - x1)^2/((x2 - x1)^2+(z2 - z1)^2)))
local dirz = (math.abs(z2 - z1)/(z2 - z1))*(math.sqrt((x2 - x1)^2/((x2 - x1)^2+(z2 - z1)^2)))
local ddotdir = (dx1 * dirx + dz1 * dirz)
if ddotdir > 0 then
local vx1,vy1,vz1 = Spring.GetUnitVelocity(unitID1)
local vx2,vy2,vz2 = 0,0,0
if FeatureDefs[Spring.GetFeatureDefID(unitID2)].blocking == false then
mass1, mass2 = UnitDefs[Spring.GetUnitDefID(unitID1)].mass, 0
else
mass1, mass2 = UnitDefs[Spring.GetUnitDefID(unitID1)].mass, FeatureDefs[Spring.GetFeatureDefID(unitID2)].mass
end
Spring.SetUnitVelocity(unitID1, vx1*(mass1/(mass1+mass2))+vx2*(mass2/(mass1+mass2)),vy1*(mass1/(mass1+mass2))+vy2*(mass2/(mass1+mass2)),vz1*(mass1/(mass1+mass2))+vz2*(mass2/(mass1+mass2)))
Spring.GiveOrderToUnit(unitID1, CMD.INSERT, {0, CMD.MOVE, CMD.OPT_ALT, x1 - 24*dirx, Spring.GetGroundHeight(x1 - 24*dirx,z1 - 24*dirz), z1 - 24*dirz},{"alt"})
end
elseif Spring.ValidFeatureID(ID1) then
local unitID1 = ID2
local unitID2 = ID1
local dx1, dy1, dz1 = Spring.GetUnitDirection(unitID1)
local x2,y2,z2 = Spring.GetFeaturePosition(unitID2)
local x1,y1,z1 = Spring.GetUnitPosition(unitID1)
local dirx = (math.abs(x2 - x1)/(x2 - x1))*(math.sqrt((x2 - x1)^2/((x2 - x1)^2+(z2 - z1)^2)))
local dirz = (math.abs(z2 - z1)/(z2 - z1))*(math.sqrt((x2 - x1)^2/((x2 - x1)^2+(z2 - z1)^2)))
local ddotdir = (dx1 * dirx + dz1 * dirz)
if ddotdir > 0 then
local vx1,vy1,vz1 = Spring.GetUnitVelocity(unitID1)
local vx2,vy2,vz2 = 0,0,0
if FeatureDefs[Spring.GetFeatureDefID(unitID2)].blocking == false then
mass1, mass2 = UnitDefs[Spring.GetUnitDefID(unitID1)].mass, 0
else
mass1, mass2 = UnitDefs[Spring.GetUnitDefID(unitID1)].mass, FeatureDefs[Spring.GetFeatureDefID(unitID2)].mass
end
Spring.SetUnitVelocity(unitID1, vx1*(mass1/(mass1+mass2))+vx2*(mass2/(mass1+mass2)),vy1*(mass1/(mass1+mass2))+vy2*(mass2/(mass1+mass2)),vz1*(mass1/(mass1+mass2))+vz2*(mass2/(mass1+mass2)))
Spring.GiveOrderToUnit(unitID1, CMD.INSERT, {0, CMD.MOVE, CMD.OPT_ALT, x1 - 24*dirx, Spring.GetGroundHeight(x1 - 24*dirx,z1 - 24*dirz), z1 - 24*dirz},{"alt"})
end
end
end
end