local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Share Unit Command",
		desc = "Adds a command which allows you to quickly share unit to other player. Just target the command on any allied unit and you will share to this player",
		author = "SuperKitowiec",
		date = "2024",
		license = "GNU GPL, v2 or later",
		version = 1.0,
		layer = 0,
		enabled = true,
		handler = true,
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

--------------------------------------------------------------------------------
--speedups
--------------------------------------------------------------------------------
local GetUnitsInCylinder = Spring.GetUnitsInCylinder
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitTeam = Spring.GetUnitTeam
local GetSelectedUnits = Spring.GetSelectedUnits
local GetTeamAllyTeamID = Spring.GetTeamAllyTeamID
local ShareResources = Spring.ShareResources
local I18N = Spring.I18N
local GetSpectatingState = Spring.GetSpectatingState
local WorldToScreenCoords = Spring.WorldToScreenCoords
local PlaySoundFile = Spring.PlaySoundFile
local GetTeamColor = Spring.GetTeamColor
local GetActiveCommand = Spring.GetActiveCommand
local GetCameraPosition = Spring.GetCameraPosition
local GetMouseState = Spring.GetMouseState
local TraceScreenRay = Spring.TraceScreenRay
local GetPlayerList = Spring.GetPlayerList
local GetPlayerInfo = Spring.GetPlayerInfo
local GetGameRulesParam = Spring.GetGameRulesParam
local GetViewGeometry = Spring.GetViewGeometry

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
local GL_LINE_LOOP = GL.LINE_LOOP

local PI = math.pi
local cos = math.cos
local sin = math.sin
local floor = math.floor
local sqrt = math.sqrt
local max = math.max

local defaultColor

local vsx, vsy = GetViewGeometry()
local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local fontfileSize = 50
local fontfileOutlineSize = 8.5
local fontfileOutlineStrength = 10
local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)

local cmdQuickShareToTargetId = 455624
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
	local name = ''
	if GetGameRulesParam('ainame_' .. teamId) then
		name = I18N('ui.playersList.aiName', { name = GetGameRulesParam('ainame_' .. teamId) })
	else
		local players = GetPlayerList(teamId)
		name = (#players > 0) and GetPlayerInfo(players[1], false) or '------'

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
	return Spring.Utilities.Color.ToString(nameColourR, nameColourG, nameColourB)
end

local function drawName(teamId)
	local mouseX, mouseY = GetMouseState()
	local textY = mouseY + 40

	if teamId then
		font:Begin()
		font:SetTextColor(defaultColor)
		font:SetOutlineColor({ 0, 0, 0, 1 })
		font:Print(I18N("ui.quickShareToTarget.shareTo", {
			playerColor = colourNames(teamId),
			player = findPlayerName(teamId)
		}), mouseX, textY, 24, "con")
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

	if (not tx and not targetUnitID) then
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

function widget:DrawWorld()
	local targetX, targetY, targetZ, selectedTeam = getSelectedTeam()

	if (not targetX) then
		return
	end

	drawAoE(targetX, targetY+10, targetZ, selectedTeam)
end

function widget:DrawScreen()
	local targetX, _, _, selectedTeam = getSelectedTeam()

	if (not targetX) then
		return
	end

	drawName(selectedTeam)
end

function widget:CommandNotify(cmdID, cmdParams, _)
	if cmdID == cmdQuickShareToTargetId then
		local targetTeamID
		if #cmdParams ~= 1 and #cmdParams ~= 3 then
			return true
		elseif #cmdParams == 1 then
			-- click on unit
			local targetUnitID = cmdParams[1]
			targetTeamID = GetUnitTeam(targetUnitID)
		elseif #cmdParams == 3 then
			-- click on the ground
			local mouseX, mouseY = WorldToScreenCoords(cmdParams[1], cmdParams[2], cmdParams[3])
			targetTeamID = findTeamInArea(mouseX, mouseY)
		end

		if targetTeamID == nil or targetTeamID == myTeamID or GetTeamAllyTeamID(targetTeamID) ~= myAllyTeamID then
			-- invalid target, don't do anything
			return true
		end

		ShareResources(targetTeamID, "units")
		PlaySoundFile("beep4", 1, 'ui')
		return false
	end
end

function widget:CommandsChanged()
	if GetSpectatingState() then
		return
	end

	local selectedUnits = GetSelectedUnits()
	if #selectedUnits > 0 then
		local customCommands = widgetHandler.customCommands
		customCommands[#customCommands + 1] = {
			id = cmdQuickShareToTargetId,
			type = CMDTYPE.ICON_UNIT_OR_MAP,
			name = 'Share Unit To Target',
			cursor = 'settarget',
			action = 'quicksharetotarget',
		}
	end
end

function widget:Initialize()
	defaultColor = { 0.88, 0.88, 0.88, 1 }
	setupDisplayLists()
end

function widget:Shutdown()
	deleteDisplayLists()
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
	if fontfileScale ~= newFontfileScale then
		fontfileScale = newFontfileScale
		font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
	end
end
