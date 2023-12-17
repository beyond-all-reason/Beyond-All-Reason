---UnsyncedCtrl

---
---Fields
---@param r number
---@param g number
---@param b number
---Fields
---@param r number
---@param g number
---@param b number
---@param a number

---
---Parameters
---@param pingTag number
---@return nil
function Spring.Ping(pingTag) end

---Parameters
---@param arg1
---@param arg2 (optional)
---@param argn (optional)
---@return nil
function Spring.Echo(arg1[, arg2[, argn]]) end

---Parameters
---@param section string
---@param logLevel ?number|string
---@param logMessage1 string
---@param logMessage2 string (optional)
---@param logMessagen string (optional)
---@return nil
function Spring.Log(section, logLevel, logMessage1[, logMessage2[, logMessagen]]) end

---Parameters
---@param command1 ?string|table
---@param command2 string
---@return nil
function Spring.SendCommands(command1, command2) end

---Parameters
---@param standardShaderID number
---@param deferredShaderID number
---@return nil
function Spring.SetMapShader(standardShaderID, deferredShaderID) end

---Parameters
---@param texSqrX number
---@param texSqrY number
---@param luaTexName string
---@return bool success
function Spring.SetMapSquareTexture(texSqrX, texSqrY, luaTexName) end

---Parameters
---@param texType string
---@param texName string
---@return bool success
function Spring.SetMapShadingTexture(texType, texName) end

---Spring.SetMapShadingTexture("$ssmf_specular", "name_of_my_shiny_texture")
---Parameters
---@param texName string
---@return nil
function Spring.SetSkyBoxTexture(texName) end


---
---Parameters
---@param message string
---@return nil
function Spring.SendMessage(message) end

---Parameters
---@param message string
---@return nil
function Spring.SendMessageToSpectators(message) end

---Parameters
---@param playerID number
---@param message string
---@return nil
function Spring.SendMessageToPlayer(playerID, message) end

---Parameters
---@param teamID number
---@param message string
---@return nil
function Spring.SendMessageToTeam(teamID, message) end

---Parameters
---@param allyID number
---@param message string
---@return nil
function Spring.SendMessageToAllyTeam(allyID, message) end


---
---Parameters
---@param soundfile string
---@return ?nil|bool success
function Spring.LoadSoundDef(soundfile) end

---Parameters
---@param soundfile string
---@param volume number (default): `1.0`
---@param posx number (optional)
---@param posy number (optional)
---@param posz number (optional)
---@param speedx number (optional)
---@param speedy number (optional)
---@param speedz number (optional)
---@param channel ?number|string (optional)
---@return ?nil|bool playSound
function Spring.PlaySoundFile(soundfile[, volume=1.0[, posx[, posy[, posz[, speedx[, speedy[, speedz[, channel]]]]]]]]) end

---Parameters
---@param oggfile string
---@param volume number (default): `1.0`
---@param enqueue boolean (optional)
---@return ?nil|bool success
function Spring.PlaySoundStream(oggfile[, volume=1.0[, enqueue]]) end

---@return nil
function Spring.StopSoundStream() end

---@return nil
function Spring.PauseSoundStream() end

---Parameters
---@param volume number
---@return nil
function Spring.SetSoundStreamVolume(volume) end

---Parameters
---@param cmdID number
---@param posX number
---@param posY number
---@param posZ number
---@return nil
function Spring.AddWorldIcon(cmdID, posX, posY, posZ) end

---Parameters
---@param text string
---@param posX number
---@param posY number
---@param posZ number
---@return nil
function Spring.AddWorldText(text, posX, posY, posZ) end

---Parameters
---@param unitDefID number
---@param posX number
---@param posY number
---@param posZ number
---@param teamID number
---@param facing number
---@return nil
function Spring.AddWorldUnit(unitDefID, posX, posY, posZ, teamID, facing) end

---Parameters
---@param unitID number
---@return nil
function Spring.DrawUnitCommands(unitID) end

---Parameters
---@param units table
---@param tableOrArray boolean
---@return nil
function Spring.DrawUnitCommands(units, tableOrArray) end


---
---Fields
---@param name string
---@param mode number
---@param fov number
---@param px number
---@param py number
---@param pz number
---@param dx number
---@param dy number
---@param dz number
---@param rx number
---@param ry number
---@param rz number
---@param angle number
---@param flipped number
---@param dist number
---@param height number
---@param oldHeight number
---Parameters
---@param x number
---@param y number
---@param z number
---@param transTime number (optional)
---@return nil
function Spring.SetCameraTarget(x, y, z[, transTime]) end

---Parameters
---@param px number
---@param py number
---@param pz number
---@param tx number
---@param ty number
---@param tz number
---@return nil
function Spring.SetCameraTarget(px, py, pz, tx, ty, tz) end

---Parameters
---@param camState camState
---@param transitionTime number (default): `0`
---@param transitionTimeFactor number (optional)
---@param transitionTimeExponent number (optional)
---@return bool set
function Spring.SetCameraState(camState[, transitionTime=0[, transitionTimeFactor[, transitionTimeExponent]]]) end


---
---Parameters
---@param unitID number
---@param append boolean (default): `false`
---@return nil
function Spring.SelectUnit(unitID[, append=false]) end

---Parameters
---@param unitID number
---@return nil
function Spring.DeselectUnit(unitID) end

---Parameters
---@param unitIDs {[number],...}
---@param append boolean (default): `false`
---@return nil
function Spring.SelectUnitArray(unitIDs[, append=false]) end

---Parameters
---@param unitMap {[number]=any,...}
---@param append boolean (default): `false`
---@return nil
function Spring.SelectUnitMap(unitMap[, append=false]) end


---
---Fields
---@param position: px number
---@param position: py number
---@param position: pz number
---@param direction: dx number
---@param direction: dy number
---@param direction: dz number
---@param ambientColor: red number
---@param ambientColor: green number
---@param ambientColor: blue number
---@param diffuseColor: red number
---@param diffuseColor: green number
---@param diffuseColor: blue number
---@param specularColor: red number
---@param specularColor: green number
---@param specularColor: blue number
---@param intensityWeight: ambientWeight number
---@param intensityWeight: diffuseWeight number
---@param intensityWeight: specularWeight number
---@param ambientDecayRate:  per-frame decay of ambientColor (spread over TTL frames)ambientRedDecay number
---@param ambientDecayRate:  per-frame decay of ambientColor (spread over TTL frames)ambientGreenDecay number
---@param ambientDecayRate:  per-frame decay of ambientColor (spread over TTL frames)ambientBlueDecay number
---@param diffuseDecayRate:  per-frame decay of diffuseColor (spread over TTL frames)diffuseRedDecay number
---@param diffuseDecayRate:  per-frame decay of diffuseColor (spread over TTL frames)diffuseGreenDecay number
---@param diffuseDecayRate:  per-frame decay of diffuseColor (spread over TTL frames)diffuseBlueDecay number
---@param specularDecayRate:  per-frame decay of specularColor (spread over TTL frames)specularRedDecay number
---@param specularDecayRate:  per-frame decay of specularColor (spread over TTL frames)specularGreenDecay number
---@param specularDecayRate:  per-frame decay of specularColor (spread over TTL frames)specularBlueDecay number
---@param decayFunctionType:  *DecayType = 0.0 -> interpret *DecayRate values as linear, else as exponentialambientDecayType number
---@param decayFunctionType:  *DecayType = 0.0 -> interpret *DecayRate values as linear, else as exponentialdiffuseDecayType number
---@param decayFunctionType:  *DecayType = 0.0 -> interpret *DecayRate values as linear, else as exponentialspecularDecayType number
---@param radius number
---@param fov number
---@param ttl number
---@param priority number
---@param ignoreLOS boolean
---Parameters
---@param lightParams lightParams
---@return number lightHandle
function Spring.AddMapLight(lightParams) end

---Parameters
---@param lightParams lightParams
---@return number lightHandle
function Spring.AddModelLight(lightParams) end

---Parameters
---@param lightHandle number
---@param lightParams lightParams
---@return bool success
function Spring.UpdateMapLight(lightHandle, lightParams) end

---Parameters
---@param lightHandle number
---@param lightParams lightParams
---@return bool success
function Spring.UpdateModelLight(lightHandle, lightParams) end

---Parameters
---@param lightHandle number
---@param unitOrProjectileID number
---@param enableTracking boolean
---@param unitOrProjectile boolean
---@return bool success
function Spring.SetMapLightTrackingState(lightHandle, unitOrProjectileID, enableTracking, unitOrProjectile) end

---Parameters
---@param lightHandle number
---@param unitOrProjectileID number
---@param enableTracking boolean
---@param unitOrProjectile boolean
---@return bool success
function Spring.SetModelLightTrackingState(lightHandle, unitOrProjectileID, enableTracking, unitOrProjectile) end


---
---Parameters
---@param unitID number
---@param noDraw boolean
---@return nil
function Spring.SetUnitNoDraw(unitID, noDraw) end

---Parameters
---@param unitID number
---@param drawMask number
---@return nil
function Spring.SetUnitEngineDrawMask(unitID, drawMask) end

---Parameters
---@param unitID number
---@param alwaysUpdateMatrix boolean
---@return nil
function Spring.SetUnitAlwaysUpdateMatrix(unitID, alwaysUpdateMatrix) end

---Parameters
---@param unitID number
---@param unitNoMinimap boolean
---@return nil
function Spring.SetUnitNoMinimap(unitID, unitNoMinimap) end

---Parameters
---@param unitID number
---@param unitNoSelect boolean
---@return nil
function Spring.SetUnitNoSelect(unitID, unitNoSelect) end

---Parameters
---@param unitID number
---@param unitLeaveTracks boolean
---@return nil
function Spring.SetUnitLeaveTracks(unitID, unitLeaveTracks) end

---Parameters
---@param unitID number
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
function Spring.SetUnitSelectionVolumeData(unitID, featureID, scaleX, scaleY, scaleZ, offsetX, offsetY, offsetZ, vType, tType, Axis) end


---
---Parameters
---@param featureID number
---@param noDraw boolean
---@return nil
function Spring.SetFeatureNoDraw(featureID, noDraw) end

---Parameters
---@param featureID number
---@param engineDrawMask number
---@return nil
function Spring.SetFeatureEngineDrawMask(featureID, engineDrawMask) end

---Parameters
---@param featureID number
---@param alwaysUpdateMat number
---@return nil
function Spring.SetFeatureAlwaysUpdateMatrix(featureID, alwaysUpdateMat) end

---Parameters
---@param featureID number
---@param allow boolean
---@return nil
function Spring.SetFeatureFade(featureID, allow) end

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
function Spring.SetFeatureSelectionVolumeData(featureID, scaleX, scaleY, scaleZ, offsetX, offsetY, offsetZ, vType, tType, Axis) end


---
---Parameters
---@param iconName string
---@param texFile string
---@param size number (optional)
---@param dist number (optional)
---@param radAdjust number (optional)
---@return ?nil|bool added
function Spring.AddUnitIcon(iconName, texFile[, size[, dist[, radAdjust]]]) end

---Parameters
---@param iconName string
---@return ?nil|bool freed
function Spring.FreeUnitIcon(iconName) end

---Parameters
---@param unitID number
---@param drawIcon boolean
---@return nil
function Spring.UnitIconSetDraw(unitID, drawIcon) end

---Parameters
---@param unitDefID number
---@param iconName string
---@return nil
function Spring.SetUnitDefIcon(unitDefID, iconName) end

---Parameters
---@param unitDefID number
---@param image string
---@return nil
function Spring.SetUnitDefImage(unitDefID, image) end


---
---Parameters
---@param modfile string
---@return bool extracted
function Spring.ExtractModArchiveFile(modfile) end

---Parameters
---@param path string
---@return ?nil|bool dirCreated
function Spring.CreateDir(path) end


---
---Parameters
---@param action string
---@param actionExtra string (optional)
---@return ?nil|bool commandSet
function Spring.SetActiveCommand(action[, actionExtra]) end

---Parameters
---@param cmdIndex number
---@param button number (default): `1`
---@param leftClick boolean (optional)
---@param rightClick ?bool
---@param alt ?bool
---@param ctrl ?bool
---@param meta ?bool
---@param shift ?bool
---@return ?nil|bool commandSet
function Spring.SetActiveCommand(cmdIndex[, button=1][, leftClick], rightClick, alt, ctrl, meta, shift) end

---Parameters
---@param config string
---@return nil
function Spring.LoadCmdColorsConfig(config) end

---Parameters
---@param config string
---@return nil
function Spring.LoadCtrlPanelConfig(config) end

---@return nil
function Spring.ForceLayoutUpdate() end

---Parameters
---@param enable boolean
---@return nil
function Spring.SetDrawSelectionInfo(enable) end

---Parameters
---@param state boolean
---@return nil
function Spring.SetBoxSelectionByEngine(state) end

---Parameters
---@param teamID number
---@param r number
---@param g number
---@param b number
---@return nil
function Spring.SetTeamColor(teamID, r, g, b) end

---Parameters
---@param cmdName string
---@param iconFileName string
---@param overwrite boolean (default): `true`
---@param hotSpotTopLeft boolean (default): `false`
---@return ?nil|bool assigned
function Spring.AssignMouseCursor(cmdName, iconFileName[, overwrite=true[, hotSpotTopLeft=false]]) end

---Parameters
---@param oldFileName string
---@param newFileName string
---@param hotSpotTopLeft boolean (default): `false`
---@return ?nil|bool assigned
function Spring.ReplaceMouseCursor(oldFileName, newFileName[, hotSpotTopLeft=false]) end

---Parameters
---@param cmdID number
---@param cmdReference string|number (optional)
---@return ?nil|bool assigned
function Spring.SetCustomCommandDrawData(cmdID[, cmdReference]) end


---
---Parameters
---@param x number
---@param y number
---@return nil
function Spring.WarpMouse(x, y) end

---Parameters
---@param cursorName string
---@param cursorScale number (default): `1.0`
---@return nil
function Spring.SetMouseCursor(cursorName[, cursorScale=1.0]) end


---
---Parameters
---@param always table
---@param LOS table
---@param radar table
---@param jam table
---@param radar2 table
---@return nil
function Spring.SetLosViewColors(always, LOS, radar, jam, radar2) end

---Parameters
---@param rotVal number (default): `0`
---@param rotVel number (default): `0`
---@param rotAcc number (default): `0`
---@param rotValRng number (default): `0`
---@param rotVelRng number (default): `0`
---@param rotAccRng number (default): `0`
---@return nil
function Spring.SetNanoProjectileParams([rotVal=0[, rotVel=0[, rotAcc=0[, rotValRng=0[, rotVelRng=0[, rotAccRng=0]]]]]]) end


---
---Parameters
---@param name string
---@param value number
---@param useOverlay boolean (default): `false`
---@return nil
function Spring.SetConfigInt(name, value[, useOverlay=false]) end

---Parameters
---@param name string
---@param value number
---@param useOverla boolean (default): `false`
---@return nil
function Spring.SetConfigFloat(name, value[, useOverla=false]) end

---Parameters
---@param name string
---@param value number
---@param useOverlay boolean (default): `false`
---@return nil
function Spring.SetConfigString(name, value[, useOverlay=false]) end

---@return nil
function Spring.Quit() end


---
---Parameters
---@param unitID number
---@param groupID number
---@return nil
function Spring.SetUnitGroup(unitID, groupID) end


---
---Fields
---@param right bool
---@param alt bool
---@param ctrl bool
---@param shift bool
---@param meta bool
---Parameters
---@param cmdID number
---@param params table
---@param options cmdOpts
---@return nil|true
function Spring.GiveOrder(cmdID, params, options) end

---Parameters
---@param unitID number
---@param cmdID number
---@param params table
---@param options cmdOpts
---@return nil|true
function Spring.GiveOrderToUnit(unitID, cmdID, params, options) end

---Parameters
---@param unitMap table
---@param cmdID number
---@param params table
---@param options cmdOpts
---@return nil|true
function Spring.GiveOrderToUnitMap(unitMap, cmdID, params, options) end

---Parameters
---@param unitArray {number,...}
---@param cmdID number
---@param params table
---@param options cmdOpts
---@return nil|true
function Spring.GiveOrderToUnitArray(unitArray, cmdID, params, options) end

---Fields
---@param cmdID number
---@param params table
---@param options cmdOpts
---Parameters
---@param unitID number
---@param cmdArray {cmdSpec,...}
---@return bool ordersGiven
function Spring.GiveOrderArrayToUnit(unitID, cmdArray) end

---Parameters
---@param unitMap table
---@param cmdArray {cmdSpec,...}
---@return bool ordersGiven
function Spring.GiveOrderArrayToUnitMap(unitMap, cmdArray) end

---Parameters
---@param unitArray {number,...}
---@param cmdArray {cmdSpec,...}
---@param pairwise bool (default): `false`
---@return nil|bool
function Spring.GiveOrderArrayToUnitArray(unitArray, cmdArray[, pairwise=false]) end

---Parameters
---@param spacing number
---@return nil
function Spring.SetBuildSpacing(spacing) end

---Parameters
---@param facing number
---@return nil
function Spring.SetBuildFacing(facing) end


---
---Parameters
---@param message string
---@param mode string
---@return nil
function Spring.SendLuaUIMsg(message, mode) end

---Parameters
---@param message string
---@return nil
function Spring.SendLuaGaiaMsg(message) end

---Parameters
---@param message string
---@return nil
function Spring.SendLuaRulesMsg(message) end

---Parameters
---@param msg string
---Parameters
---@param x number
---@param y number
---@param z number
---@return nil
function Spring.SetLastMessagePosition(x, y, z) end


---
---Parameters
---@param resource string
---@param shareLevel number
---@return nil
function Spring.SetShareLevel(resource, shareLevel) end

---Parameters
---@param teamID number
---@param units string
---@return nil
function Spring.ShareResources(teamID, units) end

---Parameters
---@param teamID number
---@param resource string
---@param amount number
---@return nil
function Spring.ShareResources(teamID, resource, amount) end


---
---Parameters
---@param x number
---@param y number
---@param z number
---@param text string (default): `""`
---@param localOnly boolean (optional)
---@return nil
function Spring.MarkerAddPoint(x, y, z[, text=""[, localOnly]]) end

---Parameters
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@param localOnly boolean (default): `false`
---@param playerId number (optional)
---@return nil
function Spring.MarkerAddLine(x1, y1, z1, x2, y2, z2[, localOnly=false[, playerId]]) end

---Parameters
---@param x number
---@param y number
---@param z number
---@param noop
---@param localOnly boolean (default): `false`
---@param playerId number (optional)
---@param alwaysErase boolean (default): `false`
---@return nil
function Spring.MarkerErasePosition(x, y, z, noop[, localOnly=false[, playerId[, alwaysErase=false]]]) end


---
---Parameters
---@param params: fogStart number
---@param params: fogEnd number
---@param params: sunColor rgb
---@param params: skyColor rgb
---@param params: cloudColor rgb
---@return nil
function Spring.SetAtmosphere(params) end

---Spring.SetAtmosphere({ fogStart = 0, fogEnd = 0.5, fogColor = { 0.7, 0.2, 0.2, 1 }})
---Parameters
---@param dirX number
---@param dirY number
---@param dirZ number
---@param intensity number (default): `true`
---@return nil
function Spring.SetSunDirection(dirX, dirY, dirZ[, intensity=true]) end

---Parameters
---@param params: groundAmbientColor rgb
---@param params: groundDiffuseColor rgb
---@return nil
function Spring.SetSunLighting(params) end

---Spring.SetSunLighting({groundAmbientColor = {1, 0.1, 1}, groundDiffuseColor = {1, 0.1, 1} })
---Fields
---@param splatTexMults rgba
---@param splatTexScales rgba
---@param voidWater boolean
---@param voidGround boolean
---@param splatDetailNormalDiffuseAlpha boolean
---Parameters
---@param params mapRenderingParams
---@return nil
function Spring.SetMapRenderingParams(params) end

---Parameters
---@param normal boolean (default): `true`
---@param shadow boolean (default): `false`
---@return bool updated
function Spring.ForceTesselationUpdate([normal=true[, shadow=false]]) end


---
---Parameters
---@param aiTeam number
---@param message string
---@return ?nil|bool ai_processed
function Spring.SendSkirmishAIMessage(aiTeam, message) end


---
---Parameters
---@param sectionName string
---@param logLevel ?string|number
---@return nil
function Spring.SetLogSectionFilterLevel(sectionName, logLevel) end

---Parameters
---@param itersPerBatch integer (optional)
---@param numStepsPerIter integer (optional)
---@param minStepsPerIter integer (optional)
---@param maxStepsPerIter integer (optional)
---@param minLoopRunTime number (optional)
---@param maxLoopRunTime number (optional)
---@param baseRunTimeMult number (optional)
---@param baseMemLoadMult number (optional)
---@return nil
function Spring.GarbageCollectCtrl([itersPerBatch[, numStepsPerIter[, minStepsPerIter[, maxStepsPerIter[, minLoopRunTime[, maxLoopRunTime[, baseRunTimeMult[, baseMemLoadMult]]]]]]]]) end

---Parameters
---@param drawSky boolean
---@return nil
function Spring.SetDrawSky(drawSky) end

---Parameters
---@param drawWater boolean
---@return nil
function Spring.SetDrawWater(drawWater) end

---Parameters
---@param drawGround boolean
---@return nil
function Spring.SetDrawGround(drawGround) end

---Parameters
---@param drawGroundDeferred boolean
---@param drawGroundForward boolean (optional)
---Parameters
---@param drawUnitsDeferred boolean
---@param drawFeaturesDeferred boolean
---@param drawUnitsForward boolean (optional)
---@param drawFeaturesForward boolean (optional)
---@return nil
function Spring.SetDrawModelsDeferred(drawUnitsDeferred, drawFeaturesDeferred[, drawUnitsForward[, drawFeaturesForward]]) end

---Parameters
---@param allowCaptureMode boolean
---@return nil
function Spring.SetVideoCapturingMode(allowCaptureMode) end

---Parameters
---@param timeOffset boolean
---@return nil
function Spring.SetVideoCapturingTimeOffset(timeOffset) end

---Fields
---@param absorb rgb
---@param baseColor rgb
---@param minColor rgb
---@param surfaceColor rgb
---@param diffuseColor rgb
---@param specularColor rgb
---@param planeColor rgb
---@param texture string
---@param foamTexture string
---@param normalTexture string
---@param damage number
---@param repeatX number
---@param repeatY number
---@param surfaceAlpha number
---@param ambientFactor number
---@param diffuseFactor number
---@param specularFactor number
---@param specularPower number
---@param fresnelMin number
---@param fresnelMax number
---@param fresnelPower number
---@param reflectionDistortion number
---@param blurBase number
---@param blurExponent number
---@param perlinStartFreq number
---@param perlinLacunarity number
---@param perlinAmplitude number
---@param numTiles number
---@param shoreWaves boolean
---@param forceRendering boolean
---@param hasWaterPlane boolean
---Parameters
---@param waterParams waterParams
---@return nil
function Spring.SetWaterParams(waterParams) end


---
---Parameters
---@param unitDefID number
---@return nil
function Spring.PreloadUnitDefModel(unitDefID) end

---Parameters
---@param featureDefID number
---@return nil
function Spring.PreloadFeatureDefModel(featureDefID) end

---Parameters
---@param name string
---@return nil
function Spring.PreloadSoundItem(name) end

---Parameters
---@param modelName string
---@return ?nil|bool success
function Spring.LoadModelTextures(modelName) end


---
---@return nil|number decalIndex
function Spring.CreateDecal() end

---Parameters
---@param decalIndex number
---@return nil
function Spring.DestroyDecal(decalIndex) end

---Parameters
---@param decalIndex number
---@param posX number
---@param posY number
---@param posZ number
---@return bool decalSet
function Spring.SetDecalPos(decalIndex, posX, posY, posZ) end

---Parameters
---@param decalIndex number
---@param sizeX number
---@param sizeY number
---@return bool decalSet
function Spring.SetDecalSize(decalIndex, sizeX, sizeY) end

---Parameters
---@param decalIndex number
---@param rot number
---@return nil|bool decalSet
function Spring.SetDecalRotation(decalIndex, rot) end

---Parameters
---@param decalIndex number
---@param textureName string
---@return nil|bool decalSet
function Spring.SetDecalTexture(decalIndex, textureName) end

---Parameters
---@param decalIndex number
---@param alpha number
---@return nil|bool decalSet
function Spring.SetDecalAlpha(decalIndex, alpha) end


---
---Parameters
---@param x number
---@param y number
---@param width number
---@param height number
---@return nil
function Spring.SDLSetTextInputRect(x, y, width, height) end

---@return nil
function Spring.SDLStartTextInput() end

---@return nil
function Spring.SDLStopTextInput() end


---
---Parameters
---@param displayIndex number
---@param winPosX number
---@param winPosY number
---@param winSizeX number
---@param winSizeY number
---@param fullScreen boolean
---@param borderless boolean
---@return nil
function Spring.SetWindowGeometry(displayIndex, winPosX, winPosY, winSizeX, winSizeY, fullScreen, borderless) end

---@return bool minimized
function Spring.SetWindowMinimized() end

---@return bool maximized
function Spring.SetWindowMaximized() end


---
---Parameters
---@param startScript string
---@return nil
function Spring.Reload(startScript) end

---Parameters
---@param commandline_args string
---@param startScript string
---@return nil
function Spring.Restart(commandline_args, startScript) end

---Parameters
---@param commandline_args string
---@param startScript string
---@return nil
function Spring.Start(commandline_args, startScript) end

---Parameters
---@param iconFileName string
---@return nil
function Spring.SetWMIcon(iconFileName) end

---Parameters
---@param title string
---@param titleShort string (default): `title`
---@return nil
function SetWMCaption(title[, titleShort=title]) end

---Parameters
---@param threadName string (default): `main`
---@return nil
function Spring.ClearWatchDogTimer([threadName=main]) end

---Parameters
---@param text string
---@return nil
function Spring.SetClipboard(text) end

---Parameters
---@param sleep number
---@return bool when true caller should continue calling `Spring.Yield` during the widgets/gadgets load, when false it shouldn't call it any longer.
function Spring.Yield(sleep) end

