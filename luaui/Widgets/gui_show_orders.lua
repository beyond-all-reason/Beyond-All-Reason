local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Show Orders",
		desc = "Hold shift+meta to show allied units orders",
		author = "Niobium",
		date = "date",
		version = 1.3,
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-----------------------------------------------------
-- Config
-----------------------------------------------------
local iconSize = 190
local cellGap = 6
local maxColumns = 4
local maxRows = 2
local maxCells = maxColumns * maxRows
local fontSize = 66
local iconZoom = 0.04

-- factory queues are re-read every N draw frames while shown
local updateInterval = 10

local enableDistanceScaling = true
local minScaleDistance = 300 -- icons start shrinking beyond this camera distance
local maxScaleDistance = 3000 -- icons are at minScale beyond this camera distance
local minScaleDistanceSq = minScaleDistance * minScaleDistance
local maxScaleDistanceSq = maxScaleDistance * maxScaleDistance
local minScale = 0.3
local maxScale = 0.6

local repeatTexture = ":l:LuaUI/Images/repeat.png"
local progressColor = { 1, 1, 1, 0.22 }
local idleString = "IDLE"

-----------------------------------------------------
-- Speedup
-----------------------------------------------------
local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local sqrt = math.sqrt

local spGetViewGeometry = Spring.GetViewGeometry
local spGetModKeyState = Spring.GetModKeyState
local spDrawUnitCommands = Spring.DrawUnitCommands
local spGetFactoryCounts = Spring.GetFactoryCounts
local spGetFactoryCommandCount = Spring.GetFactoryCommandCount
local spGetSpecState = Spring.GetSpectatingState
local spGetMyAllyTeamID = Spring.GetLocalAllyTeamID
local spGetTeamInfo = Spring.GetTeamInfo
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitPosition = Spring.GetUnitPosition
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitStates = Spring.GetUnitStates
local spGetCameraPosition = Spring.GetCameraPosition

local glColor = gl.Color
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glBlending = gl.Blending
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glScale = gl.Scale

local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

-----------------------------------------------------
-- Globals
-----------------------------------------------------
local vsx, vsy = spGetViewGeometry()
local font, chobbyInterface
local UiUnit ---@type function
local RectRoundProgress ---@type function
local isActive = false
local frameCounter = 0
local dataDirty = true

local gaiaTeamID = Spring.GetGaiaTeamID()
local fullView, myAllyTeamID
local teamAllyTeam = {} ---@type table<number, number?>

local isFactory = {}
local isMobileFactory = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isFactory then
		isFactory[unitDefID] = true
		isMobileFactory[unitDefID] = not unitDef.isImmobile
	end
end

-- unitID -> true, handed to DrawUnitCommands as a map
local shownUnits = {}

local factories = {} ---@type table<integer, table>
local factoryByUnit = {} ---@type table<number, table>

-- grid layout in pixels relative to the grid's top left corner, scaled by camera distance when drawn
local tileSize, tileCorner, scaledFontSize = 0, 0, 0
local cellX = {} ---@type table<integer, number>
local cellY = {} ---@type table<integer, number>
local textX = {} ---@type table<integer, number>
local textY = {} ---@type table<integer, number>
local gridWidth = {} ---@type table<integer, number>
local gridHeight = {} ---@type table<integer, number>
local repeatX1, repeatY1, repeatX2, repeatY2 = 0, 0, 0, 0

local percentStrings = {}
for i = 0, 100 do
	percentStrings[i] = i .. "%"
end

local numberStrings = {}
for i = 1, 999 do
	numberStrings[i] = tostring(i)
end

local unitTextures = {}
local function getUnitTexture(unitDefID)
	local texture = unitTextures[unitDefID]
	if not texture then
		texture = "#" .. unitDefID
		unitTextures[unitDefID] = texture
	end
	return texture
end

-----------------------------------------------------
-- Code
-----------------------------------------------------

local function GetDistanceScale(unitX, unitY, unitZ, camX, camY, camZ)
	local dx = unitX - camX
	local dy = unitY - camY
	local dz = unitZ - camZ
	local distanceSq = dx * dx + dy * dy + dz * dz

	if distanceSq <= minScaleDistanceSq then
		return maxScale
	elseif distanceSq >= maxScaleDistanceSq then
		return minScale
	end
	local t = (sqrt(distanceSq) - minScaleDistance) / (maxScaleDistance - minScaleDistance)
	return maxScale - (t * (maxScale - minScale))
end

local function invalidateFactoryLists()
	for i = 1, #factories do
		factories[i].listDirty = true
	end
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	local widgetScale = vsy / 2000
	font = WG.fonts.getFont(2)
	UiUnit = WG.FlowUI.Draw.Unit
	RectRoundProgress = WG.FlowUI.Draw.RectRoundProgress

	tileSize = floor(iconSize * widgetScale + 0.5)
	tileCorner = max(1, floor(tileSize * 0.024))
	scaledFontSize = fontSize * widgetScale
	local gap = max(1, floor(cellGap * widgetScale + 0.5))
	local pitch = tileSize + gap
	for i = 1, maxCells do
		local x = ((i - 1) % maxColumns) * pitch
		local y = -floor((i - 1) / maxColumns) * pitch
		cellX[i], cellY[i] = x, y
		textX[i] = x + tileSize * 0.1
		textY[i] = y - tileSize * 0.9
		gridWidth[i] = min(i, maxColumns) * pitch - gap
		gridHeight[i] = min(ceil(i / maxColumns), maxRows) * pitch - gap
	end

	local repeatSize = floor(tileSize * 0.3)
	local repeatInset = floor(tileSize * 0.05)
	repeatX2, repeatY2 = tileSize - repeatInset, -repeatInset
	repeatX1, repeatY1 = repeatX2 - repeatSize, repeatY2 - repeatSize

	invalidateFactoryLists()
end

local function addFactory(unitID, unitDefID)
	if factoryByUnit[unitID] then
		return
	end
	local fac = {
		unitID = unitID,
		unitDefID = unitDefID,
		mobile = isMobileFactory[unitDefID],
		defs = {},
		texts = {},
		n = 0,
		isRepeat = false,
		listDirty = true,
	}
	factories[#factories + 1] = fac
	fac.index = #factories
	factoryByUnit[unitID] = fac
	dataDirty = true
end

local function removeFactory(unitID)
	local fac = factoryByUnit[unitID]
	if fac.list then
		glDeleteList(fac.list)
	end
	local last = factories[#factories]
	factories[fac.index] = last
	last.index = fac.index
	factories[#factories] = nil
	factoryByUnit[unitID] = nil
end

local function isShownTeam(teamID)
	if teamID == gaiaTeamID then
		return false
	end
	if fullView then
		return true
	end
	local allyTeamID = teamAllyTeam[teamID]
	if not allyTeamID then
		allyTeamID = select(6, spGetTeamInfo(teamID, false))
		teamAllyTeam[teamID] = allyTeamID
	end
	return allyTeamID == myAllyTeamID
end

local function addUnit(unitID, unitDefID, unitTeam)
	if isShownTeam(unitTeam) then
		shownUnits[unitID] = true
		if isFactory[unitDefID] then
			addFactory(unitID, unitDefID)
		end
	end
end

local function rebuildUnits(visibleUnits)
	shownUnits = {}
	for i = #factories, 1, -1 do
		removeFactory(factories[i].unitID)
	end
	local visibleUnitsTeam = WG.unittrackerapi.visibleUnitsTeam
	for unitID, unitDefID in pairs(visibleUnits) do
		addUnit(unitID, unitDefID, visibleUnitsTeam[unitID] or spGetUnitTeam(unitID))
	end
end

-- returns true when the set of shown teams changed
local function updateViewState()
	local _, newFullView = spGetSpecState()
	local allyTeamID = spGetMyAllyTeamID()
	local changed = newFullView ~= fullView or (not newFullView and allyTeamID ~= myAllyTeamID)
	fullView, myAllyTeamID = newFullView, allyTeamID
	return changed
end

function widget:Initialize()
	widget:ViewResize()
	updateViewState()
	if WG.unittrackerapi and WG.unittrackerapi.visibleUnits then
		rebuildUnits(WG.unittrackerapi.visibleUnits)
	end
end

function widget:Shutdown()
	for i = 1, #factories do
		if factories[i].list then
			glDeleteList(factories[i].list)
		end
	end
end

function widget:VisibleUnitsChanged(visibleUnits)
	updateViewState()
	rebuildUnits(visibleUnits)
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	addUnit(unitID, unitDefID, unitTeam)
end

function widget:VisibleUnitRemoved(unitID)
	shownUnits[unitID] = nil
	if factoryByUnit[unitID] then
		removeFactory(unitID)
	end
end

function widget:PlayerChanged()
	if updateViewState() and WG.unittrackerapi then
		rebuildUnits(WG.unittrackerapi.visibleUnits)
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == "LobbyOverlayActive" then
		chobbyInterface = (msg:sub(1, 19) == "LobbyOverlayActive1")
	end
end

-- polled here rather than in DrawScreen, which the engine skips while the GUI is hidden
function widget:DrawWorld()
	local active = false
	if not chobbyInterface then
		local _, _, meta, shift = spGetModKeyState()
		active = meta and shift
	end
	if active and not isActive then
		dataDirty = true
	end
	isActive = active
	if active then
		spDrawUnitCommands(shownUnits, true)
	end
end

local function setCell(fac, i, unitDefID, text)
	if fac.defs[i] ~= unitDefID then
		fac.defs[i] = unitDefID
		fac.listDirty = true
	end
	fac.texts[i] = text
end

-- reads the factory queues, a factory's display list is only rebuilt when its tiles changed
local function UpdateFactories()
	if UiUnit ~= WG.FlowUI.Draw.Unit then
		-- FlowUI was reloaded: our lists call display lists it deleted
		UiUnit = WG.FlowUI.Draw.Unit
		RectRoundProgress = WG.FlowUI.Draw.RectRoundProgress
		invalidateFactoryLists()
	end

	for i = 1, #factories do
		local fac = factories[i]
		local unitID = fac.unitID
		local isBuilding, progress = spGetUnitIsBeingBuilt(unitID)
		local n = 0
		local progressPercent = nil ---@type integer?
		if isBuilding then
			progressPercent = floor(progress * 100)
			n = 1
			setCell(fac, 1, fac.unitDefID, percentStrings[progressPercent])
		elseif isBuilding == false and (spGetFactoryCommandCount(unitID) or 0) == 0 then
			n = 1
			setCell(fac, 1, fac.unitDefID, idleString)
		end

		-- the engine stops one entry short of the requested count
		local counts = isBuilding ~= nil and spGetFactoryCounts(unitID, maxCells + 1)
		if counts then
			for c = 1, counts.n do
				if n >= maxCells then
					break
				end
				local entry = counts[c]
				if entry then
					local unitDefID, count = next(entry)
					if unitDefID and count then
						n = n + 1
						setCell(fac, n, unitDefID, numberStrings[count] or tostring(count))
					end
				end
			end
		end

		if n ~= fac.n then
			for c = n + 1, fac.n do
				fac.defs[c] = nil
				fac.texts[c] = nil
			end
			fac.n = n
			fac.listDirty = true
		end

		if n > 0 then
			local _, _, _, isRepeat = spGetUnitStates(unitID, false, true)
			isRepeat = isRepeat == true
			if isRepeat ~= fac.isRepeat or progressPercent ~= fac.progress then
				fac.isRepeat = isRepeat
				fac.progress = progressPercent
				fac.listDirty = true
			end
			if not fac.mobile and not fac.x then
				fac.x, fac.y, fac.z = spGetUnitPosition(unitID)
			end
		end
	end
end

local function DrawFactoryTiles(fac)
	local defs = fac.defs
	for i = 1, fac.n do
		local x, y = cellX[i], cellY[i]
		glColor(1, 1, 1, 1)
		UiUnit(x, y - tileSize, x + tileSize, y, nil, 1, 1, 1, 1, iconZoom, nil, nil, getUnitTexture(defs[i]))
	end
	if fac.progress then
		glBlending(GL_SRC_ALPHA, GL_ONE)
		RectRoundProgress(0, -tileSize, tileSize, 0, tileCorner, fac.progress / 100, progressColor)
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end
	if fac.isRepeat then
		glColor(1, 1, 1, 0.85)
		glTexture(repeatTexture)
		glTexRect(repeatX1, repeatY1, repeatX2, repeatY2)
		glTexture(false)
	end
	glColor(1, 1, 1, 1)
end

function widget:DrawScreen()
	if not isActive then
		return
	end

	frameCounter = frameCounter + 1
	if dataDirty or frameCounter >= updateInterval then
		frameCounter = 0
		dataDirty = false
		UpdateFactories()
	end

	local camX, camY, camZ
	if enableDistanceScaling then
		camX, camY, camZ = spGetCameraPosition()
	end

	local fontStarted = false
	for i = 1, #factories do
		local fac = factories[i]
		local n = fac.n
		if n > 0 then
			local ux, uy, uz
			if fac.mobile then
				ux, uy, uz = spGetUnitPosition(fac.unitID)
			else
				ux, uy, uz = fac.x, fac.y, fac.z
			end
			if ux then
				local sx, sy = spWorldToScreenCoords(ux, uy, uz)
				local scale = camX and GetDistanceScale(ux, uy, uz, camX, camY, camZ) or maxScale
				if sx <= vsx and sy >= 0 and sx + gridWidth[n] * scale >= 0 and sy - gridHeight[n] * scale <= vsy then
					if fac.listDirty then
						if fac.list then
							glDeleteList(fac.list)
						end
						fac.list = glCreateList(DrawFactoryTiles, fac)
						fac.listDirty = false
					end
					glPushMatrix()
					glTranslate(sx, sy, 0)
					glScale(scale, scale, 1)
					glCallList(fac.list)
					glPopMatrix()

					-- glyphs are drawn at font:End(), on top of every tile
					if not fontStarted then
						fontStarted = true
						font:Begin()
						font:SetOutlineColor(0, 0, 0, 1)
						font:SetTextColor(0.9, 0.9, 0.9, 1)
					end
					local size = scaledFontSize * scale
					local texts = fac.texts
					for c = 1, n do
						font:Print(texts[c], sx + textX[c] * scale, sy + textY[c] * scale, size, "ob")
					end
				end
			end
		end
	end
	if fontStarted then
		font:End()
	end
end
