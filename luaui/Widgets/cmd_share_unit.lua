function widget:GetInfo()
	return {
		name = "Share Unit Command",
		desc = "Adds a command which allows you to quickly share unit to other player. Just target the command on any allied unit and you will share to this player",
		author = "SuperKitowiec",
		date = "2024",
		license = "GNU GPL, v2 or later",
		version = 3.3,
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

local function tablelength(T)
	local count = 0
	for _ in pairs(T) do
		count = count + 1
	end
	return count
end

local CMD_SHARE_UNIT_TO_TARGET = 455624
local CMD_SHARE_UNIT_TO_TARGET_DEFINITION = {
	id = CMD_SHARE_UNIT_TO_TARGET,
	type = CMDTYPE.ICON_UNIT_OR_MAP,
	name = 'Share Unit To Target',
	cursor = 'settarget',
	action = 'quicksharetotarget',
}

local myTeamID = GetMyTeamID()
local myAllyTeamID = GetTeamAllyTeamID(myTeamID)

local function GetSecondPart(offset)
	local result = secondPart + (offset or 0)
	return result - floor(result)
end

local function UnitCircleVertices()
	for i = 1, circleDivs do
		local theta = 2 * PI * i / circleDivs
		glVertex(cos(theta), 0, sin(theta))
	end
end

local function DrawUnitCircle()
	glBeginEnd(GL_LINE_LOOP, UnitCircleVertices)
end

local function SetupDisplayLists()
	circleList = glCreateList(DrawUnitCircle)
end

local function DeleteDisplayLists()
	glDeleteList(circleList)
end

local function DrawCircle(x, y, z, radius)
	glPushMatrix()
	glTranslate(x, y, z)
	glScale(radius, radius, radius)

	glCallList(circleList)

	glPopMatrix()
end

local function GetMouseTargetPosition()
	local mx, my = GetMouseState()
	local mouseTargetType, mouseTarget = TraceScreenRay(mx, my)
	if mouseTarget and mouseTargetType then
		if mouseTargetType == "ground" then
			return mouseTarget[1], mouseTarget[2], mouseTarget[3]
		elseif mouseTargetType == "unit" then
			local _, coordinates = TraceScreenRay(mx, my, true)
			return coordinates[1], coordinates[2], coordinates[3], mouseTarget
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

local function GetMouseDistance()
	local cx, cy, cz = GetCameraPosition()
	local mx, my, mz = GetMouseTargetPosition()
	if not mz then
		return nil
	end
	local dx = cx - mx
	local dy = cy - my
	local dz = cz - mz
	return sqrt(dx * dx + dy * dy + dz * dz)
end

local function GetTeamColorWithAlpha(teamId)
	local tred, tgreen, tblue = GetTeamColor(teamId)
	return { tred, tgreen, tblue, 1 }
end

local function DrawAoE(tx, ty, tz, selectedTeam)
	local color = selectedTeam and GetTeamColorWithAlpha(selectedTeam) or defaultColor

	mouseDistance = GetMouseDistance() or 1000
	glLineWidth(max(aoeLineWidthMult * range / mouseDistance, 0.5))

	for i = 1, numAoECircles do
		local proportion = i / (numAoECircles + 1)
		local radius = range * proportion
		local alpha = color[4] * (1 - proportion) / (1 - proportion) * (1 - GetSecondPart(0))
		glColor(color[1], color[2], color[3], alpha)
		DrawCircle(tx, ty, tz, radius)
	end

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

local function FindPlayerName(teamId)
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

local function DrawName(teamId)
	local mouseX, mouseY = GetMouseState()
	local textY = mouseY + 40
	local color = defaultColor

	if teamId then
		color = GetTeamColorWithAlpha(teamId)
		font:Begin()
		font:SetTextColor(GetTeamColorWithAlpha(teamId))
		font:SetOutlineColor({0,0,0,1})
		font:Print(I18N("ui.quicksharetotarget.shareTo"), mouseX, textY+30, 24, "con")
		font:Print(FindPlayerName(teamId), mouseX, textY, 24, "con")
		font:End()
	else
		font:Begin()
		font:SetTextColor(defaultColor)
		font:SetOutlineColor({0,0,0,1})
		font:Print(I18N("ui.quicksharetotarget.noTarget"), mouseX, textY, 24, "con")
		font:End()
	end

end

local function IsAlly(unitTeamId)
	return unitTeamId ~= myTeamID and GetTeamAllyTeamID(unitTeamId) == myAllyTeamID
end

local function FindTeamInArea(mx, my)
	local _, cUnitID = TraceScreenRay(mx, my, true)

	if cUnitID == nil then
		return nil
	end

	local foundUnits = GetUnitsInCylinder(cUnitID[1], cUnitID[3], range)

	if #foundUnits < 1 then
		return nil
	end

	local unitTeamCounters = {}

	for _, unitId in ipairs(foundUnits) do
		local unitTeamId = GetUnitTeam(unitId)
		if IsAlly(unitTeamId) then
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

local function GetSelectedTeam()
	local _, cmd, _ = GetActiveCommand()

	if cmd ~= CMD_SHARE_UNIT_TO_TARGET then
		return nil
	end

	local tx, ty, tz, targetUnitID = GetMouseTargetPosition()

	if (not tx) then
		return nil
	end

	local selectedTeam
	if targetUnitID then
		local targetUnitTeamID = GetUnitTeam(targetUnitID)
		if IsAlly(targetUnitTeamID) then
			selectedTeam = targetUnitTeamID
		end
	else
		local mouseX, mouseY = WorldToScreenCoords(tx, ty, tz)
		selectedTeam = FindTeamInArea(mouseX, mouseY)
	end

	return tx, ty, tz, selectedTeam
end

function widget:DrawWorld()
	local targetX, targetY, targetZ, selectedTeam = GetSelectedTeam()

	if (not targetX) then
		return
	end

	DrawAoE(targetX, targetY, targetZ, selectedTeam)
end

function widget:DrawScreen()
	local targetX, _, _, selectedTeam = GetSelectedTeam()

	if (not targetX) then
		return
	end

	DrawName(selectedTeam)
end

function widget:CommandNotify(cmdID, cmdParams, _)
	if cmdID == CMD_SHARE_UNIT_TO_TARGET then
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
			targetTeamID = FindTeamInArea(mouseX, mouseY)
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
		customCommands[#customCommands + 1] = CMD_SHARE_UNIT_TO_TARGET_DEFINITION
	end
end

function widget:Initialize()
	defaultColor = { 0.88, 0.88, 0.88, 1}
	SetupDisplayLists()
end

function widget:Shutdown()
	DeleteDisplayLists()
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
end
