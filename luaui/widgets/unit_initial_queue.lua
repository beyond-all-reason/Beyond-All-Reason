
function widget:GetInfo()
	return {
		name      = "Initial Queue",
		desc      = "Allows you to queue buildings before game start",
		author    = "Niobium",
		version   = "1.3",
		date      = "7 April 2010",
		license   = "GNU GPL, v2 or later",
		layer     = -1, -- Puts it above minimap_startboxes with layer 0
		enabled   = true,
		handler   = true
	}
end

------------------------------------------------------------
-- Config
------------------------------------------------------------
-- Panel
local iconSize = 40
local borderSize = 1
local maxCols = 5
local fontSize = 16

-- Colors
local buildDistanceColor = {0.3, 1.0, 0.3, 0.7}
local buildLinesColor = {0.3, 1.0, 0.3, 0.7}
local borderNormalColor = {0.3, 1.0, 0.3, 0.5}
local borderClashColor = {0.7, 0.3, 0.3, 1.0}
local borderValidColor = {0.0, 1.0, 0.0, 1.0}
local borderInvalidColor = {1.0, 0.0, 0.0, 1.0}
local buildingQueuedAlpha = 0.5

local metalColor = '\255\196\196\255' -- Light blue
local energyColor = '\255\255\255\128' -- Light yellow
local buildColor = '\255\128\255\128' -- Light green
local whiteColor = '\255\255\255\255' -- White

------------------------------------------------------------
-- Globals
------------------------------------------------------------
local sDefID -- Starting unit def ID
local sDef -- UnitDefs[sDefID]

local selDefID = nil -- Currently selected def ID
local buildQueue = {}
local buildNameToID = {}

local wl, wt = 500, 300
local cellRows = {} -- {{bDefID, bDefID, ...}, ...}
local panelList = nil -- Display list for panel
local areDragging = false

local isMex = {} -- isMex[uDefID] = true / nil
local weaponRange = {} -- weaponRange[uDefID] = # / nil

local changeStartUnitRegex = '^\138(%d+)$'
local startUnitParamName = 'startUnit'

local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()

------------------------------------------------------------
-- Local functions
------------------------------------------------------------
local function TraceDefID(mx, my)
	local overRow = cellRows[1 + math.floor((wt - my) / (iconSize + borderSize))]
	if not overRow then return nil end
	return overRow[1 + math.floor((mx - wl) / (iconSize + borderSize))]
end
local function GetBuildingDimensions(uDefID, facing)
	local bDef = UnitDefs[uDefID]
	if (facing % 2 == 1) then
		return 4 * bDef.zsize, 4 * bDef.xsize
	else
		return 4 * bDef.xsize, 4 * bDef.zsize
	end
end
local function DrawBuilding(buildData, borderColor, buildingAlpha, drawRanges)

	local bDefID, bx, by, bz, facing = buildData[1], buildData[2], buildData[3], buildData[4], buildData[5]
	local bw, bh = GetBuildingDimensions(bDefID, facing)

	gl.DepthTest(false)
	gl.Color(borderColor)

	gl.Shape(GL.LINE_LOOP, {{v={bx - bw, by, bz - bh}},
							{v={bx + bw, by, bz - bh}},
							{v={bx + bw, by, bz + bh}},
							{v={bx - bw, by, bz + bh}}})

	if drawRanges then

		if isMex[bDefID] then
			gl.Color(1.0, 0.3, 0.3, 0.7)
			gl.DrawGroundCircle(bx, by, bz, Game.extractorRadius, 40)
		end

		local wRange = weaponRange[bDefID]
		if wRange then
			gl.Color(1.0, 0.3, 0.3, 0.7)
			gl.DrawGroundCircle(bx, by, bz, wRange, 40)
		end
	end

	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(true)
	if buildingAlpha == 1 then gl.Lighting(true) end
	gl.Color(1.0, 1.0, 1.0, buildingAlpha)

	gl.PushMatrix()
		gl.Translate(bx, by, bz)
		gl.Rotate(90 * facing, 0, 1, 0)
		gl.UnitShape(bDefID, Spring.GetMyTeamID())
	gl.PopMatrix()

	gl.Lighting(false)
	gl.DepthTest(false)
	gl.DepthMask(false)
end
local function DrawUnitDef(uDefID, uTeam, ux, uy, uz)

	gl.Color(1.0, 1.0, 1.0, 1.0)
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(true)
	gl.Lighting(true)

	gl.PushMatrix()
		gl.Translate(ux, uy, uz)
		gl.UnitShape(uDefID, uTeam)
	gl.PopMatrix()

	gl.Lighting(false)
	gl.DepthTest(false)
	gl.DepthMask(false)
end
local function DoBuildingsClash(buildData1, buildData2)

	local w1, h1 = GetBuildingDimensions(buildData1[1], buildData1[5])
	local w2, h2 = GetBuildingDimensions(buildData2[1], buildData2[5])

	return math.abs(buildData1[2] - buildData2[2]) < w1 + w2 and
	       math.abs(buildData1[4] - buildData2[4]) < h1 + h2
end
local function SetSelDefID(defID)

	selDefID = defID

	if (isMex[selDefID] ~= nil) ~= (Spring.GetMapDrawMode() == "metal") then
		Spring.SendCommands("ShowMetalMap")
	end
end
local function GetUnitCanCompleteQueue(uID)

	local uDefID = Spring.GetUnitDefID(uID)
	if uDefID == sDefID then
		return true
	end

	-- What can this unit build ?
	local uCanBuild = {}
	local uBuilds = UnitDefs[uDefID].buildOptions
	for i = 1, #uBuilds do
		uCanBuild[uBuilds[i]] = true
	end

	-- Can it build everything that was queued ?
	for i = 1, #buildQueue do
		if not uCanBuild[buildQueue[i][1]] then
			return false
		end
	end

	return true
end
local function GetQueueBuildTime()
	local t = 0
	for i = 1, #buildQueue do
		t = t + UnitDefs[buildQueue[i][1]].buildTime
	end
	return t / sDef.buildSpeed
end
local function GetQueueCosts()
	local mCost = 0
	local eCost = 0
	local bCost = 0
	for i = 1, #buildQueue do
		local uDef = UnitDefs[buildQueue[i][1]]
		mCost = mCost + uDef.metalCost
		eCost = eCost + uDef.energyCost
		bCost = bCost + uDef.buildTime
	end
	return mCost, eCost, bCost
end

------------------------------------------------------------
-- Initialize/shutdown
------------------------------------------------------------
function widget:Initialize()

	if (Game.startPosType == 1) or			-- Don't run if start positions are random
	   (Spring.GetGameFrame() > 0) or		-- Don't run if game has already started
	   (Spring.GetSpectatingState()) then	-- Don't run if we are a spec
		widgetHandler:RemoveWidget(self)
		return
	end
	-- Get our starting unit
	-- Sometimes the information is not available, so the widget will error and exit :)
	local _, _, _, _, mySide = Spring.GetTeamInfo(myTeamID)
	local startUnitName = Spring.GetSideData(mySide)
	sDefID = UnitDefNames[startUnitName].id
	InitializeFaction(sDefID)
	WG["faction_change"] = InitializeFaction
end

function InitializeFaction(sDefID)
	sDef = UnitDefs[sDefID]
	-- Don't run if theres nothing to show
	local sBuilds = sDef.buildOptions
	if not sBuilds or (#sBuilds == 0) then
		return
	end


	-- Set up cells
	local numCols = math.min(#sBuilds, maxCols)
	local numRows = math.ceil(#sBuilds / numCols)
	for r = 1, numRows do
		cellRows[r] = {}
	end
	for b = 0, #sBuilds - 1 do
		cellRows[1 + math.floor(b / numCols)][1 + b % numCols] = sBuilds[b + 1]
	end

	-- Set up drawing function
	local drawFunc = function()

		gl.PushMatrix()
			gl.Translate(0, borderSize, 0)

			for r = 1, #cellRows do
				local cellRow = cellRows[r]

				gl.Translate(0, -iconSize - borderSize, 0)
				gl.PushMatrix()

					for c = 1, #cellRow do

						gl.Color(0, 0, 0, 1)
						gl.Rect(-borderSize, -borderSize, iconSize + borderSize, iconSize + borderSize)

						gl.Color(1, 1, 1, 1)
						gl.Texture("#" .. cellRow[c])
							gl.TexRect(0, 0, iconSize, iconSize)
						gl.Texture(false)

						gl.Translate(iconSize + borderSize, 0, 0)
					end
				gl.PopMatrix()
			end

		gl.PopMatrix()
	end

	-- delete any pre-existing displaylist
	if panelList then
		gl.DeleteList(panelList)
	end

	panelList = gl.CreateList(drawFunc)

	for uDefID, uDef in pairs(UnitDefs) do

		if uDef.isMetalExtractor then
			isMex[uDefID] = true
		end

		if uDef.maxWeaponRange > 16 then
			weaponRange[uDefID] = uDef.maxWeaponRange
		end
	end
end

function widget:Shutdown()
	if panelList then
		gl.DeleteList(panelList)
	end
	WG["faction_change"] = nil
end

------------------------------------------------------------
-- Config
------------------------------------------------------------
function widget:GetConfigData()
	local wWidth, wHeight = Spring.GetWindowGeometry()
	return {wl / wWidth, wt / wHeight}
end
function widget:SetConfigData(data)
	local wWidth, wHeight = Spring.GetWindowGeometry()
	wl = math.floor(wWidth * (data[1] or 0.25))
	wt = math.floor(wHeight * (data[2] or 0.50))
end

------------------------------------------------------------
-- Drawing
------------------------------------------------------------
--local queueTimeFormat = whiteColor .. 'Queued: ' .. buildColor .. '%.1f sec ' .. whiteColor .. '[' .. metalColor .. '%d m' .. whiteColor .. ', ' .. energyColor .. '%d e' .. whiteColor .. ']'
local queueTimeFormat = whiteColor .. 'Queued ' .. metalColor .. '%dm ' .. energyColor .. '%de ' .. buildColor .. '%.1f sec'
--local queueTimeFormat = metalColor .. '%dm ' .. whiteColor .. '/ ' .. energyColor .. '%de ' .. whiteColor .. '/ ' .. buildColor .. '%.1f sec'


-- "Queued 23.9 seconds (820m / 2012e)" (I think this one is the best. Time first emphasises point and goodness of widget)
	-- Also, it is written like english and reads well, none of this colon stuff or figures stacked together



function widget:DrawScreen()
	gl.PushMatrix()
		gl.Translate(wl, wt, 0)
		gl.CallList(panelList)
		if #buildQueue > 0 then
			local mCost, eCost, bCost = GetQueueCosts()
			gl.Text(string.format(queueTimeFormat, mCost, eCost, bCost / sDef.buildSpeed), 0, 0, fontSize, 'do')
		end
	gl.PopMatrix()
end
function widget:DrawWorld()

	-- Set up gl
	gl.LineWidth(1.49)

	-- We need data about currently selected building, for drawing clashes etc
	local selBuildData
	if selDefID then
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if pos then
			local bx, by, bz = Spring.Pos2BuildPos(selDefID, pos[1], pos[2], pos[3])
			local buildFacing = Spring.GetBuildFacing()
			selBuildData = {selDefID, bx, by, bz, buildFacing}
		end
	end

	local myTeamID = Spring.GetMyTeamID()
	local sx, sy, sz = Spring.GetTeamStartPosition(myTeamID) -- Returns -100, -100, -100 when none chosen
	local startChosen = (sx ~= -100)
	if startChosen then

		-- Correction for start positions in the air
		sy = Spring.GetGroundHeight(sx, sz)

		-- Draw the starting unit at start position
		DrawUnitDef(sDefID, myTeamID, sx, sy, sz)

		-- Draw start units build radius
		gl.Color(buildDistanceColor)
		gl.DrawGroundCircle(sx, sy, sz, sDef.buildDistance, 40)
	end

	-- Draw all the buildings
	local queueLineVerts = startChosen and {{v={sx, sy, sz}}} or {}
	for b = 1, #buildQueue do
		local buildData = buildQueue[b]

		if selBuildData and DoBuildingsClash(selBuildData, buildData) then
			DrawBuilding(buildData, borderClashColor, buildingQueuedAlpha)
		else
			DrawBuilding(buildData, borderNormalColor, buildingQueuedAlpha)
		end

		queueLineVerts[#queueLineVerts + 1] = {v={buildData[2], buildData[3], buildData[4]}}
	end

	-- Draw queue lines
	gl.Color(buildLinesColor)
	gl.LineStipple("springdefault")
		gl.Shape(GL.LINE_STRIP, queueLineVerts)
	gl.LineStipple(false)

	-- Draw selected building
	if selBuildData then
		if Spring.TestBuildOrder(selDefID, selBuildData[2], selBuildData[3], selBuildData[4], selBuildData[5]) ~= 0 then
			DrawBuilding(selBuildData, borderValidColor, 1.0, true)
		else
			DrawBuilding(selBuildData, borderInvalidColor, 1.0, true)
		end
	end

	-- Reset gl
	gl.Color(1.0, 1.0, 1.0, 1.0)
	gl.LineWidth(1.0)
end

------------------------------------------------------------
-- Game start
------------------------------------------------------------
function widget:GameFrame(n)

	-- Don't run if we are a spec
	local areSpec = Spring.GetSpectatingState()
	if areSpec then
		widgetHandler:RemoveWidget(self)
		return
	end

	-- Don't run if we didn't queue anything
	if (#buildQueue == 0) then
		widgetHandler:RemoveWidget(self)
		return
	end

	if (n < 2) then return end -- Give the unit frames 0 and 1 to spawn
	if (n > 10) then
		--Spring.Echo("> Starting unit never spawned !")
		widgetHandler:RemoveWidget(self)
		return
	end

	-- Search for our starting unit
	local units = Spring.GetTeamUnits(Spring.GetMyTeamID())
	for u = 1, #units do
		local uID = units[u]
		if GetUnitCanCompleteQueue(uID) then --Spring.GetUnitDefID(uID) == sDefID then
			Spring.Echo("sending queue to unit")
			for b = 1, #buildQueue do
				local buildData = buildQueue[b]
				Spring.GiveOrderToUnit(uID, -buildData[1], {buildData[2], buildData[3], buildData[4], buildData[5]}, {"shift"})
			end

			widgetHandler:RemoveWidget(self)
			return
		end
	end
end

------------------------------------------------------------
-- Mouse
------------------------------------------------------------
function widget:IsAbove(mx, my)
	return TraceDefID(mx, my)
end
local tooltipFormat = 'Build %s\n%s\n' .. metalColor .. '%d m ' .. whiteColor .. '/ ' .. energyColor .. '%d e ' .. whiteColor .. '/ ' .. buildColor .. '%.1f sec'
function widget:GetTooltip(mx, my)
	local bDefID = TraceDefID(mx, my)
	local bDef = UnitDefs[bDefID]
	return string.format(tooltipFormat, bDef.humanName, bDef.tooltip, bDef.metalCost, bDef.energyCost, bDef.buildTime / sDef.buildSpeed)
end
function widget:MousePress(mx, my, mButton)

	local tracedDefID = TraceDefID(mx, my)
	if tracedDefID then
		if mButton == 1 then
			SetSelDefID(tracedDefID)
			return true
		elseif mButton == 3 then
			areDragging = true
			return true
		end
	else
		if selDefID then
			if mButton == 1 then

				local mx, my = Spring.GetMouseState()
				local _, pos = Spring.TraceScreenRay(mx, my, true)
				if not pos then return end
				local bx, by, bz = Spring.Pos2BuildPos(selDefID, pos[1], pos[2], pos[3])
				local buildFacing = Spring.GetBuildFacing()

				if Spring.TestBuildOrder(selDefID, bx, by, bz, buildFacing) ~= 0 then

					local buildData = {selDefID, bx, by, bz, buildFacing}
					local _, _, meta, shift = Spring.GetModKeyState()
					if meta then
						table.insert(buildQueue, 1, buildData)

					elseif shift then

						local anyClashes = false
						for i = #buildQueue, 1, -1 do
							if DoBuildingsClash(buildData, buildQueue[i]) then
								anyClashes = true
								table.remove(buildQueue, i)
							end
						end

						if not anyClashes then
							buildQueue[#buildQueue + 1] = buildData
						end
					else
						buildQueue = {buildData}
					end

					if not shift then
						SetSelDefID(nil)
					end
				end

				return true

			elseif mButton == 3 then

				SetSelDefID(nil)
				return true
			end
		end
	end
end
function widget:MouseMove(mx, my, dx, dy, mButton)
	if areDragging then
		wl = wl + dx
		wt = wt + dy
	end
end
function widget:MouseRelease(mx, my, mButton)
	areDragging = false
end

------------------------------------------------------------
-- Misc
------------------------------------------------------------
function widget:TextCommand(cmd)

	-- Facing commands are only handled by spring if we have a building selected, which isn't possible pre-game
	local m = cmd:match("^buildfacing (.+)$")
	if m then

		local oldFacing = Spring.GetBuildFacing()
		local newFacing
		if (m == "inc") then
			newFacing = (oldFacing + 1) % 4
		elseif (m == "dec") then
			newFacing = (oldFacing + 3) % 4
		else
			return false
		end

		Spring.SetBuildFacing(newFacing)
		Spring.Echo("Buildings set to face " .. ({"South", "East", "North", "West"})[1 + newFacing])
		return true
	end

	local buildName = cmd:match("^buildunit_([^%s]+)$")
	if buildName then
		local bDefID = buildNameToID[buildName]
		if bDefID then
			SetSelDefID(bDefID)
			return true
		end
	end
end
