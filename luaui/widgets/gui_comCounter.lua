function widget:GetInfo()
	return {
		name		= "Com Counter",
		desc		= "Shows the number of coms left on each team",
		author		= "BD",
		date		= "Dec 27, 2012",
		license		= "GNU GPL, v2 or later",
		layer		= 0,
		enabled		= true
	}
end

---------------------------------------------------------------------------------------------------
--  Declarations
---------------------------------------------------------------------------------------------------

-- Config
local flashIcon				= true
local markers				= false
local flagWarningTime		= 30*10
-- whenever reclaim/rez/damage labels should be placed even if the player has LOS
local warnLOS				= false
local specMarkers			= false

local spEcho				= Spring.Echo
local X, Y					= Spring.GetViewGeometry()
local spGetMyPlayerID		= Spring.GetMyPlayerID
local spGetMyAllyTeamID		= Spring.GetMyAllyTeamID
local spGetMyTeamID			= Spring.GetMyTeamID
local spGetTeamList			= Spring.GetTeamList
local spGetAllyTeamList		= Spring.GetAllyTeamList
local spGetTeamList			= Spring.GetTeamList
local spGetTeamUnits		= Spring.GetTeamUnits
local spGetAllUnits			= Spring.GetAllUnits
local spGetPlayerList		= Spring.GetPlayerList
local spGetPlayerInfo		= Spring.GetPlayerInfo
local spGetTeamColour		= Spring.GetTeamColor
local spIsUnitAllied		= Spring.IsUnitAllied
local spGetUnitDefID		= Spring.GetUnitDefID
local spGetUnitAllyTeam		= Spring.GetUnitAllyTeam
local spGetUnitTeam			= Spring.GetUnitTeam
local spGetUnitPosition		= Spring.GetUnitPosition
local spGetGameFrame		= Spring.GetGameFrame
local spGetAllFeatures		= Spring.GetAllFeatures
local spGetFeatureTeam		= Spring.GetFeatureTeam
local spGetFeatureAllyTeam	= Spring.GetFeatureAllyTeam
local spGetFeatureDefID		= Spring.GetFeatureDefID
local spGetFeaturePosition	= Spring.GetFeaturePosition
local spGetFeatureHealth	= Spring.GetFeatureHealth
local spGetFeatureResources	= Spring.GetFeatureResources
local spMarkerAddPoint		= Spring.MarkerAddPoint
local spMarkerErasePosition	= Spring.MarkerErasePosition
local spGetSpectatingState	= Spring.GetSpectatingState
local spGetTeamInfo			= Spring.GetTeamInfo
local spIsPosInLos			= Spring.IsPosInLos
local spAreTeamsAllied		= Spring.AreTeamsAllied
local spGetGaiaTeamID		= Spring.GetGaiaTeamID

local VFSFileExists			= VFS.FileExists

local glTranslate			= gl.Translate
local glColor				= gl.Color
local glPushMatrix			= gl.PushMatrix
local glPopMatrix			= gl.PopMatrix
local glTexture				= gl.Texture
local glRect				= gl.Rect
local glTexRect				= gl.TexRect
local glText				= gl.Text
local glGetTextWidth		= gl.GetTextWidth
local glCreateList			= gl.CreateList
local glCallList			= gl.CallList
local glDeleteList			= gl.DeleteList

local floor					= math.floor
local max					= math.max
local min					= math.min
local insert				= table.insert
local toChar				= string.char

local textSize				= 20
local xPos, yPos
local xRelPos, yRelPos		= 0.80, 0.85
local vsx, vsy				= gl.GetViewSizes()
local panelWidth			= 100
local panelHeight			= 50
local panelColor			= {0, 0, 0, 0.5}
local check1x, check1y		= 6, 28
local check2x, check2y		= 6, 6
local allyComs				= 0
local enemyComs				= 0
local teamComs				= {}
local deadComs				= {}
local lastAllyComMarked		= false
local lastEnemyComMarked	= false
local amISpec				= spGetSpectatingState()
local myTeamID				= spGetMyTeamID()
local myAllyTeamID			= spGetMyAllyTeamID()
local myPlayerID			= spGetMyPlayerID()
local countChanged			= true
local displayList			= nil
local flickerLastState		= nil
local newFeatures			= {}
local is1v1					= #spGetTeamList() == 3 -- +1 because of gaia
local coopOn				= Spring.GetModOptions().mo_coop == "1" or true
--------------------------------------------------------------------------------


function placeLabel(x, y, z, msg)
	if markers and (specMarkers or not amISpec) then
		spMarkerAddPoint(x, y, z, msg)
	end
end

function isCom(unitID,unitDefID)
	if not unitDefID and unitID then
		unitDefID =  spGetUnitDefID(unitID)
	end
	if not unitDefID or not UnitDefs[unitDefID] or not UnitDefs[unitDefID].customParams then
		return false
	end
	return UnitDefs[unitDefID].customParams.iscommander ~= nil

end

function isDeadCom(fName)
	return fName == "corcom_dead" or fName == "armcom_dead" -- or fName == "corcom_heap" or fName == "armcom_heap"
end

function colourNames(teamID) -- I didn't make this, but thank you to whoever did!
	nameColourR, nameColourG, nameColourB, nameColourA = spGetTeamColour(teamID)
	R255 = floor(nameColourR*255)
	G255 = floor(nameColourG*255)
	B255 = floor(nameColourB*255)
	if ( R255%10 == 0) then
		R255 = R255+1
	end
	if( G255%10 == 0) then
		G255 = G255+1
	end
	if ( B255%10 == 0) then
		B255 = B255+1
	end
	return "\255"..toChar(R255)..toChar(G255)..toChar(B255)
end

function flicker()
	return spGetGameFrame() % 12 < 6
end


function appendComToTeam(teamID,numComs)
	countChanged = true
	numComs = numComs or 1
	teamComs[teamID] = ( teamComs[teamID] or 0 ) + numComs
	if spAreTeamsAllied(myTeamID,teamID) then
		lastAllyComMarked = false
		allyComs = allyComs + numComs
	else
		lastEnemyComMarked = false
		enemyComs = enemyComs + numComs
	end
end

function removeComFromTeam(teamID,numComs)
	countChanged = true
	numComs = numComs or 1
	teamComs[teamID] = ( teamComs[teamID] or 0 ) + numComs
	if spAreTeamsAllied(myTeamID,teamID) then
		allyComs = allyComs - numComs
	else
		enemyComs = enemyComs - numComs
	end
end

function checkTeamComCount(allyID)
	local comCount = {}
	local totalNum = 0
	for _, teamID in ipairs(spGetTeamList(allyID)) do
		comCount[teamID] = comCount[teamID] or 0
		for _, unitID in ipairs(spGetTeamUnits(teamID)) do
			if isCom(unitID) then
				comCount[teamID] = comCount[teamID] + 1
				totalNum = totalNum + 1
			end
		end
	end
	return totalNum, comCount
end

function recountAllComs()
	if not amISpec then
		-- this function will not work unless we have full LOS
		return
	end
	countChanged = true
	enemyComs = 0
	allyComs = 0
	teamComs = {}
	for _,allyTeamID in ipairs(spGetAllyTeamList()) do
		local _, comList = checkTeamComCount(allyTeamID)
		for teamID, amount in pairs(comList) do
			appendComToTeam(teamID,amount)
		end
	end
end


function widget:Initialize()
	xPos, yPos = xRelPos * vsx,yRelPos * vsy
	if spGetGameFrame() ~= 0 then
		if amISpec then
			recountAllComs()
		else
			widgetHandler:RemoveWidget()
		end
	else
		if not amISpec then --we can use UnitCreated reliably
			local teamToPlayers = {}
			for _, playerID in ipairs(spGetPlayerList()) do
				local _, _, spec, tID, aID = spGetPlayerInfo(playerID)
				if not spec then
					teamToPlayers[tID] = teamToPlayers[tID] or {}
					table.insert(teamToPlayers[tID],playerID)
				end
			end
			local gaiaTeam = spGetGaiaTeamID()
			for _,teamID in ipairs(spGetTeamList()) do
				local numComs = 1
				if teamID == gaiaTeam then
					numComs = 0
				elseif coopOn and teamToPlayers[teamID] then -- in coop mode, 1 team per player
					numComs = #teamToPlayers[teamID]
				end
				if not spAreTeamsAllied(myTeamID,teamID) then -- we can use UnitCreated for allies
					appendComToTeam(teamID,numComs)
				end
			end
		end
	end
end

function widget:Shutdown()
	glDeleteList(displayList)
end


function widget:PlayerChanged(playerID)
	if playerID == myPlayerID then
		IChanged()
	end
end

function widget:IChanged()
	amISpec = spGetSpectatingState()
	myTeamID = spGetMyTeamID()
	myPlayerID = spGetMyPlayerID()
	myAllyTeamID = spGetMyAllyTeamID()
	recountAllComs()
end


--atm this works reliably only when spectating
function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if not isCom(unitID,unitDefID) then
		return
	end
	--ignore enemy rez even if in los, because it's handled by featured died logic
	if amISpec or spAreTeamsAllied(myTeamID, unitTeam) then
		appendComToTeam(unitTeam)
	end
end


function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	if not isCom(unitID,unitDefID) then
		return
	end
	removeComFromTeam(oldTeam)
	appendComToTeam(newTeam)
end

function UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if not isCom(unitID,unitDefID) then
		return
	end
	removeComFromTeam(oldTeam)
	appendComToTeam(newTeam)
end

-- keep progress of reclaim/resurrect/damage done in each frame, calc delta
-- last time a change happened, and try to predict next value to guesstimate a
-- reason why a feature disappeared
function wreckProcessChange(gameFrame,position,data,newValue,labelPositive,labelNegative)
	data.delta = newValue - data.status
	data.status = newValue
	-- we'll use a linear interpolation to estimate which operation was successful
	data.nextValue = data.status + 2*data.delta
	if data.delta ~= 0 then
		if (data.lastUpdate + flagWarningTime) < gameFrame then
			-- don't annoy players when they can see themselves
			if warnLOS or not spIsPosInLos(position.fX, position.fY, position.fZ, myAllyTeamID ) then
				if data.delta > 0 then
					if labelPositive then
						placeLabel(position.fX, position.fY, position.fZ, labelPositive)
					end
				elseif data.delta < 0 then
					if labelNegative then
						placeLabel(position.fX, position.fY, position.fZ, labelNegative)
					end
				end
			end
		end
		data.lastUpdate = gameFrame
	end
end

function markCom(unitID,teamID)
 	if is1v1 then
 		return false
 	end
	local markAllyCom = allyComs == 1 and not lastAllyComMarked
	local markEnemyCom = enemyComs == 1 and not lastEnemyComMarked
	if not markAllyCom and not markEnemyCom then
		return false
	end
	if not isCom(unitID) then
		return false
	end
	local ally = spAreTeamsAllied(myTeamID,teamID)
	local _, _, _, uX, uY, uZ = spGetUnitPosition(unitID, true, false)
	if ally and markAllyCom then
		if markers then --we don't use placeLabel so it works as spec too
			spMarkerAddPoint(uX, uY, uZ, colourNames(teamID).."Our last Com")
		end
		lastAllyComMarked = true
	elseif not ally and markEnemyCom then
		if markers then --we don't use placeLabel so it works as spec too
			spMarkerAddPoint(uX, uY, uZ, colourNames(teamID).."Their last Com")
		end
		lastEnemyComMarked = true
	end
	return true
end

function widget:UnitEnteredRadar(unitID, unitTeam)
	markCom(unitID, unitTeam)
end

function widget:UnitEnteredLos(unitID, teamID)
	markCom(unitID, teamID)
end

function markComs()
	local markAllyCom = allyComs == 1 and not lastAllyComMarked
	local markEnemyCom = enemyComs == 1 and not lastEnemyComMarked
	if not markAllyCom and not markEnemyCom then
		return
	end
	for _,allyTeamID in ipairs(spGetAllyTeamList()) do
		for _, teamID in ipairs(spGetTeamList(allyTeamID)) do
			for _, unitID in ipairs(spGetTeamUnits(teamID)) do
				if markCom(unitID, teamID) then
					return
				end
			end
		end
	end
end


function widget:GameFrame(n)
	for featureID,data  in pairs(deadComs) do
		local Hp, maxHp, fRez = spGetFeatureHealth(featureID)
		local _,_,_,_,reclaimLeft = spGetFeatureResources(featureID)
		if Hp and maxHp then
			wreckProcessChange(n,data.position,data.damage,Hp/maxHp)
		end
		if fRez then
			wreckProcessChange(n,data.position,data.rez,fRez,"Com is being resurrected")
		end
		if reclaimLeft then
			wreckProcessChange(n,data.position,data.reclaim,reclaimLeft,"Com is being resurrected","Com is being reclaimed")
		end
	end
	-- ugly workaround to account if we change who we watch as spec
	if myTeamID ~= spGetMyTeamID() then
		IChanged()
	end
	--remove this shit when FetureCreated and FeatureDestroyed are available
	local allFeatures = {}
	for _,featureID in ipairs(spGetAllFeatures()) do
		if not newFeatures[featureID] then
			newFeature(featureID)
			newFeatures[featureID] = true
		end
		allFeatures[featureID] = true
	end
	for featureID in pairs(newFeatures) do
		if not allFeatures[featureID] then
			delFeature(featureID)
			newFeatures[featureID] = nil
		end
	end
end

function initVec(value)
	return {status=value,delta=0,lastUpdate=0,nextValue=value}
end

function newFeature(featureID)
	if not featureID then
		return
	end
	local fDefID = spGetFeatureDefID(featureID)
	if not fDefID then
		return
	end
	local fName = FeatureDefs[fDefID].name
	if not isDeadCom(fName) then
		return
	end
	local fTeamID = spGetFeatureTeam(featureID)
	local _,fPlayerID = spGetTeamInfo(fTeamID)
	local pName= spGetPlayerInfo(fPlayerID) or ""
	local _,_,_,fX,fY,fZ = spGetFeaturePosition(featureID, true, false)
	local Hp, maxHp, fRez = spGetFeatureHealth(featureID)
	local _,_,_,_,reclaimLeft = spGetFeatureResources(featureID)
	local position = {fX=fX,fY=fY,fZ=fZ}
	deadComs[featureID] = {position=position,rez=initVec(fRez),damage=initVec(Hp/maxHp),reclaim=initVec(reclaimLeft)}
	removeComFromTeam(fTeamID)
	markComs() -- mark last com if necessary
	if spAreTeamsAllied(myTeamID,fTeamID) then
		placeLabel(fX, fY, fZ, colourNames(fTeamID)..pName.." (ally) just lost their Com")
	else
		placeLabel(fX, fY, fZ, colourNames(fTeamID)..pName.." (enemy) just lost their Com")
	end
end

function delFeature(featureID)
	if not featureID then
		return
	end
	local data = deadComs[featureID]
	if not data then
		return -- it's either not a com or we got no info on it anyway
	end
	local position = data.position
	-- use the linearry interpolated value to see which operation was successful
	if data.rez.nextValue >= 1 then
		--need to figure out a better way to find who resurrected the com, then we
		--can keep track the amount of coms per team
		if not amISpec then --as spectator, we can use UnitCreated alone
			if allyComs == checkTeamComCount(myAllyTeamID) then --we can see the com with UnitCreated if allied 
				countChanged = true
				lastEnemyComMarked = false
				enemyComs = enemyComs + 1
			end
		end
	end
	-- don't annoy players when they can see themselves
	if warnLOS or not spIsPosInLos(position.fX, position.fY, position.fZ, myAllyTeamID ) then
		if data.rez.nextValue >= 1 then
			placeLabel(position.fX, position.fY, position.fZ, "Com has been resurrected")
		elseif data.reclaim.nextValue <= 0 then
			placeLabel(position.fX, position.fY, position.fZ, "Com has been reclaimed")
		elseif data.damage.nextValue <= 0 then
			placeLabel(position.fX, position.fY, position.fZ, "Com wreck destroyed")
		else
			placeLabel(position.fX, position.fY, position.fZ, "Com wreck disappeared")
		end
	else
		-- if in los we can always remove the landmark without risking to remove important labels
		spMarkerErasePosition( position.fX, position.fY, position.fZ )
	end
	deadComs[featureID] = nil
end

function widget:DrawScreen()
	if widgetHandler:InTweakMode() then
		return
	end
	if spGetGameFrame() == 0 then
		return
	end
	local flickerState = allyComs == 1 and flashIcon and flicker()
	if countChanged or flickerLastState ~= flickerState then
		countChanged = false
		glDeleteList(displayList)
		-- regenerate the display list
		displayList = glCreateList( function()
			glTranslate(xPos, yPos, 0)
			glColor(panelColor)
			glRect(0, 0, panelWidth, panelHeight)
			if flickerState then
				glColor(1,0.6,0,0.6)
			else
				glColor(1,1,1,0.3)
			end
			if VFSFileExists('LuaUI/Images/comIcon.png') then
				glTexture('LuaUI/Images/comIcon.png')
			end
			x,y = 33, 5
			glTexRect(x, y, x+34, y+40)
			glTexture(false)
			glColor(0,1,0,1)
			glText(allyComs, (33-(gl.GetTextWidth(allyComs)*textSize))/2, 18, textSize)
			glColor(1,0,0,1)
			glText(enemyComs, 66+(33-(gl.GetTextWidth(enemyComs)*textSize))/2, 18, textSize)
		end)
	end
	flickerLastState = flickerState
	glPushMatrix()
		glCallList(displayList)
	glPopMatrix()
end

function widget:TweakDrawScreen()
	glPushMatrix()
		glTranslate(xPos, yPos, 0)
		glColor(panelColor)
		glRect(0, 0, panelWidth, panelHeight)
		drawCheckbox(check1x, check1y, markers, "Place Markers")
		drawCheckbox(check2x, check2y, flashIcon, "Flashing Icon")
	glPopMatrix()
end

function drawCheckbox(x, y, state, text)
	glPushMatrix()
		glTranslate(x, y, 0)
		glColor(1, 1, 1, 0.2)
		glRect(0, 0, 16, 16)
		glColor(1, 1, 1, 1)
		if state then
			if VFSFileExists('LuaUI/Images/tick.png') then
				glTexture('LuaUI/Images/tick.png')
			end
			glTexRect(0, 0, 16, 16)
			glTexture(false)
		end
		glText(text, 20, 4, 9, "n")
	glPopMatrix()
end

function widget:IsAbove(mx, my)
	return mx > xPos and my > yPos and mx < xPos + panelWidth and my < yPos + panelHeight
end

function widget:MousePress(mx, my, button)
	if not widget:IsAbove(mx,my) then
		return false
	end
	if (mx - xPos) > (panelWidth / 2) then
		lastEnemyComMarked = false
	else
		lastAllyComMarked = false
	end
	markComs()
	return true
end

function widget:TweakMousePress(mx, my)
	if widget:IsAbove(mx,my) then
		if mx > xPos+check1x and my > yPos+check1y and mx < (xPos+check1x+16) and my < (yPos+check1y+16) then
			markers = not markers
		elseif mx > xPos+check2x and my > yPos+check2y and mx < (xPos+check2x+16) and my < (yPos+check2y+16) then
			flashIcon = not flashIcon
		end
		return true
	end
end

function widget:TweakMouseMove(mx, my, dx, dy)
	xRelPos = xRelPos + dx/vsx
	yRelPos = yRelPos + dy/vsy
	xPos, yPos = xRelPos * vsx,yRelPos * vsy
	countChanged = true
end

function widget:ViewResize(newX,newY)
	vsx, vsy = newX, newY
	xPos, yPos = xRelPos * vsx,yRelPos * vsy
	countChanged = true
end

function widget:GetConfigData()
	return {xRelPos = xRelPos, yRelPos = yRelPos, markers = markers, flashIcon = flashIcon}
end

function widget:SetConfigData(data)
	xRelPos = data.xRelPos or xRelPos
	yRelPos = data.yRelPos or yRelPos
	xPos = yRelPos * vsx
	yPos = yRelPos * vsy
	markers = data.markers or markers
	flashIcon = data.flashIcon or flashIcon
end
