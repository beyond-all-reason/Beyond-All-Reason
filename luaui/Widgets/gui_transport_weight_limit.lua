local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "gui_transport_weight_limit",
		desc = "When pressing Load command, it highlights units the transport can lift",
		author = "nixtux ( + made fancy by Floris)",
		date = "Apr 24, 2015",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local circlePieces = 3
local circlePieceDetail = 14
local circleSpaceUsage = 0.8
local circleInnerOffset = 0
local rotationSpeed = 8

-- size
local innersize = 1.85 -- outersize-innersize = circle width
local outersize = 2.02 -- outersize-innersize = circle width

local alphaFalloffdistance = 750
local maxAlpha = 0.55

local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local unitstodraw = {}
local transID = nil
local transDefID = nil

local validTrans = {}
local math_sqrt = math.sqrt

local transDefs = {}
local cantBeTransported = {}
local unitMass = {}
local unitXsize = {}

local circleList, chobbyInterface

for defID, def in pairs(UnitDefs) do
	if def.transportSize and def.transportSize > 0 then
		validTrans[defID] = true
		transDefs[defID] = { def.transportMass, def.transportCapacity, def.transportSize }
	end
	unitMass[defID] = def.mass
	unitXsize[defID] = def.xsize
	cantBeTransported[defID] = def.cantBeTransported
end

local function DrawCircleLine(innersize, outersize)
	gl.BeginEnd(GL.QUADS, function()
		local detailPartWidth, a1, a2, a3, a4
		local width = circleSpaceUsage
		local detail = circlePieceDetail

		local radstep = (2.0 * math.pi) / circlePieces
		for i = 1, circlePieces do
			for d = 1, detail do
				detailPartWidth = ((width / detail) * d)
				a1 = ((i + detailPartWidth - (width / detail)) * radstep)
				a2 = ((i + detailPartWidth) * radstep)
				a3 = ((i + circleInnerOffset + detailPartWidth - (width / detail)) * radstep)
				a4 = ((i + circleInnerOffset + detailPartWidth) * radstep)

				--outer (fadein)
				gl.Vertex(math.sin(a4) * innersize, 0, math.cos(a4) * innersize)
				gl.Vertex(math.sin(a3) * innersize, 0, math.cos(a3) * innersize)
				--outer (fadeout)
				gl.Vertex(math.sin(a1) * outersize, 0, math.cos(a1) * outersize)
				gl.Vertex(math.sin(a2) * outersize, 0, math.cos(a2) * outersize)
			end
		end
	end)
end

function widget:Initialize()
	circleList = gl.CreateList(DrawCircleLine, innersize, outersize)
end

function widget:Shutdown()
	gl.DeleteList(circleList)
end

local selectedUnits = Spring.GetSelectedUnits()
local selectedUnitsCount = Spring.GetSelectedUnitsCount()
function widget:SelectionChanged(sel)
	unitstodraw = {}

	selectedUnits = sel
	selectedUnitsCount = Spring.GetSelectedUnitsCount()

	local unitcount = 0

	if selectedUnitsCount < 1 or selectedUnitsCount > 20 then
		return
	end

	if selectedUnitsCount == 1 then
		local defID = Spring.GetUnitDefID(selectedUnits[1])
		if validTrans[defID] then
			transID = selectedUnits[1]
			transDefID = defID

			return
		end
	elseif selectedUnitsCount > 1 then
		for i = 1, #selectedUnits do
			local unitID = selectedUnits[i]
			local unitDefID = Spring.GetUnitDefID(unitID)
			if validTrans[unitDefID] then
				transID = unitID
				transDefID = unitDefID
				unitcount = unitcount + 1
				if unitcount > 1 then
					transID = nil
					transDefID = nil
					return
				end
			end
		end
	else
		transID = nil
		transDefID = nil
		return
	end
end

function widget:GameFrame(n)
	if not transID then
		return
	end

	if select(2, Spring.GetActiveCommand()) ~= CMD_LOAD_UNITS then
		if next(unitstodraw) then
			unitstodraw = {}
		end

		return
	end

	unitstodraw = {}

	local transDef = transDefs[transDefID]

	local transMassLimit = transDef[1]
	local transCapacity = transDef[2]
	local transportSize = transDef[3]

	local visibleUnits = Spring.GetVisibleUnits()

	if not visibleUnits or not next(visibleUnits) then
		return
	end

	local isinTrans = Spring.GetUnitIsTransporting(transID)

	if isinTrans and #isinTrans >= transCapacity then
		return
	end

	for _, unitID in ipairs(visibleUnits) do
		local visableID = Spring.GetUnitDefID(unitID)

		if transID and transID ~= visableID then
			local passengerX = unitXsize[visableID] / 2
			if
				unitMass[visableID] <= transMassLimit
				and passengerX <= transportSize
				and not cantBeTransported[visableID]
				and not Spring.IsUnitIcon(unitID)
			then
				local x, y, z = Spring.GetUnitBasePosition(unitID)
				if x then
					unitstodraw[unitID] = { pos = { x, y, z }, size = (passengerX * 6) }
				end
			end
		end
	end
end

local cursorGround = { 0, 0, 0 }

function widget:Update()
	if not next(unitstodraw) then
		return
	end

	local mx, my = Spring.GetMouseState()
	local _, coords = Spring.TraceScreenRay(mx, my, true)

	if type(coords) == "table" then
		cursorGround = coords
	end
end

local previousOsClock = os.clock()
local currentRotationAngle = 0
local currentRotationAngleOpposite = 0
function widget:RecvLuaMsg(msg)
	if msg:sub(1, 18) == "LobbyOverlayActive" then
		chobbyInterface = (msg:sub(1, 19) == "LobbyOverlayActive1")
	end
end

function widget:DrawWorldPreUnit()
	if chobbyInterface then
		return
	end

	if not next(unitstodraw) then
		return
	end

	-- animate rotation
	if rotationSpeed > 0 then
		local clockDifference = (os.clock() - previousOsClock)
		previousOsClock = os.clock()

		local angleDifference = rotationSpeed * (clockDifference * 5)
		currentRotationAngle = currentRotationAngle + (angleDifference * 0.66)
		if currentRotationAngle > 360 then
			currentRotationAngle = currentRotationAngle - 360
		end

		currentRotationAngleOpposite = currentRotationAngleOpposite - angleDifference
		if currentRotationAngleOpposite < -360 then
			currentRotationAngleOpposite = currentRotationAngleOpposite + 360
		end
	end

	local alpha = 1
	for unitID, opts in pairs(unitstodraw) do
		local pos = opts.pos
		local xDiff = cursorGround[1] - pos[1]
		local zDiff = cursorGround[3] - pos[3]
		alpha = 1 - math_sqrt(xDiff * xDiff + zDiff * zDiff) / alphaFalloffdistance
		if alpha > maxAlpha then
			alpha = maxAlpha
		end
		if alpha > 0.04 then
			local size = opts.size
			gl.Color(0, 0.8, 0, alpha * 0.55)
			gl.DrawListAtUnit(unitID, circleList, false, size, 1.0, size, currentRotationAngle, 0, 1, 0)
			gl.Color(0, 0.8, 0, alpha)
			gl.DrawListAtUnit(unitID, circleList, false, size * 1.18, 1.0, size * 1.18, -currentRotationAngle, 0, 1, 0)
		end
	end

	gl.Color(1, 1, 1, 1)
	gl.LineWidth(1)
end
