--==================================================================================================
--    Copyright (C) <2016>  <Florian Seidl-Schulz>
--This program is free software: you can redistribute it and/or modify
--it under the terms of the GNU General Public License as published by
--the Free Software Foundation, either version 3 of the License, or
--(at your option) any later version.
--This program is distributed in the hope that it will be useful,
--but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--GNU General Public License for more details.
-- You should have received a copy of the GNU General Public License
--along with this program.  If not, see <http://www.gnu.org/licenses/>.
--==================================================================================================
--Variables for the MockUp

Spring ={}
numberMock =42
stringMock ="TestString"
tableMock ={exampletable= true}
booleanMock =true
functionMock =function (bar) return bar; end

--==================================================================================================
-- GameRulesParameter
--==================================================================================================

---@param paramName string
---@param losAccess? losAccess
---@return string
function Spring.SetGameRulesParam   (  paramName, losAccess )
	assert(type(paramName) == "string","Argument paramName is of invalid type - expected string");
	assert(losAccess == "private" | losAccess == "allied" | losAccess == "inlos" | losAccess == "inradar"
		| losAccess == "public", "Argument losAccess is invalid");
return  stringMock
end

---@param teamID number
---@param paramName string
---@param losAccess? losAccess
---@return integer
function Spring.SetTeamRulesParam (teamID, paramName, losAccess)
	assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
	assert(type(paramName) == "string" or type(paramName) == "number","Argument paramName is of invalid type - expected string or number");
	assert(losAccess == "private" | losAccess == "allied" | losAccess == "inlos" | losAccess == "inradar"
		| losAccess == "public", "Argument losAccess is invalid");
	return numberMock
end

---@param unitID number
---@param paramName string
---@param losAccess? losAccess
---@return integer
function Spring.SetUnitRulesParam (unitID, paramName, losAccess)
    assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
    assert(type(paramName) == "string" or type(paramName) == "number","Argument paramName is of invalid type - expected string or number");
	assert(losAccess == "private" | losAccess == "allied" | losAccess == "inlos" | losAccess == "inradar"
	| losAccess == "public", "Argument losAccess is invalid");
	return numberMock
end

---SetFeatureRulesParam - no additional documentation
---@param featureID any
---@param paramName any
---@param paramValue any
---@param losAccess? losAccess
---@return nil
function Spring.SetFeatureRulesParam(featureID, paramName, paramValue, losAccess)
	assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
	assert(type(paramName))
	assert(type(paramValue))
	assert(losAccess == "private" | losAccess == "allied" | losAccess == "inlos" | losAccess == "inradar"
	| losAccess == "public", "Argument losAccess is invalid");
	return nil
end

--==================================================================================================
-- Resources
--==================================================================================================

---Set tidal Strength
---@param strength number
---@return nil
function Spring.SetTidal(strength)
	assert(type(strength) == "number", "Argument strength is of invalid type - expected number")
	return nil
end

---Sets wind strength
---@param minStrength number
---@param maxStrength number
---@return nil
function Spring.SetWind(minStrength, maxStrength)
	assert(type(minStrength) == "number", "Argument minStrength is of invalid type - expected number")
	assert(type(maxStrength) == "number", "Argument maxStrength is of invalid type - expected number")
	return nil
end

---@param teamID number
---@param resourceType resourceTypes
---@param amount number
---@return integer
function Spring.AddTeamResource   (  teamID, resourceType, amount)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(resourceType) == "string","Argument resourceType is of invalid type - expected string");
assert(type(amount) == "number","Argument amount is of invalid type - expected number");
return  numberMock
 end

 ---specify "metal" or "energy" for type
 -- Consumes metal and/or energy resources of the specified team.
 ---@param teamID number
 ---@param type resourceTypes
 ---@param amount number
 ---@return boolean | nil
 function Spring.UseTeamResource   ( teamID, type, amount )
 return  booleanMock
  end

  ---Sets team resources to given absolute value 
  ---@param teamID number
  ---@param res resValues
  ---@param amount any
  ---@return integer
  function Spring.SetTeamResource   (  teamID, res, amount)
  assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
  assert(type(res) == "string","Argument res is of invalid type - expected string");
  assert(type(amount) == "number","Argument amount is of invalid type - expected number");
  return  numberMock
   end

 ---Changes the resource amount for a team beyond which resources aren't stored but transferred to other allied teams if possible.
 ---@param teamID number
 ---@param resourceType resourceTypes
 ---@param amount number
 ---@return integer
function Spring.SetTeamShareLevel   (teamID, resourceType, amount)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(resourceType) == "string","Argument metal is of invalid type - expected string");
assert(type(amount) == "number","Argument amount is of invalid type - expected number");
return  numberMock
 end

--- Transfers resources between two teams
---@param teamID_src number source team
---@param teamID_rec number recieving team
---@param resourceType resourceTypes
---@param amount number
---@return nil
function Spring.ShareTeamResource    ( teamID_src, teamID_rec, resourceType, amount )
assert(type(teamID_src) == "number","Argument teamID_src is of invalid type - expected number");
assert(type(teamID_rec) == "number","Argument teamID_rec is of invalid type - expected number");
assert(type(resourceType) == "string", "Argument resourceType is of invalid type - expected string");
assert(type(amount) == "number","Argument amount is of invalid type - expected number");
return  numberMock
 end

--==================================================================================================
-- Teams
--==================================================================================================

---Change the value of the (one-sided) alliance between: firstAllyTeamID -> secondAllyTeamID
---@param firstAllyTeamID number
---@param secondAllyTeamID number
---@param ally boolean
---@return nil
function Spring.SetAlly    (  firstAllyTeamID, secondAllyTeamID, ally)
assert(type(firstAllyTeamID) == "number","Argument firstAllyTeamID is of invalid type - expected number");
assert(type(secondAllyTeamID) == "number","Argument secondAllyTeamID is of invalid type - expected number");
assert(type(ally) == "boolean","Argument ally is of invalid type - expected boolean");
return  numberMock
 end

 ---Assigns player playerID to team teamID
 ---@param playerID number
 ---@param teamID number
 ---@return nil
 function Spring.AssignPlayerToTeam    (  playerID, teamID)
 assert(type(playerID) == "number","Argument playerID is of invalid type - expected number");
 assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
 return boolMock
 end

---Changes access to global line of sight for a team and its allies.
---@param playerID number
---@param globallos boolean
---@return nil
function Spring.SetGlobalLos (playerID, globallos)
return nil
end

--==================================================================================================
-- Unit Handling
--==================================================================================================

function Spring.CreateUnit   (  unitDefID, x, y , z, facing, teamID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(teamID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end


---@param UnitID number
---@param selfd? boolean # if true, Makes the unit act like it self-destructed.
---@param reclaimed? boolean # Don't show any DeathSequences, don't leave a wreckage. This does not give back the resources to the team!
---@param attackerID? number 
---@param cleanupImmediately? boolean # stronger version of reclaimed, removes the unit unconditionally and makes its ID available for immediate reuse (otherwise it takes a few frames) (default false)
function Spring.DestroyUnit ( UnitID, selfd, reclaimed, attackerID, cleanupImmediately )
    assert(UnitID)
    assert(selfd)
    assert(reclaimed)
    assert(attackerID)
    assert(cleanupImmediately)
return  nil
end

---Spring.TransferUnit(unitID, newTeamID[, given=true])
---@param UnitID number
---@param newTeamID number
---@param given? boolean # If given=false, the unit is captured.
function Spring.TransferUnit   (UnitID, newTeamID, given)
return  booleanMock
end

--==================================================================================================
-- Unit Control
--==================================================================================================

function Spring.SetUnitCosts   ( )
return
 end

function Spring.SetUnitTooltip   (  unitID, tooltip)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(tooltip) == "string","Argument tooltip is of invalid type - expected string");
return  numberMock
 end

function Spring.SetUnitHealth   ( )
return
 end

function Spring.SetUnitMaxHealth   (  unitID, maxHealth)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(maxHealth) == "number","Argument maxHealth is of invalid type - expected number");
return  numberMock
 end

function Spring.AddUnitDamage   ( )
return  numberMock
 end

function Spring.SetUnitStockpile   (  unitID, stockpile, buildPercent)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(stockpile) == "number","Argument stockpile is of invalid type - expected number");
assert(type(buildPercent) == "number","Argument buildPercent is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitExperience   (  unitID, experience)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(experience) == "number","Argument experience is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitFuel   (  unitID, fuel)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(fuel) == "number","Argument fuel is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitCrashing    (  unitID, crashing)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(crashing) == "boolean","Argument crashing is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetUnitLineage    (  unitID, teamID, isRoot)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(isRoot) == "boolean","Argument isRoot is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetUnitNeutral   (  unitID, neutral)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(neutral) == "boolean","Argument neutral is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetUnitTarget    ( )
return  booleanMock
 end

function Spring.SetUnitMaxRange   (  unitID, maxRange)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(maxRange) == "number","Argument maxRange is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitBlocking    (  unitID, isBlocking, isSolidObjectCollidable, isProjectileCollidable, isRaySegmentCollidable, crushable, blockEnemyPushing, blockHeightChanges)
 assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
 assert(type(isBlocking) == "boolean","Argument isBlocking is of invalid type - expected boolean");
 assert(type(isSolidObjectCollidable) == "boolean","Argument isSolidObjectCollidable is of invalid type - expected boolean");
 assert(type(isProjectileCollidable) == "boolean","Argument isProjectileCollidable is of invalid type - expected boolean");
 assert(type(isRaySegmentCollidable) == "boolean","Argument isRaySegmentCollidable is of invalid type - expected boolean");
 assert(type(crushable) == "boolean","Argument crushable is of invalid type - expected boolean");
 assert(type(blockEnemyPushing) == "boolean","Argument blockEnemyPushing is of invalid type - expected boolean");
 assert(type(blockHeightChanges) == "boolean","Argument blockHeightChanges is of invalid type - expected boolean");
 return  numberMock
end

function Spring.SetUnitBlocking    (  unitID, depth, range)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(depth) == "number","Argument depth is of invalid type - expected number");
assert(type(range) == "number","Argument range is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitBuildSpeed   ( )
return  numberMock
 end

function Spring.SetUnitNanoPieces    (  builderID, pieces)
assert(type(builderID) == "number","Argument builderID is of invalid type - expected number");
assert(type(pieces) == "table","Argument pieces is of invalid type - expected table");
return  numberMock
 end

function Spring.UnitAttach    (  transporterID, passengerID, pieceNum)
assert(type(transporterID) == "number","Argument transporterID is of invalid type - expected number");
assert(type(passengerID) == "number","Argument passengerID is of invalid type - expected number");
assert(type(pieceNum) == "number","Argument pieceNum is of invalid type - expected number");
return  numberMock
 end

function Spring.UnitDetach    (  passengerID)
assert(type(passengerID) == "number","Argument passengerID is of invalid type - expected number");
return  numberMock
 end

function Spring.UnitDetachFromAir    (  passengerID)
assert(type(passengerID) == "number","Argument passengerID is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitLoadingTransport    (  passengerID, transportID)
assert(type(passengerID) == "number","Argument passengerID is of invalid type - expected number");
assert(type(transportID) == "number","Argument transportID is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitPieceParent    (  unitID, AlteredPiece, ParentPiece)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(AlteredPiece) == "number","Argument AlteredPiece is of invalid type - expected number");
assert(type(ParentPiece) == "number","Argument ParentPiece is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitArmored    (  unitID, armored, armorMultiple)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(armored) == "boolean","Argument armored is of invalid type - expected boolean");
assert(type(armorMultiple) == "number","Argument armorMultiple is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitShieldState   (  unitID, weaponID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(weaponID) == "number","Argument weaponID is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitFlanking   (  unitID, mode, mode)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(mode) == "string","Argument mode is of invalid type - expected string");
assert(type(mode) == "number","Argument mode is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitWeaponState   (  unitID, weaponNum, states)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(weaponNum) == "number","Argument weaponNum is of invalid type - expected number");
assert(type(states) == "table","Argument states is of invalid type - expected table");
return  numberMock
 end

function Spring.SetUnitWeaponDamages    (  unitID, weaponNum)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(weaponNum) == "number","Argument weaponNum is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitCollisionVolumeData   ( )
return
 end

function Spring.SetUnitPieceCollisionVolumeData   ( )
return
 end

function Spring.SetUnitTravel   (  unitID, travel, travelPeriod)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(travel) == "number","Argument travel is of invalid type - expected number");
assert(type(travelPeriod) == "number","Argument travelPeriod is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitMoveGoal    (  unitID, goalx, goaly, goalz, goalRadius, moveSpeed)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(goalx) == "number","Argument goalx is of invalid type - expected number");
assert(type(goaly) == "number","Argument goaly is of invalid type - expected number");
assert(type(goalz) == "number","Argument goalz is of invalid type - expected number");
assert(type(goalRadius) == "number","Argument goalRadius is of invalid type - expected number");
assert(type(moveSpeed) == "number","Argument moveSpeed is of invalid type - expected number");
return  booleanMock
 end


function Spring.SetUnitPosition   (  unitID, x, z, alwaysAboveSea)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(alwaysAboveSea) == "boolean","Argument alwaysAboveSea is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetUnitDirection    (  unitID, x, y, z)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitVelocity   (  unitID, velx, vely, velz)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(velx) == "number","Argument velx is of invalid type - expected number");
assert(type(vely) == "number","Argument vely is of invalid type - expected number");
assert(type(velz) == "number","Argument velz is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitRotation   (  unitID, rotx, roty, rotz)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(rotx) == "number","Argument rotx is of invalid type - expected number");
assert(type(roty) == "number","Argument roty is of invalid type - expected number");
assert(type(rotz) == "number","Argument rotz is of invalid type - expected number");
return  numberMock
 end

function Spring.AddUnitImpulse   (  unitID, x, y, z)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.AddUnitSeismicPing   (  unitID, pingSize)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(pingSize) == "number","Argument pingSize is of invalid type - expected number");
return  numberMock
 end

function Spring.RemoveBuildingDecal   ( unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitMidAndAimPos    ( )
return  booleanMock
 end

function Spring.SetUnitRadiusAndHeight    ( unitID, radius, height)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(radius) == "number","Argument radius is of invalid type - expected number");
assert(type(height) == "number","Argument height is of invalid type - expected number");
return  numberMock
 end

function Spring.UnitWeaponFire   ( unitID, weaponID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(weaponID) == "number","Argument weaponID is of invalid type - expected number");
return  numberMock
 end

function Spring.UnitWeaponHoldFire   ( unitID, weaponID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(weaponID) == "number","Argument weaponID is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitCloak   ( )
return  numberMock
 end

function Spring.SetUnitSonarStealth   (  unitID, sonarStealth)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(sonarStealth) == "boolean","Argument sonarStealth is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetUnitStealth   (  unitID, stealth)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(stealth) == "boolean","Argument stealth is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetUnitAlwaysVisible   (  unitID, alwaysVisible)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(alwaysVisible) == "boolean","Argument alwaysVisible is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetUnitLosMask   (  unitID, allyTeam, los)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(allyTeam) == "number","Argument allyTeam is of invalid type - expected number");
assert(type(los) == "number","Argument los is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitLosState   (  unitID, allyTeam, los)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(allyTeam) == "number","Argument allyTeam is of invalid type - expected number");
assert(type(los) == "number","Argument los is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitSensorRadius   (  unitID, type, radius)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(type) == "string","Argument type is of invalid type - expected string");
assert(type(radius) == "number","Argument radius is of invalid type - expected number");
return  numberMock
 end

function Spring.SetRadarErrorParams    ( )
return  numberMock
 end

function Spring.SetUnitPosErrorParams    ( )
return  numberMock
 end

function Spring.SetUnitResourcing   ( )
return
 end

function Spring.AddUnitResource   (  unitID, m)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(m) == "string","Argument m is of invalid type - expected string");
return  numberMock
 end

function Spring.UseUnitResource   (  unitID, m)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(m) == "string","Argument m is of invalid type - expected string");
return  booleanMock
 end

function Spring.SetUnitHarvestStorage    (  unitid, metal)
assert(type(unitid) == "number","Argument unitid is of invalid type - expected number");
assert(type(metal) == "number","Argument metal is of invalid type - expected number");

return  numberMock
 end

function Spring.DestroyFeature   (  featureID)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
return  numberMock
 end

function Spring.TransferFeature   (  featureID, teamID)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.SetFeatureHealth   (  featureID, health)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(health) == "number","Argument health is of invalid type - expected number");
return  numberMock
 end

function Spring.SetFeatureReclaim   (  featureID, reclaimLeft)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(reclaimLeft) == "number","Argument reclaimLeft is of invalid type - expected number");
return  numberMock
 end

function Spring.SetFeatureResurrect   (  featureID, UnitDefName, facing)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(UnitDefName) == "string","Argument UnitDefName? is of invalid type - expected string");
assert(type(facing) == "number","Argument facing is of invalid type - expected number");
return  numberMock
 end

function Spring.SetFeaturePosition   (  featureID, x, y, z, snapToGround)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(snapToGround) == "boolean","Argument snapToGround is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetFeatureDirection   (  featureID, x, y, z)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.SetFeatureVelocity    ( featureID, noSelect)

assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(noSelect) == "boolean","Argument noSelect is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetFeatureAlwaysVisible   (  featureID, enable)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(enable) == "boolean","Argument enable is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetFeatureCollisionVolumeData   ( )
return
 end

function Spring.SetUnitCollisionVolumeData    ( )
return  booleanMock
 end

function Spring.SetUnitMidAndAimPos    (  unitID, radius, height)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(radius) == "number","Argument radius is of invalid type - expected number");
assert(type(height) == "number","Argument height is of invalid type - expected number");
return  numberMock
 end

function Spring.SetFeatureBlocking   (  featureID, blocking, collidable)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(blocking) == "boolean","Argument blocking is of invalid type - expected boolean");
assert(type(collidable) == "boolean","Argument collidable is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetFeatureBlocking    (  unitID, funcID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(funcID) == "number","Argument funcID is of invalid type - expected number");
return  numberMock
 end

function Spring.CallCOBScriptCB   (  unitID, funcID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(funcID) == "number","Argument funcID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetCOBScriptID   (  unitID, funcName)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(funcName) == "string","Argument funcName is of invalid type - expected string");
return  numberMock
 end


function Spring.SetUnitCOBValue   (  unitID, COBValue, param1)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(COBValue) == "number","Argument COBValue is of invalid type - expected number");
assert(type(param1) == "number","Argument param1 is of invalid type - expected number");
return  numberMock
 end

function Spring.GiveOrderToUnit   ( )
return
 end

function Spring.GiveOrderToUnitMap   ( )
return
 end

function Spring.GiveOrderToUnitArray   ( )
return
 end

function Spring.GiveOrderArrayToUnitMap   ( )
return
 end

function Spring.GiveOrderArrayToUnitArray   ( )
return
 end

function Spring.AddGrass   (  x, z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.RemoveGrass   (  x, z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.LevelHeightMap   (  x,z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.AdjustHeightMap    (  x,z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.RevertHeightMap   (  x,z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.SetHeightMapFunc   ( )
return  numberMock
 end



function Spring.SetHeightMap    ( x, z, height, terraform)

assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(height) == "number","Argument height is of invalid type - expected number");
assert(type(terraform) == "number","Argument terraform is of invalid type - expected number");
return  numberMock
 end

function Spring.LevelSmoothMesh    (  x,z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end


function Spring.AdjustSmoothMesh    (  x,z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end


function Spring.RevertSmoothMesh    (  x,z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end


function Spring.SetSmoothMeshFunc   ( )
return  numberMock
 end

function Spring.AddSmoothMesh    ( x, z, height)

assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(height) == "number","Argument height is of invalid type - expected number");
return  numberMock
 end

function Spring.SetSmoothMesh    (
 x, z, height, terraform)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(height) == "number","Argument height is of invalid type - expected number");
assert(type(terraform) == "number","Argument terraform is of invalid type - expected number");
return  numberMock
 end

function Spring.SetMapSquareTerrainType   (  x, z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return
 end

function Spring.SetTerrainTypeData   ( )
return  booleanMock
 end

function Spring.SetMetalAmount    (  x, z, metalAmount)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(metalAmount) == "number","Argument metalAmount is of invalid type - expected number");
end


function Spring.EditUnitCmdDesc  (  unitID,  cmdDescID,  cmdArray )

assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(cmdDescID) == "number","Argument cmdDescID is of invalid type - expected number");
assert(type(cmdArray) == "table","Argument cmdArray is of invalid type - expected table");
return  numberMock
 end

function Spring.InsertUnitCmdDesc   (  unitID, cmdDescID, cmdArray)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(cmdDescID) == "number","Argument cmdDescID is of invalid type - expected number");
assert(type(cmdArray) == "table","Argument cmdArray is of invalid type - expected table");
return  numberMock
 end

function Spring.RemoveUnitCmdDesc   (  unitID, cmdDescID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(cmdDescID) == "number","Argument cmdDescID is of invalid type - expected number");
return  numberMock
 end

function Spring.SetNoPause   (  noPause)
assert(type(noPause) == "boolean","Argument noPause is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.SetUnitToFeature   (  tofeature)
assert(type(tofeature) == "boolean","Argument tofeature is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.SetExperienceGrade   ( )
return  numberMock
 end

function Spring.SpawnCEG   ( )
return  booleanMock
 end

function Spring.SpawnProjectile   (  weaponDefID, projectileParams)
assert(type(weaponDefID) == "number","Argument weaponDefID is of invalid type - expected number");
assert(type(projectileParams) == "table","Argument projectileParams is of invalid type - expected table");
return  numberMock
 end

function Spring.SetProjectileTarget   ( )
return  booleanMock
 end

function Spring.SetProjectileIsIntercepted    (  projID)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
return  numberMock
 end

function Spring.SetProjectileMoveControl    (
 projID, enable)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
assert(type(enable) == "boolean","Argument enable is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetProjectilePosition   (  projID, x, y, z)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.SetProjectileVelocity   (  projID, x, y, z)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.SetProjectileCollision   (  projID)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
return  numberMock
 end

function Spring.SetProjectileGravity   (  projID, grav)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
assert(type(grav) == "number","Argument grav is of invalid type - expected number");
return  numberMock
 end

function Spring.SetProjectileSpinAngle    (  projID, spinAngle)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
assert(type(spinAngle) == "number","Argument spinAngle is of invalid type - expected number");
return  numberMock
 end

function Spring.SetProjectileSpinSpeed    (  projID, speed)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
assert(type(speed) == "number","Argument speed is of invalid type - expected number");
return  numberMock
 end

function Spring.SetProjectileSpinVec    (  projID, x, y, z)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.SetProjectileCEG   (  projID, ceg_)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
assert(type(ceg_) == "string","Argument ceg_ is of invalid type - expected string");
return  numberMock
 end

function Spring.SetPieceProjectileParams    ( )
return  numberMock
 end

function Spring.SetProjectileAlwaysVisible    (  projectileID, alwaysVisible)
assert(type(projectileID) == "number","Argument projectileID is of invalid type - expected number");
assert(type(alwaysVisible) == "boolean","Argument alwaysVisible is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetProjectileDamages    (  unitID, weaponNum, damages)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(weaponNum) == "number","Argument weaponNum is of invalid type - expected number");
assert(type(damages) == "table","Argument damages is of invalid type - expected table");
return  numberMock
 end

