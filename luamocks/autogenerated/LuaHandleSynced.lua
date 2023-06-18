---LuaHandleSynced

---
---Parameters
---@param arg1 any
---@param arg2 any
---@param argn any

---
---Parameters
---@param unitID number
---@param drawMode number
---@return bool suppressEngineDraw
function DrawUnit(unitID, drawMode) end

---Parameters
---@param featureID number
---@param drawMode number
---@return bool suppressEngineDraw
function DrawFeature(featureID, drawMode) end

---Parameters
---@param featureID number
---@param weaponID number
---@param drawMode number
---@return bool suppressEngineDraw
function DrawShield(featureID, weaponID, drawMode) end

---Parameters
---@param projectileID number
---@param drawMode number
---@return bool suppressEngineDraw
function DrawProjectile(projectileID, drawMode) end

---Parameters
---@param uuid number
---@param drawMode number
---@return bool suppressEngineDraw
function DrawMaterial(uuid, drawMode) end

---Parameters
---@param unitID number
---@param unitDefID number
---@param unitTeam number
---@param cmdID number
---@param cmdParams {number,...}
---@param cmdOptions cmdOptions
---@param cmdTag number
---@return boolean whether to remove the command from the queue
function CommandFallback(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag) end

---Parameters
---@param unitID number
---@param unitDefID number
---@param unitTeam number
---@param cmdID number
---@param cmdParams {number,...}
---@param cmdOptions cmdOptions
---@param cmdTag number
---@param synced boolean
---@param fromLua boolean
---@return bool whether it should be let into the queue.
function AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced, fromLua) end

---Parameters
---@param unitDefID number
---@param builderID number
---@param builderTeam number
---@param x number
---@param y number
---@param z number
---@param facing number
---@return bool whether or not the creation is permitted.
function AllowUnitCreation(unitDefID, builderID, builderTeam, x, y, z, facing) end

---Parameters
---@param unitID number
---@param unitDefID number
---@param oldTeam number
---@param newTeam number
---@param capture boolean
---@return bool whether or not the transfer is permitted.
function AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture) end

---Parameters
---@param builderID number
---@param builderTeam number
---@param unitID number
---@param unitDefID number
---@param part number
---@return bool whether or not the build makes progress.
function AllowUnitBuildStep(builderID, builderTeam, unitID, unitDefID, part) end

---Parameters
---@param builderID number
---@param builderTeam number
---@param unitID number
---@param unitDefID number
---@param part number
---@return bool whether or not the capture makes progress.
function AllowUnitCaptureStep(builderID, builderTeam, unitID, unitDefID, part) end

---Parameters
---@param transporterID number
---@param transporterUnitDefID number
---@param transporterTeam number
---@param transporteeID number
---@param transporteeUnitDefID number
---@param transporteeTeam number
---@return bool whether or not the transport is allowed
function AllowUnitTransport(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam) end

---Parameters
---@param transporterID number
---@param transporterUnitDefID number
---@param transporterTeam number
---@param transporteeID number
---@param transporteeUnitDefID number
---@param transporteeTeam number
---@param x number
---@param y number
---@param z number
---@return bool whether or not the transport load is allowed
function AllowUnitTransportLoad(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, x, y, z) end

---Parameters
---@param transporterID number
---@param transporterUnitDefID number
---@param transporterTeam number
---@param transporteeID number
---@param transporteeUnitDefID number
---@param transporteeTeam number
---@param x number
---@param y number
---@param z number
---@return bool whether or not the transport unload is allowed
function AllowUnitTransportUnload(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, x, y, z) end

---Parameters
---@param unitID number
---@param enemyID number (optional)
---@return bool whether unit is allowed to cloak
function AllowUnitCloak(unitID[, enemyID]) end

---Parameters
---@param unitID number
---@param objectID number (optional)
---@param weaponNum number (optional)
---@return bool whether unit is allowed to decloak
function AllowUnitCloak(unitID[, objectID[, weaponNum]]) end

---Parameters
---@param unitID number
---@param targetID number
---@return bool whether unit is allowed to selfd
function AllowUnitKamikaze(unitID, targetID) end

---Parameters
---@param featureDefID number
---@param teamID number
---@param x number
---@param y number
---@param z number
---@return bool whether or not the creation is permitted
function AllowFeatureCreation(featureDefID, teamID, x, y, z) end

---Parameters
---@param builderID number
---@param builderTeam number
---@param featureID number
---@param featureDefID number
---@param part number
---@return bool whether or not the change is permitted
function AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part) end

---Parameters
---@param teamID number
---@param res string
---@param level number
---@return bool whether or not the sharing level is permitted
function AllowResourceLevel(teamID, res, level) end

---Parameters
---@param oldTeamID number
---@param newTeamID number
---@param res string
---@param amount number
---@return bool whether or not the transfer is permitted.
function AllowResourceTransfer(oldTeamID, newTeamID, res, amount) end

---Parameters
---@param unitID number
---@param unitDefID number
---@param unitTeam number
---@param playerID number
---@return bool allow
function AllowDirectUnitControl(unitID, unitDefID, unitTeam, playerID) end

---Parameters
---@param unitID number
---@param unitDefID number
---@param action number
---@return bool actionAllowed
function AllowBuilderHoldFire(unitID, unitDefID, action) end

---Parameters
---@param playerID number
---@param teamID number
---@param readyState number
---@param clampedX number
---@param clampedY number
---@param clampedZ number
---@param rawX number
---@param rawY number
---@param rawZ number
---@return bool allow
function AllowStartPosition(playerID, teamID, readyState, clampedX, clampedY, clampedZ, rawX, rawY, rawZ) end

---Parameters
---@param unitID number
---@param unitDefID number
---@param unitTeam number
---@param data number
---@return bool whether or not the unit should remain script-controlled (false) or return to engine controlled movement (true).
function MoveCtrlNotify(unitID, unitDefID, unitTeam, data) end

---Parameters
---@param unitID number
---@param unitDefID number
---@param unitTeam number
---@param buildUnitID number
---@param buildUnitDefID number
---@param buildUnitTeam number
---@return bool if true the current build order is terminated
function TerraformComplete(unitID, unitDefID, unitTeam, buildUnitID, buildUnitDefID, buildUnitTeam) end

---Parameters
---@param unitID number
---@param unitDefID number
---@param unitTeam number
---@param damage number
---@param paralyzer boolean
---@param weaponDefID number (optional)
---@param projectileID number (optional)
---@param attackerID number (optional)
---@param attackerDefID number (optional)
---@param attackerTeam number (optional)
---@return  number newDamage, number impulseMult
function UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer[, weaponDefID[, projectileID[, attackerID[, attackerDefID[, attackerTeam]]]]]) end

---Parameters
---@param featureID number
---@param featureDefID number
---@param featureTeam number
---@param damage number
---@param weaponDefID number
---@param projectileID number
---@param attackerID number
---@param attackerDefID number
---@param attackerTeam number
---@return number newDamage
function FeaturePreDamaged(featureID, featureDefID, featureTeam, damage, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam) end

---@return number impulseMult
function FeaturePreDamaged(featureID, featureDefID, featureTeam, damage, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam) end

---Parameters
---@param projectileID number
---@param projectileOwnerID number
---@param shieldWeaponNum number
---@param shieldCarrierID number
---@param bounceProjectile boolean
---@param beamEmitterWeaponNum number
---@param beamEmitterUnitID number
---@param startX number
---@param startY number
---@param startZ number
---@param hitX number
---@param hitY number
---@param hitZ number
---@return bool if true the gadget handles the collision event and the engine does not remove the projectile
function ShieldPreDamaged(projectileID, projectileOwnerID, shieldWeaponNum, shieldCarrierID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ) end

---Parameters
---@param attackerID number
---@param attackerWeaponNum number
---@param attackerWeaponDefID number
---@return bool allowCheck
function AllowWeaponTargetCheck(attackerID, attackerWeaponNum, attackerWeaponDefID) end

---@return bool ignoreCheck
function AllowWeaponTargetCheck(attackerID, attackerWeaponNum, attackerWeaponDefID) end

---Parameters
---@param attackerID number
---@param targetID number
---@param attackerWeaponNum number
---@param attackerWeaponDefID number
---@param defPriority number
---@return bool allowed
function AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority) end

---@return number the new priority for this target (if you don't want to change it, return defPriority). Lower priority targets are targeted first.
function AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority) end

---Parameters
---@param interceptorUnitID number
---@param interceptorWeaponID number
---@param targetProjectileID number
---@return bool allowed
function AllowWeaponInterceptTarget(interceptorUnitID, interceptorWeaponID, targetProjectileID) end

