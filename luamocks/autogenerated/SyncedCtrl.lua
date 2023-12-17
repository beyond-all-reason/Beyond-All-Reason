---SyncedCtrl

---
---Parameters
---@param firstAllyTeamID number
---@param secondAllyTeamID number
---@param ally boolean
---@return nil
function Spring.SetAlly(firstAllyTeamID, secondAllyTeamID, ally) end

---Changes the start box position of an allyTeam.
---@param allyTeamID integer
---@param xMin integer left start box boundary (elmos)
---@param zMin integer top start box boundary (elmos)
---@param xMax integer right start box boundary (elmos)
---@param zMax integer bottom start box boundary (elmos)
---@return nil
function Spring.SetAllyTeamStartBox(allyTeamID, xMin, zMin, xMax, zMax) end

---Parameters
---@param playerID number
---@param teamID number
---@return nil
function Spring.AssignPlayerToTeam(playerID, teamID) end

---Parameters
---@param allyTeamID number
---@param globallos boolean
---@return nil
function Spring.SetGlobalLos(allyTeamID, globallos) end


---
---Parameters
---@param teamID number
---@return nil
function Spring.KillTeam(teamID) end

---Parameters
---@param allyTeamID1 number (optional)
---@param allyTeamID2 number (optional)
---@param allyTeamIDn number (optional)
---@return nil
function Spring.GameOver([allyTeamID1[, allyTeamID2[, allyTeamIDn]]]) end


---
---Parameters
---@param strength number
---@return nil
function Spring.SetTidal(strength) end

---Parameters
---@param minStrength number
---@param maxStrength number
---@return nil
function Spring.SetWind(minStrength, maxStrength) end

---Parameters
---@param teamID number
---@param type string
---@param amount number
---@return nil
function Spring.AddTeamResource(teamID, type, amount) end

---Parameters
---@param teamID number
---@param type string
---@param amount ?number|table
---@return ?nil|bool hadEnough
function Spring.UseTeamResource(teamID, type, amount) end

---Parameters
---@param teamID number
---@param res string
---@param amount number
---@return nil
function Spring.SetTeamResource(teamID, res, amount) end

---Parameters
---@param teamID number
---@param type string
---@param amount number
---@return nil
function Spring.SetTeamShareLevel(teamID, type, amount) end

---Parameters
---@param teamID_src number
---@param teamID_recv number
---@param type string
---@param amount number
---@return nil
function Spring.ShareTeamResource(teamID_src, teamID_recv, type, amount) end


---
---Fields
---@param private boolean (optional)
---@param allied boolean (optional)
---@param inlos boolean (optional)
---@param inradar boolean (optional)
---@param public boolean (optional)
---Parameters
---@param paramName string
---@param paramValue ?number|string
---@param losAccess losAccess (optional)
---@return nil
function Spring.SetGameRulesParam(paramName, paramValue[, losAccess]) end

---Parameters
---@param teamID number
---@param paramName string
---@param paramValue ?number|string
---@param losAccess losAccess (optional)
---@return nil
function Spring.SetTeamRulesParam(teamID, paramName, paramValue[, losAccess]) end

---Parameters
---@param playerID number
---@param paramName string
---@param paramValue ?number|string
---@param losAccess losAccess (optional)
---@return nil
function Spring.SetPlayerRulesParam(playerID, paramName, paramValue[, losAccess]) end

---Parameters
---@param unitID number
---@param paramName string
---@param paramValue ?number|string
---@param losAccess losAccess (optional)
---@return nil
function Spring.SetUnitRulesParam(unitID, paramName, paramValue[, losAccess]) end

---Parameters
---@param featureID number
---@param paramName string
---@param paramValue ?number|string
---@param losAccess losAccess (optional)
---@return nil
function Spring.SetFeatureRulesParam(featureID, paramName, paramValue[, losAccess]) end


---
---Parameters
---@param unitID number
---@param funcName ?number|string
---@param retArgs number
---@param COBArg1 (optional)
---@param COBArg2 (optional)
---@param COBArgn (optional)
---@return ?nil|number returnValue
function Spring.CallCOBScript(unitID, funcName, retArgs[, COBArg1[, COBArg2[, COBArgn]]]) end

---@return ?nil|number returnArg1
function Spring.CallCOBScript(unitID, funcName, retArgs[, COBArg1[, COBArg2[, COBArgn]]]) end

---@return ?nil|number returnArg2
function Spring.CallCOBScript(unitID, funcName, retArgs[, COBArg1[, COBArg2[, COBArgn]]]) end

---@return ?nil|number returnArgn
function Spring.CallCOBScript(unitID, funcName, retArgs[, COBArg1[, COBArg2[, COBArgn]]]) end

---Parameters
---@param unitID number
---@param funcName string
---@return ?nil|number funcID
function Spring.GetCOBScriptID(unitID, funcName) end


---
---Parameters
---@param unitDefName string|number
---@param x number
---@param y number
---@param z number
---@param facing string|number
---@param teamID number
---@param build boolean (default): `false`
---@param flattenGround boolean (default): `true`
---@param unitID number (optional)
---@param builderID number (optional)
---@return number|nil unitID meaning unit was created
function Spring.CreateUnit(unitDefName, x, y, z, facing, teamID[, build=false[, flattenGround=true[, unitID[, builderID]]]]) end

local newthing = Spring.CreateUnit()

---Parameters
---@param unitID number
---@param selfd boolean (default): `false`
---@param reclaimed boolean (default): `false`
---@param attackerID number (optional)
---@param cleanupImmediately boolean (default): `false`
---@return nil
function Spring.DestroyUnit(unitID[, selfd=false[, reclaimed=false[, attackerID[, cleanupImmediately=false]]]]) end

---Parameters
---@param unitID number
---@param newTeamID number
---@param given boolean (default): `true`
---@return nil
function Spring.TransferUnit(unitID, newTeamID[, given=true]) end


---
---Parameters
---@param unitID number
---@param where {[number]=number,...}
---@return nil
function Spring.SetUnitCosts(unitID, where) end


---
---Parameters
---@param unitID number
---@param res string
---@param amount number
---@return nil
function Spring.SetUnitResourcing(unitID, res, amount) end

---Parameters
---@param unitID number
---@param res {[string]=number,...}
---@return nil
function Spring.SetUnitResourcing(unitID, res) end

---Parameters
---@param unitID number
---@param tooltip string
---@return nil
function Spring.SetUnitTooltip(unitID, tooltip) end

---Parameters
---@param unitID number
---@param health number|{[string]=number,...}
---@return nil
function Spring.SetUnitHealth(unitID, health) end

---Parameters
---@param unitID number
---@param maxHealth number
---@return nil
function Spring.SetUnitMaxHealth(unitID, maxHealth) end

---Parameters
---@param unitID number
---@param stockpile number (optional)
---@param buildPercent number (optional)
---@return nil
function Spring.SetUnitStockpile(unitID[, stockpile[, buildPercent]]) end

---Parameters
---@param unitID number
---@param forceUseWeapons number (optional)
---@param allowUseWeapons number (optional)
---@return nil
function Spring.SetUnitUseWeapons(unitID[, forceUseWeapons[, allowUseWeapons]]) end

---Fields
---@param reloadState number
---@param reloadFrame number
---@param reloadTime number
---@param accuracy number
---@param sprayAngle number
---@param range number
---@param projectileSpeed number
---@param burst number
---@param burstRate number
---@param projectiles number
---@param salvoLeft number
---@param nextSalvo number
---@param aimReady number
---Parameters
---@param unitID number
---@param weaponNum number
---@param states states
---@return nil
function Spring.SetUnitWeaponState(unitID, weaponNum, states) end

---Parameters
---@param unitID number
---@param weaponNum number
---@param key string
---@param value number
---@return nil
function Spring.SetUnitWeaponState(unitID, weaponNum, key, value) end

---Fields
---@param paralyzeDamageTime number
---@param impulseFactor number
---@param impulseBoost number
---@param craterMult number
---@param craterBoost number
---@param dynDamageExp number
---@param dynDamageMin number
---@param dynDamageRange number
---@param dynDamageInverted number
---@param craterAreaOfEffect number
---@param damageAreaOfEffect number
---@param edgeEffectiveness number
---@param explosionSpeed number
---@param armorType number
---Parameters
---@param unitID number
---@param weaponNum ?number|string
---@param damages damages
---@return nil
function Spring.SetUnitWeaponDamages(unitID, weaponNum, damages) end

---Parameters
---@param unitID number
---@param weaponNum ?number|string
---@param key string
---@param value number
---@return nil
function Spring.SetUnitWeaponDamages(unitID, weaponNum, key, value) end

---Parameters
---@param unitID number
---@param maxRange number
---@return nil
function Spring.SetUnitMaxRange(unitID, maxRange) end

---Parameters
---@param unitID number
---@param experience number
---@return nil
function Spring.SetUnitExperience(unitID, experience) end

---Parameters
---@param unitID number
---@param deltaExperience number
---@return nil
function Spring.AddUnitExperience(unitID, deltaExperience) end

---Parameters
---@param unitID number
---@param armored boolean (optional)
---@param armorMultiple number (optional)
---@return nil
function Spring.SetUnitArmored(unitID[, armored[, armorMultiple]]) end


---
---Parameters
---@param unitID number
---@param allyTeam number
---@param losTypes number|table
---@return nil
function Spring.SetUnitLosMask(unitID, allyTeam, losTypes) end

---Parameters
---@param unitID number
---@param allyTeam number
---@param los number|table
---@return nil
function Spring.SetUnitLosState(unitID, allyTeam, los) end

---Parameters
---@param unitID number
---@param cloak bool|number
---@param cloakArg bool|number
---@return nil
function Spring.SetUnitCloak(unitID, cloak, cloakArg) end

---Parameters
---@param unitID number
---@param stealth boolean
---@return nil
function Spring.SetUnitStealth(unitID, stealth) end

---Parameters
---@param unitID number
---@param sonarStealth boolean
---@return nil
function Spring.SetUnitSonarStealth(unitID, sonarStealth) end

---Parameters
---@param unitID number
---@param seismicSignature number
---@return nil
function Spring.SetUnitSeismicSignature(unitID, seismicSignature) end

---Parameters
---@param unitID number
---@param alwaysVisible boolean
---@return nil
function Spring.SetUnitAlwaysVisible(unitID, alwaysVisible) end

---Parameters
---@param unitID number
---@param useAirLos boolean
---@return nil
function Spring.SetUnitUseAirLos(unitID, useAirLos) end

---Parameters
---@param unitID number
---@param depth number
---@param range number (optional)
---@return nil
function Spring.SetUnitMetalExtraction(unitID, depth[, range]) end

---Parameters
---@param unitID number
---@param metal number
---@return nil
function Spring.SetUnitHarvestStorage(unitID, metal) end

---Parameters
---@param unitID number
---@param paramName string
---@param bool number
---@return nil
function Spring.SetUnitBuildParams(unitID, paramName, bool) end

---Parameters
---@param builderID number
---@param buildSpeed number
---@param repairSpeed number (optional)
---@param reclaimSpeed number (optional)
---@param captureSpeed number (optional)
---@param terraformSpeed number (optional)
---@return nil
function Spring.SetUnitBuildSpeed(builderID, buildSpeed[, repairSpeed[, reclaimSpeed[, captureSpeed[, terraformSpeed]]]]) end

---Parameters
---@param builderID number
---@param pieces table
---@return nil
function Spring.SetUnitNanoPieces(builderID, pieces) end

---Parameters
---@param unitID number
---@param isblocking boolean
---@param isSolidObjectCollidable boolean
---@param isProjectileCollidable boolean
---@param isRaySegmentCollidable boolean
---@param crushable boolean
---@param blockEnemyPushing boolean
---@param blockHeightChanges boolean
---@return nil
function Spring.SetUnitBlocking(unitID, isblocking, isSolidObjectCollidable, isProjectileCollidable, isRaySegmentCollidable, crushable, blockEnemyPushing, blockHeightChanges) end

---Parameters
---@param unitID number
---@param crashing boolean
---@return bool success
function Spring.SetUnitCrashing(unitID, crashing) end

---Parameters
---@param unitID number
---@param weaponID number (default): `-1`
---@param enabled boolean (optional)
---@param power number (optional)
---@return nil
function Spring.SetUnitShieldState(unitID[, weaponID=-1[, enabled[, power]]]) end

---Parameters
---@param unitID number
---@param weaponID number (optional)
---@param rechargeTime number (optional)
---@return nil
function Spring.SetUnitShieldRechargeDelay(unitID[, weaponID[, rechargeTime]]) end

---Parameters
---@param unitID number
---@param type string
---@param arg1 number
---@param y number (optional)
---@param z number (optional)
---@return nil
function Spring.SetUnitFlanking(unitID, type, arg1[, y[, z]]) end

---Parameters
---@param unitID number
---@param neutral boolean
---@return nil|bool setNeutral
function Spring.SetUnitNeutral(unitID, neutral) end

---Parameters
---@param unitID number
---@param enemyUnitID number (optional)
---@param dgun boolean (default): `false`
---@param userTarget boolean (default): `false`
---@param weaponNum number (default): `-1`
---@return bool success
function Spring.SetUnitTarget(unitID[, enemyUnitID[, dgun=false[, userTarget=false[, weaponNum=-1]]]]) end

---Parameters
---@param unitID number
---@param x number (optional)
---@param y number (optional)
---@param z number (optional)
---@param dgun boolean (default): `false`
---@param userTarget boolean (default): `false`
---@param weaponNum number (default): `-1`
---@return bool success
function Spring.SetUnitTarget(unitID[, x[, y[, z[, dgun=false[, userTarget=false[, weaponNum=-1]]]]]]) end

---Parameters
---@param unitID number
---@param mpX number
---@param mpY number
---@param mpZ number
---@param apX number
---@param apY number
---@param apZ number
---@param relative boolean (default): `false`
---@return bool success
function Spring.SetUnitMidAndAimPos(unitID, mpX, mpY, mpZ, apX, apY, apZ[, relative=false]) end

---Parameters
---@param unitID number
---@param radius number
---@param height number
---@return bool success
function Spring.SetUnitRadiusAndHeight(unitID, radius, height) end

---Parameters
---@param unitID number
---@param AlteredPiece number
---@param ParentPiece number
---@return nil
function Spring.SetUnitPieceParent(unitID, AlteredPiece, ParentPiece) end

---Parameters
---@param unitID number
---@param pieceNum number
---@param matrix {number,...}
---@return nil
function Spring.SetUnitPieceMatrix(unitID, pieceNum, matrix) end

---Parameters
---@param unitID number
---@param scaleX number
---@param scaleY number
---@param scaleZ number
---@param offsetX number
---@param offsetY number
---@param offsetZ number
---@param vType number
---@param tType number
---@param Axis number
---@return nil

  enum COLVOL_TYPES {
      COLVOL_TYPE_DISABLED = -1,
      COLVOL_TYPE_ELLIPSOID = 0,
      COLVOL_TYPE_CYLINDER,
      COLVOL_TYPE_BOX,
      COLVOL_TYPE_SPHERE,
      COLVOL_NUM_TYPES       // number of non-disabled collision volume types
    };
    enum COLVOL_TESTS {
      COLVOL_TEST_DISC = 0,
      COLVOL_TEST_CONT = 1,
      COLVOL_NUM_TESTS = 2   // number of tests
    };
    enum COLVOL_AXES {
      COLVOL_AXIS_X   = 0,
      COLVOL_AXIS_Y   = 1,
      COLVOL_AXIS_Z   = 2,
      COLVOL_NUM_AXES = 3    // number of collision volume axes
    };
function Spring.SetUnitCollisionVolumeData(unitID, scaleX, scaleY, scaleZ, offsetX, offsetY, offsetZ, vType, tType, Axis) end

---Parameters
---@param unitID number
---@param pieceIndex number
---@param enable boolean
---@param scaleX number
---@param scaleY number
---@param scaleZ number
---@param offsetX number
---@param offsetY number
---@param offsetZ number
---@param volumeType number (optional)
---@param primaryAxis number (optional)
---@return nil
function Spring.SetUnitPieceCollisionVolumeData(unitID, pieceIndex, enable, scaleX, scaleY, scaleZ, offsetX, offsetY, offsetZ[, volumeType[, primaryAxis]]) end

---Parameters
---@param unitID number
---@param pieceIndex number
---@param visible boolean
---@return nil
function Spring.SetUnitPieceVisible(unitID, pieceIndex, visible) end

---Parameters
---@param unitID number
---@param type string
---@return ?nil|number newRadius
function Spring.SetUnitSensorRadius(unitID, type) end

---Parameters
---@param unitID number
---@param posErrorVectorX number
---@param posErrorVectorY number
---@param posErrorVectorZ number
---@param posErrorDeltaX number
---@param posErrorDeltaY number
---@param posErrorDeltaZ number
---@param nextPosErrorUpdate number (optional)
---@return nil
function Spring.SetUnitPosErrorParams(unitID, posErrorVectorX, posErrorVectorY, posErrorVectorZ, posErrorDeltaX, posErrorDeltaY, posErrorDeltaZ[, nextPosErrorUpdate]) end

---Parameters
---@param unitID number
---@param goalX number
---@param goalY number
---@param goalZ number
---@param goalRadius number (optional)
---@param moveSpeed number (optional)
---@param moveRaw boolean (optional)
---@return nil
function Spring.SetUnitMoveGoal(unitID, goalX, goalY, goalZ[, goalRadius[, moveSpeed[, moveRaw]]]) end

---Parameters
---@param unitID number
---@param goalX number
---@param goalY number
---@param goalZ number
---@param goalRadius number (optional)
---@return nil
function Spring.SetUnitLandGoal(unitID, goalX, goalY, goalZ[, goalRadius]) end

---Parameters
---@param unitID number
---@return nil
function Spring.ClearUnitGoal(unitID) end

---Parameters
---@param unitID number
---@param posX number
---@param posY number
---@param posZ number
---@param velX number
---@param velY number
---@param velZ number
---@param rotX number
---@param rotY number
---@param rotZ number
---@param dragX number
---@param dragY number
---@param dragZ number
---@return nil
function Spring.SetUnitPhysics(unitID, posX, posY, posZ, velX, velY, velZ, rotX, rotY, rotZ, dragX, dragY, dragZ) end

---Parameters
---@param unitID number
---@param mass number
---@return nil
function Spring.SetUnitMass(unitID, mass) end

---Parameters
---@param unitID number
---@param x number
---@param z number
---@param alwaysAboveSea boolean (optional)
---@return nil
function Spring.SetUnitPosition(unitID, x, z[, alwaysAboveSea]) end

---Parameters
---@param unitID number
---@param yaw number
---@param pitch number
---@param roll number
---@return nil
function Spring.SetUnitRotation(unitID, yaw, pitch, roll) end

---Parameters
---@param unitID number
---@param x number
---@param y number
---@param z number
---@return nil
function Spring.SetUnitDirection(unitID, x, y, z) end

---Parameters
---@param unitID number
---@param heading number
---@param upx number
---@param upy number
---@param upz number
---@return nil
function Spring.SetUnitHeadingAndUpDir(unitID, heading, upx, upy, upz) end

---Parameters
---@param unitID number
---@param velX number
---@param velY number
---@param velZ number
---@return nil
function Spring.SetUnitVelocity(unitID, velX, velY, velZ) end

---Parameters
---@param unitID number
---@param buggerOff boolean (optional)
---@param offset number (optional)
---@param radius number (optional)
---@param relHeading number (optional)
---@param spherical boolean (optional)
---@param forced boolean (optional)
---@return nil|number buggerOff
function Spring.SetFactoryBuggerOff(unitID[, buggerOff[, offset[, radius[, relHeading[, spherical[, forced]]]]]]) end

---Parameters
---@param x number
---@param y number
---@param z number (optional)
---@param radius number
---@param teamID number
---@param spherical boolean (default): `true`
---@param forced boolean (default): `true`
---@param excludeUnitID number (optional)
---@param excludeUnitDefIDs {[number],...} (optional)
---@return nil
function Spring.BuggerOff(x, y[, z], radius, teamID[, spherical=true[, forced=true[, excludeUnitID[, excludeUnitDefIDs]]]]) end

---Parameters
---@param unitID number
---@param damage number
---@param paralyze number (default): `0`
---@param attackerID number (default): `-1`
---@param weaponID number (default): `-1`
---@param impulseX number (optional)
---@param impulseY number (optional)
---@param impulseZ number (optional)
---@return nil
function Spring.AddUnitDamage(unitID, damage[, paralyze=0[, attackerID=-1[, weaponID=-1[, impulseX[, impulseY[, impulseZ]]]]]]) end

---Parameters
---@param unitID number
---@param x number
---@param y number
---@param z number
---@param decayRate number (optional)
---@return nil
function Spring.AddUnitImpulse(unitID, x, y, z[, decayRate]) end

---Parameters
---@param unitID number
---@param pindSize number
---@return nil
function Spring.AddUnitSeismicPing(unitID, pindSize) end

---Parameters
---@param unitID number
---@param resource string
---@param amount number
---@return nil
function Spring.AddUnitResource(unitID, resource, amount) end

---Parameters
---@param unitID number
---@param resource string
---@param amount number
---@return ?nil|bool okay
function Spring.UseUnitResource(unitID, resource, amount) end

---Parameters
---@param unitID number
---@param resources {[string]=number,...}
---@return ?nil|bool okay
function Spring.UseUnitResource(unitID, resources) end


---
---Parameters
---@param unitID number
---@return nil
function Spring.AddObjectDecal(unitID) end

---Parameters
---@param unitID number
---@return nil
function Spring.RemoveObjectDecal(unitID) end


---
---Parameters
---@param x number
---@param z number
---@return nil
function Spring.AddGrass(x, z) end

---Parameters
---@param x number
---@param z number
---@return nil
function Spring.RemoveGrass(x, z) end


---
---Parameters
---@param featureDef string|number
---@param x number
---@param y number
---@param z number
---@param heading number (optional)
---@param AllyTeamID number (optional)
---@param featureID number (optional)
---@return number featureID
function Spring.CreateFeature(featureDef, x, y, z[, heading[, AllyTeamID[, featureID]]]) end

---Parameters
---@param featureDefID number
---@return nil
function Spring.DestroyFeature(featureDefID) end

---Parameters
---@param featureDefID number
---@param teamID number
---@return nil
function Spring.TransferFeature(featureDefID, teamID) end

---Parameters
---@param featureID number
---@param enable boolean
---@return nil
function Spring.SetFeatureAlwaysVisible(featureID, enable) end

---Parameters
---@param featureID number
---@param useAirLos boolean
---@return nil
function Spring.SetFeatureUseAirLos(featureID, useAirLos) end

---Parameters
---@param featureID number
---@param health number
---@return nil
function Spring.SetFeatureHealth(featureID, health) end

---Parameters
---@param featureID number
---@param maxHealth number
---@return nil
function Spring.SetFeatureMaxHealth(featureID, maxHealth) end

---Parameters
---@param featureID number
---@param reclaimLeft number
---@return nil
function Spring.SetFeatureReclaim(featureID, reclaimLeft) end

---Parameters
---@param featureID number
---@param metal number
---@param energy number
---@param reclaimTime number (optional)
---@param reclaimLeft number (optional)
---@param featureDefMetal number (optional)
---@param featureDefEnergy number (optional)
---@return nil
function Spring.SetFeatureResources(featureID, metal, energy[, reclaimTime[, reclaimLeft[, featureDefMetal[, featureDefEnergy]]]]) end

---Parameters
---@param featureID number
---@param unitDef string|number
---@param facing string|number (optional)
---@param progress number (optional)
---@return nil
function Spring.SetFeatureResurrect(featureID, unitDef[, facing[, progress]]) end

---Parameters
---@param featureID number
---@param enable boolean (optional)
---@param arg1 number (optional)
---@param arg2 number (optional)
---@param argn number (optional)
---@return nil
function Spring.SetFeatureMoveCtrl(featureID[, enable[, arg1[, arg2[, argn]]]]) end

---Parameters
---@param featureID number
---@param posX number
---@param posY number
---@param posZ number
---@param velX number
---@param velY number
---@param velZ number
---@param rotX number
---@param rotY number
---@param rotZ number
---@param dragX number
---@param dragY number
---@param dragZ number
---@return nil
function Spring.SetFeaturePhysics(featureID, posX, posY, posZ, velX, velY, velZ, rotX, rotY, rotZ, dragX, dragY, dragZ) end

---Parameters
---@param featureID number
---@param mass number
---@return nil
function Spring.SetFeatureMass(featureID, mass) end

---Parameters
---@param featureID number
---@param x number
---@param y number
---@param z number
---@param snapToGround boolean (optional)
---@return nil
function Spring.SetFeaturePosition(featureID, x, y, z[, snapToGround]) end

---Parameters
---@param featureID number
---@param rotX number
---@param rotY number
---@param rotZ number
---@return nil
function Spring.SetFeatureRotation(featureID, rotX, rotY, rotZ) end

---Parameters
---@param featureID number
---@param dirX number
---@param dirY number
---@param dirZ number
---@return nil
function Spring.SetFeatureDirection(featureID, dirX, dirY, dirZ) end

---Parameters
---@param featureID number
---@param heading number
---@param upx number
---@param upy number
---@param upz number
---@return nil
function Spring.SetFeatureHeadingAndUpDir(featureID, heading, upx, upy, upz) end

---Parameters
---@param featureID number
---@param velX number
---@param velY number
---@param velZ number
---@return nil
function Spring.SetFeatureVelocity(featureID, velX, velY, velZ) end

---Parameters
---@param featureID number
---@param isBlocking boolean
---@param isSolidObjectCollidable boolean
---@param isProjectileCollidable boolean
---@param isRaySegmentCollidable boolean
---@param crushable boolean
---@param blockEnemyPushing boolean
---@param blockHeightChanges boolean
---@return nil
function Spring.SetFeatureBlocking(featureID, isBlocking, isSolidObjectCollidable, isProjectileCollidable, isRaySegmentCollidable, crushable, blockEnemyPushing, blockHeightChanges) end

---Parameters
---@param featureID number
---@param noSelect boolean
---@return nil
function Spring.SetFeatureNoSelect(featureID, noSelect) end

---Parameters
---@param featureID number
---@param mpX number
---@param mpY number
---@param mpZ number
---@param apX number
---@param apY number
---@param apZ number
---@param relative boolean (optional)
---@return bool success
function Spring.SetFeatureMidAndAimPos(featureID, mpX, mpY, mpZ, apX, apY, apZ[, relative]) end

---Parameters
---@param featureID number
---@param radius number
---@param height number
---@return bool success
function Spring.SetFeatureRadiusAndHeight(featureID, radius, height) end

---Parameters
---@param featureID number
---@param scaleX number
---@param scaleY number
---@param scaleZ number
---@param offsetX number
---@param offsetY number
---@param offsetZ number
---@param vType number
---@param tType number
---@param Axis number
---@return nil
function Spring.SetFeatureCollisionVolumeData(featureID, scaleX, scaleY, scaleZ, offsetX, offsetY, offsetZ, vType, tType, Axis) end

---Parameters
---@param featureID number
---@param pieceIndex number
---@param enable boolean
---@param scaleX number
---@param scaleY number
---@param scaleZ number
---@param offsetX number
---@param offsetY number
---@param offsetZ number
---@param Axis number
---@param volumeType number
---@param primaryAxis number (optional)
---@return nil
function Spring.SetFeaturePieceCollisionVolumeData(featureID, pieceIndex, enable, scaleX, scaleY, scaleZ, offsetX, offsetY, offsetZ, Axis, volumeType[, primaryAxis]) end

---Parameters
---@param featureID number
---@param pieceIndex number
---@param visible boolean
---@return nil
function Spring.SetFeaturePieceVisible(featureID, pieceIndex, visible) end


---
---Fields
---@param pos: x number
---@param pos: y number
---@param pos: z number
---@param end: x number
---@param end: y number
---@param end: z number
---@param speed: x number
---@param speed: y number
---@param speed: z number
---@param spread: x number
---@param spread: y number
---@param spread: z number
---@param error: x number
---@param error: y number
---@param error: z number
---@param owner number
---@param team number
---@param ttl number
---@param gravity number
---@param tracking number
---@param maxRange number
---@param startAlpha number
---@param endAlpha number
---@param model string
---@param cegTag string
---Parameters
---@param projectileID number
---@param alwaysVisible boolean
---@return nil
function Spring.SetProjectileAlwaysVisible(projectileID, alwaysVisible) end

---Parameters
---@param projectileID number
---@param useAirLos boolean
---@return nil
function Spring.SetProjectileUseAirLos(projectileID, useAirLos) end

---Parameters
---@param projectileID number
---@param enable boolean
---@return nil
function Spring.SetProjectileMoveControl(projectileID, enable) end

---Parameters
---@param projectileID number
---@param posX number (default): `0`
---@param posY number (default): `0`
---@param posZ number (default): `0`
---@return nil
function Spring.SetProjectilePosition(projectileID[, posX=0[, posY=0[, posZ=0]]]) end

---Parameters
---@param projectileID number
---@param velX number (default): `0`
---@param velY number (default): `0`
---@param velZ number (default): `0`
---@return nil
function Spring.SetProjectileVelocity(projectileID[, velX=0[, velY=0[, velZ=0]]]) end

---Parameters
---@param projectileID number
---@return nil
function Spring.SetProjectileCollision(projectileID) end

---Parameters
---@param projectileID number
---@param arg1 number (default): `0`
---@param arg2 number (default): `0`
---@param posZ number (default): `0`
---@return ?nil|bool validTarget
function Spring.SetProjectileTarget(projectileID[, arg1=0[, arg2=0[, posZ=0]]]) end

---Parameters
---@param projectileID number
---@return nil
function Spring.SetProjectileIsIntercepted(projectileID) end

---Parameters
---@param unitID number
---@param weaponNum number
---@param key string
---@param value number
---@return nil
function Spring.SetProjectileDamages(unitID, weaponNum, key, value) end

---Parameters
---@param projectileID number
---@param ignore boolean
---@return nil
function Spring.SetProjectileIgnoreTrackingError(projectileID, ignore) end

---Parameters
---@param projectileID number
---@param grav number (default): `0`
---@return nil
function Spring.SetProjectileGravity(projectileID[, grav=0]) end

---Parameters
---@param projectileID number
---@param explosionFlags number (optional)
---@param spinAngle number (optional)
---@param spinSpeed number (optional)
---@param spinVectorX number (optional)
---@param spinVectorY number (optional)
---@param spinVectorZ number (optional)
---@return nil
function Spring.SetPieceProjectileParams(projectileID[, explosionFlags[, spinAngle[, spinSpeed[, spinVectorX[, spinVectorY[, spinVectorZ]]]]]]) end


---
---Fields
---@param right bool
---@param alt bool
---@param ctrl bool
---@param shift bool
---Fields
---@param cmdID number
---@param params {number,...}
---@param options cmdOpts
---Parameters
---@param unitID number
---@return nil
function Spring.UnitFinishCommand(unitID) end

---Parameters
---@param unitID number
---@param cmdID number
---@param params {number,...}
---@param cmdOpts cmdOpts
---@return bool unitOrdered
function Spring.GiveOrderToUnit(unitID, cmdID, params, cmdOpts) end

---Parameters
---@param unitMap {[number]=table,...}
---@param cmdID number
---@param params {number,...}
---@param cmdOpts cmdOpts
---@return number unitsOrdered
function Spring.GiveOrderToUnitMap(unitMap, cmdID, params, cmdOpts) end

---Parameters
---@param unitIDs {number,...}
---@param cmdID number
---@param params {number,...}
---@param cmdOpts cmdOpts
---@return number unitsOrdered
function Spring.GiveOrderToUnitArray(unitIDs, cmdID, params, cmdOpts) end

---Parameters
---@param unitID number
---@param cmdArray {cmdSpec,...}
---@return bool ordersGiven
function Spring.GiveOrderArrayToUnit(unitID, cmdArray) end

---Parameters
---@param unitMap {[number]=table}
---@param orderArray {cmdSpec,...}
---@return number unitsOrdered
function Spring.GiveOrderArrayToUnitMap(unitMap, orderArray) end

---Parameters
---@param unitArray {number,...}
---@param orderArray {cmdSpec,...}
---@return nil
function Spring.GiveOrderArrayToUnitArray(unitArray, orderArray) end


---
---Parameters
---@param x1 number
---@param z1 number
---@param x2_height number
---@param z2 number (optional)
---@param height number (optional)
---@return nil
function Spring.LevelHeightMap(x1, z1, x2_height[, z2[, height]]) end

---Parameters
---@param x1 number
---@param y1 number
---@param x2_height number
---@param y2 number (optional)
---@param height number (optional)
---@return nil
function Spring.AdjustHeightMap(x1, y1, x2_height[, y2[, height]]) end

---Parameters
---@param x1 number
---@param y1 number
---@param x2_factor number
---@param y2 number (optional)
---@param factor number (optional)
---@return nil
function Spring.RevertHeightMap(x1, y1, x2_factor[, y2[, factor]]) end

---Parameters
---@param x number
---@param z number
---@param height number
---@return ?nil|number newHeight
function Spring.AddHeightMap(x, z, height) end

---Parameters
---@param x number
---@param z number
---@param height number
---@param terraform number (default): `1`
---@return ?nil|number absHeightDiff =0 nothing will be changed (the terraform starts) and if =1 the terraform will be finished.
function Spring.SetHeightMap(x, z, height[, terraform=1]) end

---Parameters
---@param lua_function function
---@param arg1 (optional)
---@param arg2 (optional)
---@param argn (optional)
---@return ?nil|number absTotalHeightMapAmountChanged
function Spring.SetHeightMapFunc(lua_function[, arg1[, arg2[, argn]]]) end


---
---Parameters
---@param x1 number
---@param y1 number
---@param x2_height number
---@param y2 number (optional)
---@param height number (optional)
---@return nil
function Spring.LevelOriginalHeightMap(x1, y1, x2_height[, y2[, height]]) end

---Parameters
---@param x1 number
---@param y1 number
---@param x2_height number
---@param y2 number (optional)
---@param height number (optional)
---@return nil
function Spring.AdjustOriginalHeightMap(x1, y1, x2_height[, y2[, height]]) end

---Parameters
---@param x1 number
---@param y1 number
---@param x2_factor number
---@param y2 number (optional)
---@param factor number (optional)
---@return nil
function Spring.RevertOriginalHeightMap(x1, y1, x2_factor[, y2[, factor]]) end

---Parameters
---@param x number
---@param y number
---@param height number
---@return nil
function Spring.AddOriginalHeightMap(x, y, height) end

---Parameters
---@param x number
---@param y number
---@param height number
---@param factor number (optional)
---@return nil
function Spring.SetOriginalHeightMap(x, y, height[, factor]) end

---Parameters
---@param heightMapFunc function
---@return nil
function Spring.SetOriginalHeightMapFunc(heightMapFunc) end

---Parameters
---@param x1 number
---@param z1 number
---@param x2 number (optional)
---@param z2 number (optional)
---@param height number
---@return nil
function Spring.LevelSmoothMesh(x1, z1[, x2][, z2], height) end

---Parameters
---@param x1 number
---@param z1 number
---@param x2 number (optional)
---@param z2 number (optional)
---@param height number
---@return nil
function Spring.AdjustSmoothMesh(x1, z1[, x2][, z2], height) end

---Parameters
---@param x1 number
---@param z1 number
---@param x2 number (optional)
---@param z2 number (optional)
---@param origFactor number
---@return nil
function Spring.RevertSmoothMesh(x1, z1[, x2][, z2], origFactor) end

---Parameters
---@param x number
---@param z number
---@param height number
---@return ?nil|number newHeight
function Spring.AddSmoothMesh(x, z, height) end

---Parameters
---@param x number
---@param z number
---@param height number
---@param terraform number (default): `1`
---@return ?nil|number absHeightDiff
function Spring.SetSmoothMesh(x, z, height[, terraform=1]) end

---Parameters
---@param lua_function function
---@param arg1
---@param arg2
---@param argn
---@return ?nil|number absTotalHeightMapAmountChanged
function Spring.SetSmoothMeshFunc(lua_function, arg1, arg2, argn) end


---
---Parameters
---@param x number
---@param z number
---@param newType number
---@return ?nil|number oldType
function Spring.SetMapSquareTerrainType(x, z, newType) end

---Parameters
---@param typeIndex number
---@param speedTanks number (default): `nil`
---@param speedKBOts number (default): `nil`
---@param speedHovers number (default): `nil`
---@param speedShips number (default): `nil`
---@return ?nil|bool true
function Spring.SetTerrainTypeData(typeIndex[, speedTanks=nil[, speedKBOts=nil[, speedHovers=nil[, speedShips=nil]]]]) end

---Parameters
---@param x number
---@param z number
---@param mask number
---@return nil See also buildingMask unitdef tag.
function Spring.SetSquareBuildingMask(x, z, mask) end

---Parameters
---@param unitID number
---@param weaponID number
---@return nil
function Spring.UnitWeaponFire(unitID, weaponID) end

---Parameters
---@param transporterID number
---@param passengerID number
---@param pieceNum number
---@return nil
function Spring.UnitAttach(transporterID, passengerID, pieceNum) end

---Parameters
---@param passengerID number
---@return nil
function Spring.UnitDetach(passengerID) end

---Parameters
---@param passengerID number
---@return nil
function Spring.UnitDetachFromAir(passengerID) end

---Parameters
---@param passengerID number
---@param transportID number
---@return nil
function Spring.SetUnitLoadingTransport(passengerID, transportID) end

---Parameters
---@param weaponDefID number
---@param projectileParams projectileParams
---@return ?nil|number projectileID
function Spring.SpawnProjectile(weaponDefID, projectileParams) end

---Parameters
---@param projectileID number
---@return nil
function Spring.DeleteProjectile(projectileID) end

---Fields
---@param weaponDef number
---@param owner number
---@param hitUnit number
---@param hitFeature number
---@param craterAreaOfEffect number
---@param damageAreaOfEffect number
---@param edgeEffectiveness number
---@param explosionSpeed number
---@param gfxMod number
---@param impactOnly boolean
---@param ignoreOwner boolean
---@param damageGround boolean
---Parameters
---@param posX number (default): `0`
---@param posY number (default): `0`
---@param posZ number (default): `0`
---@param dirX number (default): `0`
---@param dirY number (default): `0`
---@param dirZ number (default): `0`
---@param explosionParams explosionParams
---@return nil
function Spring.SpawnExplosion([posX=0][, posY=0][, posZ=0][, dirX=0][, dirY=0][, dirZ=0], explosionParams) end

---Parameters
---@param cegname string
---@param posX number (default): `0`
---@param posY number (default): `0`
---@param posZ number (default): `0`
---@param dirX number (default): `0`
---@param dirY number (default): `0`
---@param dirZ number (default): `0`
---@param radius number (default): `0`
---@param damage number (default): `0`
---@return ?nil|bool success
function Spring.SpawnCEG(cegname[, posX=0[, posY=0[, posZ=0[, dirX=0[, dirY=0[, dirZ=0[, radius=0[, damage=0]]]]]]]]) end

---@return number cegID
function Spring.SpawnCEG(cegname[, posX=0[, posY=0[, posZ=0[, dirX=0[, dirY=0[, dirZ=0[, radius=0[, damage=0]]]]]]]]) end

---Parameters
---@param unitID number (default): `0`
---@param sfxID number (default): `0`
---@param posX number (default): `0`
---@param posY number (default): `0`
---@param posZ number (default): `0`
---@param dirX number (default): `0`
---@param dirY number (default): `0`
---@param dirZ number (default): `0`
---@param radius number (default): `0`
---@param damage number (default): `0`
---@param absolute boolean (optional)
---@return ?nil|bool success
function Spring.SpawnSFX([unitID=0[, sfxID=0[, posX=0[, posY=0[, posZ=0[, dirX=0[, dirY=0[, dirZ=0[, radius=0[, damage=0[, absolute]]]]]]]]]]]) end


---
---Parameters
---@param noPause boolean
---@return nil
function Spring.SetNoPause(noPause) end

---Parameters
---@param expGrade number
---@param ExpPowerScale number (optional)
---@param ExpHealthScale number (optional)
---@param ExpReloadScale number (optional)
---@return nil
function Spring.SetExperienceGrade(expGrade[, ExpPowerScale[, ExpHealthScale[, ExpReloadScale]]]) end

---Parameters
---@param allyTeamID number
---@param allyteamErrorSize number
---@param baseErrorSize number (optional)
---@param baseErrorMult number (optional)
---@return nil
function Spring.SetRadarErrorParams(allyTeamID, allyteamErrorSize[, baseErrorSize[, baseErrorMult]]) end


---
---Parameters
---@param unitID number
---@param cmdDescID number
---@param cmdArray table
---@return nil
function Spring.EditUnitCmdDesc(unitID, cmdDescID, cmdArray) end

---Parameters
---@param unitID number
---@param cmdDescID number (optional)
---@param cmdArray table
---@return nil
function Spring.InsertUnitCmdDesc(unitID[, cmdDescID], cmdArray) end

---Parameters
---@param unitID number
---@param cmdDescID number (optional)
---@return nil
function Spring.RemoveUnitCmdDesc(unitID[, cmdDescID]) end

