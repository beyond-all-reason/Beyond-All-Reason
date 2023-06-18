---UnsyncedRead

---
---@return ?nil|bool isReplay
function Spring.IsReplay() end

---@return ?nil|number timeInSeconds
function Spring.GetReplayLength() end


---
---@return string name
function Spring.GetGameName() end

---@return string name name .. version from Modinfo.lua. E.g. "Spring: 1944 test-5640-ac2d15b".
function Spring.GetMenuName() end


---
---Parameters
---@param profilerName string
---@param frameData boolean (default): `false`
---@return number total in ms
function Spring.GetProfilerTimeRecord(profilerName[, frameData=false]) end

---@return number current in ms
function Spring.GetProfilerTimeRecord(profilerName[, frameData=false]) end

---@return number max_dt
function Spring.GetProfilerTimeRecord(profilerName[, frameData=false]) end

---@return number time_pct
function Spring.GetProfilerTimeRecord(profilerName[, frameData=false]) end

---@return number peak_pct
function Spring.GetProfilerTimeRecord(profilerName[, frameData=false]) end

---@return ?nil|{[number]=number,...} frameData where key is the frame index and value is duration
function Spring.GetProfilerTimeRecord(profilerName[, frameData=false]) end

---@return {string,...} profilerNames
function Spring.GetProfilerRecordNames() end

---@return number luaHandleAllocedMem in kilobytes
function Spring.GetLuaMemUsage() end

---@return number luaHandleNumAllocs divided by 1000
function Spring.GetLuaMemUsage() end

---@return number luaGlobalAllocedMem in kilobytes
function Spring.GetLuaMemUsage() end

---@return number luaGlobalNumAllocs divided by 1000
function Spring.GetLuaMemUsage() end

---@return number luaUnsyncedGlobalAllocedMem in kilobytes
function Spring.GetLuaMemUsage() end

---@return number luaUnsyncedGlobalNumAllocs divided by 1000
function Spring.GetLuaMemUsage() end

---@return number luaSyncedGlobalAllocedMem in kilobytes
function Spring.GetLuaMemUsage() end

---@return number luaSyncedGlobalNumAllocs divided by 1000
function Spring.GetLuaMemUsage() end

---@return number usedMem in MB
function Spring.GetVidMemUsage() end

---@return number availableMem in MB
function Spring.GetVidMemUsage() end


---
---@return Timer
function Spring.GetTimer() end

---@return Timer
function Spring.GetTimerMicros() end

---Parameters
---@param lastFrameTime boolean (default): `false`
---@return Timer
function Spring.GetFrameTimer([lastFrameTime=false]) end

---Parameters
---@param endTimer Timer
---@param startTimer Timer
---@param returnMs boolean (default): `false`
---@param fromMicroSecs boolean (default): `false`
---@return number timeAmount
function Spring.DiffTimers(endTimer, startTimer[, returnMs=false[, fromMicroSecs=false]]) end


---
---@return number numDisplays as returned by `SDL_GetNumVideoDisplays`
function Spring.GetNumDisplays() end

---@return number viewSizeX in px
function Spring.GetViewGeometry() end

---@return number viewSizeY in px
function Spring.GetViewGeometry() end

---@return number viewPosX offset from leftmost screen left border in px
function Spring.GetViewGeometry() end

---@return number viewPosY offset from bottommost screen bottom border in px
function Spring.GetViewGeometry() end

---@return number dualViewSizeX in px
function Spring.GetDualViewGeometry() end

---@return number dualViewSizeY in px
function Spring.GetDualViewGeometry() end

---@return number dualViewPosX offset from leftmost screen left border in px
function Spring.GetDualViewGeometry() end

---@return number dualViewPosY offset from bottommost screen bottom border in px
function Spring.GetDualViewGeometry() end

---@return number winSizeX in px
function Spring.GetWindowGeometry() end

---@return number winSizeY in px
function Spring.GetWindowGeometry() end

---@return number winPosX in px
function Spring.GetWindowGeometry() end

---@return number winPosY in px
function Spring.GetWindowGeometry() end

---@return number windowBorderTop in px
function Spring.GetWindowGeometry() end

---@return number windowBorderLeft in px
function Spring.GetWindowGeometry() end

---@return number windowBorderBottom in px
function Spring.GetWindowGeometry() end

---@return number windowBorderRight in px
function Spring.GetWindowGeometry() end

---Parameters
---@param displayIndex number (default): `-1`
---@param queryUsable boolean (default): `false`
---@return number screenSizeX in px
function Spring.GetScreenGeometry([displayIndex=-1[, queryUsable=false]]) end

---@return number screenSizeY in px
function Spring.GetScreenGeometry([displayIndex=-1[, queryUsable=false]]) end

---@return number screenPosX in px
function Spring.GetScreenGeometry([displayIndex=-1[, queryUsable=false]]) end

---@return number screenPosY in px
function Spring.GetScreenGeometry([displayIndex=-1[, queryUsable=false]]) end

---@return number windowBorderTop in px
function Spring.GetScreenGeometry([displayIndex=-1[, queryUsable=false]]) end

---@return number windowBorderLeft in px
function Spring.GetScreenGeometry([displayIndex=-1[, queryUsable=false]]) end

---@return number windowBorderBottom in px
function Spring.GetScreenGeometry([displayIndex=-1[, queryUsable=false]]) end

---@return number windowBorderRight in px
function Spring.GetScreenGeometry([displayIndex=-1[, queryUsable=false]]) end

---@return ?nil|number screenUsableSizeX in px
function Spring.GetScreenGeometry([displayIndex=-1[, queryUsable=false]]) end

---@return ?nil|number screenUsableSizeY in px
function Spring.GetScreenGeometry([displayIndex=-1[, queryUsable=false]]) end

---@return ?nil|number screenUsablePosX in px
function Spring.GetScreenGeometry([displayIndex=-1[, queryUsable=false]]) end

---@return ?nil|number screenUsablePosY in px
function Spring.GetScreenGeometry([displayIndex=-1[, queryUsable=false]]) end

---@return number minimapPosX in px
function Spring.GetMiniMapGeometry() end

---@return number minimapPosY in px
function Spring.GetMiniMapGeometry() end

---@return number minimapSizeX in px
function Spring.GetMiniMapGeometry() end

---@return number minimapSizeY in px
function Spring.GetMiniMapGeometry() end

---@return bool minimized
function Spring.GetMiniMapGeometry() end

---@return bool maximized
function Spring.GetMiniMapGeometry() end

---@return number amount in radians
function Spring.GetMiniMapRotation() end

---@return string|false position "left"|"right" when dual screen is enabled, false when not
function Spring.GetMiniMapDualScreen() end

---@return ?nil|number bottomLeftX
function Spring.GetSelectionBox() end

---@return ?nil|number topRightX
function Spring.GetSelectionBox() end

---@return ?nil|number topRightY
function Spring.GetSelectionBox() end

---@return ?nil|number bottomLeftY
function Spring.GetSelectionBox() end

---@return bool
function Spring.GetDrawSelectionInfo() end

---Parameters
---@param x number
---@param y number
---@return bool isAbove
function Spring.IsAboveMiniMap(x, y) end

---@return number low_16bit
function Spring.GetDrawFrame() end

---@return number high_16bit
function Spring.GetDrawFrame() end

---@return nil|number offset of the current draw frame from the last sim frame, expressed in fractions of a frame
function Spring.GetFrameTimeOffset() end

---@return nil|number lastUpdateSeconds
function Spring.GetLastUpdateSeconds() end

---@return bool allowRecord
function Spring.GetVideoCapturingMode() end


---
---Parameters
---@param unitID number
---@return nil|bool isAllied nil with unitID cannot be parsed
function Spring.IsUnitAllied(unitID) end

---Parameters
---@param unitID number
---@return nil|bool isSelected nil when unitID cannot be parsed
function Spring.IsUnitSelected(unitID) end

---Parameters
---@param unitID number
---@return nil|bool draw nil when unitID cannot be parsed
function Spring.GetUnitLuaDraw(unitID) end

---Parameters
---@param unitID number
---@return nil|bool nil when unitID cannot be parsed
function Spring.GetUnitNoDraw(unitID) end

---Parameters
---@param unitID number
---@return nil|bool nil when unitID cannot be parsed
function Spring.GetUnitEngineDrawMask(unitID) end

---Parameters
---@param unitID number
---@return nil|bool nil when unitID cannot be parsed
function Spring.GetUnitAlwaysUpdateMatrix(unitID) end

---Parameters
---@param unitID number
---@return nil|number nil when unitID cannot be parsed
function Spring.GetUnitDrawFlag(unitID) end

---Parameters
---@param unitID number
---@return nil|bool nil when unitID cannot be parsed
function Spring.GetUnitNoMinimap(unitID) end

---Parameters
---@param unitID number
---@return nil|bool nil when unitID cannot be parsed
function Spring.GetUnitNoSelect(unitID) end

---Parameters
---@param unitID number
---@param nil nil|bool
---Parameters
---@param unitID number
---@return number|nil scaleX nil when unitID cannot be parsed
function Spring.GetUnitSelectionVolumeData(unitID) end

---@return number scaleY
function Spring.GetUnitSelectionVolumeData(unitID) end

---@return number scaleZ
function Spring.GetUnitSelectionVolumeData(unitID) end

---@return number offsetX
function Spring.GetUnitSelectionVolumeData(unitID) end

---@return number offsetY
function Spring.GetUnitSelectionVolumeData(unitID) end

---@return number offsetZ
function Spring.GetUnitSelectionVolumeData(unitID) end

---@return number volumeType
function Spring.GetUnitSelectionVolumeData(unitID) end

---@return number useContHitTest
function Spring.GetUnitSelectionVolumeData(unitID) end

---@return number getPrimaryAxis
function Spring.GetUnitSelectionVolumeData(unitID) end

---@return bool ignoreHits
function Spring.GetUnitSelectionVolumeData(unitID) end


---
---Parameters
---@param featureID number
---@return nil|bool nil when featureID cannot be parsed
function Spring.GetFeatureLuaDraw(featureID) end

---Parameters
---@param featureID number
---@return nil|bool nil when featureID cannot be parsed
function Spring.GetFeatureNoDraw(featureID) end

---Parameters
---@param featureID number
---@return nil|bool nil when featureID cannot be parsed
function Spring.GetFeatureEngineDrawMask(featureID) end

---Parameters
---@param featureID number
---@return nil|bool nil when featureID cannot be parsed
function Spring.GetFeatureAlwaysUpdateMatrix(featureID) end

---Parameters
---@param featureID number
---@return nil|number nil when featureID cannot be parsed
function Spring.GetFeatureDrawFlag(featureID) end

---Parameters
---@param featureID number
---@return number|nil scaleX nil when unitID cannot be parsed
function Spring.GetFeatureSelectionVolumeData(featureID) end

---@return number scaleY
function Spring.GetFeatureSelectionVolumeData(featureID) end

---@return number scaleZ
function Spring.GetFeatureSelectionVolumeData(featureID) end

---@return number offsetX
function Spring.GetFeatureSelectionVolumeData(featureID) end

---@return number offsetY
function Spring.GetFeatureSelectionVolumeData(featureID) end

---@return number offsetZ
function Spring.GetFeatureSelectionVolumeData(featureID) end

---@return number volumeType
function Spring.GetFeatureSelectionVolumeData(featureID) end

---@return number useContHitTest
function Spring.GetFeatureSelectionVolumeData(featureID) end

---@return number getPrimaryAxis
function Spring.GetFeatureSelectionVolumeData(featureID) end

---@return bool ignoreHits
function Spring.GetFeatureSelectionVolumeData(featureID) end


---
---Parameters
---@param unitID number
---@return number|nil m11 nil when unitID cannot be parsed
function Spring.GetUnitTransformMatrix(unitID) end

---@return number m12
function Spring.GetUnitTransformMatrix(unitID) end

---@return number m13
function Spring.GetUnitTransformMatrix(unitID) end

---@return number m14
function Spring.GetUnitTransformMatrix(unitID) end

---@return number m21
function Spring.GetUnitTransformMatrix(unitID) end

---@return number m22
function Spring.GetUnitTransformMatrix(unitID) end

---@return number m23
function Spring.GetUnitTransformMatrix(unitID) end

---@return number m24
function Spring.GetUnitTransformMatrix(unitID) end

---@return number m31
function Spring.GetUnitTransformMatrix(unitID) end

---@return number m32
function Spring.GetUnitTransformMatrix(unitID) end

---@return number m33
function Spring.GetUnitTransformMatrix(unitID) end

---@return number m34
function Spring.GetUnitTransformMatrix(unitID) end

---@return number m41
function Spring.GetUnitTransformMatrix(unitID) end

---@return number m42
function Spring.GetUnitTransformMatrix(unitID) end

---@return number m43
function Spring.GetUnitTransformMatrix(unitID) end

---@return number m44
function Spring.GetUnitTransformMatrix(unitID) end

---Parameters
---@param featureID number
---@return number|nil m11 nil when featureID cannot be parsed
function Spring.GetFeatureTransformMatrix(featureID) end

---@return number m12
function Spring.GetFeatureTransformMatrix(featureID) end

---@return number m13
function Spring.GetFeatureTransformMatrix(featureID) end

---@return number m14
function Spring.GetFeatureTransformMatrix(featureID) end

---@return number m21
function Spring.GetFeatureTransformMatrix(featureID) end

---@return number m22
function Spring.GetFeatureTransformMatrix(featureID) end

---@return number m23
function Spring.GetFeatureTransformMatrix(featureID) end

---@return number m24
function Spring.GetFeatureTransformMatrix(featureID) end

---@return number m31
function Spring.GetFeatureTransformMatrix(featureID) end

---@return number m32
function Spring.GetFeatureTransformMatrix(featureID) end

---@return number m33
function Spring.GetFeatureTransformMatrix(featureID) end

---@return number m34
function Spring.GetFeatureTransformMatrix(featureID) end

---@return number m41
function Spring.GetFeatureTransformMatrix(featureID) end

---@return number m42
function Spring.GetFeatureTransformMatrix(featureID) end

---@return number m43
function Spring.GetFeatureTransformMatrix(featureID) end

---@return number m44
function Spring.GetFeatureTransformMatrix(featureID) end

---Parameters
---@param forced boolean (default): `false`
---@return bool
function Spring.MakeGLDBQuery([forced=false]) end

---Parameters
---@param blockingCall boolean (default): `true`
---@return nil|bool ready
function Spring.GetGLDBQuery([blockingCall=true]) end

---@return bool drivers not ok when true
function Spring.GetGLDBQuery([blockingCall=true]) end

---@return number maxCtxX
function Spring.GetGLDBQuery([blockingCall=true]) end

---@return number maxCtxY
function Spring.GetGLDBQuery([blockingCall=true]) end

---@return string url
function Spring.GetGLDBQuery([blockingCall=true]) end

---@return string driver
function Spring.GetGLDBQuery([blockingCall=true]) end

---Parameters
---@param collectGC boolean (default): `false`
---@return nil|number GC values are expressed in Kbytes: #bytes/2^10
function Spring.GetSyncedGCInfo([collectGC=false]) end


---
---Parameters
---@param unitID number
---@return nil|bool inView nil when unitID cannot be parsed
function Spring.IsUnitInView(unitID) end

---Parameters
---@param unitID number
---@param radius number (optional)
---@param checkIcon boolean
---@return nil|bool isVisible nil when unitID cannot be parsed
function Spring.IsUnitVisible(unitID[, radius], checkIcon) end

---Parameters
---@param unitID number
---@return nil|bool isUnitIcon nil when unitID cannot be parsed
function Spring.IsUnitIcon(unitID) end

---Parameters
---@param minX number
---@param minY number
---@param minZ number
---@param maxX number
---@param maxY number
---@param maxZ number
---@return bool inView
function Spring.IsAABBInView(minX, minY, minZ, maxX, maxY, maxZ) end

---Parameters
---@param posX number
---@param posY number
---@param posZ number
---@param radius number (default): `0`
---@return bool inView
function Spring.IsSphereInView(posX, posY, posZ[, radius=0]) end

---Parameters
---@param unitID number
---@param midPos boolean (default): `false`
---@return number|nil x nil when unitID cannot be parsed
function Spring.GetUnitViewPosition(unitID[, midPos=false]) end

---@return number y
function Spring.GetUnitViewPosition(unitID[, midPos=false]) end

---@return number z
function Spring.GetUnitViewPosition(unitID[, midPos=false]) end

---Parameters
---@param teamID number (default): `-1`
---@param radius number (default): `30`
---@param icons boolean (default): `true`
---@return nil|{[number],...} unitIDs
function Spring.GetVisibleUnits([teamID=-1[, radius=30[, icons=true]]]) end

---Parameters
---@param teamID number (default): `-1`
---@param radius number (default): `30`
---@param icons boolean (default): `true`
---@param geos boolean (default): `true`
---@return nil|{[number],...} featureIDs
function Spring.GetVisibleFeatures([teamID=-1[, radius=30[, icons=true[, geos=true]]]]) end

---Parameters
---@param allyTeamID number (default): `-1`
---@param addSyncedProjectiles boolean (default): `true`
---@param addWeaponProjectiles boolean (default): `true`
---@param addPieceProjectiles boolean (default): `true`
---@return nil|{[number],...} projectileIDs
function Spring.GetVisibleProjectiles([allyTeamID=-1[, addSyncedProjectiles=true[, addWeaponProjectiles=true[, addPieceProjectiles=true]]]]) end

---@return nil
function Spring.ClearUnitsPreviousDrawFlag() end

---@return nil
function Spring.ClearFeaturesPreviousDrawFlag() end

---Parameters
---@param left number
---@param top number
---@param right number
---@param bottom number
---@param allegiance number (default): `-1`
---@return nil|{[number],...} unitIDs
function Spring.GetUnitsInScreenRectangle(left, top, right, bottom[, allegiance=-1]) end

---Parameters
---@param left number
---@param top number
---@param right number
---@param bottom number
---@return nil|{[number],...} featureIDs
function Spring.GetFeaturesInScreenRectangle(left, top, right, bottom) end

---@return number playerID
function Spring.GetLocalPlayerID() end

---@return number teamID
function Spring.GetLocalTeamID() end

---@return number allyTeamID
function Spring.GetLocalAllyTeamID() end

---@return bool spectating
function Spring.GetSpectatingState() end

---@return bool spectatingFullView
function Spring.GetSpectatingState() end

---@return bool spectatingFullSelect
function Spring.GetSpectatingState() end

---@return {[number],...} unitIDs
function Spring.GetSelectedUnits() end

---@return {[number]={number,...},...} where keys are unitDefIDs and values are unitIDs
function Spring.GetSelectedUnitsSorted() end

---@return n the number of unitDefIDs
function Spring.GetSelectedUnitsSorted() end

---@return {[number]=number,...} unitsCounts where keys are unitDefIDs and values are counts
function Spring.GetSelectedUnitsCounts() end

---@return n the number of unitDefIDs
function Spring.GetSelectedUnitsCounts() end

---@return number selectedUnitsCount
function Spring.GetSelectedUnitsCount() end

---@return bool when true engine won't select units inside selection box when released
function Spring.GetBoxSelectionByEngine() end

---@return bool
function Spring.IsGUIHidden() end

---@return shadowsLoaded
function Spring.HaveShadows() end

---@return bool useAdvShading
function Spring.HaveAdvShading() end

---@return bool groundUseAdvShading
function Spring.HaveAdvShading() end

---@return number waterRendererID
function Spring.GetWaterMode() end

---@return string waterRendererName
function Spring.GetWaterMode() end

---@return nil|string "normal"|"height"|"metal"|"pathTraversability"|"los"
function Spring.GetMapDrawMode() end

---Parameters
---@param texSquareX number
---@param texSquareY number
---@param texMipLevel number
---@param luaTexName string
---@return nil|bool success
function Spring.GetMapSquareTexture(texSquareX, texSquareY, texMipLevel, luaTexName) end

---Fields
---@param r number
---@param g number
---@param b number
---@return { always=rgb, LOS=rgb, radar=rgb, jam=rgb, radar2=rgb }
function Spring.GetLosViewColors() end

---@return number rotVal in degrees
function Spring.GetNanoProjectileParams() end

---@return number rotVel in degrees
function Spring.GetNanoProjectileParams() end

---@return number rotAcc in degrees
function Spring.GetNanoProjectileParams() end

---@return number rotValRng in degrees
function Spring.GetNanoProjectileParams() end

---@return number rotVelRng in degrees
function Spring.GetNanoProjectileParams() end

---@return number rotAccRng in degrees
function Spring.GetNanoProjectileParams() end

---@return {[string] = number} where keys are names and values are indices
function Spring.GetCameraNames() end

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
---@param useReturns boolean (default): `true`
---@return any|camState ret1
function Spring.GetCameraState([useReturns=true]) end

---@return any|nil ret2
function Spring.GetCameraState([useReturns=true]) end

---@return any|nil retn
function Spring.GetCameraState([useReturns=true]) end

---@return posX
function Spring.GetCameraPosition() end

---@return posY
function Spring.GetCameraPosition() end

---@return posZ
function Spring.GetCameraPosition() end

---@return dirX
function Spring.GetCameraDirection() end

---@return dirY
function Spring.GetCameraDirection() end

---@return dirZ
function Spring.GetCameraDirection() end

---@return rotX in radians
function Spring.GetCameraRotation() end

---@return rotY in radians
function Spring.GetCameraRotation() end

---@return rotZ in radians
function Spring.GetCameraRotation() end

---@return number vFOV
function Spring.GetCameraFOV() end

---@return number hFOV
function Spring.GetCameraFOV() end

---Fields
---@param x number
---@param y number
---@param z number
---@return { forward = xyz, up = xyz, right = xyz, topFrustumPlane = xyz, botFrustumPlane = xyz, lftFrustumPlane = xyz, rgtFrustumPlane = xyz }
function Spring.GetCameraVectors() end

---Parameters
---@param x number
---@param y number
---@param z number
---@return viewPortX
function Spring.WorldToScreenCoords(x, y, z) end

---@return viewPortY
function Spring.WorldToScreenCoords(x, y, z) end

---@return viewPortZ
function Spring.WorldToScreenCoords(x, y, z) end

---Parameters
---@param screenX number
---@param screenY number
---@param onlyCoords boolean (default): `false`
---@param useMinimap boolean (default): `false`
---@param includeSky boolean (default): `false`
---@param ignoreWater boolean (default): `false`
---@param heightOffset number (default): `0`
---@return nil|string description of traced position
function Spring.TraceScreenRay(screenX, screenY[, onlyCoords=false[, useMinimap=false[, includeSky=false[, ignoreWater=false[, heightOffset=0]]]]]) end

---@return nil|number|string|xyz unitID or feature, position triple when onlyCoords=true
function Spring.TraceScreenRay(screenX, screenY[, onlyCoords=false[, useMinimap=false[, includeSky=false[, ignoreWater=false[, heightOffset=0]]]]]) end

---@return nil|number|string featureID or ground
function Spring.TraceScreenRay(screenX, screenY[, onlyCoords=false[, useMinimap=false[, includeSky=false[, ignoreWater=false[, heightOffset=0]]]]]) end

---@return nil|xyz coords
function Spring.TraceScreenRay(screenX, screenY[, onlyCoords=false[, useMinimap=false[, includeSky=false[, ignoreWater=false[, heightOffset=0]]]]]) end

---Parameters
---@param x number
---@param y number
---@return dirX
function Spring.GetPixelDir(x, y) end

---@return dirY
function Spring.GetPixelDir(x, y) end

---@return dirZ
function Spring.GetPixelDir(x, y) end

---Parameters
---@param teamID number
---@return nil|number r factor from 0 to 1
function Spring.GetTeamColor(teamID) end

---@return nil|number g factor from 0 to 1
function Spring.GetTeamColor(teamID) end

---@return nil|number b factor from 0 to 1
function Spring.GetTeamColor(teamID) end

---@return nil|number a factor from 0 to 1
function Spring.GetTeamColor(teamID) end

---Parameters
---@param teamID number
---@return nil|number r factor from 0 to 1
function Spring.GetTeamOrigColor(teamID) end

---@return nil|number g factor from 0 to 1
function Spring.GetTeamOrigColor(teamID) end

---@return nil|number b factor from 0 to 1
function Spring.GetTeamOrigColor(teamID) end

---@return nil|number a factor from 0 to 1
function Spring.GetTeamOrigColor(teamID) end

---@return time in seconds
function Spring.GetDrawSeconds() end


---
---@return number playTime
function Spring.GetSoundStreamTime() end

---@return number time
function Spring.GetSoundStreamTime() end


---
---@return number fps
function Spring.GetFPS() end

---@return number wantedSpeedFactor
function Spring.GetGameSpeed() end

---@return number speedFactor
function Spring.GetGameSpeed() end

---@return bool paused
function Spring.GetGameSpeed() end

---Parameters
---@param maxLatency number (default): `500`
---@return bool doneLoading
function Spring.GetGameState([maxLatency=500]) end

---@return bool isSavedGame
function Spring.GetGameState([maxLatency=500]) end

---@return bool isClientPaused
function Spring.GetGameState([maxLatency=500]) end

---@return bool isSimLagging
function Spring.GetGameState([maxLatency=500]) end


---
---@return nil|number cmdIndex
function Spring.GetActiveCommand() end

---@return nil|number cmdID
function Spring.GetActiveCommand() end

---@return nil|number cmdType
function Spring.GetActiveCommand() end

---@return nil|string cmdName
function Spring.GetActiveCommand() end

---@return nil|number cmdIndex
function Spring.GetDefaultCommand() end

---@return nil|number cmdID
function Spring.GetDefaultCommand() end

---@return nil|number cmdType
function Spring.GetDefaultCommand() end

---@return nil|string cmdName
function Spring.GetDefaultCommand() end

---Fields
---@param id number
---@param type number
---@param name string
---@param action string
---@param tooltip string
---@param texture string
---@param cursor string
---@param queueing boolean
---@param hidden boolean
---@param disabled boolean
---@param showUnique boolean
---@param onlyTexture boolean
---@param params {[string],...}
---@return {[cmdDesc],...} cmdDescs
function Spring.GetActiveCmdDescs() end

---Parameters
---@param cmdIndex number
---@return nil|cmdDesc
function Spring.GetActiveCmdDesc(cmdIndex) end

---Parameters
---@param cmdID number
---@return nil|number cmdDescIndex
function Spring.GetCmdDescIndex(cmdID) end

---@return number buildFacing
function Spring.GetBuildFacing() end

---@return number buildSpacing
function Spring.GetBuildSpacing() end

---@return number gatherMode
function Spring.GetGatherMode() end

---@return number activePage
function Spring.GetActivePage() end

---@return number maxPage
function Spring.GetActivePage() end


---
---@return number x
function Spring.GetMouseState() end

---@return number y
function Spring.GetMouseState() end

---@return number lmbPressed left mouse button pressed
function Spring.GetMouseState() end

---@return number mmbPressed middle mouse button pressed
function Spring.GetMouseState() end

---@return number rmbPressed right mouse button pressed
function Spring.GetMouseState() end

---@return bool offscreen
function Spring.GetMouseState() end

---@return bool mmbScroll
function Spring.GetMouseState() end

---@return string cursorName
function Spring.GetMouseCursor() end

---@return number cursorScale
function Spring.GetMouseCursor() end

---Parameters
---@param button number
---@return number x
function Spring.GetMouseStartPosition(button) end

---@return number y
function Spring.GetMouseStartPosition(button) end

---@return number camPosX
function Spring.GetMouseStartPosition(button) end

---@return number camPosY
function Spring.GetMouseStartPosition(button) end

---@return number camPosZ
function Spring.GetMouseStartPosition(button) end

---@return number dirX
function Spring.GetMouseStartPosition(button) end

---@return number dirY
function Spring.GetMouseStartPosition(button) end

---@return number dirZ
function Spring.GetMouseStartPosition(button) end


---
---@return string text
function Spring.GetClipboard() end

---@return bool
function Spring.IsUserWriting() end


---
---@return {xyz,...} message positions
function Spring.GetLastMessagePositions() end

---Parameters
---@param maxLines number
---@return nil|{{text=string,priority=number},...} pair array of (text, priority)
function Spring.GetConsoleBuffer(maxLines) end

---@return string tooltip
function Spring.GetCurrentTooltip() end


---
---Parameters
---@param scanSymbol string
---@return string keyName
function Spring.GetKeyFromScanSymbol(scanSymbol) end

---Parameters
---@param keyCode number
---@return bool pressed
function Spring.GetKeyState(keyCode) end

---@return bool alt
function Spring.GetModKeyState() end

---@return bool ctrl
function Spring.GetModKeyState() end

---@return bool meta
function Spring.GetModKeyState() end

---@return bool shift
function Spring.GetModKeyState() end

---@return {[number|string]=true,...} where keys are keyCodes or key names
function Spring.GetPressedKeys() end

---@return {[number|string]=true,...} where keys are scanCodes or scan names
function Spring.GetPressedScans() end

---@return nil|number queueKey
function Spring.GetInvertQueueKey() end

---Parameters
---@param keySym string
---@return number keyCode
function Spring.GetKeyCode(keySym) end

---Parameters
---@param keyCode number
---@return string keyCodeName
function Spring.GetKeySymbol(keyCode) end

---@return string keyCodeDefaultName name when there are not aliases
function Spring.GetKeySymbol(keyCode) end

---Parameters
---@param scanCode number
---@return string scanCodeName
function Spring.GetScanSymbol(scanCode) end

---@return string scanCodeDefaultName name when there are not aliases
function Spring.GetScanSymbol(scanCode) end

---Fields
---@param command string
---@param extra string
---@param boundWith string
---Parameters
---@param keySet1 string (optional)
---@param keySet2 string (optional)
---@return {[keybindingSpec],...}
function Spring.GetKeyBindings([keySet1[, keySet2]]) end

---Parameters
---@param actionName string
---@return nil|{[string],...} hotkeys
function Spring.GetActionHotKeys(actionName) end


---
---@return nil|{[number]=number,...} where keys are groupIDs and values are counts
function Spring.GetGroupList() end

---@return number groupID -1 when no group selected
function Spring.GetSelectedGroup() end

---Parameters
---@param unitID number
---@return nil|number groupID
function Spring.GetUnitGroup(unitID) end

---Parameters
---@param groupID number
---@return nil|{[number],...} unitIDs
function Spring.GetGroupUnits(groupID) end

---Parameters
---@param groupID number
---@return nil|{[number]={[number],...},...} where keys are unitDefIDs and values are unitIDs
function Spring.GetGroupUnitsSorted(groupID) end

---Parameters
---@param groupID number
---@return nil|{[number]=number,...} where keys are unitDefIDs and values are counts
function Spring.GetGroupUnitsCounts(groupID) end

---Parameters
---@param groupID number
---@return nil|number groupSize
function Spring.GetGroupUnitsCount(groupID) end


---
---Fields
---@param name string
---@param playerID number
---@param teamID number
---@param allyTeamID number
---@param spectator boolean
---@param cpuUsage number
---@param pingTime number
---Parameters
---@param sortType number (optional)
---@param showPathingPlayers boolean (default): `false`
---@return nil|{[rosterSpec],...} playerTable
function Spring.GetPlayerRoster([sortType[, showPathingPlayers=false]]) end

---Parameters
---@param playerID number
---@param packetID number
---@return number traffic
function Spring.GetPlayerTraffic(playerID, packetID) end

---Parameters
---@param playerID number
---@return nil|number mousePixels nil when invalid playerID
function Spring.GetPlayerStatistics(playerID) end

---@return number mouseClicks
function Spring.GetPlayerStatistics(playerID) end

---@return number keyPresses
function Spring.GetPlayerStatistics(playerID) end

---@return number numCommands
function Spring.GetPlayerStatistics(playerID) end

---@return number unitCommands
function Spring.GetPlayerStatistics(playerID) end


---
---Fields
---@param name string
---@param type string
---@param description string
---@param defaultValue string
---@param minimumValue string
---@param maximumValue string
---@param safemodeValue string
---@param declarationFile string
---@param declarationLine string
---@param readOnly boolean
---@return {[configSpec],...}
function Spring.GetConfigParams() end

---Parameters
---@param name string
---@param default number|nil (default): `0`
---@return nil|number configInt
function Spring.GetConfigInt(name[, default=0]) end

---Parameters
---@param name string
---@param default number|nil (default): `0`
---@return nil|number configFloat
function Spring.GetConfigFloat(name[, default=0]) end

---Parameters
---@param name string
---@param default string|nil (default): `""`
---@return nil|number configString
function Spring.GetConfigString(name[, default=""]) end

---@return {[string]=number,...} sections where keys are names and loglevel are values. E.g. `{ "KeyBindings" = LOG.INFO, "Font" = LOG.INFO, "Sound" = LOG.WARNING, ... }`
function Spring.GetLogSections() end


---
---@return nil|{[number],...} decalIndices
function Spring.GetAllDecals() end

---Parameters
---@param decalIndex number
---@return nil|number posX
function Spring.GetDecalPos(decalIndex) end

---@return number posY
function Spring.GetDecalPos(decalIndex) end

---@return number posZ
function Spring.GetDecalPos(decalIndex) end

---Parameters
---@param decalIndex number
---@return nil|number sizeX
function Spring.GetDecalSize(decalIndex) end

---@return number sizeY
function Spring.GetDecalSize(decalIndex) end

---Parameters
---@param decalIndex number
---@return nil|number rotation in radians
function Spring.GetDecalRotation(decalIndex) end

---Parameters
---@param decalIndex number
---@return nil|string texture
function Spring.GetDecalTexture(decalIndex) end

---Parameters
---@param decalIndex number
---@return nil|number alpha
function Spring.GetDecalAlpha(decalIndex) end

---Parameters
---@param decalIndex number
---@return nil|number unitID
function Spring.GetDecalOwner(decalIndex) end

---Parameters
---@param decalIndex number
---@return nil|string type "explosion"|"building"|"lua"|"unknown"
function Spring.GetDecalType(decalIndex) end

