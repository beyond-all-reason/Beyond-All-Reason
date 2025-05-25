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
		enabled = true
	}
end

local textSize = 16

------------------------------------------------
-- speedups
------------------------------------------------

local GetActiveCommand = Spring.GetActiveCommand
local GetMouseState = Spring.GetMouseState
local TraceScreenRay = Spring.TraceScreenRay
local GetGroundInfo = Spring.GetGroundInfo
local GetGameFrame = Spring.GetGameFrame
local GetMapDrawMode = Spring.GetMapDrawMode

local glColor = gl.Color
local glRect = gl.Rect
local glPolygonMode = gl.PolygonMode


local GL_FRONT_AND_BACK = GL.FRONT_AND_BACK
local GL_FILL = GL.FILL

local floor = math.floor
local min, max = math.min, math.max
local sqrt = math.sqrt
local strFind = string.find
local strFormat = string.format

------------------------------------------------
-- vars
------------------------------------------------

local vsx, vsy = Spring.GetViewGeometry()
--unitDefID = {extractsMetal, extractSquare, oddX, oddZ}
local mexDefInfos = {}
local defaultDefID

local centerX, centerZ
local extraction = 0
local lastUnitDefID

local TEXT_CORRECT_Y = 1.25

local metalMap = false
local METAL_MAP_SQUARE_SIZE = 16
local MEX_RADIUS = Game.extractorRadius
local MAP_SIZE_X = Game.mapSizeX
local MAP_SIZE_X_SCALED = MAP_SIZE_X / METAL_MAP_SQUARE_SIZE
local MAP_SIZE_Z = Game.mapSizeZ
local MAP_SIZE_Z_SCALED = MAP_SIZE_Z / METAL_MAP_SQUARE_SIZE

local once, font, forceUpdate

------------------------------------------------
-- helpers
------------------------------------------------

local function DrawTextWithBackground(text, x, y, size, opt)
	local width = (font:GetTextWidth(text) * size) + 8
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)

	glColor(0.25, 0.25, 0.25, 0.75)
	if opt then
		if strFind(opt, "r") then
			glRect(x, y, x - width, y + size * TEXT_CORRECT_Y)
		elseif strFind(opt, "c") then
			glRect(x + width * 0.5, y, x - width * 0.5, y + size * TEXT_CORRECT_Y)
		else
			glRect(x, y, x + width, y + size * TEXT_CORRECT_Y)
		end
	else
		glRect(x, y, x + width, y + size * TEXT_CORRECT_Y)
	end

	font:Begin()
	font:SetOutlineColor(0,0,0, 0.5)
	font:SetTextColor(1, 1, 1, 0.85)
	font:Print(text, x + 4, y, size, opt)
	font:End()
end

local function SetupMexDefInfos()
	local minExtractsMetal

	local armMexDef = UnitDefNames["armmex"]

	if armMexDef and armMexDef.extractsMetal > 0 then
		defaultDefID = UnitDefNames["armmex"].id
		minExtractsMetal = 0
	end

	for unitDefID = 1, #UnitDefs do
		local unitDef = UnitDefs[unitDefID]
		local extractsMetal = unitDef.extractsMetal
		if extractsMetal > 0 then
			mexDefInfos[unitDefID] = {}
			mexDefInfos[unitDefID][1] = extractsMetal
			--mexDefInfos[unitDefID][2] = unitDef.extractSquare --removed because deprecated from unitdefs; so mexDefInfos[UnitDefID][x] is defined only for only x=1,3,4.
			if unitDef.xsize % 4 == 2 then
				mexDefInfos[unitDefID][3] = true
			end
			if unitDef.zsize % 4 == 2 then
				mexDefInfos[unitDefID][4] = true
			end
			if not minExtractsMetal or extractsMetal < minExtractsMetal then
				defaultDefID = unitDefID
				minExtractsMetal = extractsMetal
			end
		end
	end

end

local function IntegrateMetal(mexDefInfo, x, z, forceUpdate)
	local newCenterX, newCenterZ
	if mexDefInfo[3] then
		newCenterX = (floor(x / METAL_MAP_SQUARE_SIZE) + 0.5) * METAL_MAP_SQUARE_SIZE
	else
		newCenterX = floor(x / METAL_MAP_SQUARE_SIZE + 0.5) * METAL_MAP_SQUARE_SIZE
	end

	if mexDefInfo[4] then
		newCenterZ = (floor(z / METAL_MAP_SQUARE_SIZE) + 0.5) * METAL_MAP_SQUARE_SIZE
	else
		newCenterZ = floor(z / METAL_MAP_SQUARE_SIZE + 0.5) * METAL_MAP_SQUARE_SIZE
	end

	if centerX == newCenterX and centerZ == newCenterZ and not forceUpdate then
		return
	end

	centerX = newCenterX
	centerZ = newCenterZ

	local startX = floor((centerX - MEX_RADIUS) / METAL_MAP_SQUARE_SIZE)
	local startZ = floor((centerZ - MEX_RADIUS) / METAL_MAP_SQUARE_SIZE)
	local endX = floor((centerX + MEX_RADIUS) / METAL_MAP_SQUARE_SIZE)
	local endZ = floor((centerZ + MEX_RADIUS) / METAL_MAP_SQUARE_SIZE)
	startX, startZ = max(startX, 0), max(startZ, 0)
	endX, endZ = min(endX, MAP_SIZE_X_SCALED - 1), min(endZ, MAP_SIZE_Z_SCALED - 1)

	local mult = mexDefInfo[1]
	local result = 0

	for i = startX, endX do
		for j = startZ, endZ do
			local cx, cz = (i + 0.5) * METAL_MAP_SQUARE_SIZE, (j + 0.5) * METAL_MAP_SQUARE_SIZE
			local dx, dz = cx - centerX, cz - centerZ
			local dist = sqrt(dx * dx + dz * dz)

			if dist < MEX_RADIUS then
				local _, metal, metal2 = GetGroundInfo(cx, cz)
				if type(metal) == 'string' then
					-- Spring > v104
					metal = metal2
				end
				result = result + metal
			end
		end
	end

	extraction = result * mult
end

------------------------------------------------
--callins
------------------------------------------------

function widget:Initialize()
	SetupMexDefInfos()
	once = true
	metalMap = WG["resource_spot_finder"].isMetalMap
end


function widget:DrawScreen()
	if once then
		widget:ViewResize()
		once = false
	end

	local mexDefInfo

	if GetGameFrame() < 1 then
		local drawMode = GetMapDrawMode()
		if drawMode == "metal" then
			mexDefInfo = mexDefInfos[defaultDefID]
		end
	else
		local _, cmd_id = GetActiveCommand()
		if not cmd_id then
			return
		end
		local unitDefID = -cmd_id
		forceUpdate = false
		if unitDefID ~= lastUnitDefID then
			forceUpdate = true
		end
		lastUnitDefID = unitDefID
		mexDefInfo = mexDefInfos[unitDefID]
	end

	if not mexDefInfo then
		return
	end

	local mx, my = GetMouseState()
	local _, coords = TraceScreenRay(mx, my, true, true)

	if not coords then
		return
	end
	if not metalMap then
		local pos = WG["resource_spot_finder"].GetClosestMexSpot(coords[1], coords[3])
		if not pos then return end
		coords[1] = pos.x
		coords[3] = pos.z
	end
	IntegrateMetal(mexDefInfo, coords[1], coords[3], forceUpdate)
	DrawTextWithBackground(Spring.I18N('ui.prospector.metalExtraction', { amount = strFormat("%.2f", extraction) }), mx, my, textSize, "do")
	glColor(1, 1, 1, 1)
end

function widget:ViewResize()
	font = WG['fonts'].getFont(1, 1.6)
end
