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

function Spring.SetUnitRulesParam (unitID, paramName)
    assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
    assert(type(paramName) == "string" or type(paramName) == "number","Argument paramName is of invalid type - expected string or number");
    return numberMock
end

function Spring.SetTeamRulesParam (teamID, paramName)
    assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
    assert(type(paramName) == "string" or type(paramName) == "number","Argument paramName is of invalid type - expected string or number");
    return numberMock
end

function Spring.SetGameRulesParam   (  paramName)
assert(type(paramName) == "string","Argument paramName is of invalid type - expected string");
return  stringMock
 end

function Spring.AddTeamResource   (  teamID, metal)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(metal) == "string","Argument metal is of invalid type - expected string");
return  numberMock
 end

function Spring.UseTeamResource   ( )
return  booleanMock
 end

function Spring.SetTeamResource   (  teamID, res, amount)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(res) == "string","Argument res is of invalid type - expected string");
assert(type(amount) == "number","Argument amount is of invalid type - expected number");
return  numberMock
 end

function Spring.SetTeamShareLevel   (  teamID, metal)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(metal) == "string","Argument metal is of invalid type - expected string");
return  numberMock
 end

function Spring.ShareTeamResource    (  teamID_)
assert(type(teamID_) == "number","Argument teamID_ is of invalid type - expected number");
return  numberMock
 end

function Spring.SetAlly    (  firstAllyTeamID, secondAllyTeamID, ally)
assert(type(firstAllyTeamID) == "number","Argument firstAllyTeamID is of invalid type - expected number");
assert(type(secondAllyTeamID) == "number","Argument secondAllyTeamID is of invalid type - expected number");
assert(type(ally) == "boolean","Argument ally is of invalid type - expected boolean");
return  numberMock
 end

function Spring.AssignPlayerToTeam    (  playerID, teamID)
assert(type(playerID) == "number","Argument playerID is of invalid type - expected number");
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return boolMock
end

function Spring.CreateUnit   (  unitDefID, x, y , z, facing, teamID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(teamID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.DestroyUnit   ( )
return  numberMock
 end

function Spring.TransferUnit   ( )
return  booleanMock
 end

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

--function Spring.SetUnitBlocking    (  unitID, blocking, collide, crushable)
--assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
--assert(type(blocking) == "boolean","Argument blocking is of invalid type - expected boolean");
--assert(type(collide) == "boolean","Argument collide is of invalid type - expected boolean");
--assert(type(crushable) == "boolean","Argument crushable is of invalid type - expected boolean");
--return  numberMock
-- end

--function Spring.SetUnitBlocking    (  unitID, depth, range)
--assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
--assert(type(depth) == "number","Argument depth is of invalid type - expected number");
--assert(type(range) == "number","Argument range is of invalid type - expected number");
--return  numberMock
-- end

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

function Spring.RemoveBuildingDecal   (  unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitMidAndAimPos    ( )
return  booleanMock
 end

function Spring.SetUnitRadiusAndHeight    (  unitID, radius, height)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(radius) == "number","Argument radius is of invalid type - expected number");
assert(type(height) == "number","Argument height is of invalid type - expected number");
return  numberMock
 end

function Spring.UnitWeaponFire   (  unitID, weaponID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(weaponID) == "number","Argument weaponID is of invalid type - expected number");
return  numberMock
 end

function Spring.UnitWeaponHoldFire   (  unitID, weaponID)
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


function Spring.IsDevLuaEnabled   ( )
return  booleanMock
 end

function Spring.IsEditDefsEnabled   ( )
return  booleanMock
 end

function Spring.AreHelperAIsEnabled   ( )
return  booleanMock
 end

function Spring.FixedAllies   ( )
return  booleanMock
 end

function Spring.IsGameOver   ( )
return  booleanMock
 end

function Spring.GetRulesInfoMap    ( )
return  stringMock
 end

function Spring.GetGameRulesParam   (  ruleIndex)
 assert(type(ruleIndex) == "number","Argument ruleIndex is of invalid type - expected number");
 return  numberMock
end

function Spring.GetGameRulesParams   ( )
 return  numberMock
end

function Spring.GetTeamRulesParam   (index, teamID)
 assert(type(index) == "number","Argument index is of invalid type - expected number");
 assert(type(teamID) == "number","Argument teamID, is of invalid type - expected number");
 return  numberMock
end

function Spring.GetTeamRulesParams   (teamID)
 assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
 return  numberMock
end

function Spring.GetUnitRulesParam   (unitID, ruleName)
 assert(type(unitID) == "number","Argument index is of invalid type - expected number");
 assert(type(ruleName) == "string","Argument param is of invalid type - expected string");
 return  numberMock
end

function Spring.GetUnitRulesParam   (unitID, index)
 assert(type(unitID) == "number","Argument index is of invalid type - expected number");
 assert(type(index) == "number","Argument index is of invalid type - expected number");
 return  numberMock
end

function Spring.GetUnitRulesParams   (unitID)
 assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
 return  numberMock
end

function Spring.GetModOptions   ( )
return  stringMock
 end

function Spring.GetMapOptions   ( )
return  stringMock
 end

function Spring.GetModOptions.exampleOption  ()
return  numberMock
 end

function Spring.GetGameFrame   ( )
return  numberMock
 end

function Spring.GetGameSeconds   ( )
return  numberMock
 end

function Spring.GetWind   ( )
return  numberMock
 end

function Spring.GetHeadingFromVector   (  x, z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.GetVectorFromHeading   (  heading)
assert(type(heading) == "number","Argument heading is of invalid type - expected number");
return  numberMock
 end

function Spring.GetSideData   (  sideName)
assert(type(sideName) == "string","Argument sideName is of invalid type - expected string");
return  stringMock
 end

function Spring.GetAllyTeamStartBox   (  allyID)
assert(type(allyID) == "number","Argument allyID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamStartPosition   (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetPlayerList   (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamList   (  allyTeamID)
assert(type(allyTeamID) == "number","Argument allyTeamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetAllyTeamList   ( )
return  numberMock
 end

function Spring.GetPlayerInfo   (  playerID)
assert(type(playerID) == "number","Argument playerID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetPlayerControlledUnit   (  playerID)
assert(type(playerID) == "number","Argument playerID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetAIInfo   (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetAllyTeamInfo   (  allyteamID)
assert(type(allyteamID) == "number","Argument allyteamID is of invalid type - expected number");
return  tableMock
 end

function Spring.GetTeamInfo   (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamResources   (  metal, teamID)
assert(type(metal) == "string","Argument metal is of invalid type - expected string");
assert(type(teamID) == "number","Argument teamID, is of invalid type - expected number");
return
 end

function Spring.GetTeamUnitStats   (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamResourceStats    (  metal, teamID)
assert(type(metal) == "string","Argument metal is of invalid type - expected string");
assert(type(teamID) == "number","Argument teamID, is of invalid type - expected number");
return
 end

function Spring.GetTeamStatsHistory   (  teamID, endIndex, startIndex)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(endIndex) == "number","Argument endIndex is of invalid type - expected number");
assert(type(startIndex) == "number","Argument startIndex is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamLuaAI   (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.AreTeamsAllied   (  teamID1)
assert(type(teamID1) == "number","Argument teamID1 is of invalid type - expected number");
return  booleanMock
 end

function Spring.ArePlayersAllied   (  playerID1)
assert(type(playerID1) == "number","Argument playerID1 is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetAllUnits   ( )
return  numberMock
 end

function Spring.GetTeamUnits   (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamUnitsSorted   (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return
 end

function Spring.GetTeamUnitsCounts   (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamUnitsByDefs   (  teamID, unitDefID)
assert(type(teamID) == "number","Argument teamID, is of invalid type - expected number");
assert(type(unitDefID) == "number","Argument unitDefID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamUnitDefCount   (  teamID, unitDefID)
assert(type(teamID) == "number","Argument teamID, is of invalid type - expected number");
assert(type(unitDefID) == "number","Argument unitDefID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamUnitCount   (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetUnitsInRectangle   (  xmin, teamID, zmin, zmax, xmax)
assert(type(xmin) == "number","Argument xmin, is of invalid type - expected number");
assert(type(teamID) == "number","Argument teamID] is of invalid type - expected number");
assert(type(zmin) == "number","Argument zmin, is of invalid type - expected number");
assert(type(zmax) == "number","Argument zmax is of invalid type - expected number");
assert(type(xmax) == "number","Argument xmax, is of invalid type - expected number");
return  numberMock
 end

function Spring.GetUnitsInBox   ( )
return  numberMock
 end

function Spring.GetUnitsInSphere   (  radius, y, z, teamID, x)
assert(type(radius) == "number","Argument radius is of invalid type - expected number");
assert(type(y) == "number","Argument y, is of invalid type - expected number");
assert(type(z) == "number","Argument z, is of invalid type - expected number");
assert(type(teamID) == "number","Argument teamID] is of invalid type - expected number");
assert(type(x) == "number","Argument x, is of invalid type - expected number");
return  numberMock
 end

function Spring.GetUnitsInCylinder (x, z, radius, teamID)
    assert(type(x) == "number","Argument x, is of invalid type - expected number");
    assert(type(z) == "number","Argument z, is of invalid type - expected number");
    assert(type(radius) == "number","Argument radius is of invalid type - expected number");
    assert(type(teamID) == "number","Argument teamID] is of invalid type - expected number");
return  numberMock
end

function Spring.GetUnitsInPlanes   ( )
return  numberMock
 end

function Spring.GetUnitNearestAlly   (  range, unitID)
assert(type(range) == "number","Argument range is of invalid type - expected number");
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetUnitNearestEnemy   (  range, unitID)
assert(type(range) == "number","Argument range is of invalid type - expected number");
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.ValidUnitID   (  unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetUnitIsDead   (  unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end


function Spring.SetLastMessagePosition   (  x, y, z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.Echo (msg)
 assert(type(msg) == "string","Argument command1 is of invalid type - expected string");
return
 end

function Spring.Log ( command1, logLevel )
 assert(type(command1) == "string","Argument command1 is of invalid type - expected string");
 assert(type(logLevel) == "string" or type(logLevel) == "number","Argument command1 is of invalid type - expected string or number");
return
 end

function Spring.SendCommands    (  command1)
assert(type(command1) == "string","Argument command1 is of invalid type - expected string");
return  stringMock
 end

function Spring.SetActiveCommand    (  action, actionExtra)
assert(type(action) == "string","Argument action is of invalid type - expected string");
assert(type(actionExtra) == "string","Argument actionExtra is of invalid type - expected string");
return  booleanMock
 end

function Spring.LoadCmdColorsConfig    (  config)
assert(type(config) == "string","Argument config is of invalid type - expected string");
return  stringMock
 end

function Spring.LoadCtrlPanelConfig    (  config)
assert(type(config) == "string","Argument config is of invalid type - expected string");
return  stringMock
 end

function Spring.ForceLayoutUpdate    ( )
return
 end

function Spring.SetDrawSelectionInfo    (  enable)
assert(type(enable) == "boolean","Argument enable is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.SetMouseCursor    (  cursorName, scale)
assert(type(cursorName) == "string","Argument cursorName is of invalid type - expected string");
assert(type(scale) == "number","Argument scale is of invalid type - expected number");
return  stringMock
 end

function Spring.WarpMouse    (  x, y)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
return  numberMock
 end

function Spring.SetLosViewColors    (  always, LOS, radar, jam, radar2)
assert(type(always) == "table","Argument always is of invalid type - expected table");
assert(type(LOS) == "table","Argument LOS is of invalid type - expected table");
assert(type(radar) == "table","Argument radar is of invalid type - expected table");
assert(type(jam) == "table","Argument jam is of invalid type - expected table");
assert(type(radar2) == "table","Argument radar2 is of invalid type - expected table");
return  tableMock
 end

function Spring.SendMessage   (  message)
assert(type(message) == "string","Argument message is of invalid type - expected string");
return  stringMock
 end

function Spring.SendMessageToPlayer   (  playerID, message)
assert(type(playerID) == "number","Argument playerID is of invalid type - expected number");
assert(type(message) == "string","Argument message is of invalid type - expected string");
return  numberMock
 end

function Spring.SendMessageToTeam   (  teamID, message)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(message) == "string","Argument message is of invalid type - expected string");
return  numberMock
 end

function Spring.SendMessageToAllyTeam   (  allyID, message)
assert(type(allyID) == "number","Argument allyID is of invalid type - expected number");
assert(type(message) == "string","Argument message is of invalid type - expected string");
return  numberMock
 end

function Spring.SendMessageToSpectators   (  message)
assert(type(message) == "string","Argument message is of invalid type - expected string");
return  stringMock
 end

function Spring.MarkerAddPoint    (  x, y, z, text)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(text) == "string","Argument text is of invalid type - expected string");
return  numberMock
 end

function Spring.MarkerAddLine    (  x1)
assert(type(x1) == "number","Argument x1 is of invalid type - expected number");
return  numberMock
 end

function Spring.MarkerErasePosition    (  x, y, z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.LoadSoundDef   (  soundfile)
assert(type(soundfile) == "string","Argument soundfile is of invalid type - expected string");
return  booleanMock
 end

function Spring.PlaySoundFile    (  soundfile, volume)
assert(type(soundfile) == "string","Argument soundfile is of invalid type - expected string");
assert(type(volume) == "number","Argument volume is of invalid type - expected number");
return  booleanMock
 end

function Spring.PlaySoundStream   (  oggfile, volume)
assert(type(oggfile) == "string","Argument oggfile is of invalid type - expected string");
assert(type(volume) == "number","Argument volume is of invalid type - expected number");
return  booleanMock
 end

function Spring.StopSoundStream   ( )
return
 end

function Spring.PauseSoundStream   ( )
return
 end

function Spring.SetSoundStreamVolume   (  volume)
assert(type(volume) == "number","Argument volume is of invalid type - expected number");
return  numberMock
 end

function Spring.SendLuaUIMsg    (  message, mode)
assert(type(message) == "string","Argument message is of invalid type - expected string");
assert(type(mode) == "string","Argument mode is of invalid type - expected string");
return  stringMock
 end

function Spring.SendLuaGaiaMsg    (  message)
assert(type(message) == "string","Argument message is of invalid type - expected string");
return  stringMock
 end

function Spring.SendLuaRulesMsg   (  message)
assert(type(message) == "string","Argument message is of invalid type - expected string");
return  stringMock
 end

function Spring.SendSkirmishAIMessage    (  aiTeam, message)
assert(type(aiTeam) == "number","Argument aiTeam is of invalid type - expected number");
assert(type(message) == "string","Argument message is of invalid type - expected string");
return  booleanMock
 end

function Spring.SetUnitLeaveTracks   (  unitID, leavetracks)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(leavetracks) == "boolean","Argument leavetracks is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SelectUnitMap   (  keyUnitIDvalueAnything, append)
assert(type(keyUnitIDvalueAnything) == "table","Argument keyUnitIDvalueAnything is of invalid type - expected table");
assert(type(append) == "boolean","Argument append is of invalid type - expected boolean");
return  tableMock
 end

function Spring.SelectUnitArray   (  unitIDs, append)
assert(type(unitIDs) == "table","Argument unitIDs is of invalid type - expected table");
assert(type(append) == "boolean","Argument append is of invalid type - expected boolean");
return  tableMock
 end

function Spring.SetDrawSelectionInfo   (  drawSelectionInfo)
assert(type(drawSelectionInfo) == "boolean","Argument drawSelectionInfo is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.SetUnitGroup    (  unitID, groupID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(groupID) == "number","Argument groupID is of invalid type - expected number");
return  numberMock
 end

function Spring.GiveOrder    ( )
return  booleanMock
 end

function Spring.GiveOrderToUnit    ( )
return  booleanMock
 end

function Spring.GiveOrderToUnitMap    ( )
return  booleanMock
 end

function Spring.GiveOrderToUnitArray    ( )
return  booleanMock
 end

function Spring.GiveOrderArrayToUnitMap    ( )
return  booleanMock
 end

function Spring.GiveOrderArrayToUnitArray    ( )
return  booleanMock
 end

function Spring.SetBuildFacing   (  Facing)
assert(type(Facing) == "number","Argument Facing is of invalid type - expected number");
return  numberMock
 end

function Spring.SetBuildSpacing   (  Spacing)
assert(type(Spacing) == "number","Argument Spacing is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitNoDraw    (  unitID, noDraw)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(noDraw) == "boolean","Argument noDraw is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetUnitNoSelect    (  unitID, noSelect)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(noSelect) == "boolean","Argument noSelect is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetUnitNoMinimap    (  unitID, noMinimap)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(noMinimap) == "boolean","Argument noMinimap is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetDrawSky   (  drawSky)
assert(type(drawSky) == "boolean","Argument drawSky is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.SetDrawWater   (  drawWater)
assert(type(drawWater) == "boolean","Argument drawWater is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.SetDrawGround   (  drawGround)
assert(type(drawGround) == "boolean","Argument drawGround is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.SetWaterParams    (  params)
assert(type(params) == "table","Argument params is of invalid type - expected table");
return  tableMock
 end

function Spring.SetLogSectionFilterLevel   (  sectionName, logLevel)
assert(type(sectionName) == "string","Argument sectionName is of invalid type - expected string");
assert(type(logLevel) == "number","Argument logLevel is of invalid type - expected number");
return  booleanMock
 end


function Spring.SetDrawGroundDeferred   ( Activate)
assert(type(Activate) == "boolean","Argument Activate is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.SetDrawModelsDeferred    (  Activate)
assert(type(Activate) == "boolean","Argument Activate is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.DrawUnitCommands   (  unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.SetTeamColor   (  teamID, r, g, b)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(r) == "number","Argument r is of invalid type - expected number");
assert(type(g) == "number","Argument g is of invalid type - expected number");
assert(type(b) == "number","Argument b is of invalid type - expected number");
return  numberMock
 end

function Spring.AssignMouseCursor   ( )
return  booleanMock
 end

function Spring.ReplaceMouseCursor    (  oldFileName, newFileName, hotSpotTopLeft)
assert(type(oldFileName) == "string","Argument oldFileName is of invalid type - expected string");
assert(type(newFileName) == "string","Argument newFileName is of invalid type - expected string");
assert(type(hotSpotTopLeft) == "boolean","Argument hotSpotTopLeft is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.SetCustomCommandDrawData    ( )
return  tableMock
 end

function Spring.SetShareLevel    (  metal)
assert(type(metal) == "string","Argument metal is of invalid type - expected string");
return  stringMock
 end

function Spring.ShareResources    (  teamID, units)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(units) == "string","Argument units is of invalid type - expected string");
return  numberMock
 end

function Spring.AddUnitIcon   (  iconName, texFile, size, dist, radAdjust)
assert(type(iconName) == "string","Argument iconName is of invalid type - expected string");
assert(type(texFile) == "string","Argument texFile is of invalid type - expected string");
assert(type(size) == "number","Argument size is of invalid type - expected number");
assert(type(dist) == "number","Argument dist is of invalid type - expected number");
assert(type(radAdjust) == "boolean","Argument radAdjust is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.FreeUnitIcon   (  iconName)
assert(type(iconName) == "string","Argument iconName is of invalid type - expected string");
return  booleanMock
 end

function Spring.SetUnitDefIcon    ( unitDefID, iconName)
assert(type(unitDefID) == "number","Argument unitDefID is of invalid type - expected number");
assert(type(iconName) == "string","Argument iconName is of invalid type - expected string");
return  numberMock
 end

function Spring.SetUnitDefImage    ( unitDefID)
assert(type(unitDefID) == "number","Argument unitDefID is of invalid type - expected number");
return  numberMock
 end

function Spring.SetCameraState   (  camState, camTime)
assert(type(camState) == "table","Argument camState is of invalid type - expected table");
assert(type(camTime) == "number","Argument camTime is of invalid type - expected number");
return  booleanMock
 end

function Spring.SetCameraTarget   (  x, y, z, transTime)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(transTime) == "number","Argument transTime is of invalid type - expected number");
return  numberMock
 end

function Spring.SetCameraOffset    ( )
return  numberMock
 end

function Spring.ExtractModArchiveFile   (  modfile)
assert(type(modfile) == "string","Argument modfile is of invalid type - expected string");
return  stringMock
 end

function Spring.CreateDir    (  path)
assert(type(path) == "number","Argument path is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetConfigInt    (  name, default, setInOverlay)
assert(type(name) == "string","Argument name is of invalid type - expected string");
assert(type(default) == "number","Argument default is of invalid type - expected number");
assert(type(setInOverlay) == "boolean","Argument setInOverlay is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetConfigInt    (  name, value, useOverlay)
assert(type(name) == "string","Argument name is of invalid type - expected string");
assert(type(value) == "number","Argument value is of invalid type - expected number");
assert(type(useOverlay) == "boolean","Argument useOverlay is of invalid type - expected boolean");
return  stringMock
 end

function Spring.GetConfigString    (  name, default, setInOverlay)
assert(type(name) == "string","Argument name is of invalid type - expected string");
assert(type(default) == "string","Argument default is of invalid type - expected string");
assert(type(setInOverlay) == "boolean","Argument setInOverlay is of invalid type - expected boolean");
return  stringMock
 end

function Spring.SetConfigString    (  name, value, useOverlay)
assert(type(name) == "string","Argument name is of invalid type - expected string");
assert(type(value) == "string","Argument value is of invalid type - expected string");
assert(type(useOverlay) == "boolean","Argument useOverlay is of invalid type - expected boolean");
return  stringMock
 end

function Spring.AddWorldIcon   (  cmdID, x, y, z)
assert(type(cmdID) == "number","Argument cmdID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.AddWorldText   (  text, x, y, z)
assert(type(text) == "string","Argument text is of invalid type - expected string");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  stringMock
 end

function Spring.AddWorldUnit   ( )
return  numberMock
 end

function Spring.SetSunManualControl   (  setManualControl)
assert(type(setManualControl) == "boolean","Argument setManualControl is of invalid type - expected boolean");
return booleanMock
end

function Spring.SetSunParameters  (  dirX, dirY, dirZ, dist, startTime, orbitTime)
assert(type(dirX) == "number","Argument dirX is of invalid type - expected number");
assert(type(dirY) == "number","Argument dirY is of invalid type - expected number");
assert(type(dirZ) == "number","Argument dirZ is of invalid type - expected number");
assert(type(dist) == "number","Argument dist is of invalid type - expected number");
assert(type(startTime) == "number","Argument startTime is of invalid type - expected number");
assert(type(orbitTime) == "number","Argument orbitTime is of invalid type - expected number");
return  numberMock
 end

function Spring.SetSunDirection   (  dirX, dirY, dirZ)
assert(type(dirX) == "number","Argument dirX is of invalid type - expected number");
assert(type(dirY) == "number","Argument dirY is of invalid type - expected number");
assert(type(dirZ) == "number","Argument dirZ is of invalid type - expected number");
return  numberMock
 end

function Spring.SetSunLighting    (  params)
assert(type(params) == "table","Argument params is of invalid type - expected table");
return  tableMock
 end

function Spring.SetAtmosphere    (  params)
assert(type(params) == "table","Argument params is of invalid type - expected table");
return  tableMock
 end

function Spring.Reload   (  startscript)
assert(type(startscript) == "string","Argument startscript is of invalid type - expected string");
return booleanMock
end


function Spring.Restart   ( commandline_)
assert(type(commandline_) == "string","Argument commandline_ is of invalid type - expected string");
return booleanMock
 end

function Spring.SetWMIcon    (  iconFileName)
assert(type(iconFileName) == "string","Argument iconFileName is of invalid type - expected string");
return  stringMock
 end

function Spring.SetWMCaption    (  title, titleShort)
assert(type(title) == "string","Argument title is of invalid type - expected string");
assert(type(titleShort) == "string","Argument titleShort is of invalid type - expected string");
return  stringMock
 end

function Spring.ClearWatchdogTimer    (  threadName)
assert(type(threadName) == "string","Argument threadName is of invalid type - expected string");
return  stringMock
 end

function Spring.SetClipboard    (  text)
assert(type(text) == "string","Argument text is of invalid type - expected string");
return  stringMock
 end

function Spring.AddMapLight    ( lightParams)
assert(type(lightParams) == "table","Argument lightParams is of invalid type - expected table");
return  tableMock
 end

function Spring.AddModelLight    ( lightParams)
assert(type(lightParams) == "table","Argument lightParams is of invalid type - expected table");
return  tableMock
 end

function Spring.UpdateMapLight   (  lightHandle, lightParams)
assert(type(lightHandle) == "number","Argument lightHandle is of invalid type - expected number");
assert(type(lightParams) == "table","Argument lightParams is of invalid type - expected table");
return  numberMock
 end

function Spring.UpdateModelLight   (  lightHandle, lightParams)
assert(type(lightHandle) == "number","Argument lightHandle is of invalid type - expected number");
assert(type(lightParams) == "table","Argument lightParams is of invalid type - expected table");
return  numberMock
 end

function Spring.SetMapLightTrackingState   ( )
return  booleanMock
 end

function Spring.SetModelLightTrackingState   ( )
return  booleanMock
 end

function Spring.SetMapShadingTexture   (  texType, texName)
assert(type(texType) == "string","Argument texType is of invalid type - expected string");
assert(type(texName) == "string","Argument texName is of invalid type - expected string");
return  stringMock
 end

function Spring.SetMapSquareTexture   (  texSqrX, texSqrY, luaTexName)
assert(type(texSqrX) == "number","Argument texSqrX is of invalid type - expected number");
assert(type(texSqrY) == "number","Argument texSqrY is of invalid type - expected number");
assert(type(luaTexName) == "string","Argument luaTexName is of invalid type - expected string");
return  numberMock
 end

function Spring.SetMapShader   (  standardShaderID, deferredShaderID)
assert(type(standardShaderID) == "number","Argument standardShaderID is of invalid type - expected number");
assert(type(deferredShaderID) == "number","Argument deferredShaderID is of invalid type - expected number");
return  numberMock
 end
 
 
function Spring.IsReplay   ( )
return  booleanMock
 end

function Spring.GetReplayLength    ( )
return  numberMock
 end

function Spring.GetSpectatingState   ( )
return  booleanMock
 end

function Spring.GetModUICtrl   ( )
return  booleanMock
 end

function Spring.GetMyAllyTeamID   ( )
return  numberMock
 end

function Spring.GetMyTeamID   ( )
return  numberMock
 end

function Spring.GetMyPlayerID   ( )
return  numberMock
 end

function Spring.GetLocalPlayerID   ( )
return  numberMock
 end

function Spring.GetLocalTeamID   ( )
return  numberMock
 end

function Spring.GetLocalAllyTeamID   ( )
return  numberMock
 end

function Spring.GetPlayerRoster   (  sortType)
assert(type(sortType) == "number","Argument sortType is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamColor   (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamOrigColor   (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetPlayerTraffic   (  playerID, packetID)
assert(type(playerID) == "number","Argument playerID is of invalid type - expected number");
assert(type(packetID) == "number","Argument packetID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetSoundStreamTime   ( )
return  numberMock
 end

function Spring.GetCameraNames   ( )
return  tableMock
 end

function Spring.GetCameraState   ( )
return  tableMock
 end

function Spring.GetCameraPosition   ( )
return  numberMock
 end

function Spring.GetCameraDirection   ( )
return  numberMock
 end

function Spring.GetCameraFOV   ( )
return  numberMock
 end

function Spring.GetCameraVectors   ( )
return  tableMock
 end

function Spring.GetVisibleUnits   (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  tableMock
 end

function Spring.GetVisibleFeatures   (  allyTeamID)
assert(type(allyTeamID) == "number","Argument allyTeamID is of invalid type - expected number");
return  tableMock
 end

function Spring.IsAABBInView   ( )
return  booleanMock
 end

function Spring.IsSphereInView   (  x, y, z, radius)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(radius) == "number","Argument radius is of invalid type - expected number");
return  booleanMock
 end

function Spring.IsUnitIcon   (  unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.IsUnitInView   (  unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.IsUnitVisible   (  unitID, radius, checkIcons)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(radius) == "number","Argument radius is of invalid type - expected number");
assert(type(checkIcons) == "boolean","Argument checkIcons is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.WorldToScreenCoords   (  x, y, z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.TraceScreenRay   ( )
return
 end

function Spring.GetPixelDir    (  x, y)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
return  numberMock
 end

function Spring.GetViewGeometry   ( )
return  numberMock
 end

function Spring.GetWindowGeometry   ( )
return  numberMock
 end

function Spring.GetScreenGeometry    ()
return  numberMock
 end

function Spring.IsUnitAllied   (  unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetUnitViewPosition   (  unitID, midPos)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(midPos) == "boolean","Argument midPos is of invalid type - expected boolean");
return  numberMock
 end

function Spring.GetUnitTransformMatrix   (  unitID, invert)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(invert) == "boolean","Argument invert is of invalid type - expected boolean");
return  numberMock
 end

function Spring.GetSelectedUnits   ( )
return  tableMock
 end

function Spring.GetSelectedUnitsSorted   ( )
return  tableMock
 end

function Spring.GetSelectedUnitsCounts   ( )
return  tableMock
 end

function Spring.GetSelectedUnitsCount   ( )
return  numberMock
 end

function Spring.IsUnitSelected   (  unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetUnitGroup   (  unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetGroupList   ( )
return  tableMock
 end

function Spring.GetSelectedGroup   ( )
return  numberMock
 end

function Spring.GetGroupAIName   (  groupID)
assert(type(groupID) == "number","Argument groupID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetGroupAIList   ( )
return  tableMock
 end

function Spring.GetGroupUnits   (  groupID)
assert(type(groupID) == "number","Argument groupID is of invalid type - expected number");
return  tableMock
 end

function Spring.GetGroupUnitsSorted   (  groupID)
assert(type(groupID) == "number","Argument groupID is of invalid type - expected number");
return
 end

function Spring.GetGroupUnitsCounts   (  groupID)
assert(type(groupID) == "number","Argument groupID is of invalid type - expected number");
return  tableMock
 end

function Spring.GetGroupUnitsCount   (  groupID)
assert(type(groupID) == "number","Argument groupID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetVisibleProjectiles    ( )
return  tableMock
 end

function Spring.IsGUIHidden   ( )
return  booleanMock
 end

function Spring.HaveShadows   ( )
return  booleanMock
 end

function Spring.HaveAdvShading   ( )
return  booleanMock
 end

function Spring.GetWaterMode   ( )
return  numberMock
 end

function Spring.GetMapDrawMode   ( )
return
 end

function Spring.GetDrawSelectionInfo    ( )
return  booleanMock
 end

function Spring.GetUnitLuaDraw   (  unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetUnitNoDraw   (  unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetUnitNoMinimap   (  unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetUnitNoSelect   (  unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetMiniMapGeometry   ( )
return  numberMock
 end

function Spring.GetMiniMapDualScreen   ( )
return  stringMock
 end

function Spring.IsAboveMiniMap   (  x, y)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetActiveCommand   ( )
return  numberMock
 end

function Spring.GetDefaultCommand   ( )
return  numberMock
 end

function Spring.GetActiveCmdDescs   ( )
return  tableMock
 end

function Spring.GetActiveCmdDesc   (  index)
assert(type(index) == "number","Argument index is of invalid type - expected number");
return  tableMock
 end

function Spring.GetCmdDescIndex   (  cmdID)
assert(type(cmdID) == "number","Argument cmdID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetActivePage   ( )
return  numberMock
 end

function Spring.GetBuildFacing   ( )
return  numberMock
 end

function Spring.GetBuildSpacing   ( )
return  numberMock
 end

function Spring.GetGatherMode   ( )
return  numberMock
 end

function Spring.GetInvertQueueKey   ( )
return  booleanMock
 end

function Spring.GetMouseState   ( )
return  numberMock
 end

function Spring.GetMouseCursor   ( )
return  stringMock
 end

function Spring.GetMouseStartPosition   (  mouseButton)
assert(type(mouseButton) == "number","Argument mouseButton is of invalid type - expected number");
return  numberMock
 end

function Spring.GetKeyState   (  key)
assert(type(key) == "number","Argument key is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetModKeyState   ( )
return  booleanMock
 end

function Spring.GetPressedKeys   ( )
return  tableMock
 end

function Spring.GetKeyCode   (  keysym)
assert(type(keysym) == "string","Argument keysym is of invalid type - expected string");
return  stringMock
 end

function Spring.GetKeySymbol   (  key)
assert(type(key) == "number","Argument key is of invalid type - expected number");
return  numberMock
 end

function Spring.GetKeyBindings   (  keyset)
assert(type(keyset) == "string","Argument keyset is of invalid type - expected string");
return  tableMock
 end

function Spring.GetActionHotKeys   (  action)
assert(type(action) == "string","Argument action is of invalid type - expected string");
return  tableMock
 end

function Spring.GetLastMessagePositions   ( )
return  tableMock
 end

function Spring.GetConsoleBuffer   (  maxLines)
assert(type(maxLines) == "number","Argument maxLines is of invalid type - expected number");
return  tableMock
 end

function Spring.GetCurrentTooltip   ( )
return  stringMock
 end

function Spring.GetLosViewColors   ( )
return  tableMock
 end

function Spring.GetConfigParams    ( )
return  tableMock
 end

function Spring.GetFPS   ( )
return  numberMock
 end

function Spring.GetDrawFrame   ( )
return  numberMock
 end

function Spring.GetGameSpeed    ( )
return  numberMock
 end

function Spring.GetFrameTimeOffset   ( )
return  numberMock
 end

function Spring.GetLastUpdateSeconds   ( )
return  numberMock
 end

function Spring.GetHasLag   ( )
return  booleanMock
 end

function Spring.GetTimer   ( )
return  numberMock
 end

function Spring.DiffTimers   (  timercur, timerago, inMilliseconds)
assert(type(timercur) == "number","Argument timercur is of invalid type - expected number");
assert(type(timerago) == "number","Argument timerago is of invalid type - expected number");
assert(type(inMilliseconds) == "boolean","Argument inMilliseconds is of invalid type - expected boolean");
return  numberMock
 end

function Spring.GetMapSquareTexture   (  texSqrX, texSqrY, texMipLvl, luaTexName)
assert(type(texSqrX) == "number","Argument texSqrX is of invalid type - expected number");
assert(type(texSqrY) == "number","Argument texSqrY is of invalid type - expected number");
assert(type(texMipLvl) == "number","Argument texMipLvl is of invalid type - expected number");
assert(type(luaTexName) == "string","Argument luaTexName is of invalid type - expected string");
return  numberMock
 end

function Spring.GetLogSections   ( )
return  tableMock
 end

function Spring.GetClipboard    ( )
return  stringMock
 end

