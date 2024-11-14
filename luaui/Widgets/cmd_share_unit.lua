function widget:GetInfo()
	return {
		name = "Share Unit Command",
		desc = "Adds a command which allows you to quickly share unit to other player. Just target the command on any allied unit and you will share to this player",
		author = "SuperKitowiec",
		date = "2024",
		license = "GNU GPL, v2 or later",
		version = 3.2,
		layer = 0,
		enabled = true,
		handler = true,
	}
end

--------------------------------------------------------------------------------
--vars
--------------------------------------------------------------------------------
local aoeColor = { 0.7, 0.7, 0.7, 1 }
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
local GetUnitPosition = Spring.GetUnitPosition
local TraceScreenRay = Spring.TraceScreenRay

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
	action = 'quick_share_to_target',
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

local function DrawAoE(tx, ty, tz, color)
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

local function IsAlly(unitTeamId)
	return unitTeamId ~= myTeamID and GetTeamAllyTeamID(unitTeamId) == myAllyTeamID
end

local function FindTeam(mx, my)
	local _, cUnitID = TraceScreenRay(mx, my, true)
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

function widget:DrawWorld()
	local _, cmd, _ = GetActiveCommand()

	if cmd ~= CMD_SHARE_UNIT_TO_TARGET then
		return
	end

	local tx, ty, tz, targetUnitID = GetMouseTargetPosition()

	if (not tx) then
		return
	end

	mouseDistance = GetMouseDistance() or 1000
	local selectedTeam
	if targetUnitID then
		local targetUnitTeamID = GetUnitTeam(targetUnitID)
		if IsAlly(targetUnitTeamID) then
			selectedTeam = targetUnitTeamID
		end
	else
		local mouseX, mouseY = WorldToScreenCoords(tx, ty, tz)
		selectedTeam = FindTeam(mouseX, mouseY)
	end

	local selectedColor = aoeColor
	if selectedTeam then
		local tred, tgreen, tblue = GetTeamColor(selectedTeam)
		selectedColor = { tred, tgreen, tblue, 1 }
	end
	DrawAoE(tx, ty, tz, selectedColor)
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
			targetTeamID = FindTeam(mouseX, mouseY)
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
	SetupDisplayLists()
	I18N.load({
		en = {
			["ui.orderMenu.quick_share_to_target"] = "Share Unit",
			["ui.orderMenu.quick_share_to_target_tooltip"] = "Share unit to target player.",
		}
	})
end

function widget:Shutdown()
	DeleteDisplayLists()
end
