-----------------------------------------------
-- Displays the precise extraction value for metal extractors no matter where they are placed
-- Most maps have in-world text displaying the spot value, but that shows the same value regardless of
-- a mexes actual metal extraction amount (e.g. t2 is higher)
-- On metal maps, there is no spot value at all, so this is required to see how much mexes will produce
-----------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Prospector",
		desc = "Tooltip for amount of metal extracted when placing mexes.",
		author = "Evil4Zerggin",
		date = "9 January 2009",
		license = "GNU LGPL, v2.1 or later",
		layer = 1010,
		enabled = true,
	}
end

local textSize = 16

------------------------------------------------
-- speedups
------------------------------------------------

local GetActiveCommand = Spring.GetActiveCommand
local GetMouseState = Spring.GetMouseState
local TraceScreenRay = Spring.TraceScreenRay
local GetMetalAmount = Spring.GetMetalAmount
local GetGameFrame = Spring.GetGameFrame
local GetMapDrawMode = Spring.GetMapDrawMode

local glColor = gl.Color
local glRect = gl.Rect
local glPolygonMode = gl.PolygonMode
local glCreateList = gl.CreateList
local glDeleteList = gl.DeleteList
local glCallList = gl.CallList
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate

local GL_FRONT_AND_BACK = GL.FRONT_AND_BACK
local GL_FILL = GL.FILL

local floor, ceil = math.floor, math.ceil
local min, max = math.min, math.max
local sqrt = math.sqrt
local strFormat = string.format

------------------------------------------------
-- vars
------------------------------------------------

--unitDefID = {extractsMetal, roundX, roundZ, rows}
local mexDefInfos = {}
local defaultMexDefInfo
local activeMexDefInfo

local TEXT_CORRECT_Y = 1.25

local metalMap = false
local METAL_MAP_SQUARE_SIZE = 16
local MEX_RADIUS = Game.extractorRadius
local MAX_SQUARE_X = Game.mapSizeX / METAL_MAP_SQUARE_SIZE - 1
local MAX_SQUARE_Z = Game.mapSizeZ / METAL_MAP_SQUARE_SIZE - 1

local font ---@type LuaFont
local pregame = true
local drawing = true

-- metal summed over the last mask position
local metalSum = 0 ---@type number
local sumRows, sumX, sumZ
local extraction = 0 ---@type number

-- last traced ground position, and whether a value could be shown there
local lastX, lastZ, lastMexDefInfo, hasValue

local labelList ---@type integer?
local labelExtraction ---@type number?
local labelAmount ---@type string?

------------------------------------------------
-- helpers
------------------------------------------------

-- Metal squares within MEX_RADIUS of a mex centered on a square (odd footprint) or a square corner (even),
-- as flat {di, djMin, djMax} rows, di ascending
local maskRows = {} ---@type table<integer, integer[]?>

local function GetMaskRows(oddX, oddZ)
	local key = (oddX and 1 or 0) + (oddZ and 2 or 0)
	local cached = maskRows[key]
	if cached then
		return cached
	end
	local offsetX = oddX and 0 or 0.5
	local offsetZ = oddZ and 0 or 0.5
	local reach = ceil(MEX_RADIUS / METAL_MAP_SQUARE_SIZE) + 1
	local rows = {} ---@type integer[]
	for di = -reach, reach do
		local dx = (di + offsetX) * METAL_MAP_SQUARE_SIZE
		local djMin, djMax
		for dj = -reach, reach do
			local dz = (dj + offsetZ) * METAL_MAP_SQUARE_SIZE
			if sqrt(dx * dx + dz * dz) < MEX_RADIUS then
				djMin = djMin or dj
				djMax = dj
			end
		end
		if djMin then
			rows[#rows + 1] = di
			rows[#rows + 1] = djMin
			rows[#rows + 1] = djMax
		end
	end
	maskRows[key] = rows
	return rows
end

local function SetupMexDefInfos()
	local minExtractsMetal
	local defaultDefID

	local armMexDef = UnitDefNames.armmex

	if armMexDef and armMexDef.extractsMetal > 0 then
		defaultDefID = UnitDefNames.armmex.id
		minExtractsMetal = 0
	end

	for unitDefID = 1, #UnitDefs do
		local unitDef = UnitDefs[unitDefID]
		local extractsMetal = unitDef.extractsMetal
		if extractsMetal > 0 then
			local oddX = unitDef.xsize % 4 == 2
			local oddZ = unitDef.zsize % 4 == 2
			mexDefInfos[unitDefID] = { extractsMetal, oddX and 0 or 0.5, oddZ and 0 or 0.5, GetMaskRows(oddX, oddZ) }
			if not minExtractsMetal or extractsMetal < minExtractsMetal then
				defaultDefID = unitDefID
				minExtractsMetal = extractsMetal
			end
		end
	end

	defaultMexDefInfo = defaultDefID and mexDefInfos[defaultDefID]
end

local function IntegrateMetal(mexDefInfo, x, z)
	local squareX = floor(x / METAL_MAP_SQUARE_SIZE + mexDefInfo[2])
	local squareZ = floor(z / METAL_MAP_SQUARE_SIZE + mexDefInfo[3])

	local rows = mexDefInfo[4]
	if rows ~= sumRows or squareX ~= sumX or squareZ ~= sumZ then
		sumRows, sumX, sumZ = rows, squareX, squareZ
		local result = 0 ---@type number
		for k = 1, #rows, 3 do
			local i = squareX + rows[k]
			if i >= 0 and i <= MAX_SQUARE_X then
				for j = max(squareZ + rows[k + 1], 0), min(squareZ + rows[k + 2], MAX_SQUARE_Z) do
					result = result + GetMetalAmount(i, j)
				end
			end
		end
		metalSum = result
	end

	extraction = metalSum * mexDefInfo[1]
end

local function DeleteLabel()
	if labelList then
		glDeleteList(labelList)
		labelList = nil
	end
	labelAmount = nil
end

local function UpdateLabel()
	labelExtraction = extraction
	local amount = strFormat("%.2f", extraction)
	if labelList and amount == labelAmount then
		return
	end
	DeleteLabel()
	labelAmount = amount

	local text = BAR.I18N("ui.prospector.metalExtraction", { amount = amount })
	local width = (font:GetTextWidth(text) * textSize) + 8
	labelList = glCreateList(function()
		glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
		glColor(0.25, 0.25, 0.25, 0.75)
		glRect(0, 0, width, textSize * TEXT_CORRECT_Y)

		font:Begin()
		font:SetOutlineColor(0, 0, 0, 0.5)
		font:SetTextColor(1, 1, 1, 0.85)
		font:Print(text, 4, 0, textSize, "do")
		font:End()
		glColor(1, 1, 1, 1)
	end)
end

-- DrawScreen runs all pregame (metal view), then only while a mex is being placed
local function UpdateDrawing()
	local active = pregame or activeMexDefInfo ~= nil
	if active == drawing then
		return
	end
	drawing = active
	if active then
		widgetHandler:UpdateCallIn("DrawScreen")
	else
		widgetHandler:RemoveCallIn("DrawScreen")
	end
end

------------------------------------------------
--callins
------------------------------------------------

function widget:Initialize()
	SetupMexDefInfos()
	metalMap = WG.resource_spot_finder.isMetalMap
	widget:ViewResize()
	pregame = GetGameFrame() < 1
	local _, cmdID = GetActiveCommand()
	widget:ActiveCommandChanged(cmdID)
end

function widget:Shutdown()
	DeleteLabel()
end

function widget:ActiveCommandChanged(cmdID)
	activeMexDefInfo = cmdID and mexDefInfos[-cmdID]
	UpdateDrawing()
end

function widget:DrawScreen()
	local mexDefInfo = activeMexDefInfo

	if pregame then
		if GetGameFrame() < 1 then
			mexDefInfo = GetMapDrawMode() == "metal" and defaultMexDefInfo or nil
		else
			pregame = false
			UpdateDrawing()
		end
	end

	if not mexDefInfo then
		return
	end

	local mx, my = GetMouseState()
	local _, coords = TraceScreenRay(mx, my, true, true)

	if not coords then
		return
	end

	local x, z = coords[1], coords[3]
	if x ~= lastX or z ~= lastZ or mexDefInfo ~= lastMexDefInfo then
		lastX, lastZ, lastMexDefInfo = x, z, mexDefInfo
		hasValue = true
		if not metalMap then
			local pos = WG.resource_spot_finder.GetClosestMexSpot(x, z)
			if pos then
				x, z = pos.x, pos.z
			else
				hasValue = false
			end
		end
		if hasValue then
			IntegrateMetal(mexDefInfo, x, z)
		end
	end

	if not hasValue then
		return
	end

	if not labelList or extraction ~= labelExtraction then
		UpdateLabel()
	end

	glPushMatrix()
	glTranslate(mx, my, 0)
	glCallList(labelList)
	glPopMatrix()
end

function widget:ViewResize()
	font = WG.fonts.getFont(1, 1.5)
	DeleteLabel()
end

function widget:LanguageChanged()
	DeleteLabel()
end
