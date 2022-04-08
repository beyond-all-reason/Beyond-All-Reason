include("keysym.h.lua")

function widget:GetInfo()
	return {
		name      = "Ally Selected Units",
		desc      = "Shows units selected by teammates",
		author    = "very_bad_soldier",
		date      = "August 1, 2008",
		license   = "GNU GPL v2",
		layer     = -10,
		enabled   = true
	}
end

local spGetSelectedUnits	= Spring.GetSelectedUnits
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitBasePosition = Spring.GetUnitBasePosition
local spGetPlayerInfo       = Spring.GetPlayerInfo
local spGetLocalTeamID		= Spring.GetLocalTeamID
local spSelectUnitMap		= Spring.SelectUnitMap
local spGetTeamColor 		= Spring.GetTeamColor
local spIsSphereInView  	= Spring.IsSphereInView
local spGetSpectatingState	= Spring.GetSpectatingState
local spGetGameSeconds		= Spring.GetGameSeconds
local spIsGUIHidden			= Spring.IsGUIHidden
local glColor               = gl.Color
local glDepthTest           = gl.DepthTest
local glPopMatrix           = gl.PopMatrix
local glPushMatrix          = gl.PushMatrix
local glTranslate           = gl.Translate
local glLineWidth 			= gl.LineWidth
local glScale				= gl.Scale
local glCallList   			= gl.CallList
local glDrawListAtUnit      = gl.DrawListAtUnit

local spec = false
local playerIsSpec = {}

local scaleMultiplier			= 1.05
local maxAlpha					= 0.45
local hotFadeTime				= 0.25
local lockTeamUnits				= false -- disallow selection of units selected by teammates
local showAlly					= true -- also show allies (besides coop)
local useHotColor				= false -- use RED for all hot units, if false use playerColor starting with transparency
local showAsSpectator			= true
local circleDivsCoop			= 32  -- nice circle
local circleDivsAlly			= 5  -- aka pentagon
local selectPlayerUnits			= true

local hotColor = {1.0, 0.0, 0.0, 1.0}

local playerColorPool = {
	{0.0, 1.0, 0.0},
	{1.0, 1.0, 0.0},
	{0.0, 0.0, 1.0},
	{0.6, 0.0, 0.0}, -- reserve full-red for hot units
	{0.0, 1.0, 1.0},
	{1.0, 0.0, 1.0},
	{1.0, 0.0, 0.0},
	{1.0, 0.0, 0.0},
}

local nextPlayerPoolId = 1
local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local playerSelectedUnits = {}
local hotUnits = {}
local circleLinesCoop
local circleLinesAlly
local lockPlayerID

local playerColors = {}

local teamColorKeys = {}
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local r, g, b, a = spGetTeamColor(teams[i])
	teamColorKeys[teams[i]] = r..'_'..g..'_'..b
end
teams = nil

local unitScale = {}
local unitCanFly = {}
local unitBuilding = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	unitScale[unitDefID] = (7.5 * ( unitDef.xsize^2 + unitDef.zsize^2 ) ^ 0.5) + 8
	if unitDef.canFly then
		unitCanFly[unitDefID] = true
		unitScale[unitDefID] = unitScale[unitDefID] * 0.7
	elseif unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0 then
		unitBuilding[unitDefID] = {
			unitDef.xsize * 8.2 + 12,
			unitDef.zsize * 8.2 + 12
		}
	end
end


local unitConf = {}
for udid, unitDef in pairs(UnitDefs) do
	local scaleFactor = 2.6			-- preferred to keep this value the same as other widgets
	local rectangleFactor = 3.25	-- preferred to keep this value the same as other widgets

	local xsize, zsize = unitDef.xsize, unitDef.zsize
	local scale = scaleFactor*( xsize^2 + zsize^2 )^0.5
	local shape, xscale, zscale

	if unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0 then
		shape = 'square'
		xscale, zscale = rectangleFactor * xsize, rectangleFactor * zsize
	elseif unitDef.isAirUnit then
		shape = 'triangle'
		xscale, zscale = scale*1.07, scale*1.07
	elseif unitDef.modCategories.ship then
		shape = 'circle'
		xscale, zscale = scale*0.82, scale*0.82
	else
		shape = 'circle'
		xscale, zscale = scale, scale
	end

	local radius = Spring.GetUnitDefDimensions(udid).radius
	xscale = (xscale*0.7) + (radius/5)
	zscale = (zscale*0.7) + (radius/5)

	unitConf[udid] = {shape=shape, xscale=xscale, zscale=zscale}
end

local function getPlayerColour(playerID,teamID)
	if playerSelectedUnits[playerID].coop and not spec then
		if not playerColorPool[nextPlayerPoolId] then
			playerColors[playerID] = playerColorPool[1]  --we have only 8 colors, take color 1 as default
		else
			playerColors[playerID] = playerColorPool[nextPlayerPoolId]
		end
		nextPlayerPoolId = nextPlayerPoolId + 1
	else
		playerColors[playerID] = {spGetTeamColor(teamID)}--he is only ally, use his color
	end
end

local function newHotUnit(unitID, coop, playerID)
	if not playerSelectedUnits[playerID].todraw then
		return
	end
	local udef = spGetUnitDefID(unitID)
	if udef ~= nil then
		local realDefRadius = unitConf[udef].xscale*1.5
		if realDefRadius ~= nil then
			local defRadius = realDefRadius * scaleMultiplier
			hotUnits[ unitID ] = {ts = os.clock(), coop = coop, defRadius = defRadius, playerID = playerID}
		end
	end
end

local function selectPlayerSelectedUnits(playerID)
	local units = {}
	local count = 0
	for pID, selUnits in pairs(playerSelectedUnits) do
		if pID == playerID then
			for unitId, _ in pairs(selUnits.units) do
				count = count + 1
				units[count] = unitId
			end
		end
	end
	Spring.SelectUnitArray(units)
end

local function selectedUnitsClear(playerID)
	if not playerIsSpec[playerID] or (lockPlayerID ~= nil and playerID == lockPlayerID) then
		if not playerSelectedUnits[playerID] then
			widget:PlayerAdded(playerID)
		end
		--make all hot
		for unitId, defRadius in pairs(playerSelectedUnits[playerID].units) do
			newHotUnit(unitId, playerSelectedUnits[playerID].coop, playerID)
		end
		--clear all
		playerSelectedUnits[playerID].units = {}
	end
	if lockPlayerID ~= nil and playerID == lockPlayerID and selectPlayerUnits then
		selectPlayerSelectedUnits(lockPlayerID)
	end
end

local function selectedUnitsAdd(playerID,unitID)
	if not playerIsSpec[playerID] or (lockPlayerID ~= nil and playerID == lockPlayerID) then
		if not playerSelectedUnits[playerID] then
			widget:PlayerAdded(playerID)
		end
		--add unit
		local udefID = spGetUnitDefID(unitID)
		if spGetUnitDefID(unitID) ~= nil then
			local realDefRadius = unitConf[udefID].xscale*1.5
			if realDefRadius then
				playerSelectedUnits[playerID].units[unitID] = realDefRadius * scaleMultiplier
				--un-hot it
				hotUnits[unitID] = nil
			end
		end
	end
	if lockPlayerID ~= nil and playerID == lockPlayerID and selectPlayerUnits then
		selectPlayerSelectedUnits(lockPlayerID)
	end
end

local function selectedUnitsRemove(playerID,unitID)
	if not playerIsSpec[playerID] or (lockPlayerID ~= nil and playerID == lockPlayerID) then
		if not playerSelectedUnits[playerID] then
			widget:PlayerAdded(playerID)
		end
		--remove unit
		playerSelectedUnits[playerID].units[unitID] = nil
		--make it hot
		newHotUnit(unitID, playerSelectedUnits[playerID].coop, playerID)
	end
	if lockPlayerID ~= nil and playerID == lockPlayerID and selectPlayerUnits then
		selectPlayerSelectedUnits(lockPlayerID)
	end
end

local function array2Table(arr)
	local tab = {}
	for i,v in ipairs(arr) do
		tab[v] = true
	end
	return tab
end

local function DoDrawPlayer(playerID,teamID)
	if playerID == myPlayerID then
		return false
	end
	if teamID ~= myTeamID and not showAlly then
		return false
	end
	return true
end

local function deselectAllTeamSelected()
	local selectedUnits = array2Table(spGetSelectedUnits())
	for playerID, selUnits in pairs(playerSelectedUnits) do
		for unitId, defRadius in pairs(selUnits.units) do
			selectedUnits[unitId] = nil
		end
	end
	spSelectUnitMap(selectedUnits)
end

local function setPlayerColours()
	playerColors = {}
	for _, playerID in pairs(Spring.GetPlayerList()) do
		widget:PlayerAdded(playerID)
	end
end

local function calcCircleLines(divs)
	local circleOffset = 0
	local lines = gl.CreateList(function()
		gl.BeginEnd(GL.LINE_LOOP, function()
			local radstep = (2.0 * math.pi) / divs
			for i = 1, divs do
				local a = (i * radstep)
				gl.Vertex(math.sin(a), circleOffset, math.cos(a))
			end
		end)
	end)

	return lines
end

function widget:PlayerRemoved(playerID, reason)
	for unitID, val in pairs( hotUnits ) do
		if val.playerID == playerID then
			hotUnits[unitID] = nil
		end
	end
	playerSelectedUnits[playerID].units = {}
end

function widget:PlayerAdded(playerID)
	local playerTeam = select(4, spGetPlayerInfo(playerID, false))
	if not playerSelectedUnits[playerID] then
		playerSelectedUnits[playerID] = {
			units = {},
			coop = (playerTeam == myTeamID),
			todraw = DoDrawPlayer(playerID),
		}
	end
	playerIsSpec[playerID] = select(3, spGetPlayerInfo(playerID, false))
	--grab color from color pool for new teammate
	--no color yet
	getPlayerColour(playerID,playerTeam)
end

function widget:PlayerChanged(playerID)
	if not spec and spGetSpectatingState() then
		spec = true
		setPlayerColours()
		if not showAsSpectator then
			widgetHandler:RemoveWidget()
			return
		end
	end
	myTeamID = spGetLocalTeamID()
	local playerTeam = select(4, spGetPlayerInfo(playerID, false))
	local oldCoopStatus = playerSelectedUnits[playerID].coop
	playerSelectedUnits[playerID].coop = (playerTeam == myTeamID)
	playerSelectedUnits[playerID].todraw = DoDrawPlayer(playerID)

	--grab color from color pool for new teammate
	if oldCoopStatus ~= playerSelectedUnits[playerID].coop then
		getPlayerColour(playerID,playerTeam)
	end

	for i,playerID in pairs(Spring.GetPlayerList()) do
		playerIsSpec[playerID] = select(3, spGetPlayerInfo(playerID, false))
	end
end

function widget:CommandsChanged(id, params, options)
	if lockTeamUnits then
		deselectAllTeamSelected()
	end
end

function widget:UnitDestroyed(unitID)
	hotUnits[unitID] = nil

	for playerID, selUnits in pairs(playerSelectedUnits) do
		selUnits.units[unitID] = nil
	end
end

local updateTime = 0
local checkLockPlayerInterval = 1
local sec = 0
function widget:Update(dt)
	if WG['advplayerlist_api'] ~= nil then
		updateTime = updateTime + dt
		if updateTime > checkLockPlayerInterval then
			lockPlayerID = WG['advplayerlist_api'].GetLockPlayerID()
			if lockPlayerID ~= nil and selectPlayerUnits then
				selectPlayerSelectedUnits(lockPlayerID)
			end
			updateTime = 0
		end
	end

	sec = sec + dt
	if sec > 1.5 then
		sec = 0

		-- check if team colors have changed
		local teams = Spring.GetTeamList()
		for i = 1, #teams do
			local r, g, b, a = spGetTeamColor(teams[i])
			if teamColorKeys[teams[i]] ~= r..'_'..g..'_'..b then
				teamColorKeys[teams[i]] = r..'_'..g..'_'..b
				local players = Spring.GetPlayerList(teams[i])
				for _, playerID in ipairs(players) do
					widget:PlayerChanged(playerID)
				end
			end
		end
	end
end

function widget:Initialize()
	circleLinesCoop = calcCircleLines(circleDivsCoop)
	circleLinesAlly = calcCircleLines(circleDivsAlly)

	setPlayerColours()

	widget:PlayerChanged(myPlayerID)

	widgetHandler:RegisterGlobal('selectedUnitsRemove', selectedUnitsRemove)
	widgetHandler:RegisterGlobal('selectedUnitsClear', selectedUnitsClear)
	widgetHandler:RegisterGlobal('selectedUnitsAdd', selectedUnitsAdd)
	spec = spGetSpectatingState()

	WG['allyselectedunits'] = {}
	WG['allyselectedunits'].getOpacity = function()
		return maxAlpha
	end
	WG['allyselectedunits'].setOpacity = function(value)
		maxAlpha = value
	end
	WG['allyselectedunits'].getSelectPlayerUnits = function()
		return selectPlayerUnits
	end
	WG['allyselectedunits'].setSelectPlayerUnits = function(value)
		selectPlayerUnits = value
	end
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal('selectedUnitsRemove')
	widgetHandler:DeregisterGlobal('selectedUnitsClear')
	widgetHandler:DeregisterGlobal('selectedUnitsAdd')
	if circleLinesCoop ~= nil then
		gl.DeleteList(circleLinesCoop)
	end
	if circleLinesAlly ~= nil then
		gl.DeleteList(circleLinesAlly)
	end
end

local function DrawHotUnits()
	glDepthTest(false)
	glLineWidth( 2 )

	local toDelete = {}

	for unitID, val in pairs( hotUnits ) do
		if lockPlayerID == nil or val.playerID ~= lockPlayerID or (val.playerID == lockPlayerID and not selectPlayerUnits) then
			local x, y, z = spGetUnitBasePosition(unitID)
			local defRadius = val["defRadius"]
			local inView = false
			if z ~= nil then --checking z should be enough insteady of x,y,z
				inView = spIsSphereInView(x, y, z, defRadius)
			end
			if inView then
				local timeDiff = (os.clock() - val["ts"])

				if timeDiff <= hotFadeTime then
					if useHotColor then
						hotColor[4] = 1.0 - (timeDiff / hotFadeTime)
						glColor(hotColor)
					else
						local cl = playerColors[val["playerID"]]
						cl[4] = maxAlpha - maxAlpha * (timeDiff / hotFadeTime)
						glColor(cl)
					end
				else
					toDelete[unitID] = true
				end

				if toDelete[unitID] == nil then
					local lines = circleLinesAlly
					if val["coop"] == true and not spec then
						lines = circleLinesCoop
					end

					glPushMatrix()
					glTranslate(x,y,z)
					glScale(defRadius, 1, defRadius)
					glCallList(lines)
					glPopMatrix()
				end
			end
		end
	end

	for unitID, val in pairs(toDelete) do
		hotUnits[unitID] = nil
	end

	glDepthTest(false)
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

local function DrawSelectedUnits()
	glColor(0.0, 1.0, 0.0, 1.0)
	glLineWidth(2)
	gl.PointSize(1)
	local now = spGetGameSeconds()
	for playerID, selUnits in pairs(playerSelectedUnits) do
		if lockPlayerID == nil or lockPlayerID ~= playerID or (lockPlayerID == playerID and not selectPlayerUnits) then
			if selUnits.todraw and not playerIsSpec[playerID] then

				glColor(playerColors[playerID][1],  playerColors[playerID][2],  playerColors[playerID][3], maxAlpha)
				for unitID, defRadius in pairs(selUnits.units) do
					local x, y, z = spGetUnitBasePosition(unitID)
					if z and spIsSphereInView(x, y, z, defRadius) then
						if selUnits.coop == true and not spec then
							glDrawListAtUnit(unitID, circleLinesCoop, false, defRadius,defRadius,defRadius)
						else
							glDrawListAtUnit(unitID, circleLinesAlly, false, defRadius,defRadius,defRadius)
						end
					end
				end
			end
		end
	end

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

function widget:DrawWorldPreUnit()
	if spIsGUIHidden() then return end
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)      -- disable layer blending
	DrawSelectedUnits()
	DrawHotUnits()
end

function widget:GetConfigData()
    return {
		maxAlpha = maxAlpha,
        selectPlayerUnits = selectPlayerUnits,
        version = 1.1
    }
end

function widget:SetConfigData(data)
    if data.version ~= nil and data.version == 1.1 then
        maxAlpha = data.maxAlpha or maxAlpha
		if data.selectPlayerUnits ~= nil then
			selectPlayerUnits = data.selectPlayerUnits
		end
    end
end
