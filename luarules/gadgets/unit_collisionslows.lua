
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

local uPos = Spring.GetUnitPosition
local fPos = Spring.GetFeaturePosition
local uDir = Spring.GetUnitDirection

Ignoring = {}

if (gadgetHandler:IsSyncedCode()) then --SYNCED
Units = {}

function SendToIgnoreList(id, delay)
	Ignoring[id] = Spring.GetGameFrame() + delay
end

function CheckIgnore(id)
	if Ignoring[id] then
		if Ignoring[id] > Spring.GetGameFrame() then
			return false
		else
			Ignoring[id] = nil
			return true
		end
	else
	return false
	end
end


function gadget:Initialize()
	for uDid, uDef in pairs(UnitDefs) do
		Script.SetWatchUnit(uDid, true)
	end
	for fid, fdef in pairs(FeatureDefs) do
		Script.SetWatchFeature(fid, true)	
	end		
end

function FeatureCrushing(unitID, featureID)
mu = UnitDefs[Spring.GetUnitDefID(unitID)].mass
mf = Spring.GetFeatureMass(featureID)
_,_,_,_,crushing = Spring.GetFeatureBlocking(featureID)
if mu > mf and crushing == true then
-- Spring.Echo("true")
return true
else
-- Spring.Echo("false")
return false
end

end
function dot(cx1,cz1,cx2,cz2)
	local dotprod = cx1*cx2 + cz1*cz2
	return dotprod
end

function Norm2DVectr(cx,cy,cz)
	local ndx = (cx/math.abs(cx))*math.sqrt(cx^2/(cx^2+cz^2))
	local ndz = (cz/math.abs(cz))*math.sqrt(cz^2/(cx^2+cz^2))
		if cx == 0 then
			ndx = 0
			ndz = ndz
		end
		if cz == 0 then
			ndz = 0
			ndx = ndx
		end
	return ndx, ndz
end

function GetDirVectr(px1,py1,pz1,px2,py2,pz2)
local cx = px2 - px1
local cy = py2 - py1
local cz = pz2 - pz1
return cx, cy, cz
end

function gadget:UnitUnitCollision(unitID1, unitID2)
	if not (CheckIgnore(unitID1) or CheckIgnore(unitID2)) then
	SendToIgnoreList(unitID1, 5)
	SendToIgnoreList(unitID2, 5)
	local dx1, dz1 = Norm2DVectr(uDir(unitID1))
	local dx2, dz2 = Norm2DVectr(uDir(unitID2))

	local x2,y2,z2 = uPos(unitID2)
	local x1,y1,z1 = uPos(unitID1)

	local dirx1, dirz1 = Norm2DVectr(GetDirVectr(x1,y1,z1, x2,y2,z2))
	local ddotdir1 = (dx1 * dirx1 + dz1 * dirz1)

	local dirx2, dirz2 = Norm2DVectr(GetDirVectr(x2,y2,z2, x1,y1,z1))
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
					if ddotdir1 > 0.7 and UnitDefs[Spring.GetUnitDefID(unitID1)].rSpeed ~= 0 then
						local movegoalx, movegoaly, movegoalz =  x1 - 24*dirx1, Spring.GetGroundHeight(x1 - 24*dirx1,z1 - 24*dirz1), z1 - 24*dirz1

						local unitsatgoal = Spring.GetUnitsInSphere(movegoalx, movegoaly, movegoalz, 24)
						if #unitsatgoal < 2 and Spring.TestMoveOrder(Spring.GetUnitDefID(unitID1), movegoalx, movegoaly, movegoalz, dx1, 0, dz1, true, true, false) == true then
						Spring.GiveOrderToUnit(unitID1, CMD.INSERT, {0, CMD.MOVE, CMD.OPT_ALT,movegoalx, movegoaly, movegoalz},{"alt"})
						end
					else
						local movegoalx, movegoaly, movegoalz =  x1 + 8*(-dirx1+dx1), Spring.GetGroundHeight(x1 + 8*(-dirx1+dx1),z1 + 8*(-dirz1+dz1)), z1 + 8*(-dirz1+dz1)
						local unitsatgoal = Spring.GetUnitsInSphere(movegoalx, movegoaly, movegoalz, 24)
						if dot(dx1,dz1, -dirx1+dx1, -dirz1+dz1) > 0.9 and  #unitsatgoal < 2 and Spring.TestMoveOrder(Spring.GetUnitDefID(unitID1), movegoalx, movegoaly, movegoalz, dx1, 0, dz1, true, true, false) == true then
						Spring.GiveOrderToUnit(unitID1, CMD.INSERT, {0, CMD.MOVE, CMD.OPT_ALT,movegoalx, movegoaly, movegoalz},{"alt"})
						end			
					end
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
				if ddotdir2 > 0.7 and UnitDefs[Spring.GetUnitDefID(unitID2)].rSpeed ~= 0  then
					local movegoalx, movegoaly, movegoalz =  x2 - 24*dirx2, Spring.GetGroundHeight(x2 - 24*dirx2,z2 - 24*dirz2), z2 - 24*dirz
						local unitsatgoal = Spring.GetUnitsInSphere(movegoalx, movegoaly, movegoalz, 24)
						if #unitsatgoal < 2 and Spring.TestMoveOrder(Spring.GetUnitDefID(unitID2), movegoalx, movegoaly, movegoalz,  dx2, 0, dz2, true, true, false) == true then
					Spring.GiveOrderToUnit(unitID2, CMD.INSERT, {0, CMD.MOVE, CMD.OPT_ALT,movegoalx, movegoaly, movegoalz},{"alt"})
					end
				else
					local movegoalx, movegoaly, movegoalz =  x2+ 8*(-dirx2+dx2), Spring.GetGroundHeight(x2 + 8*(-dirx2+dx2),z2 + 8*(-dirz2+dz2)), z2 + 8*(-dirz2+dz2)
						local unitsatgoal = Spring.GetUnitsInSphere(movegoalx, movegoaly, movegoalz, 24)
						if dot(dx2,dz2, -dirx2+dx2, -dirz2+dz2) > 0.9 and  #unitsatgoal < 2 and Spring.TestMoveOrder(Spring.GetUnitDefID(unitID2), movegoalx, movegoaly, movegoalz, dx2, 0, dz2, true, true, false) == true then
					Spring.GiveOrderToUnit(unitID2, CMD.INSERT, {0, CMD.MOVE, CMD.OPT_ALT,movegoalx, movegoaly, movegoalz},{"alt"})
					end
				end
			end
		end
	end
end
end
end

function gadget:UnitFeatureCollision(ID1, ID2)
	if not (CheckIgnore(ID1) or CheckIgnore(ID2)) then
	SendToIgnoreList(ID1, 5)
	SendToIgnoreList(ID2, 5)
	if Spring.ValidUnitID(ID1) then
		local unitID1 = ID1
		local unitID2 = ID2
		if FeatureCrushing(unitID1, unitID2) ~= true then
		local dx1, dz1 = Norm2DVectr(uDir(unitID1))

		local x2,y2,z2 = fPos(unitID2)
		local x1,y1,z1 = uPos(unitID1)

		local dirx, dirz = Norm2DVectr(GetDirVectr(x1,y1,z1, x2,y2,z2))
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
				if ddotdir > 0.7 and UnitDefs[Spring.GetUnitDefID(unitID1)].rSpeed ~= 0  then
					local movegoalx, movegoaly, movegoalz = x1 + 24*-dirx,Spring.GetGroundHeight(x1 + 24*(-dirx),z1 + 24*(-dirz)),z1 + 24*-dirz
						local unitsatgoal = Spring.GetUnitsInSphere(movegoalx, movegoaly, movegoalz, 24)
						if #unitsatgoal < 2 and Spring.TestMoveOrder(Spring.GetUnitDefID(unitID1), movegoalx, movegoaly, movegoalz, dx1, 0, dz1, true, true, false) == true then
					Spring.GiveOrderToUnit(unitID1, CMD.INSERT, {0, CMD.MOVE, CMD.OPT_ALT, movegoalx, movegoaly, movegoalz},{"alt"})
					end
				else
					local movegoalx, movegoaly, movegoalz = x1 + 8*(-dirx+dx1), Spring.GetGroundHeight(x1 + 8*(-dirx+dx1),z1 + 8*(-dirz+dz1)), z1 + 8*(-dirz+dz1)
						local unitsatgoal = Spring.GetUnitsInSphere(movegoalx, movegoaly, movegoalz, 24)
						if dot(dx1,dz1, -dirx+dx1, -dirz+dz1) > 0.9 and  #unitsatgoal < 2 and Spring.TestMoveOrder(Spring.GetUnitDefID(unitID1), movegoalx, movegoaly, movegoalz, dx1, 0, dz1, true, true, false) == true then
					Spring.GiveOrderToUnit(unitID1, CMD.INSERT, {0, CMD.MOVE, CMD.OPT_ALT, movegoalx, movegoaly, movegoalz},{"alt"})
					end
				end
			end
		end
	elseif Spring.ValidFeatureID(ID1) then
		local unitID1 = ID2
		local unitID2 = ID1
		if FeatureCrushing(unitID1, unitID2) ~= true then
		local dx1, dz1 = Norm2DVectr(uDir(unitID1))

		local x2,y2,z2 = fPos(unitID2)
		local x1,y1,z1 = uPos(unitID1)

		local dirx, dirz = Norm2DVectr(GetDirVectr(x1,y1,z1, x2,y2,z2))
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
				if ddotdir > 0.7 and UnitDefs[Spring.GetUnitDefID(unitID1)].rSpeed ~= 0  then
					local movegoalx, movegoaly, movegoalz = x1 + 24*-dirx,Spring.GetGroundHeight(x1 + 24*(-dirx),z1 + 24*(-dirz)),z1 + 24*-dirz
						local unitsatgoal = Spring.GetUnitsInSphere(movegoalx, movegoaly, movegoalz, 24)
						if #unitsatgoal < 2 and Spring.TestMoveOrder(Spring.GetUnitDefID(unitID1), movegoalx, movegoaly, movegoalz, dx1, 0, dz1, true, true, false) == true then
					Spring.GiveOrderToUnit(unitID1, CMD.INSERT, {0, CMD.MOVE, CMD.OPT_ALT, movegoalx, movegoaly, movegoalz},{"alt"})
					end				
					else
					local movegoalx, movegoaly, movegoalz = x1 + 8*(-dirx+dx1), Spring.GetGroundHeight(x1 + 8*(-dirx+dx1),z1 + 8*(-dirz+dz1)), z1 + 8*(-dirz+dz1)
						local unitsatgoal = Spring.GetUnitsInSphere(movegoalx, movegoaly, movegoalz, 24)
						if dot(dx1,dz1, -dirx+dx1, -dirz+dz1) > 0.9 and  #unitsatgoal < 2 and Spring.TestMoveOrder(Spring.GetUnitDefID(unitID1), movegoalx, movegoaly, movegoalz, dx1, 0, dz1, true, true, false) == true then
					Spring.GiveOrderToUnit(unitID1, CMD.INSERT, {0, CMD.MOVE, CMD.OPT_ALT, movegoalx, movegoaly, movegoalz},{"alt"})
					end				
					end
			end
		end
	end
end
end
end