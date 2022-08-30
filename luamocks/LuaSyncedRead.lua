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

function Spring.GetTeamRulesParam   (  index, teamID)
assert(type(index) == "number","Argument index is of invalid type - expected number");
assert(type(teamID) == "number","Argument teamID, is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamRulesParams   (  teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetUnitRulesParam   (  unitID, paramID )
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
assert(type(paramID) == "number" or type(paramID) == "string","Argument index is of invalid type - expected number or string");
return  numberMock
 end

function Spring.GetUnitRulesParams   (  unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetModOptions   ( )
return  stringMock
 end

function Spring.GetMapOptions   ( )
return  stringMock
 end

function Spring.GetModOptions.exampleOption    ()
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

function Spring.GetAllyTeamInfo   (allyteamID)
assert(type(allyteamID) == "number","Argument allyteamID is of invalid type - expected number");
return  tableMock
 end

function Spring.GetTeamInfo   (teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamResources   (teamID, resourceType)
    assert(type(teamID) == "number","Argument teamID, is of invalid type - expected number");
    assert(type(resourceType) == "string","Argument 'resourceType' is of invalid type - expected string");
    return numberMock
end

function Spring.GetTeamUnitStats   (teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamResourceStats    (metal, teamID)
assert(type(metal) == "string","Argument metal is of invalid type - expected string");
assert(type(teamID) == "number","Argument teamID, is of invalid type - expected number");
return
 end

function Spring.GetTeamStatsHistory   (teamID, endIndex, startIndex)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
assert(type(endIndex) == "number","Argument endIndex is of invalid type - expected number");
assert(type(startIndex) == "number","Argument startIndex is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamLuaAI   (teamID)
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

function Spring.GetTeamUnitDefCount   ( teamID, unitDefID)
assert(type(teamID) == "number","Argument teamID, is of invalid type - expected number");
assert(type(unitDefID) == "number","Argument unitDefID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetTeamUnitCount   ( teamID)
assert(type(teamID) == "number","Argument teamID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetUnitsInRectangle   ( xmin, teamID, zmin, zmax, xmax)
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

function Spring.GetUnitsInCylinder   (  radius, z, teamID, x)
assert(type(radius) == "number","Argument radius is of invalid type - expected number");
assert(type(z) == "number","Argument z, is of invalid type - expected number");
assert(type(teamID) == "number","Argument teamID] is of invalid type - expected number");
assert(type(x) == "number","Argument x, is of invalid type - expected number");
return  numberMock
 end

function Spring.GetUnitsInPlanes   ( )
return  numberMock
 end

function Spring.GetUnitNearestAlly   ( range, unitID)
assert(type(range) == "number","Argument range is of invalid type - expected number");
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetUnitNearestEnemy   ( range, unitID)
assert(type(range) == "number","Argument range is of invalid type - expected number");
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.ValidUnitID   ( unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  numberMock
 end

function Spring.GetUnitIsDead   (  unitID)
assert(type(unitID) == "number","Argument unitID is of invalid type - expected number");
return  booleanMock
 end

