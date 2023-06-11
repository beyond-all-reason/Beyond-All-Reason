--==================================================================================================
--    Copyright (C) <2016>  <PicassoCT>
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

