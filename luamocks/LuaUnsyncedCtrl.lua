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

function Spring.SetLastMessagePosition   (  x, y, z)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
return  numberMock
 end

function Spring.Echo   ( )
return
 end

function Spring.Log   ( )
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

function Spring.MarkerAddPoint    (  x, y, z, text, localOnly)
assert(type(x) == "number","Argument x is of invalid type - expected number");
assert(type(y) == "number","Argument y is of invalid type - expected number");
assert(type(z) == "number","Argument z is of invalid type - expected number");
assert(type(text) == "string","Argument text is of invalid type - expected string");
assert(type(localOnly) == "bool","Argument text is of invalid type - expected string");
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

