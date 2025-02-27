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

---@meta
---@type number
numberMock =42
stringMock ="TestString"
tableMock ={exampletable= true}
arrayMock = {}
booleanMock =true
functionMock =function (bar) return bar; end

Spring ={}
Game = {}
Engine = {}
VFS = {}
GL = {
	SRC_ALPHA = stringMock,
	ONE_MINUS_SRC_ALPHA = stringMock,
	ONE = stringMock,
	DST_ALPHA = stringMock,
	ONE_MINUS_SRC_COLOR = stringMock,
}
gl = {}
--==================================================================================================

Game = {
	armorTypes = arrayMock,
	gameID = numberMock,
	gameSpeed = numberMock,
	gameName = stringMock,
	gameShortName = stringMock,
	gameVersion = stringMock,
	gravity = numberMock,
	mapName = stringMock,
	mapX = numberMock,
	mapY = numberMock,
	mapZ = numberMock,
	mapSizeX = numberMock,
	mapSizeY = numberMock,
	mapSizeZ = numberMock,
	modName = stringMock,
	squareSize = numberMock,
	version = stringMock,
	startPosType = numberMock,
	tidal = numberMock,
	waterDamage = numberMock,
	windMin = numberMock,
	windMax = numberMock,
	commEnds = booleanMock,
	limitDGun = booleanMock,
	diminishingMetal = booleanMock,
}

Engine = {
	version = stringMock,
	versionFull = stringMock,
}

---@param path string
function VFS.Include(path)
    assert(type(path) == "string", "Argument path is of invalid type - expected string");
    return numberMock
end

--TODO Move markup examples to another filename
---Produces syntax highlighted code block within the tooltip
--- ```
--- assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
--- assert(type(resourceType) == "string","Argument metal is of invalid type - expected string");
--- assert(type(amount) == "number","Argument amount is of invalid type - expected number");
--- ```

--==================================================================================================
-- Teams
--==================================================================================================

---Change the value of the (one-sided) alliance between: firstAllyTeamID -> secondAllyTeamID
---@param firstAllyTeamID number
---@param secondAllyTeamID number
---@param ally boolean
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetAlly)
function Spring.SetAlly (  firstAllyTeamID, secondAllyTeamID, ally)
assert(type(firstAllyTeamID) == "number","Argument firstAllyTeamID is of invalid type - expected number");
assert(type(secondAllyTeamID) == "number","Argument secondAllyTeamID is of invalid type - expected number");
assert(type(ally) == "boolean","Argument ally is of invalid type - expected boolean");
return  numberMock
end

---Assigns player playerID to team teamID
---@param playerID number
---@param teamID number
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.AssignPlayerToTeam)
function Spring.AssignPlayerToTeam (  playerID, teamID)
assert(type(playerID) == "number","Argument playerID is of invalid type - expected number");
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return boolMock
end

---Changes access to global line of sight for a team and its allies.
---@param playerID number
---@param globallos boolean
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetGlobalLos)
function Spring.SetGlobalLos (playerID, globallos)
return nil
end

--==================================================================================================
-- Game End
--==================================================================================================


---Will declare a team to be dead (no further orders can be assigned to such teams units)
---@param teamID number #Gaia team cannot be killed.
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.KillTeam)
function Spring.KillTeam(teamID)
	return nil
end

---Will declare game over.
---@param AllyTeamID1 number
---@param AllyTeamID2 number
---@param AllyTeamIDn number
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.GameOver)
function Spring.GameOver(AllyTeamID1, AllyTeamID2, AllyTeamIDn)
	return nil
end

--==================================================================================================
-- Resources
--==================================================================================================

---Set tidal Strength
---@param strength number
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetTidal)
function Spring.SetTidal(strength)
	assert(type(strength) == "number", "Argument strength is of invalid type - expected number")
	return nil
end

---Sets wind strength
---@param minStrength number
---@param maxStrength number
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetWind)
function Spring.SetWind(minStrength, maxStrength)
	assert(type(minStrength) == "number", "Argument minStrength is of invalid type - expected number")
	assert(type(maxStrength) == "number", "Argument maxStrength is of invalid type - expected number")
	return nil
end

---@param teamID number
---@param resourceType resourceTypes
---@param amount number
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.AddTeamResource)
function Spring.AddTeamResource (  teamID, resourceType, amount)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(resourceType) == "string","Argument resourceType is of invalid type - expected string");
assert(type(amount) == "number","Argument amount is of invalid type - expected number");
return  nil
end

---@alias resourceTypes
---| "metal"
---| "energy"

-- Consumes metal and/or energy resources of the specified team.
---@param teamID number
---@param type resourceTypes
---@param amount number
---@return boolean | nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.UseTeamResource)
function Spring.UseTeamResource ( teamID, type, amount )
return  booleanMock
end

---@alias resValues
---| "m" # metal
---| "e" # energy
---| "ms" # metalStorage
---| "es" # energyStorage

---Sets team resources to given absolute value
---@param teamID number
---@param res resValues
---@param amount any
---@return integer
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetTeamResource)
function Spring.SetTeamResource (  teamID, res, amount)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(res) == "string","Argument res is of invalid type - expected string");
assert(type(amount) == "number","Argument amount is of invalid type - expected number");
return  numberMock
end

---Changes the resource amount for a team beyond which resources aren't stored but transferred to other allied teams if possible
---@param teamID number
---@param resourceType resourceTypes
---@param amount number
---@return integer
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetTeamShareLevel)
function Spring.SetTeamShareLevel (teamID, resourceType, amount)
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
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.ShareTeamResource)
function Spring.ShareTeamResource ( teamID_src, teamID_rec, resourceType, amount )
assert(type(teamID_src) == "number","Argument teamID_src is of invalid type - expected number");
assert(type(teamID_rec) == "number","Argument teamID_rec is of invalid type - expected number");
assert(type(resourceType) == "string", "Argument resourceType is of invalid type - expected string");
assert(type(amount) == "number","Argument amount is of invalid type - expected number");
return  numberMock
end

--==================================================================================================
-- GameRulesParameter
--==================================================================================================


--- If one condition is fulfilled all beneath it are too (e.g. if an unit is in LOS it can read params with `inradar=true` even if the param has `inlos=false`) All GameRulesParam are public, TeamRulesParams can just be `private`,`allied` and/or `public` You can read RulesParams from any Lua enviroments! With those losAccess policies you can limit their access.
--- Fields:
---     private bool only readable by the ally (default) 
---     allied bool readable by ally + ingame allied 
---     typed bool readable if the unit is type (= in radar and was once in LOS)
---     inlos bool readable if the unit is in LOS 
---     inradar bool readable if the unit is in AirLOS 
---     public bool readable by all 

---@alias losAccess
---| "private" #only readable by the ally (default) 
---| "allied" #readable by ally + ingame allied 
---| "inlos" #readable if the unit is in LOS 
---| "typed" #readable if the unit is type (= in radar and was once in LOS)
---| "inradar" #readable if the unit is in AirLOS 
---| "public" #readable by all 

---@param paramName string 
---@param paramValue number | string #numeric paramValues in quotes will be converted to number.
---@param losAccess? losAccess # not typically used in GameRules, see GetGameRulesParams, it will be ignored.
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetGameRulesParam)<br>
---[losAccess parameter details](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#losAccess)
function Spring.SetGameRulesParam (  paramName, paramValue, losAccess )
	assert(type(paramName) == "string","Argument paramName is of invalid type - expected string");
	assert(losAccess == "private" | losAccess == "allied" | losAccess == "inlos" | losAccess == "inradar"
		| losAccess == "public" | losAccess == "typed" , "Argument losAccess is invalid");
return  nil
end

---@param teamID number
---@param paramName string
---@param paramValue number | string #numeric paramValues in quotes will be converted to number.
---@param losAccess? losAccess # while valid arguments, inLos, inRdar, typed, are not meaningful for team rules.
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetTeamRulesParam)
function Spring.SetTeamRulesParam (teamID, paramName, paramValue, losAccess)
	assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
	assert(type(paramName) == "string" or type(paramName) == "number","Argument paramName is of invalid type - expected string or number");
	assert(type(paramValue) == "string" | type(paramName) == "number","Argument paramName is of invalid type - expected string or number");
	assert(type((losAccess) == "string" | type(losAccess) == "table") & (losAccess == "private" | losAccess == "allied" | losAccess == "inlos" | losAccess == "inradar"
	| losAccess == "public" | losAccess == "typed") , "Argument losAccess is invalid");
	return nil
end

---@param unitID number
---@param paramName string
---@param paramValue number | string #numeric paramValues in quotes will be converted to number.
---@param losAccess? losAccess
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitRulesParam)
function Spring.SetUnitRulesParam (unitID, paramName, paramValue, losAccess)
    assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
	assert(type(paramName) == "string", "invalid type for argument paramName, expected String")
    assert(type(paramValue) == "string" | type(paramName) == "number","Argument paramName is of invalid type - expected string or number");
	assert(type((losAccess) == "string" | type(losAccess) == "table") & (losAccess == "private" | losAccess == "allied" | losAccess == "inlos" | losAccess == "inradar"
	| losAccess == "public" | losAccess == "typed") , "Argument losAccess is invalid");
	return nil
end

---@param featureID number
---@param paramName string
---@param paramValue number | string
---@param losAccess? losAccess
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetFeatureRulesParam)
function Spring.SetFeatureRulesParam(featureID, paramName, paramValue, losAccess)
	assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
	assert(type(paramName))
	assert(type(paramValue))
	assert(type((losAccess) == "string" | type(losAccess) == "table") & (losAccess == "private" | losAccess == "allied" | losAccess == "inlos" | losAccess == "inradar"
	| losAccess == "public" | losAccess == "typed") , "Argument losAccess is invalid");
	return nil
end

--==================================================================================================
-- Lua to COB
--==================================================================================================

---@param UnitID number
---@param funcName number | string
---@param retArgs number
---@param COBArg1? any #
---@param COBArg2? any #
---@param COBArgn? any #
---@return nil|number
---Consult wizard for additional return param info. <br>
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.CallCOBScript)
function Spring.CallCOBScript(UnitID, funcName, retArgs, COBArg1, COBArg2, COBArgn)
	return numberMock
end

---@param unitID number
---@param funcName string
---@return nil | number
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.GetCOBScriptID)
function Spring.GetCOBScriptID (unitID, funcName)
	assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
	assert(type(funcName) == "string","Argument funcName is of invalid type - expected string");
	return  numberMock
end


--==================================================================================================
-- Unit Handling
--==================================================================================================



---@alias facing
---| "south"
---| "0" # south
---| "east"
---| "e"
---| "1" # east
---| "north"
---| "n"
---| "2" # north
---| "west"
---| "w"
---| "3" # west

---@param unitDefName 'string UnitDefName'|'number UnitDefID'
---@param x number
---@param y number
---@param z number
---@param facing facing
---@param teamID number
---@param build? boolean # the unit is created in "being built" state with buildProgress = 0 (default false)
---@param flattenGround? boolean # the unit flattens ground, if it normally does so (default true)
---@param unitID? number # Requests specific unitID 
---@param builderID? number # 
---@return nil | number # `unitID` meaning unit was created
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.CreateUnit)
function Spring.CreateUnit (  unitDefName, x, y , z, facing, teamID, build, flattenGround, unitID, builderID)
	assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
	assert(type(teamID) == "number","Argument unitID is of invalid type - expected number");
	return  numberMock
end



---@param UnitID number
---@param selfd? boolean # if true, Makes the unit act like it self-destructed.
---@param reclaimed? boolean # Don't show any DeathSequences, don't leave a wreckage. This does not give back the resources to the team!
---@param attackerID? number 
---@param cleanupImmediately? boolean # stronger version of reclaimed, removes the unit unconditionally and makes its ID available for immediate reuse (otherwise it takes a few frames) (default false)
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.DestroyUnit)
function Spring.DestroyUnit ( UnitID, selfd, reclaimed, attackerID, cleanupImmediately )
	return  nil
end

---@param UnitID number
---@param newTeamID number
---@param given? boolean # If given=false, the unit is captured.
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.TransferUnit)
function Spring.TransferUnit (UnitID, newTeamID, given)
	return nil
end

--==================================================================================================
-- Unit Control
--==================================================================================================


---@alias SetCostKey
---| "buildTime=number"
---| "metalCost=number"
---| "energyCost=number"

---@param unitID number
---@param where SetCostKey
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitCosts)
function Spring.SetUnitCosts (unitID, where)
	return nil
end

--==================================================================================================
-- Unit Resourcing
--==================================================================================================

---@param UnitID number
---@param res string | '[u|c][u|m][m|e]' # `[unconditional|conditional][use|make][metal|energy]` ex. `"uum"`, `"cme"`
---@param amount number
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitResourcing)
function Spring.SetUnitResourcing (UnitID, res, amount)
	return nil
end

---@param UnitID number
---@param res table
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitResourcing)
function Spring.SetUnitResourcing (UnitID, res)
	return nil
end

---@param unitID number
---@param tooltip string
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitTooltip)
function Spring.SetUnitTooltip (unitID, tooltip)
	assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
	assert(type(tooltip) == "string","Argument tooltip is of invalid type - expected string");
	return  nil
end

---@param unitID number
---@param health number | string #number or {[string]=number,...} where keys can be one of health|capture|paralyze|build and values are amounts
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitHealth)
function Spring.SetUnitHealth (unitID, health)
	return
end

---@param unitID number
---@param maxHealth number
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitMaxHealth)
function Spring.SetUnitMaxHealth (unitID, maxHealth)
	assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
	assert(type(maxHealth) == "number","Argument maxHealth is of invalid type - expected number");
	return  nil
end

---@param unitID number
---@param stockpile number
---@param buildPercent number
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitStockpile)
function Spring.SetUnitStockpile (unitID, stockpile, buildPercent)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(stockpile) == "number","Argument stockpile is of invalid type - expected number");
assert(type(buildPercent) == "number","Argument buildPercent is of invalid type - expected number");
return  nil
end

---@param unitID number
---@param forceUseWeapons? number # 
---@param allowUseWeapons? number # 
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitUseWeapons)
function Spring.SetUnitUseWeapons (unitID, forceUseWeapons, allowUseWeapons)
	return nil
end


---@alias states table
---| 'reloadState':number
---| "reloadFrame=number" # synonym for reloadState!
---| "reloadTime=number"
---| "accuracy=number"
---| "sprayAngle=number"
---| "range=number" # if you change the range of a weapon with dynamic damage make sure you use `SetUnitWeaponDamages` to change dynDamageRange as well.
---| "projectileSpeed=number"
---| "burst=number"
---| "burstRate=number"
---| "projectiles=number"
---| "salvoLeft=number"
---| "nextSalvo=number"
---| "aimReady=number" # (<>0.0f := true)

---@param unitID number
---@param weaponNum number
---@param states states
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitWeaponState)
---@diagnostic disable-next-line
function Spring.SetUnitWeaponState (unitID, weaponNum, states)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(weaponNum) == "number","Argument weaponNum is of invalid type - expected number");
assert(type(states) == "table","Argument states is of invalid type - expected table");
return nil
end

---@param unitID number
---@param weaponNum number
---@param key states
---@param value number
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitWeaponState)
---@diagnostic disable-next-line 
function Spring.SetUnitWeaponState (unitID, weaponNum, key, value)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(weaponNum) == "number","Argument weaponNum is of invalid type - expected number");
assert(type(states) == "table","Argument states is of invalid type - expected table");
return nil
end

---@alias damages table
---| "paralyzeDamageTime=number" 
---| "impulseFactor=number" 
---| "impulseBoost=number" 
---| "craterMult=number" 
---| "craterBoost=number" 
---| "dynDamageExp=number" 
---| "dynDamageMin=number" 
---| "dynDamageRange=number" 
---| "dynDamageInverted=number" (<>0.0f := true)
---| "craterAreaOfEffect=number" 
---| "damageAreaOfEffect=number" 
---| "edgeEffectiveness=number" 
---| "explosionSpeed=number" 

---@param unitID number
---@param weaponNum number | string # Number or string ["selfDestruct" | "explode"]
---@param damages damages
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitWeaponDamages)
---@diagnostic disable-next-line
function Spring.SetUnitWeaponDamages (unitID, weaponNum, damages)
	assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
	assert(type(weaponNum) == "number","Argument weaponNum is of invalid type - expected number");
	return  nil
end

---@param unitID number
---@param weaponNum number | string # Number or string ["selfDestruct" | "explode"]
---@param key string
---@param value number
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitWeaponDamages)
---@diagnostic disable-next-line
function Spring.SetUnitWeaponDamages (unitID, weaponNum, key, value)
	assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
	assert(type(weaponNum) == "number","Argument weaponNum is of invalid type - expected number");
	return  nil
end

---@param unitID number
---@param maxRange number
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitMaxRange)
function Spring.SetUnitMaxRange (unitID, maxRange)
	assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
	assert(type(maxRange) == "number","Argument maxRange is of invalid type - expected number");
	return nil
end

---@param unitID number
---@param experience number
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitExperience)
---@see Spring.AddUnitExperience
function Spring.SetUnitExperience (unitID, experience)
	assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
	assert(type(experience) == "number","Argument experience is of invalid type - expected number");
	return  numberMock
end

---@param unitID number
---@param deltaExperience number # Can be negative to subtract, but the unit will never have negative total afterwards
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.AddUnitExperience)
---@see Spring.SetUnitExperience
function Spring.AddUnitExperience (unitID, deltaExperience)
	return nil
end

---@param unitID number
---@param armored? boolean
---@param armorMultiple? number # Cannot be less than zero, clamped to .0001 
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitArmored)
function Spring.SetUnitArmored (unitID, armored, armorMultiple)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(armored) == "boolean","Argument armored is of invalid type - expected boolean");
assert(type(armorMultiple) == "number","Argument armorMultiple is of invalid type - expected number");
return  nil
end

--==================================================================================================
-- Unit LOS
--==================================================================================================


---The 3rd argument is either the bit-and combination of the following numbers: LOS_INLOS = 1 LOS_INRADAR = 2 LOS_PREVLOS = 4 LOS_CONTRADAR = 8 or a table of the following form: losTypes = { [los = boolean,] [radar = boolean,] [prevLos = boolean,] [contRadar = boolean] }
---@param unitID number
---@param allyTeam number
---@param losTypes number | table
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitLosMask)
function Spring.SetUnitLosMask (unitID, allyTeam, losTypes)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(allyTeam) == "number","Argument allyTeam is of invalid type - expected number");
--assert(type(los) == "number","Argument los is of invalid type - expected number");
return  nil
end

---The 3rd argument is either the bit-and combination of the following numbers: LOS_INLOS = 1 LOS_INRADAR = 2 LOS_PREVLOS = 4 LOS_CONTRADAR = 8 or a table of the following form: losTypes = { [los = boolean,] [radar = boolean,] [prevLos = boolean,] [contRadar = boolean] }
---@param unitID number
---@param allyTeam number
---@param los number | table
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitLosState)
function Spring.SetUnitLosState(unitID, allyTeam, los)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(allyTeam) == "number","Argument allyTeam is of invalid type - expected number");
assert(type(los) == "number","Argument los is of invalid type - expected number");
return  nil
end

---If the 2nd argument is a number, the value works like this: 1:=normal cloak 2:=for free cloak (cost no E) 3:=for free + no decloaking (except the unit is stunned) 4:=ultimative cloak (no ecost, no decloaking, no stunned decloak) The decloak distance is only changed: - if the 3th argument is a number or a boolean. - if the boolean is false it takes the default decloak distance for that unitdef, - if the boolean is true it takes the absolute value of it.
---@param unitID number
---@param cloak boolean | number
---@param cloakArg boolean | number
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitCloak)
function Spring.SetUnitCloak (unitID, cloak, cloakArg)
return nil
end

---@param unitID number
---@param stealth boolean
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitStealth)
function Spring.SetUnitStealth (unitID, stealth)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(stealth) == "boolean","Argument stealth is of invalid type - expected boolean");
return nil
end

---@param unitID number
---@param sonarStealth boolean
---@return nil
function Spring.SetUnitSonarStealth (unitID, sonarStealth)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(sonarStealth) == "boolean","Argument sonarStealth is of invalid type - expected boolean");
return nil
end

---@param unitID number
---@param seismicSignature number
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitSeismicSignature)
function Spring.SetUnitSeismicSignature (unitID, seismicSignature)
	return nil
end

---@param unitID number
---@param alwaysVisible boolean
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitAlwaysVisible)
function Spring.SetUnitAlwaysVisible(unitID, alwaysVisible)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(alwaysVisible) == "boolean","Argument alwaysVisible is of invalid type - expected boolean");
return nil
end

---@param unitID number
---@param useAirLos boolean
---@return nil
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitUseAirLos)
function Spring.SetUnitUseAirLos(unitID, useAirLos)
	return nil
end

---@param unitID number
---@param depth number # corresponds to metal extraction rawState
---@param range? number similar to "extractsMetal" in unitDefs 
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitMetalExtraction)
function Spring.SetUnitMetalExtraction(unitID, depth, range) end

---@param unitID number
---@param metal number
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitHarvestStorage)
function Spring.SetUnitHarvestStorage (unitID, metal)
	assert(type(unitid) == "number","Argument unitid is of invalid type - expected number");
	assert(type(metal) == "number","Argument metal is of invalid type - expected number");
end

---@param unitID number
---@param paramName string # one of `buildRange|buildDistance|buildRange3D`
---@param value number | boolean # boolean when `paramName` is `buildRange3D`, number otherwise
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitBuildParams)
function Spring.SetUnitBuildParams(unitID, paramName, value) end

---@param builderID number
---@param buildSpeed number
---@param repairSpeed? number #
---@param reclaimSpeed? number #
---@param captureSpeed? number #
---@param terraformSpeed? number #
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitBuildSpeed)
function Spring.SetUnitBuildSpeed (builderID, buildSpeed, repairSpeed, reclaimSpeed, captureSpeed, terraformSpeed) end

---This saves a lot of engine calls, by replacing: `function script.QueryNanoPiece() return currentpiece end` **Use it!**
---@param builderID number
---@param pieces table
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitNanoPieces)
function Spring.SetUnitNanoPieces (builderID, pieces)
	assert(type(builderID) == "number","Argument builderID is of invalid type - expected number");
	assert(type(pieces) == "table","Argument pieces is of invalid type - expected table");
end

---@param unitID number
---@param isBlocking boolean
---@param isSolidObjectCollidable boolean
---@param isProjectileCollidable boolean
---@param isRaySegmentCollidable boolean
---@param crushable boolean
---@param blockEnemyPushing boolean
---@param blockHeightChanges boolean
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitBlocking)
function Spring.SetUnitBlocking (unitID, isBlocking, isSolidObjectCollidable, isProjectileCollidable, isRaySegmentCollidable, crushable, blockEnemyPushing, blockHeightChanges)
	assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
	assert(type(isBlocking) == "boolean","Argument isBlocking is of invalid type - expected boolean");
	assert(type(isSolidObjectCollidable) == "boolean","Argument isSolidObjectCollidable is of invalid type - expected boolean");
	assert(type(isProjectileCollidable) == "boolean","Argument isProjectileCollidable is of invalid type - expected boolean");
	assert(type(isRaySegmentCollidable) == "boolean","Argument isRaySegmentCollidable is of invalid type - expected boolean");
	assert(type(crushable) == "boolean","Argument crushable is of invalid type - expected boolean");
	assert(type(blockEnemyPushing) == "boolean","Argument blockEnemyPushing is of invalid type - expected boolean");
	assert(type(blockHeightChanges) == "boolean","Argument blockHeightChanges is of invalid type - expected boolean");
end

--function Spring.SetUnitBlocking (unitID, blocking, collide, crushable)
--assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
--assert(type(blocking) == "boolean","Argument blocking is of invalid type - expected boolean");
--assert(type(collide) == "boolean","Argument collide is of invalid type - expected boolean");
--assert(type(crushable) == "boolean","Argument crushable is of invalid type - expected boolean");
--return  numberMock
-- end

--function Spring.SetUnitBlocking (unitID, depth, range)
--assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
--assert(type(depth) == "number","Argument depth is of invalid type - expected number");
--assert(type(range) == "number","Argument range is of invalid type - expected number");
--return  numberMock
-- end

---@param unitID number
---@param crashing boolean
---@return boolean success
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitCrashing)
function Spring.SetUnitCrashing (unitID, crashing)
	assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
	assert(type(crashing) == "boolean","Argument crashing is of invalid type - expected boolean");
	return booleanMock
end

---@param unitID number
---@param weaponID number (default -1)
---@param enabled boolean? 
---@param power number?
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitShieldState)
function Spring.SetUnitShieldState (unitID, weaponID, enabled, power)
	assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
	assert(type(weaponID) == "number","Argument weaponID is of invalid type - expected number");
end

---@param unitID number
---@param type string
---|"dir"
---|"minDamage"
---|"maxDamage"
---|"moveFactor"
---|"mode" # if type = mode, 0 = no flanking bonus, 1 = global coords, mobile, 2 = unit coords, mobile, 3 = unit coords, locked
---@param arg1 number
---| 'x'
---| 'minDamage'
---| 'maxDamage'
---| 'moveFactor'
---| 'mode'
---@param y number? # only when type is "dir" 
---@param z number? # only when type is "dir" 
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitFlanking)
function Spring.SetUnitFlanking (unitID, type, arg1, y, z)
	assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
	assert(type(mode) == "string","Argument mode is of invalid type - expected string");
end

---@param unitID number
---@param neutral boolean
---@return nil | boolean
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitNeutral)
function Spring.SetUnitNeutral (unitID, neutral)
	assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
	assert(type(neutral) == "boolean","Argument neutral is of invalid type - expected boolean");
	return  nil
end

---@param unitID number
---@param x? number # when nil or not passed it will drop target and ignore other parameters 
---@param y? number # 
---@param z? number # 
---@param dgun boolean? # default false
---@param userTarget boolean? # default false
---@param weaponNum number? # default -1
---@return boolean success
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitTarget)
function Spring.SetUnitTarget (unitID, x, y, z, dgun, userTarget, weaponNum)
	return  booleanMock
end

---@param unitID number
---@param enemyUnitID? number # when nil, drops the units current target
---@param dgun boolean? # default false
---@param userTarget boolean? # default false
---@param weaponNum number? # default -1
---@return boolean success
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitTarget)
function Spring.SetUnitTarget (unitID, enemyUnitID, dgun, userTarget, weaponNum)
	return  booleanMock
end

---@param unitID number
---@param mpX number new middle positionX of unit
---@param mpY number new middle positionY of unit
---@param mpZ number new middle positionZ of unit
---@param apX number new positionX that enemies aim at on this unit
---@param apY number new positionY that enemies aim at on this unit
---@param apZ number new positionZ that enemies aim at on this unit
---@param relative? boolean are the new coordinates relative to the world (false) or unit (true) coordinates? Also, not that apY is inverted. (default false) 
---@return boolean success
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitMidAndAimPos)
function Spring.SetUnitMidAndAimPos(unitID, mpX, mpY, mpZ, apX, apY, apZ, relative)
	return  booleanMock
end

---@param unitID number
---@param radius number
---@param height number
---@return boolean success
---
---[Open in Browser](https://beyond-all-reason.github.io/spring/ldoc/modules/SyncedCtrl.html#Spring.SetUnitRadiusAndHeight)
function Spring.SetUnitRadiusAndHeight (unitID, radius, height)
	assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
	assert(type(radius) == "number","Argument radius is of invalid type - expected number");
	assert(type(height) == "number","Argument height is of invalid type - expected number");
	return booleanMock
end

---@param transporterID number
---@param passengerID number
---@param pieceNum number
---@return nil
function Spring.UnitAttach (transporterID, passengerID, pieceNum)
assert(type(transporterID) == "number","Argument transporterID is of invalid type - expected number");
assert(type(passengerID) == "number","Argument passengerID is of invalid type - expected number");
assert(type(pieceNum) == "number","Argument pieceNum is of invalid type - expected number");
return  nil
end

--=================================
--TODO Continue from here 6-6-23
--=================================

---@param passengerID number
---@return nil
function Spring.UnitDetach (passengerID)
assert(type(passengerID) == "number","Argument passengerID is of invalid type - expected number");
return  nil
end

---@param passengerID number
---@return nil
function Spring.UnitDetachFromAir (  passengerID)
assert(type(passengerID) == "number","Argument passengerID is of invalid type - expected number");
return  nil
end

---@param passengerID number
---@param transportID number
---@return nil
function Spring.SetUnitLoadingTransport (  passengerID, transportID)
assert(type(passengerID) == "number","Argument passengerID is of invalid type - expected number");
assert(type(transportID) == "number","Argument transportID is of invalid type - expected number");
return  nil
end

---Changes the pieces hierarchy of a unit by attaching a piece to a new parent.
---@param unitID number
---@param AlteredPiece number
---@param ParentPiece number
---@return nil
function Spring.SetUnitPieceParent (unitID, AlteredPiece, ParentPiece)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(AlteredPiece) == "number","Argument AlteredPiece is of invalid type - expected number");
assert(type(ParentPiece) == "number","Argument ParentPiece is of invalid type - expected number");
return  nil
end

---@alias COLVOL_TYPES table
---| "COLVOL_TYPE_DISABLED=-1"
---| "COLVOL_TYPE_ELLIPSOID=0"
---| "COLVOL_TYPE_CYLINDER=0"
---| "COLVOL_TYPE_BOX=0"
---| "COLVOL_TYPE_SPHERE=0"
---| "COLVOL_NUM_TYPES=0" ---number of non-disabled collision volumn types

---@alias COLVOL_TESTS table
---| "COLVOL_TEST_DISC=0"
---| "COLVOL_TEST_CONT=1"
---| "COLVOL_NUM_TESTS=2"  // number of tests

---@alias COLVOL_AXES table
---| "COLVOL_AXIS_X=0"
---| "COLVOL_AXIS_Y=1"
---| "COLVOL_AXIS_Z=2"
---| "COLVOL_NUM_AXES=3"   // number of collision volume axes

---@param UnitID number
---@param scaleX number
---@param scaleY number
---@param scaleZ number
---@param offsetX number
---@param offsetY number
---@param offsetZ number
---@param vType COLVOL_TYPES
---@param tType COLVOL_TESTS
---@param Axis COLVOL_AXES
---@diagnostic disable-next-line
function Spring.SetUnitCollisionVolumeData (UnitID, scaleX, scaleY, scaleZ, offsetX, offsetY, offsetZ, vType, tType, Axis)
return nil
end
--- piece volumes not allowed to use discrete hit-testing
---@param unitID number
---@param pieceIndex number
---@param enable boolean
---@param scaleX number
---@param scaleY number
---@param scaleZ number
---@param offsetX number
---@param offsetY number
---@param offsetZ number
---@param volumeType? number 
---@param primaryAxis? number 
function Spring.SetUnitPieceCollisionVolumeData (unitID, pieceIndex, enable, scaleX, scaleY, scaleZ, offsetX, offsetY, offsetZ, volumeType, primaryAxis)
return nil
end

---Deprecated and marked for deletion in CPP API fields
---@param unitID number
---@param travel number
---@param travelPeriod number
---@return nil
---@deprecated
function Spring.SetUnitTravel (unitID, travel, travelPeriod)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(travel) == "number","Argument travel is of invalid type - expected number");
assert(type(travelPeriod) == "number","Argument travelPeriod is of invalid type - expected number");
return  nil
end

---Used by default commands to get in build-, attackrange etc.
---@param unitID number
---@param goalx number
---@param goaly number
---@param goalz number
---@param goalRadius? number 
---@param moveSpeed? number 
---@param moveRaw? boolean 
---@return nil
function Spring.SetUnitMoveGoal (unitID, goalx, goaly, goalz, goalRadius, moveSpeed, moveRaw)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(goalx) == "number","Argument goalx is of invalid type - expected number");
assert(type(goaly) == "number","Argument goaly is of invalid type - expected number");
assert(type(goalz) == "number","Argument goalz is of invalid type - expected number");
assert(type(goalRadius) == "number","Argument goalRadius is of invalid type - expected number");
assert(type(moveSpeed) == "number","Argument moveSpeed is of invalid type - expected number");
return  nil
end

---Used in conjuction with Spring.UnitAttach et al.
---to re-implement old airbase & fuel system in lua
---@param unitID number
---@param goalX number
---@param goalY number
---@param goalZ number
---@param goalRadius? number
---@return nil
---@see Spring.UnitAttach
---@see Spring.ClearUnitGoal
function Spring.SetLandUnitGoal(unitID, goalX, goalY, goalZ, goalRadius)
	return nil
end

unitdefs = Spring.CreateUnit('number UnitDefID')

---@param unitID number
---@return nil
---@see Spring.SetLandUnitGoal
---@see Spring.SetUnitMoveGoal
function Spring.ClearUnitGoal(unitID)
	return nil
end

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
function Spring.SetUnitPhysics(unitID, posX, posY, posZ, velX, velY, velZ, rotX, rotY, rotZ, dragX, dragY, dragZ)
	return nil
end

---@param unitID number
---@param mass number
---@return nil
function Spring.SetUnitMass(unitID, mass)
return nil
end

---@param unitID number
---@param x number
---@param z number
---@param alwaysAboveSea? boolean 
---@return nil
function Spring.SetUnitPosition (unitID, x, z, alwaysAboveSea)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(alwaysAboveSea) == "boolean","Argument alwaysAboveSea is of invalid type - expected boolean");
return  nil
end

---@param unitID number
---@param velx number
---@param vely number
---@param velz number
---@return nil
function Spring.SetUnitVelocity (unitID, velx, vely, velz)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(velx) == "number","Argument velx is of invalid type - expected number");
assert(type(vely) == "number","Argument vely is of invalid type - expected number");
assert(type(velz) == "number","Argument velz is of invalid type - expected number");
return  nil
end

---@param unitID number
---@param rotx number
---@param roty number
---@param rotz number
---@return nil
function Spring.SetUnitRotation (unitID, rotx, roty, rotz)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(rotx) == "number","Argument rotx is of invalid type - expected number");
assert(type(roty) == "number","Argument roty is of invalid type - expected number");
assert(type(rotz) == "number","Argument rotz is of invalid type - expected number");
return  nil
end

---@param unitID number
---@param yaw number
---@param pitch number
---@param roll number
---@return nil
function Spring.SetUnitDirection (unitID, yaw, pitch, roll)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  nil
end

---@param unitID number
---@param x number
---@param y number
---@param z number
---@param decayRate? number 
---@return nil
function Spring.AddUnitImpulse (unitID, x, y, z, decayRate)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  nil
end

---@param unitID number
---@param pingSize number
---@return nil
function Spring.AddUnitSeismicPing (unitID, pingSize)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(pingSize) == "number","Argument pingSize is of invalid type - expected number");
return  nil
end

---Deprecated - no references to this function in current recoil engine 2023-06-04
---@param unitID number
---@deprecated
---@return nil
function Spring.RemoveBuildingDecal (unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  nil
end

---@param unitID number
---@param weaponID number
---@return nil
function Spring.UnitWeaponFire (unitID, weaponID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(weaponID) == "number","Argument weaponID is of invalid type - expected number");
return  nil
end

--TODO is this function deprecated, debug only, or intended to be maintained?
---Marked not permanent, missing doc in Recoil API autodoc 
---@param unitID number
---@param weaponID number
---@return nil
function Spring.UnitWeaponHoldFire (unitID, weaponID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(weaponID) == "number","Argument weaponID is of invalid type - expected number");
return nil
end

---Sets a unit sensor radius based on sensor type
---@param unitID number
---@param type string "los" | "airLos" | "radar" | "sonar" | "seismic" | "radarJammer" | "sonarJammer"
---@return nil | number newRadius
function Spring.SetUnitSensorRadius(unitID, type)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(type) == "string","Argument type is of invalid type - expected string");
--assert(type(radius) == "number","Argument radius is of invalid type - expected number"); radius is defined by type
return numberMock
end

function Spring.SetRadarErrorParams ( )
return  numberMock
end

function Spring.SetUnitPosErrorParams ( )
return  numberMock
end

function Spring.AddUnitResource (unitID, m)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(m) == "string","Argument m is of invalid type - expected string");
return  numberMock
end

function Spring.UseUnitResource (unitID, m)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(m) == "string","Argument m is of invalid type - expected string");
return  booleanMock
end

function Spring.DestroyFeature (  featureID)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
return  numberMock
end

function Spring.TransferFeature (  featureID, teamID)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
end

function Spring.SetFeatureHealth (  featureID, health)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(health) == "number","Argument health is of invalid type - expected number");
return  numberMock
end

function Spring.SetFeatureReclaim (  featureID, reclaimLeft)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(reclaimLeft) == "number","Argument reclaimLeft is of invalid type - expected number");
return  numberMock
end

function Spring.SetFeatureResurrect (  featureID, UnitDefName, facing)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(UnitDefName) == "string","Argument UnitDefName? is of invalid type - expected string");
assert(type(facing) == "number","Argument facing is of invalid type - expected number");
return  numberMock
end

function Spring.SetFeaturePosition (  featureID, x, y, z, snapToGround)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(snapToGround) == "boolean","Argument snapToGround is of invalid type - expected boolean");
return  numberMock
end

function Spring.SetFeatureDirection (  featureID, x, y, z)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
end

function Spring.SetFeatureVelocity ( featureID, noSelect)

assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(noSelect) == "boolean","Argument noSelect is of invalid type - expected boolean");
return  numberMock
end

function Spring.SetFeatureAlwaysVisible (  featureID, enable)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(enable) == "boolean","Argument enable is of invalid type - expected boolean");
return  numberMock
end

function Spring.SetFeatureCollisionVolumeData ( )
return
end

function Spring.SetUnitCollisionVolumeData ( )
return  booleanMock
end

---@param featureID number
---@param mpX number new middle positionX of unit
---@param mpY number new middle positionY of unit
---@param mpZ number new middle positionZ of unit
---@param apX number new positionX that enemies aim at on this unit
---@param apY number new positionY that enemies aim at on this unit
---@param apZ number new positionZ that enemies aim at on this unit
---@param relative? boolean are the new coordinates relative to the world (false) or unit (true) coordinates? Also, not that apY is inverted. (default false) 
---@return boolean
function Spring.SetFeatureMidAndAimPos ( featureID, mpX, mpY, mpZ, apX, apY, apZ, relative)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(radius) == "number","Argument radius is of invalid type - expected number");
assert(type(height) == "number","Argument height is of invalid type - expected number");
return  numberMock
end

function Spring.SetFeatureBlocking (  featureID, blocking, collidable)
assert(type(featureID) == "number","Argument featureID is of invalid type - expected number");
assert(type(blocking) == "boolean","Argument blocking is of invalid type - expected boolean");
assert(type(collidable) == "boolean","Argument collidable is of invalid type - expected boolean");
return  numberMock
end

function Spring.SetFeatureBlocking (unitID, funcID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(funcID) == "number","Argument funcID is of invalid type - expected number");
return  numberMock
end

function Spring.CallCOBScriptCB (unitID, funcID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(funcID) == "number","Argument funcID is of invalid type - expected number");
return  numberMock
end


function Spring.SetUnitCOBValue (unitID, COBValue, param1)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(COBValue) == "number","Argument COBValue is of invalid type - expected number");
assert(type(param1) == "number","Argument param1 is of invalid type - expected number");
return  numberMock
end

function Spring.GiveOrderToUnit ( )
return
end

function Spring.GiveOrderToUnitMap ( )
return
end

function Spring.GiveOrderToUnitArray ( )
return
end

function Spring.GiveOrderArrayToUnitMap ( )
return
end

function Spring.GiveOrderArrayToUnitArray ( )
return
end

function Spring.AddGrass (  x, z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
end

function Spring.RemoveGrass (  x, z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
end

function Spring.LevelHeightMap (  x,z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
end

function Spring.AdjustHeightMap (  x,z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
end

function Spring.RevertHeightMap (  x,z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
end

function Spring.SetHeightMapFunc ( )
return  numberMock
end



function Spring.SetHeightMap ( x, z, height, terraform)

assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(height) == "number","Argument height is of invalid type - expected number");
assert(type(terraform) == "number","Argument terraform is of invalid type - expected number");
return  numberMock
end

function Spring.LevelSmoothMesh (  x,z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
end


function Spring.AdjustSmoothMesh (  x,z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
end


function Spring.RevertSmoothMesh (  x,z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
end


function Spring.SetSmoothMeshFunc ( )
return  numberMock
end

function Spring.AddSmoothMesh ( x, z, height)

assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(height) == "number","Argument height is of invalid type - expected number");
return  numberMock
end

function Spring.SetSmoothMesh (
x, z, height, terraform)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(height) == "number","Argument height is of invalid type - expected number");
assert(type(terraform) == "number","Argument terraform is of invalid type - expected number");
return  numberMock
end

function Spring.SetMapSquareTerrainType (  x, z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return
end

function Spring.SetTerrainTypeData ( )
return  booleanMock
end

function Spring.SetMetalAmount (  x, z, metalAmount)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(metalAmount) == "number","Argument metalAmount is of invalid type - expected number");
end


function Spring.EditUnitCmdDesc (unitID,  cmdDescID,  cmdArray )

assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(cmdDescID) == "number","Argument cmdDescID is of invalid type - expected number");
assert(type(cmdArray) == "table","Argument cmdArray is of invalid type - expected table");
return  numberMock
end

function Spring.InsertUnitCmdDesc (unitID, cmdDescID, cmdArray)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(cmdDescID) == "number","Argument cmdDescID is of invalid type - expected number");
assert(type(cmdArray) == "table","Argument cmdArray is of invalid type - expected table");
return  numberMock
end

function Spring.RemoveUnitCmdDesc (unitID, cmdDescID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(cmdDescID) == "number","Argument cmdDescID is of invalid type - expected number");
return  numberMock
end

function Spring.SetNoPause (  noPause)
assert(type(noPause) == "boolean","Argument noPause is of invalid type - expected boolean");
return  booleanMock
end

function Spring.SetUnitToFeature (  tofeature)
assert(type(tofeature) == "boolean","Argument tofeature is of invalid type - expected boolean");
return  booleanMock
end

function Spring.SetExperienceGrade ( )
return  numberMock
end

function Spring.SpawnCEG ( )
return  booleanMock
end

function Spring.SpawnProjectile (  weaponDefID, projectileParams)
assert(type(weaponDefID) == "number","Argument weaponDefID is of invalid type - expected number");
assert(type(projectileParams) == "table","Argument projectileParams is of invalid type - expected table");
return  numberMock
end

function Spring.SetProjectileTarget ( )
return  booleanMock
end

function Spring.SetProjectileIsIntercepted (  projID)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
return  numberMock
end

function Spring.SetProjectileMoveControl (
projID, enable)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
assert(type(enable) == "boolean","Argument enable is of invalid type - expected boolean");
return  numberMock
end

function Spring.SetProjectilePosition (  projID, x, y, z)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
end

function Spring.SetProjectileVelocity (  projID, x, y, z)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
end

function Spring.SetProjectileCollision (  projID)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
return  numberMock
end

function Spring.SetProjectileGravity (  projID, grav)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
assert(type(grav) == "number","Argument grav is of invalid type - expected number");
return  numberMock
end

function Spring.SetProjectileSpinAngle (  projID, spinAngle)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
assert(type(spinAngle) == "number","Argument spinAngle is of invalid type - expected number");
return  numberMock
end

function Spring.SetProjectileSpinSpeed (  projID, speed)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
assert(type(speed) == "number","Argument speed is of invalid type - expected number");
return  numberMock
end

function Spring.SetProjectileSpinVec (  projID, x, y, z)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
end

function Spring.SetProjectileCEG (  projID, ceg_)
assert(type(projID) == "number","Argument projID is of invalid type - expected number");
assert(type(ceg_) == "string","Argument ceg_ is of invalid type - expected string");
return  numberMock
end

function Spring.SetPieceProjectileParams ( )
return  numberMock
end

function Spring.SetProjectileAlwaysVisible (  projectileID, alwaysVisible)
assert(type(projectileID) == "number","Argument projectileID is of invalid type - expected number");
assert(type(alwaysVisible) == "boolean","Argument alwaysVisible is of invalid type - expected boolean");
return  numberMock
end

function Spring.SetProjectileDamages (unitID, weaponNum, damages)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(weaponNum) == "number","Argument weaponNum is of invalid type - expected number");
assert(type(damages) == "table","Argument damages is of invalid type - expected table");
return  numberMock
end

--==================================================================================================
-- End of LuaSyncedCtrl, start of ?
--==================================================================================================


function Spring.IsDevLuaEnabled ( )
return  booleanMock
 end

function Spring.IsEditDefsEnabled ( )
return  booleanMock
 end

function Spring.AreHelperAIsEnabled ( )
return  booleanMock
 end

function Spring.FixedAllies ( )
return  booleanMock
 end

function Spring.IsGameOver ( )
return  booleanMock
 end

function Spring.GetRulesInfoMap ( )
return  stringMock
 end

function Spring.GetGameRulesParam (  ruleIndex)
 assert(type(ruleIndex) == "number","Argument ruleIndex is of invalid type - expected number");
 return  numberMock
end

function Spring.GetGameRulesParams ( )
 return  numberMock
end

function Spring.GetTeamRulesParam (index, teamID)
 assert(type(index) == "number","Argument index is of invalid type - expected number");
 assert(type(teamID) == "number","Argument teamID, is of invalid type - expected number");
 return  numberMock
end

function Spring.GetTeamRulesParams (teamID)
 assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
 return  numberMock
end

function Spring.GetUnitRulesParam (unitID, ruleName)
 assert(type(unitID) == "number","Argument index is of invalid type - expected number");
 assert(type(ruleName) == "string","Argument param is of invalid type - expected string");
 return  numberMock
end

function Spring.GetUnitRulesParam (unitID, index)
 assert(type(unitID) == "number","Argument index is of invalid type - expected number");
 assert(type(index) == "number","Argument index is of invalid type - expected number");
 return  numberMock
end

function Spring.GetUnitRulesParams (unitID)
 assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
 return  numberMock
end

function Spring.GetModOptions ( )
return  stringMock
 end

function Spring.GetMapOptions ( )
return  stringMock
 end

function Spring.GetModOptions.exampleOption ()
return  numberMock
 end

function Spring.GetGameFrame ( )
return  numberMock
 end

function Spring.GetGameSeconds ( )
return  numberMock
 end

function Spring.GetWind ( )
return  numberMock
 end

function Spring.GetHeadingFromVector (  x, z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.GetVectorFromHeading (  heading)
assert(type(heading) == "number","Argument heading is of invalid type - expected number");
return  numberMock
 end

function Spring.GetSideData (  sideName)
assert(type(sideName) == "string","Argument sideName is of invalid type - expected string");
return  stringMock
 end

function Spring.GetAllyTeamStartBox (  allyID)
assert(type(allyID) == "number","Argument allyID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamStartPosition (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetPlayerList (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamList (  allyTeamID)
assert(type(allyTeamID) == "number","Argument allyTeamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetAllyTeamList ( )
return  numberMock
 end

function Spring.GetPlayerInfo (  playerID)
assert(type(playerID) == "number","Argument playerID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetPlayerControlledUnit (  playerID)
assert(type(playerID) == "number","Argument playerID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetAIInfo (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetAllyTeamInfo (  allyteamID)
assert(type(allyteamID) == "number","Argument allyteamID is of invalid type - expected number");
return  tableMock
 end

function Spring.GetTeamInfo (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamResources (  metal, teamID)
assert(type(metal) == "string","Argument metal is of invalid type - expected string");
assert(type(teamID) == "number","Argument teamID, is of invalid type - expected number");
return
 end

function Spring.GetTeamUnitStats (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamResourceStats (  metal, teamID)
assert(type(metal) == "string","Argument metal is of invalid type - expected string");
assert(type(teamID) == "number","Argument teamID, is of invalid type - expected number");
return
 end

function Spring.GetTeamStatsHistory (  teamID, endIndex, startIndex)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(endIndex) == "number","Argument endIndex is of invalid type - expected number");
assert(type(startIndex) == "number","Argument startIndex is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamLuaAI (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.AreTeamsAllied (  teamID1)
assert(type(teamID1) == "number","Argument teamID1 is of invalid type - expected number");
return  booleanMock
 end

function Spring.ArePlayersAllied (  playerID1)
assert(type(playerID1) == "number","Argument playerID1 is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetAllUnits ( )
return  numberMock
 end

function Spring.GetTeamUnits (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamUnitsSorted (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return
 end

function Spring.GetTeamUnitsCounts (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamUnitsByDefs (  teamID, unitDefID)
assert(type(teamID) == "number","Argument teamID, is of invalid type - expected number");
assert(type(unitDefID) == "number","Argument unitDefID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamUnitDefCount (  teamID, unitDefID)
assert(type(teamID) == "number","Argument teamID, is of invalid type - expected number");
assert(type(unitDefID) == "number","Argument unitDefID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamUnitCount (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetUnitsInRectangle (  xmin, zmin, xmax, zmax, teamID)
assert(type(xmin) == "number","Argument xmin, is of invalid type - expected number");
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(zmin) == "number","Argument zmin, is of invalid type - expected number");
assert(type(zmax) == "number","Argument zmax is of invalid type - expected number");
assert(type(xmax) == "number","Argument xmax, is of invalid type - expected number");
return  tableMock
 end

function Spring.GetUnitsInBox ( xmin, ymin, zmin, xmax, ymax, zmax, teamID)
assert(type(xmin) == "number","Argument xmin, is of invalid type - expected number");
assert(type(ymin) == "number","Argument ymin, is of invalid type - expected number");
assert(type(zmin) == "number","Argument zmin, is of invalid type - expected number");
assert(type(xmax) == "number","Argument xmax, is of invalid type - expected number");
assert(type(ymax) == "number","Argument ymax, is of invalid type - expected number");
assert(type(zmax) == "number","Argument zmax, is of invalid type - expected number");
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  tableMock
 end

function Spring.GetUnitsInSphere (  radius, y, z, teamID, x)
assert(type(radius) == "number","Argument radius is of invalid type - expected number");
assert(type(y) == "number","Argument y, is of invalid type - expected number");
assert(type(z) == "number","Argument z, is of invalid type - expected number");
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(x) == "number","Argument x, is of invalid type - expected number");
return  tableMock
 end

function Spring.GetUnitsInCylinder (x, z, radius, teamID)
    assert(type(x) == "number","Argument x, is of invalid type - expected number");
    assert(type(z) == "number","Argument z, is of invalid type - expected number");
    assert(type(radius) == "number","Argument radius is of invalid type - expected number");
    assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  tableMock
end

function Spring.GetUnitsInPlanes ( )
return  tableMock
 end

function Spring.GetUnitNearestAlly (  range, unitID)
assert(type(range) == "number","Argument range is of invalid type - expected number");
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetUnitNearestEnemy (  range, unitID)
assert(type(range) == "number","Argument range is of invalid type - expected number");
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.ValidUnitID (unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetUnitIsDead (unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetUnitIsActive (unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.SetLastMessagePosition (  x, y, z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

--Spring.Echo ( arg1 [, arg2 [, ... ]] )
-- return: nil 
---@param msg string
function Spring.Echo ( msg, ... )
 assert(type(msg) == "string","Argument command1 is of invalid type - expected string");
return
 end

function Spring.Log ( command1, logLevel )
 assert(type(command1) == "string","Argument command1 is of invalid type - expected string");
 assert(type(logLevel) == "string" or type(logLevel) == "number","Argument command1 is of invalid type - expected string or number");
return
 end

function Spring.SendCommands (  command1)
assert(type(command1) == "string","Argument command1 is of invalid type - expected string");
return  stringMock
 end

function Spring.SetActiveCommand (  action, actionExtra)
assert(type(action) == "string","Argument action is of invalid type - expected string");
assert(type(actionExtra) == "string","Argument actionExtra is of invalid type - expected string");
return  booleanMock
 end

function Spring.LoadCmdColorsConfig (  config)
assert(type(config) == "string","Argument config is of invalid type - expected string");
return  stringMock
 end

function Spring.LoadCtrlPanelConfig (  config)
assert(type(config) == "string","Argument config is of invalid type - expected string");
return  stringMock
 end

function Spring.ForceLayoutUpdate ( )
return
 end

function Spring.SetDrawSelectionInfo (  enable)
assert(type(enable) == "boolean","Argument enable is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.SetMouseCursor (  cursorName, scale)
assert(type(cursorName) == "string","Argument cursorName is of invalid type - expected string");
assert(type(scale) == "number","Argument scale is of invalid type - expected number");
return  stringMock
 end

function Spring.WarpMouse (  x, y)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
return  numberMock
 end

function Spring.SetLosViewColors (  always, LOS, radar, jam, radar2)
assert(type(always) == "table","Argument always is of invalid type - expected table");
assert(type(LOS) == "table","Argument LOS is of invalid type - expected table");
assert(type(radar) == "table","Argument radar is of invalid type - expected table");
assert(type(jam) == "table","Argument jam is of invalid type - expected table");
assert(type(radar2) == "table","Argument radar2 is of invalid type - expected table");
return  tableMock
 end

function Spring.SendMessage (  message)
assert(type(message) == "string","Argument message is of invalid type - expected string");
return  stringMock
 end

function Spring.SendMessageToPlayer (  playerID, message)
assert(type(playerID) == "number","Argument playerID is of invalid type - expected number");
assert(type(message) == "string","Argument message is of invalid type - expected string");
return  numberMock
 end

function Spring.SendMessageToTeam (  teamID, message)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(message) == "string","Argument message is of invalid type - expected string");
return  numberMock
 end

function Spring.SendMessageToAllyTeam (  allyID, message)
assert(type(allyID) == "number","Argument allyID is of invalid type - expected number");
assert(type(message) == "string","Argument message is of invalid type - expected string");
return  numberMock
 end

function Spring.SendMessageToSpectators (  message)
assert(type(message) == "string","Argument message is of invalid type - expected string");
return  stringMock
 end

function Spring.MarkerAddPoint (  x, y, z, text)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(text) == "string","Argument text is of invalid type - expected string");
return  numberMock
 end

function Spring.MarkerAddLine (  x1)
assert(type(x1) == "number","Argument x1 is of invalid type - expected number");
return  numberMock
 end

function Spring.MarkerErasePosition (  x, y, z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.LoadSoundDef (  soundfile)
assert(type(soundfile) == "string","Argument soundfile is of invalid type - expected string");
return  booleanMock
 end

function Spring.PlaySoundFile (  soundfile, volume)
assert(type(soundfile) == "string","Argument soundfile is of invalid type - expected string");
assert(type(volume) == "number","Argument volume is of invalid type - expected number");
return  booleanMock
 end

function Spring.PlaySoundStream (  oggfile, volume)
assert(type(oggfile) == "string","Argument oggfile is of invalid type - expected string");
assert(type(volume) == "number","Argument volume is of invalid type - expected number");
return  booleanMock
 end

function Spring.StopSoundStream ( )
return
 end

function Spring.PauseSoundStream ( )
return
 end

function Spring.SetSoundStreamVolume (  volume)
assert(type(volume) == "number","Argument volume is of invalid type - expected number");
return  numberMock
 end

function Spring.SendLuaUIMsg (  message, mode)
assert(type(message) == "string","Argument message is of invalid type - expected string");
assert(type(mode) == "string","Argument mode is of invalid type - expected string");
return  stringMock
 end

function Spring.SendLuaGaiaMsg (  message)
assert(type(message) == "string","Argument message is of invalid type - expected string");
return  stringMock
 end

function Spring.SendLuaRulesMsg (  message)
assert(type(message) == "string","Argument message is of invalid type - expected string");
return  stringMock
 end

function Spring.SendSkirmishAIMessage (  aiTeam, message)
assert(type(aiTeam) == "number","Argument aiTeam is of invalid type - expected number");
assert(type(message) == "string","Argument message is of invalid type - expected string");
return  booleanMock
 end

function Spring.SetUnitLeaveTracks (unitID, leavetracks)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(leavetracks) == "boolean","Argument leavetracks is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SelectUnitMap (  keyUnitIDvalueAnything, append)
assert(type(keyUnitIDvalueAnything) == "table","Argument keyUnitIDvalueAnything is of invalid type - expected table");
assert(type(append) == "boolean","Argument append is of invalid type - expected boolean");
return  tableMock
 end

function Spring.SelectUnitArray (unitIDs, append)
assert(type(unitIDs) == "table","Argument unitIDs is of invalid type - expected table");
assert(type(append) == "boolean","Argument append is of invalid type - expected boolean");
return  tableMock
 end

function Spring.SetDrawSelectionInfo (  drawSelectionInfo)
assert(type(drawSelectionInfo) == "boolean","Argument drawSelectionInfo is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.SetUnitGroup (unitID, groupID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(groupID) == "number","Argument groupID is of invalid type - expected number");
return  numberMock
 end

function Spring.GiveOrder ( )
return  booleanMock
 end

function Spring.GiveOrderToUnit ( )
return  booleanMock
 end

function Spring.GiveOrderToUnitMap ( )
return  booleanMock
 end

function Spring.GiveOrderToUnitArray ( )
return  booleanMock
 end

function Spring.GiveOrderArrayToUnitMap ( )
return  booleanMock
 end

function Spring.GiveOrderArrayToUnitArray ( )
return  booleanMock
 end

function Spring.SetBuildFacing (  Facing)
assert(type(Facing) == "number","Argument Facing is of invalid type - expected number");
return  numberMock
 end

function Spring.SetBuildSpacing (  Spacing)
assert(type(Spacing) == "number","Argument Spacing is of invalid type - expected number");
return  numberMock
 end

function Spring.SetUnitNoDraw (unitID, noDraw)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(noDraw) == "boolean","Argument noDraw is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetUnitNoSelect (unitID, noSelect)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(noSelect) == "boolean","Argument noSelect is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetUnitNoMinimap (unitID, noMinimap)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(noMinimap) == "boolean","Argument noMinimap is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetDrawSky (  drawSky)
assert(type(drawSky) == "boolean","Argument drawSky is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.SetDrawWater (  drawWater)
assert(type(drawWater) == "boolean","Argument drawWater is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.SetDrawGround (  drawGround)
assert(type(drawGround) == "boolean","Argument drawGround is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.SetWaterParams (  params)
assert(type(params) == "table","Argument params is of invalid type - expected table");
return  tableMock
 end

function Spring.SetLogSectionFilterLevel (  sectionName, logLevel)
assert(type(sectionName) == "string","Argument sectionName is of invalid type - expected string");
assert(type(logLevel) == "number","Argument logLevel is of invalid type - expected number");
return  booleanMock
 end


function Spring.SetDrawGroundDeferred ( Activate)
assert(type(Activate) == "boolean","Argument Activate is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.SetDrawModelsDeferred (  Activate)
assert(type(Activate) == "boolean","Argument Activate is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.DrawUnitCommands (unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.SetTeamColor (  teamID, r, g, b)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(r) == "number","Argument r is of invalid type - expected number");
assert(type(g) == "number","Argument g is of invalid type - expected number");
assert(type(b) == "number","Argument b is of invalid type - expected number");
return  numberMock
 end

function Spring.AssignMouseCursor ( )
return  booleanMock
 end

function Spring.ReplaceMouseCursor (  oldFileName, newFileName, hotSpotTopLeft)
assert(type(oldFileName) == "string","Argument oldFileName is of invalid type - expected string");
assert(type(newFileName) == "string","Argument newFileName is of invalid type - expected string");
assert(type(hotSpotTopLeft) == "boolean","Argument hotSpotTopLeft is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.SetCustomCommandDrawData ( )
return  tableMock
 end

function Spring.SetShareLevel (  metal)
assert(type(metal) == "string","Argument metal is of invalid type - expected string");
return  stringMock
 end

function Spring.ShareResources (  teamID, units)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(units) == "string","Argument units is of invalid type - expected string");
return  numberMock
 end

---@param unitID number
---@param damage number
---@param paralyze number # equal to the paralyzetime in WeaponDef
---@param attackerID number
---@param weaponID number
---@param impulse_x number
---@param impulse_y number
---@param impulse_z number
---@see paralyzeDamage
---@see Spring.AddUnitImpulse
---@return nil
function Spring.AddUnitDamage ( unitID, damage, paralyze, attackerID, weaponID, impulse_x, impulse_y, impulse_z )
	return  nil
end

function Spring.AddUnitIcon (  iconName, texFile, size, dist, radAdjust)
assert(type(iconName) == "string","Argument iconName is of invalid type - expected string");
assert(type(texFile) == "string","Argument texFile is of invalid type - expected string");
assert(type(size) == "number","Argument size is of invalid type - expected number");
assert(type(dist) == "number","Argument dist is of invalid type - expected number");
assert(type(radAdjust) == "boolean","Argument radAdjust is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.FreeUnitIcon (  iconName)
assert(type(iconName) == "string","Argument iconName is of invalid type - expected string");
return  booleanMock
 end

function Spring.SetUnitDefIcon ( unitDefID, iconName)
assert(type(unitDefID) == "number","Argument unitDefID is of invalid type - expected number");
assert(type(iconName) == "string","Argument iconName is of invalid type - expected string");
return  numberMock
 end

function Spring.SetUnitDefImage ( unitDefID)
assert(type(unitDefID) == "number","Argument unitDefID is of invalid type - expected number");
return  numberMock
 end

function Spring.SetCameraState (  camState, camTime)
assert(type(camState) == "table","Argument camState is of invalid type - expected table");
assert(type(camTime) == "number","Argument camTime is of invalid type - expected number");
return  booleanMock
 end

function Spring.SetCameraTarget (  x, y, z, transTime)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(transTime) == "number","Argument transTime is of invalid type - expected number");
return  numberMock
 end

function Spring.SetCameraOffset ( )
return  numberMock
 end

function Spring.ExtractModArchiveFile (  modfile)
assert(type(modfile) == "string","Argument modfile is of invalid type - expected string");
return  stringMock
 end

function Spring.CreateDir (  path)
assert(type(path) == "number","Argument path is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetConfigInt (  name, default, setInOverlay)
assert(type(name) == "string","Argument name is of invalid type - expected string");
assert(type(default) == "number","Argument default is of invalid type - expected number");
assert(type(setInOverlay) == "boolean","Argument setInOverlay is of invalid type - expected boolean");
return  numberMock
 end

function Spring.SetConfigInt (  name, value, useOverlay)
assert(type(name) == "string","Argument name is of invalid type - expected string");
assert(type(value) == "number","Argument value is of invalid type - expected number");
assert(type(useOverlay) == "boolean","Argument useOverlay is of invalid type - expected boolean");
return  stringMock
 end

function Spring.GetConfigString (  name, default, setInOverlay)
assert(type(name) == "string","Argument name is of invalid type - expected string");
assert(type(default) == "string","Argument default is of invalid type - expected string");
assert(type(setInOverlay) == "boolean","Argument setInOverlay is of invalid type - expected boolean");
return  stringMock
 end

function Spring.SetConfigString (  name, value, useOverlay)
assert(type(name) == "string","Argument name is of invalid type - expected string");
assert(type(value) == "string","Argument value is of invalid type - expected string");
assert(type(useOverlay) == "boolean","Argument useOverlay is of invalid type - expected boolean");
return  stringMock
 end

function Spring.AddWorldIcon (  cmdID, x, y, z)
assert(type(cmdID) == "number","Argument cmdID is of invalid type - expected number");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.AddWorldText (  text, x, y, z)
assert(type(text) == "string","Argument text is of invalid type - expected string");
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  stringMock
 end

function Spring.AddWorldUnit ( )
return  numberMock
 end

function Spring.SetSunManualControl (  setManualControl)
assert(type(setManualControl) == "boolean","Argument setManualControl is of invalid type - expected boolean");
return booleanMock
end

function Spring.SetSunParameters (  dirX, dirY, dirZ, dist, startTime, orbitTime)
assert(type(dirX) == "number","Argument dirX is of invalid type - expected number");
assert(type(dirY) == "number","Argument dirY is of invalid type - expected number");
assert(type(dirZ) == "number","Argument dirZ is of invalid type - expected number");
assert(type(dist) == "number","Argument dist is of invalid type - expected number");
assert(type(startTime) == "number","Argument startTime is of invalid type - expected number");
assert(type(orbitTime) == "number","Argument orbitTime is of invalid type - expected number");
return  numberMock
 end

function Spring.SetSunDirection (  dirX, dirY, dirZ)
assert(type(dirX) == "number","Argument dirX is of invalid type - expected number");
assert(type(dirY) == "number","Argument dirY is of invalid type - expected number");
assert(type(dirZ) == "number","Argument dirZ is of invalid type - expected number");
return  numberMock
 end

function Spring.SetSunLighting (  params)
assert(type(params) == "table","Argument params is of invalid type - expected table");
return  tableMock
 end

function Spring.SetAtmosphere (  params)
assert(type(params) == "table","Argument params is of invalid type - expected table");
return  tableMock
 end

function Spring.Reload (  startscript)
assert(type(startscript) == "string","Argument startscript is of invalid type - expected string");
return booleanMock
end


function Spring.Restart ( commandline_)
assert(type(commandline_) == "string","Argument commandline_ is of invalid type - expected string");
return booleanMock
 end

function Spring.SetWMIcon (  iconFileName)
assert(type(iconFileName) == "string","Argument iconFileName is of invalid type - expected string");
return  stringMock
 end

function Spring.SetWMCaption (  title, titleShort)
assert(type(title) == "string","Argument title is of invalid type - expected string");
assert(type(titleShort) == "string","Argument titleShort is of invalid type - expected string");
return  stringMock
 end

function Spring.ClearWatchdogTimer (  threadName)
assert(type(threadName) == "string","Argument threadName is of invalid type - expected string");
return  stringMock
 end

function Spring.SetClipboard (  text)
assert(type(text) == "string","Argument text is of invalid type - expected string");
return  stringMock
 end

function Spring.AddMapLight ( lightParams)
assert(type(lightParams) == "table","Argument lightParams is of invalid type - expected table");
return  tableMock
 end

function Spring.AddModelLight ( lightParams)
assert(type(lightParams) == "table","Argument lightParams is of invalid type - expected table");
return  tableMock
 end

function Spring.UpdateMapLight (  lightHandle, lightParams)
assert(type(lightHandle) == "number","Argument lightHandle is of invalid type - expected number");
assert(type(lightParams) == "table","Argument lightParams is of invalid type - expected table");
return  numberMock
 end

function Spring.UpdateModelLight (  lightHandle, lightParams)
assert(type(lightHandle) == "number","Argument lightHandle is of invalid type - expected number");
assert(type(lightParams) == "table","Argument lightParams is of invalid type - expected table");
return  numberMock
 end

function Spring.SetMapLightTrackingState ( )
return  booleanMock
 end

function Spring.SetModelLightTrackingState ( )
return  booleanMock
 end

function Spring.SetMapShadingTexture (  texType, texName)
assert(type(texType) == "string","Argument texType is of invalid type - expected string");
assert(type(texName) == "string","Argument texName is of invalid type - expected string");
return  stringMock
 end

function Spring.SetMapSquareTexture (  texSqrX, texSqrY, luaTexName)
assert(type(texSqrX) == "number","Argument texSqrX is of invalid type - expected number");
assert(type(texSqrY) == "number","Argument texSqrY is of invalid type - expected number");
assert(type(luaTexName) == "string","Argument luaTexName is of invalid type - expected string");
return  numberMock
 end

function Spring.SetMapShader (  standardShaderID, deferredShaderID)
assert(type(standardShaderID) == "number","Argument standardShaderID is of invalid type - expected number");
assert(type(deferredShaderID) == "number","Argument deferredShaderID is of invalid type - expected number");
return  numberMock
 end
 
 
function Spring.IsReplay ( )
return  booleanMock
 end

function Spring.GetReplayLength ( )
return  numberMock
 end

function Spring.GetSpectatingState ( )
return  booleanMock
 end

function Spring.GetModUICtrl ( )
return  booleanMock
 end

function Spring.GetMyAllyTeamID ( )
return  numberMock
 end

function Spring.GetMyTeamID ( )
return  numberMock
 end

function Spring.GetMyPlayerID ( )
return  numberMock
 end

function Spring.GetLocalPlayerID ( )
return  numberMock
 end

function Spring.GetLocalTeamID ( )
return  numberMock
 end

function Spring.GetLocalAllyTeamID ( )
return  numberMock
 end

function Spring.GetPlayerRoster (  sortType)
assert(type(sortType) == "number","Argument sortType is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamColor (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamOrigColor (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetPlayerTraffic (  playerID, packetID)
assert(type(playerID) == "number","Argument playerID is of invalid type - expected number");
assert(type(packetID) == "number","Argument packetID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetSoundStreamTime ( )
return  numberMock
 end

function Spring.GetCameraNames ( )
return  tableMock
 end

function Spring.GetCameraState ( )
return  tableMock
 end

function Spring.GetCameraPosition ( )
return  numberMock
 end

function Spring.GetCameraDirection ( )
return  numberMock
 end

function Spring.GetCameraFOV ( )
return  numberMock
 end

function Spring.GetCameraVectors ( )
return  tableMock
 end

function Spring.GetVisibleUnits (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  tableMock
 end

function Spring.GetVisibleFeatures (  allyTeamID)
assert(type(allyTeamID) == "number","Argument allyTeamID is of invalid type - expected number");
return  tableMock
 end

function Spring.IsAABBInView ( )
return  booleanMock
 end

function Spring.IsSphereInView (  x, y, z, radius)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(radius) == "number","Argument radius is of invalid type - expected number");
return  booleanMock
 end

function Spring.IsUnitIcon (unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.IsUnitInView (unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.IsUnitVisible (unitID, radius, checkIcons)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(radius) == "number","Argument radius is of invalid type - expected number");
assert(type(checkIcons) == "boolean","Argument checkIcons is of invalid type - expected boolean");
return  booleanMock
 end

function Spring.WorldToScreenCoords (  x, y, z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.TraceScreenRay ( )
return
 end

function Spring.GetPixelDir (  x, y)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
return  numberMock
 end

function Spring.GetViewGeometry ( )
return  numberMock
 end

function Spring.GetWindowGeometry ( )
return  numberMock
 end

function Spring.GetScreenGeometry ()
return  numberMock
 end

function Spring.IsUnitAllied (unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetUnitViewPosition (unitID, midPos)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(midPos) == "boolean","Argument midPos is of invalid type - expected boolean");
return  numberMock
 end

function Spring.GetUnitTransformMatrix (unitID, invert)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(invert) == "boolean","Argument invert is of invalid type - expected boolean");
return  numberMock
 end

function Spring.GetSelectedUnits ( )
return  tableMock
 end

function Spring.GetSelectedUnitsSorted ( )
return  tableMock
 end

function Spring.GetSelectedUnitsCounts ( )
return  tableMock
 end

function Spring.GetSelectedUnitsCount ( )
return  numberMock
 end

function Spring.IsUnitSelected (unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetUnitGroup (unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetGroupList ( )
return  tableMock
 end

function Spring.GetSelectedGroup ( )
return  numberMock
 end

function Spring.GetGroupAIName (  groupID)
assert(type(groupID) == "number","Argument groupID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetGroupAIList ( )
return  tableMock
 end

function Spring.GetGroupUnits (  groupID)
assert(type(groupID) == "number","Argument groupID is of invalid type - expected number");
return  tableMock
 end

function Spring.GetGroupUnitsSorted (  groupID)
assert(type(groupID) == "number","Argument groupID is of invalid type - expected number");
return
 end

function Spring.GetGroupUnitsCounts (  groupID)
assert(type(groupID) == "number","Argument groupID is of invalid type - expected number");
return  tableMock
 end

function Spring.GetGroupUnitsCount (  groupID)
assert(type(groupID) == "number","Argument groupID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetVisibleProjectiles ( )
return  tableMock
 end

function Spring.IsGUIHidden ( )
return  booleanMock
 end

function Spring.HaveShadows ( )
return  booleanMock
 end

function Spring.HaveAdvShading ( )
return  booleanMock
 end

function Spring.GetWaterMode ( )
return  numberMock
 end

function Spring.GetMapDrawMode ( )
return
 end

function Spring.GetDrawSelectionInfo ( )
return  booleanMock
 end

function Spring.GetUnitLuaDraw (unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetUnitNoDraw (unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetUnitNoMinimap (unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetUnitNoSelect (unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetMiniMapGeometry ( )
return  numberMock
 end

function Spring.GetMiniMapDualScreen ( )
return  stringMock
 end

function Spring.IsAboveMiniMap (  x, y)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetActiveCommand ( )
return  numberMock
 end

function Spring.GetDefaultCommand ( )
return  numberMock
 end

function Spring.GetActiveCmdDescs ( )
return  tableMock
 end

function Spring.GetActiveCmdDesc (  index)
assert(type(index) == "number","Argument index is of invalid type - expected number");
return  tableMock
 end

function Spring.GetCmdDescIndex (  cmdID)
assert(type(cmdID) == "number","Argument cmdID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetActivePage ( )
return  numberMock
 end

function Spring.GetBuildFacing ( )
return  numberMock
 end

function Spring.GetBuildSpacing ( )
return  numberMock
 end

function Spring.GetGatherMode ( )
return  numberMock
 end

function Spring.GetInvertQueueKey ( )
return  booleanMock
 end

function Spring.GetMouseState ( )
return  numberMock
 end

function Spring.GetMouseCursor ( )
return  stringMock
 end

function Spring.GetMouseStartPosition (  mouseButton)
assert(type(mouseButton) == "number","Argument mouseButton is of invalid type - expected number");
return  numberMock
 end

function Spring.GetKeyState (  key)
assert(type(key) == "number","Argument key is of invalid type - expected number");
return  booleanMock
 end

function Spring.GetModKeyState ( )
return  booleanMock
 end

function Spring.GetPressedKeys ( )
return  tableMock
 end

function Spring.GetKeyCode (  keysym)
assert(type(keysym) == "string","Argument keysym is of invalid type - expected string");
return  stringMock
 end

function Spring.GetKeySymbol (  key)
assert(type(key) == "number","Argument key is of invalid type - expected number");
return  numberMock
 end

function Spring.GetKeyBindings (  keyset)
assert(type(keyset) == "string","Argument keyset is of invalid type - expected string");
return  tableMock
 end

function Spring.GetActionHotKeys (  action)
assert(type(action) == "string","Argument action is of invalid type - expected string");
return  tableMock
 end

function Spring.GetLastMessagePositions ( )
return  tableMock
 end

function Spring.GetConsoleBuffer (  maxLines)
assert(type(maxLines) == "number","Argument maxLines is of invalid type - expected number");
return  tableMock
 end

function Spring.GetCurrentTooltip ( )
return  stringMock
 end

function Spring.GetLosViewColors ( )
return  tableMock
 end

function Spring.GetConfigParams ( )
return  tableMock
 end

function Spring.GetFPS ( )
return  numberMock
 end

function Spring.GetDrawFrame ( )
return  numberMock
 end

function Spring.GetGameSpeed ( )
return  numberMock
 end

function Spring.GetFrameTimeOffset ( )
return  numberMock
 end

function Spring.GetLastUpdateSeconds ( )
return  numberMock
 end

function Spring.GetHasLag ( )
return  booleanMock
 end

function Spring.GetTimer ( )
return  numberMock
 end

function Spring.DiffTimers (  timercur, timerago, inMilliseconds)
assert(type(timercur) == "number","Argument timercur is of invalid type - expected number");
assert(type(timerago) == "number","Argument timerago is of invalid type - expected number");
assert(type(inMilliseconds) == "boolean","Argument inMilliseconds is of invalid type - expected boolean");
return  numberMock
 end

function Spring.GetMapSquareTexture (  texSqrX, texSqrY, texMipLvl, luaTexName)
assert(type(texSqrX) == "number","Argument texSqrX is of invalid type - expected number");
assert(type(texSqrY) == "number","Argument texSqrY is of invalid type - expected number");
assert(type(texMipLvl) == "number","Argument texMipLvl is of invalid type - expected number");
assert(type(luaTexName) == "string","Argument luaTexName is of invalid type - expected string");
return  numberMock
 end

function Spring.GetLogSections ( )
return  tableMock
 end

function Spring.GetClipboard ( )
return  stringMock
 end

function gl.Flush()
	return nil
end

function gl.Finish()
	return nil
end

function gl.GetSun()
	return numberMock, numberMock, numberMock
end

function gl.GetAtmosphere(name)
	assert(type(name) == "string","Argument name is of invalid type - expected string");

	return numberMock, numberMock, numberMock
end

function gl.GetWaterRendering(name)
	assert(type(name) == "string","Argument name is of invalid type - expected string");

	return numberMock, numberMock, numberMock
end

function gl.GetMapRendering(name)
	assert(type(name) == "string","Argument name is of invalid type - expected string");

	return numberMock, numberMock, numberMock
end

function gl.ConfigScreen(screenWidth, screenDistance)
	assert(type(screenWidth) == "number","Argument screenWidth is of invalid type - expected number");
	assert(type(screenDistance) == "number","Argument screenDistance is of invalid type - expected number");

	return nil
end

function gl.DrawMiniMap(transform)
	assert(type(transform) == "boolean","Argument transform is of invalid type - expected boolean");

	return nil
end

function gl.SlaveMiniMap(mode)
	assert(type(mode) == "boolean","Argument mode is of invalid type - expected boolean");

	return nil
end

function gl.ConfigMiniMap(intPX, intPY, intSX, intSY)
	assert(type(intPX) == "number","Argument intPX is of invalid type - expected number");
	assert(type(intPY) == "number","Argument intPY is of invalid type - expected number");
	assert(type(intSX) == "number","Argument intSX is of invalid type - expected number");
	assert(type(intSY) == "number","Argument intSY is of invalid type - expected number");

	return nil
end

function gl.GetViewSizes()
	return numberMock, numberMock
end

--====================================================================================================
-- Deprecated functions
--====================================================================================================

---@param unitID number
---@param fuel number
---@deprecated 
function Spring.SetUnitFuel (unitID, fuel)
	assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
	assert(type(fuel) == "number","Argument fuel is of invalid type - expected number");
	return  numberMock
end

---@deprecated
---@param unitID number
---@param teamID number
---@param isRoot boolean
---@return integer
---@deprecated
function Spring.SetUnitLineage (unitID, teamID, isRoot)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(isRoot) == "boolean","Argument isRoot is of invalid type - expected boolean");
return  numberMock
end

--gl.Viewport ( number x, number y, number w, number h )
--return: nil
--gl.PushMatrix ( )
--return: nil
--gl.PopMatrix ( )
--return: nil
--gl.Translate ( number x, number y, number z )
--return: nil
--gl.Scale ( number x, number y, number z )
--return: nil
--gl.Scale ( number angle, number x, number y, number z )
--return: nil
--gl.Billboard ( )
--return: nil
--gl.MatrixMode ( number mode )
--return: nil
--gl.LoadIdentity ( )
--return: nil
--gl.LoadMatrix ( 16 numbers or a matrix name )
--return: nil
--gl.MultMatrix ( ??? )
--return: ???
--gl.Ortho ( number left, number right, number bottom, number top, number near, number far )
--return: nil
--gl.Frustum ( number left, number right, number bottom, number top, number near, number far )
--return: nil
--gl.PushPopMatrix ( ??? )
--return: ???
--gl.ClipPlane ( number intPlane, bool enable | number A, number B, number C, number D )
--return: nil
--gl.Clear ( GL.DEPTH_BUFFER_BIT [, number cleardepth ] )
--return: nil
--gl.SwapBuffers ( )
--return: nil
--gl.ResetState ( )
--return: nil
--gl.ResetMatrices ( )
--return: nil
--gl.BeginEnd ( number GLType, function [, arg1, ... ] )
--return: nil
--gl.Color ( number r, number g, number b [, number a ] | table colors = { number r, number g, number b [, number a ] } )
--return: nil
--gl.Vertex ( table vertex = { number x, number y, [, number z [, number w ]] } )
--return: nil
--gl.Vertex ( number x, number y )
--return: nil
--gl.Vertex ( number x, number y, number z )
--return: nil
--gl.Vertex ( number x, number y, number z, number w )
--return: nil
--gl.Normal ( table normal = { number x, number y, number z } | number x, number y, number z )
--return: nil
--gl.EdgeFlag ( bool enable )
--return: nil
--gl.Rect ( number x1, number y1, number x2, number y2 )
--return: nil
--gl.TexRect ( number x1, number y1, number x2, number y2 [, bool flip_s, bool flip_t | number s1, number t1, number s2, number t2 ] )
--return: nil
--gl.Shape ( number GLtype, table elements )
--return: nil
--gl.SecondaryColor ( table color = { number r, number g, number b } | number r, number g, number b )
--return: nil
--gl.FogCoord ( number value )
--return: nil
--gl.CreateList ( function [, arg1 [, arg2 ... ]] )
--return: number listID
--gl.CallList ( number listID )
--return: nil
--gl.DeleteList ( number listID )
--return: nil
--gl.CreateVertexArray ( number numElements, number numIndices [, bool persistentBuffer = false ] )
--return: number bufferID
--gl.UpdateVertexArray ( number bufferID, number elementPos, number indexPos, table tbl | function func )
--return: bool success
--gl.RenderVertexArray ( number bufferID, number primType [, number firstIndex = 0, number count = numElements ] )
--return: bool success
--gl.DeleteVertexArray ( number bufferID )
--return: bool success
--gl.Text ( string "text", number x, number y, number size [, string "options" ] )
--return: nil
--gl.GetTextWidth ( string "text" )
--return: number width
--gl.GetTextHeight ( string "text" )
--return: nil | number height, number descender, number numlines
--gl.BeginText ( )
--return: nil
--gl.EndText ( )
--return: nil
--gl.Unit ( number unitID [, bool rawdraw, number intLOD ] )
--return: nil
--gl.UnitRaw ( number unitID [, bool rawdraw, number intLOD ] )
--return: nil
--gl.UnitShape ( number unitDefID, number teamID, bool rawState, bool toScreen, bool opaque )
--return: nil
--gl.UnitMultMatrix ( number unitID )
--return: nil
--gl.UnitPieceMultMatrix ( number unitID, number intPiece )
--return: nil
--gl.UnitPiece ( number unitID, number intPiece )
--return: nil
--gl.UnitPieceMatrix ( number unitID, number intPiece )
--return: nil
--gl.Feature ( number featureID )
--return: nil
--gl.FeatureRaw ( number featureID [, bool rawdraw, number intLOD ] )
--return: nil
--gl.FeatureShape ( number featureDefID, number teamID, bool custom, bool drawScreen, bool opaque )
--return: nil
--gl.FeatureMultMatrix ( number featureID )
--return: nil
--gl.FeaturePieceMultMatrix ( number featureID, number intPiece )
--return: nil
--gl.FeaturePiece ( number featureID, number intPiece )
--return: nil
--gl.FeaturePieceMatrix ( number featureID, number intPiece )
--return: nil
--gl.DrawListAtUnit ( number unitID, number listID [, bool midPos, number scaleX, number scaleY, number scaleZ, number degrees, number rotX, number rotY, number rotZ ] )
--return: nil
--gl.DrawFuncAtUnit ( number unitID, bool midPos, function [, arg1, ... ] )
--return: nil
--gl.Blending ( bool enable | number srcmode, number dstmode )
--return: nil
--gl.Blending ( string mode )
--return: nil
--gl.BlendEquation ( number mode )
--return: nil
--gl.BlendFunc ( number srcmode, number dstmode )
--return: nil
--gl.BlendEquationSeparate ( number modeRGB, number modeAlpha )
--return: nil
--gl.BlendFuncSeparate ( number srcRGB, number [Lua_ConstGL#BlendingFactorDest, number srcAlpha, number dstAlpha )
--return: nil
--gl.AlphaTest ( bool enable | number func, number threshold )
--return: nil
--gl.DepthTest ( bool enable | number func )
--return: nil
--gl.Culling ( bool enable | number face )
--return: nil
--gl.DepthClamp ( bool enable )
--return: nil
--gl.DepthMask ( bool enable )
--return: nil
--gl.ColorMask ( bool masked )
--return: nil
--gl.ColorMask ( bool r, bool g, bool b, bool a )
--return: nil
--gl.LogicOp ( bool enable | number func )
--return: nil
--gl.Fog ( bool enable )
--return: nil
--gl.Smoothing ( bool enable | number point, bool enable | number line, bool enable | number polygon )
--return: nil
--gl.EdgeFlag ( bool enable )
--return: nil
--gl.Scissor ( bool enable )
--return: nil
--gl.Scissor ( number intX, number intY, number intW, number intH )
--return: nil
--gl.LineStipple ( string any )
--return: nil
--gl.LineStipple ( bool enable )
--return: nil
--gl.LineStipple ( number intFactor, number pattern )
--return: nil
--gl.PolygonMode ( number face, number mode )
--return: nil
--gl.PolygonOffset ( bool enable | number factor, number units )
--return: nil
--gl.PushAttrib ( [ number attrib ] )
--return: nil
--gl.PopAttrib ( )
--return: nil
--gl.StencilTest ( bool enable )
--return: nil
--gl.StencilMask ( number mask )
--return: nil
--gl.StencilFunc ( number func, number ref, number mask )
--return: nil
--gl.StencilOp ( number fail, number zfail, number zpass )
--return: nil
--gl.StencilMaskSeparate ( number face, number mask )
--return: nil
--gl.StencilFuncSeparate ( number face, number func, number ref, number mask )
--return: nil
--gl.StencilOpSeparate ( number face, number fail, number zfail, number zpass )
--return: nil
--gl.LineWidth ( number width )
--return: nil
--gl.PointSize ( number size )
--return: nil
--gl.PointSprite ( bool enable [, bool coord_replace, bool coord_origin_upper ] )
--return: nil
--gl.PointParameter ( number v1, number v2, number v3 [, number sizeMin, number sizeMax, number sizeFade ] )
--return: nil
--gl.Texture ( [ number texNum, ] bool enable | string name )
--return: nil | bool loaded
--gl.CreateTexture ( number intXSize, number intYSize [, table texProps ] )
--return: string texture
--gl.DeleteTexture ( string texture )
--return: bool deleted
--gl.DeleteTextureFBO ( string texture )
--return: bool deleted
--gl.TextureInfo ( string texture )
--return: nil | table texInfo
--gl.MultiTexCoord ( number x [, number y [, number z [, number w ]]] | table texCoords = { number x [, number y [, number z [, number w ]]] } )
--return: nil
--gl.TexEnv ( number target, number pname, number var1, number var2, number var3 )
--return: nil
--gl.MultiTexEnv ( number texNum, number target, number pname, number var1, number var2, number var3 )
--return: nil
--gl.TexGen ( number target, bool pname, number var1, number var2, number var3 )
--return: nil
--gl.MultiTexGen ( number intTexNum, number target, number pname, number var1, number var2, number var3 )
--return: nil
--gl.CopyToTexture ( string texture, number intXOff, number intYOff, number intX, number intY, number intW, number intH [, number target, number level ] )
--return: nil
--gl.RenderToTexture ( string fbotexture, function lua_func )
--return: nil
--gl.GenerateMipmap ( string texture )
--return: bool created
--gl.UnitTextures ( number unitID, bool enable )
--return: bool enabled
--gl.UnitShapeTextures ( number unitDefID, bool enable )
--return: bool enabled
--gl.FeatureTextures ( number featureID, bool enable )
--return: bool enabled
--gl.FeatureShapeTextures ( number featureDefID, bool enable )
--return: bool enabled
--gl.SaveImage ( number x, number y, number w, number h, string filename [, table imgProps = { alpha=bool, yflip=bool, grayscale16bit=bool, readbuffer=number } ] )
--return: nil | bool success
--gl.ReadPixels ( number x, number y, number w, number h [, number format = GL.RGBA ] )
--return: nil | number r [, g [, b [, a {rbracket
--gl.Lighting ( bool enable )
--return: nil
--gl.ShadeModel ( number mode )
--return: nil
--gl.Light ( number intLight, bool enable )
--return: nil
--gl.Material ( table material )
--return: nil
--gl.HasExtension ( string extname )
--return: bool hasExtension
--gl.GetNumber ( number ext, number intCount )
--return: number number1 [, number number2, number number3, ... #count ]
--gl.GetString ( number ext )
--return: string extString
--gl.DrawGroundCircle ( number x, number y, number z, number radius, number divs [, number slope ] )
--return: nil
--gl.DrawGroundQuad ( number x1, number z1, number x2, number z2 [, bool useNorm [, number tu1, number tv1, number tu2, number tv2 ] | [ bool useTextureCoord ] ] )
--return: nil
--gl.CreateQuery ( )
--return: nil | userdata query
--gl.DeleteQuery ( userdata query )
--return: nil
--gl.RunQuery ( userdata query, function func, arg1, arg2, ... )
--return: nil
--gl.GetQuery ( userdata query )
--return: nil | number renderedFragments
--gl.ActiveTexture ( number intTexNum, function func [, arg1, ... ] )
--return: nil
--gl.GetGlobalTexNames ( )
--return: table texNames = { [1] = string texture, etc ... }
--gl.GetGlobalTexCoords ( string 3doTextureName )
--return: number xstart, number ystart, number xend, number yend
--gl.UnsafeState ( number state [, bool disable_state ], bool func, arg1, arg2, ... )
--return: nil
--gl.GetShadowMapParams ( )
--return: number xmid, number ymid, number p17, number p18
--gl.GetMatrixData ( string "billboard" )
--return: nil | number number1, etc...
