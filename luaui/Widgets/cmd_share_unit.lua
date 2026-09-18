local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Share Unit Command",
		desc = "Draws the target preview for the Share Unit command (see luarules/gadgets/cmd_share_unit.lua). Target the command on any allied unit to share to its owning player.",
		author = "SuperKitowiec",
		date = "2024",
		license = "GNU GPL, v2 or later",
		version = 1.0,
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--vars
--------------------------------------------------------------------------------
local aoeLineWidthMult = 100
local circleDivs = 96
local numAoECircles = 5
local circleList
local secondPart = 0
local mouseDistance = 1000
local range = 200

-- queued share orders are drawn here in the target team's color, the engine line is hidden
local queueLineWidth = 1.49
local queueLineAlpha = 0.5
local queueRefreshInterval = 0.1
local queueRefreshTimer = queueRefreshInterval
local shareQueues = {} -- unitID -> command queue, for selected units that have a share order queued

--------------------------------------------------------------------------------
--speedups
--------------------------------------------------------------------------------
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local GetMyTeamID = Spring.GetLocalTeamID
local GetUnitTeam = Spring.GetUnitTeam
local GetTeamAllyTeamID = Spring.GetTeamAllyTeamID
local I18N = BAR.I18N
local WorldToScreenCoords = Spring.WorldToScreenCoords
local GetTeamColor = Spring.GetTeamColor
local GetActiveCommand = Spring.GetActiveCommand
local GetCameraPosition = Spring.GetCameraPosition
local GetMouseState = Spring.GetMouseState
local TraceScreenRay = Spring.TraceScreenRay
local GetPlayerList = Spring.GetPlayerList
local GetPlayerInfo = Spring.GetPlayerInfo
local GetGameRulesParam = Spring.GetGameRulesParam
local GetSelectedUnits = Spring.GetSelectedUnits
local GetUnitCommands = Spring.GetUnitCommands
local GetUnitPosition = Spring.GetUnitPosition
local GetFeaturePosition = Spring.GetFeaturePosition
local ValidUnitID = Spring.ValidUnitID
local IsGUIHidden = Spring.IsGUIHidden
local SetCustomCommandDrawData = Spring.SetCustomCommandDrawData
local maxUnits = Game.maxUnits

local glBeginEnd = gl.BeginEnd
local glCallList = gl.CallList
local glCreateList = gl.CreateList
local glColor = gl.Color
local glDeleteList = gl.DeleteList
local glLineWidth = gl.LineWidth
local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glScale = gl.Scale
local glTranslate = gl.Translate
local glVertex = gl.Vertex
local glLineStipple = gl.LineStipple
local glDepthTest = gl.DepthTest
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_LINES = GL.LINES

local PI = math.pi
local cos = math.cos
local sin = math.sin
local floor = math.floor
local sqrt = math.sqrt
local max = math.max

local defaultColor

local cmdQuickShareToTargetId = GameCMD.SHARE_UNIT
local myTeamID = GetMyTeamID()
local myAllyTeamID = GetTeamAllyTeamID(myTeamID)

local function tablelength(T)
	local count = 0
	for _ in pairs(T) do
		count = count + 1
	end
	return count
end

local function getSecondPart(offset)
	local result = secondPart + (offset or 0)
	return result - floor(result)
end

local function unitCircleVertices()
	for i = 1, circleDivs do
		local theta = 2 * PI * i / circleDivs
		glVertex(cos(theta), 0, sin(theta))
	end
end

local function drawUnitCircle()
	glBeginEnd(GL_LINE_LOOP, unitCircleVertices)
end

local function setupDisplayLists()
	circleList = glCreateList(drawUnitCircle)
end

local function deleteDisplayLists()
	glDeleteList(circleList)
end

local function drawCircle(x, y, z, radius)
	glPushMatrix()
	glTranslate(x, y, z)
	glScale(radius, radius, radius)

	glCallList(circleList)

	glPopMatrix()
end

local function getMouseTargetPosition()
	local mx, my = GetMouseState()
	local mouseTargetType, mouseTarget = TraceScreenRay(mx, my)
	if mouseTarget and mouseTargetType then
		if mouseTargetType == "ground" then
			return mouseTarget[1], mouseTarget[2], mouseTarget[3]
		elseif mouseTargetType == "unit" then
			local _, coordinates = TraceScreenRay(mx, my, true)
			if coordinates then
				return coordinates[1], coordinates[2], coordinates[3], mouseTarget
			else
				return nil, nil, nil, mouseTarget
			end
		elseif mouseTargetType == "feature" then
			local _, coordinates = TraceScreenRay(mx, my, true)
			if coordinates then
				return coordinates[1], coordinates[2], coordinates[3]
			end
		else
			return nil
		end
	else
		return nil
	end
end

local function getMouseDistance()
	local cx, cy, cz = GetCameraPosition()
	local mx, my, mz = getMouseTargetPosition()
	if not mz then
		return nil
	end
	local dx = cx - mx
	local dy = cy - my
	local dz = cz - mz
	return sqrt(dx * dx + dy * dy + dz * dz)
end

local function getTeamColorWithAlpha(teamId)
	local tred, tgreen, tblue = GetTeamColor(teamId)
	return { tred, tgreen, tblue, 1 }
end

local function drawAoE(tx, ty, tz, selectedTeam)
	--local color = selectedTeam and getTeamColorWithAlpha(selectedTeam) or defaultColor
	local color = defaultColor

	mouseDistance = getMouseDistance() or 1000
	glLineWidth(max(aoeLineWidthMult * range / mouseDistance, 0.5))

	for i = 1, numAoECircles do
		local proportion = i / (numAoECircles + 1)
		local radius = range * proportion
		local alpha = color[4] * (1 - proportion) / (1 - proportion) * (1 - getSecondPart(0))
		glColor(color[1], color[2], color[3], alpha)
		drawCircle(tx, ty, tz, radius)
	end

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

local function findPlayerName(teamId)
	local name = ""
	if GetGameRulesParam("ainame_" .. teamId) then
		name = I18N("ui.playersList.aiName", { name = GetGameRulesParam("ainame_" .. teamId) })
	else
		local players = GetPlayerList(teamId)
		name = (#players > 0) and GetPlayerInfo(players[1], false) or "------"

		for _, pID in ipairs(players) do
			local pname, active, isspec = GetPlayerInfo(pID, false)
			if active and not isspec then
				name = pname
				break
			end
		end
	end
	return name
end

local function colourNames(teamId)
	if tonumber(teamId) < 0 then
		return ""
	end
	local nameColourR, nameColourG, nameColourB, nameColourA = Spring.GetTeamColor(teamId)
	return BAR.Utilities.Color.ToString(nameColourR, nameColourG, nameColourB)
end

local function drawName(teamId)
	local mouseX, mouseY = GetMouseState()
	local textY = mouseY + 40

	if teamId then
		font:Begin()
		font:SetTextColor(defaultColor)
		font:SetOutlineColor({ 0, 0, 0, 1 })
		font:Print(
			I18N("ui.quickShareToTarget.shareTo", {
				playerColor = colourNames(teamId),
				player = findPlayerName(teamId),
			}),
			mouseX,
			textY,
			24,
			"con"
		)
		font:End()
	else
		font:Begin()
		font:SetTextColor(defaultColor)
		font:SetOutlineColor({ 0, 0, 0, 1 })
		font:Print(I18N("ui.quickShareToTarget.noTarget"), mouseX, textY, 24, "con")
		font:End()
	end
end

local function isAlly(unitTeamId)
	return unitTeamId ~= myTeamID and GetTeamAllyTeamID(unitTeamId) == myAllyTeamID
end

local function findTeamInArea(mx, my)
	local _, cUnitID = TraceScreenRay(mx, my, true)

	if cUnitID == nil then
		return nil
	end

	local foundUnits = GetUnitsInCylinder(cUnitID[1], cUnitID[3], range, -3)

	if #foundUnits < 1 then
		return nil
	end

	local unitTeamCounters = {}

	for _, unitId in ipairs(foundUnits) do
		local unitTeamId = GetUnitTeam(unitId)
		if unitTeamId ~= myTeamID then
			unitTeamId = tostring(unitTeamId)
			if unitTeamCounters[unitTeamId] == nil then
				unitTeamCounters[unitTeamId] = 1
			else
				unitTeamCounters[unitTeamId] = unitTeamCounters[unitTeamId] + 1
			end
		end
	end

	if tablelength(unitTeamCounters) < 1 then
		return nil
	end

	local selectedTeam
	for unitTeamId, count in pairs(unitTeamCounters) do
		if selectedTeam == nil then
			selectedTeam = unitTeamId
		elseif count > unitTeamCounters[selectedTeam] then
			selectedTeam = unitTeamId
		end
	end
	return selectedTeam
end

local function getSelectedTeam()
	local _, cmd, _ = GetActiveCommand()

	if cmd ~= cmdQuickShareToTargetId then
		return nil
	end

	local tx, ty, tz, targetUnitID = getMouseTargetPosition()

	if not tx and not targetUnitID then
		return nil
	end

	local selectedTeam
	if targetUnitID then
		local targetUnitTeamID = GetUnitTeam(targetUnitID)
		if isAlly(targetUnitTeamID) then
			selectedTeam = targetUnitTeamID
		end
	else
		local mouseX, mouseY = WorldToScreenCoords(tx, ty, tz)
		selectedTeam = findTeamInArea(mouseX, mouseY)
	end

	return tx, ty, tz, selectedTeam
end

-- position the engine's queue line passes through for a command, nil if it has none
local function getCommandPosition(cmd)
	local params = cmd.params
	local paramCount = #params
	if paramCount >= 3 then
		return params[1], params[2], params[3]
	elseif paramCount == 1 then
		local targetID = params[1]
		if targetID >= maxUnits then
			return GetFeaturePosition(floor(targetID - maxUnits))
		elseif ValidUnitID(targetID) then
			return GetUnitPosition(targetID)
		end
	end
end

local function refreshShareQueues()
	for unitID in pairs(shareQueues) do
		shareQueues[unitID] = nil
	end
	local selectedUnits = GetSelectedUnits()
	for i = 1, #selectedUnits do
		local unitID = selectedUnits[i]
		-- for factories this is the queue given to the units they build
		local commands = GetUnitCommands(unitID, -1)
		for j = 1, #commands do
			if commands[j].id == cmdQuickShareToTargetId then
				shareQueues[unitID] = commands
				break
			end
		end
	end
end

local function lineVertices(x1, y1, z1, x2, y2, z2)
	glVertex(x1, y1, z1)
	glVertex(x2, y2, z2)
end

local function drawShareQueueLines()
	glDepthTest(false)
	glLineWidth(queueLineWidth)
	glLineStipple("springdefault") -- the engine's animated queue line dashes
	for unitID, commands in pairs(shareQueues) do
		local px, py, pz = GetUnitPosition(unitID)
		for i = 1, #commands do
			local cmd = commands[i]
			local x, y, z = getCommandPosition(cmd)
			if x then
				local targetTeamID = cmd.params[4]
				if cmd.id == cmdQuickShareToTargetId and targetTeamID and px then
					local r, g, b = GetTeamColor(targetTeamID)
					glColor(r or 1, g or 1, b or 1, queueLineAlpha)
					glBeginEnd(GL_LINES, lineVertices, px, py, pz, x, y, z)
				end
				px, py, pz = x, y, z
			end
		end
	end
	glLineStipple(false)
	glColor(1, 1, 1, 1)
	glLineWidth(1)
	glDepthTest(true)
end

function widget:Update(dt)
	queueRefreshTimer = queueRefreshTimer + dt
	if queueRefreshTimer >= queueRefreshInterval then
		queueRefreshTimer = 0
		refreshShareQueues()
	end
end

function widget:DrawWorld()
	if next(shareQueues) and not IsGUIHidden() then
		drawShareQueueLines()
	end

	local targetX, targetY, targetZ, selectedTeam = getSelectedTeam()

	if not targetX then
		return
	end

	drawAoE(targetX, targetY + 10, targetZ, selectedTeam)
end

function widget:DrawScreen()
	local targetX, _, _, selectedTeam = getSelectedTeam()

	if not targetX then
		return
	end

	drawName(selectedTeam)
end

function widget:ViewResize(vsx, vsy)
	font = WG.fonts.getFont(2, 1.5)
end

function widget:Initialize()
	widget:ViewResize()
	defaultColor = { 0.88, 0.88, 0.88, 1 }
	setupDisplayLists()
	-- keep the engine's queue icon but hide its line, drawShareQueueLines draws it in team color
	SetCustomCommandDrawData(cmdQuickShareToTargetId, "settarget", { 1, 1, 1, 0 }, false)
end

function widget:Shutdown()
	deleteDisplayLists()
	-- back to the default set in luarules/gadgets/cmd_share_unit.lua
	SetCustomCommandDrawData(cmdQuickShareToTargetId, "settarget", { 0.88, 0.88, 0.88, 0.8 }, false)
end
