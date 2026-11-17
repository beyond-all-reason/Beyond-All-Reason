local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Metalspots",
		desc = "Displays rotating circles around metal spots",
		author = "Floris, Beherith GL4",
		date = "October 2019",
		license = "GNU GPL v2",
		layer = 2,
		enabled = true,
	}
end

-- Localized functions for performance
local mathCeil = math.ceil
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathSin = math.sin
local mathCos = math.cos
local mathRound = math.round
local stringFormat = string.format
local stringFind = string.find

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spGetMyTeamID = Spring.GetLocalTeamID
local spEcho = Spring.Echo
local spGetSpectatingState = Spring.GetSpectatingState

--2023.05.21 TODO list
-- Add occupied circle to center
-- Add text billboard vertices at end (exploit vertex index)
-- Add a vertex type field to indicate outer circle, inner circle, billboard
-- Add UV coordinates field to instances
-- Add options to control the display of all of these.
-- Add income multiplier gating for individual players (well that's a doozy!)
-- GL4 stuff
-- Notes:
-- 1. Could a prerendered texture be better at conveying metal spot value?
-- 2. VertexVBO contains: x, y pos, rotdir and radians in angle?
-- 3. InstanceVBO contains:
--x,y,z offsets, radius,
-- visibility, and gameframe num of the last change teamid of occupier?
-- 2023.05.12
-- Add atlas text to all this
-- Add a cyan circle to visible spots anyway
-- Fix height changing on noox
-- totally nuke the fucking F4 view, its terrible!
-- move font init into initialize instead of load
-- untie from os.clock that's stupid too

if Spring.GetModOptions().unit_restrictions_noextractorDefs then
	return
end

local showValue = false
local metalViewOnly = false
local lavaWaterLevel = nil

local circleSpaceUsage = 0.62
local circleInnerOffset = 0.28
local opacity = 0.5

local innersize = 1.8 -- outersize-innersize = circle width
local outersize = 1.98 -- outersize-innersize = circle width
local billboardsize = 0.38 -- actual fontsize

local maxValue = 15 -- ignore spots above this metal value (probably metalmap)
local maxScale = 4 -- ignore spots above this scale (probably metalmap)

local extractorRadius = Game.extractorRadius * 1.2

local pollFrames = 151 -- every spot is re-checked once per this many frames (enemy extractors fire no callins)
local pollBatch = 16 -- spots re-checked together: a lone sphere query costs ~3x one inside a batch
local waterMargin = 32 -- a draw pass is skipped only while every spot is this many elmos on the other side of the water level

local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetGroundHeight = Spring.GetGroundHeight
local spGetMapDrawMode = Spring.GetMapDrawMode
local spIsGUIHidden = Spring.IsGUIHidden

local mySpots = {} -- {x, y, z, value, scale, radius, occupied, instanceID, worth}
local numSpots = 0

-- spatial grid of mySpots, so extractor events only re-check the spots around them
local spotGridSize = 512
local spotGridWidth = mathCeil(Game.mapSizeX / spotGridSize)
local spotGridHeight = mathCeil(Game.mapSizeZ / spotGridSize)
---@type table<integer, table[]|nil>
local spotGrid = {} -- cell index -> list of spots
local maxSpotRadius = 0

local pendingSpots, pendingFrames, pendingCount = {}, {}, 0 -- spots to re-check at a given frame
local pollIndex = 0
---@type number
local pollBudget = 0

-- lowest and highest ground height of all spots, to skip a water pass that has nothing to draw
local spotMinY, spotMaxY = math.huge, -math.huge
local spotBoundsDirty = false

local isSpec, fullview = spGetSpectatingState()
local myAllyTeamID = Spring.GetLocalAllyTeamID()
local incomeMultiplier = select(7, Spring.GetTeamInfo(spGetMyTeamID(), false))

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local vsx, vsy = Spring.GetViewGeometry()
local fontfileScale = 1 -- fixed scale: billboard size is resolution-independent (world-space)
local fontfileSize = 110
local fontfileOutlineSize = 12
local fontfileOutlineStrength = 20
--spEcho("Loading Font",fontfile,fontfileSize*fontfileScale,fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
local font =
	gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)

local chobbyInterface

local extractorDefs = {}
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.extractsMetal > 0 then
		extractorDefs[uDefID] = true
	end
end

local teamIncomeMultipliers = {} -- {key teamID value Multiplier number}

local spotVBO = nil
local spotIndexVBO = nil
---@type InstanceVBOTable?
local spotInstanceVBO = nil
local spotShader = nil

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local pushElementInstance = InstanceVBOTable.pushElementInstance
local drawInstanceVBO = InstanceVBOTable.drawInstanceVBO
local uploadElementRange = InstanceVBOTable.uploadElementRange

local shaderConfig = {}
local vsSrcPath = "LuaUI/Shaders/metalspots_gl4.vert.glsl"
local fsSrcPath = "LuaUI/Shaders/metalspots_gl4.frag.glsl"

local shaderSourceCache = {
	vssrcpath = vsSrcPath,
	fssrcpath = fsSrcPath,
	shaderName = "Metalspots GL4",
	uniformInt = {
		heightMap = 0,
		textAtlas = 1,
	},
	uniformFloat = {
		visibilitycontrols = { 0, 0, 0, 0 },
		drawPass = 0,
		waterLevel = 0,
	},
	shaderConfig = shaderConfig,
}

local MetalSpotTextAtlas
local AtlasTextureID
local MakeAtlasOnDemand = require("luaui/Include/AtlasOnDemand")
local valueToUVs = {} -- key value string to uvCoords object from atlas in xXyYwh array

local function goodbye(reason)
	spEcho("Metalspots GL4 widget exiting with reason: " .. reason)
	widgetHandler:RemoveWidget()
end

local function makeSpotVBO()
	spotVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	spotIndexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	if spotVBO == nil or spotIndexVBO == nil then
		goodbye("Failed to create spotVBO")
		return nil
	end
	local VBOLayout = { { id = 0, name = "localpos_dir_angle", size = 4 } }
	local VBOData = {}
	local indices = {}
	local n = 0
	local numVertices = 0
	local numIndices = 0

	local function addVertex(x, y, dir, vertexType)
		VBOData[n + 1] = x
		VBOData[n + 2] = y
		VBOData[n + 3] = dir
		VBOData[n + 4] = vertexType
		n = n + 4
		numVertices = numVertices + 1
	end
	local function addTriangle(a, b, c)
		indices[numIndices + 1] = a
		indices[numIndices + 2] = b
		indices[numIndices + 3] = c
		numIndices = numIndices + 3
	end

	local detailPartWidth, outerAngle, innerAngle
	local width = circleSpaceUsage
	local pieces = 8
	local detail = 6
	local radstep = (2.0 * math.pi) / pieces
	for _, dir in ipairs({ -1, 1 }) do
		for i = 1, pieces do -- pieces
			-- one strip per piece: inner arc vertex k at first + 2k, outer arc vertex k at first + 2k + 1
			local first = numVertices
			for k = 0, detail do -- detail
				detailPartWidth = ((width / detail) * k) + (dir + 1)
				outerAngle = ((i + detailPartWidth) * radstep)
				innerAngle = ((i + circleInnerOffset + detailPartWidth) * radstep)
				addVertex(mathSin(innerAngle) * innersize, mathCos(innerAngle) * innersize, dir, 0)
				addVertex(mathSin(outerAngle) * outersize, mathCos(outerAngle) * outersize, dir, 0)
			end
			for d = 1, detail do
				local innerPrev, outerPrev = first + 2 * d - 2, first + 2 * d - 1
				local innerCur, outerCur = first + 2 * d, first + 2 * d + 1
				-- dir mirrors the ring in the shader, so the winding flips with it
				if dir == -1 then
					addTriangle(innerPrev, innerCur, outerPrev)
					addTriangle(outerCur, outerPrev, innerCur)
				else
					addTriangle(innerPrev, outerPrev, innerCur)
					addTriangle(outerPrev, outerCur, innerCur)
				end
			end
		end
	end

	-- Add the 2 tris for the billboard:
	local first = numVertices
	addVertex(billboardsize, 0, 1, 2)
	addVertex(billboardsize, billboardsize, 1, 2)
	addVertex(-billboardsize, 0, 1, 2)
	addVertex(-billboardsize, billboardsize, 1, 2)
	addTriangle(first, first + 1, first + 2)
	addTriangle(first + 1, first + 3, first + 2)

	spotVBO:Define(numVertices, VBOLayout)
	spotVBO:Upload(VBOData)
	spotIndexVBO:Define(numIndices)
	spotIndexVBO:Upload(indices)
	return spotVBO, spotIndexVBO, numIndices
end

local function initGL4()
	spotShader = LuaShader.CheckShaderUpdates(shaderSourceCache)
	if not spotShader then
		goodbye("Failed to compile spotShader GL4 ")
		return false
	end
	local vertexVBO, indexVBO, numIndices = makeSpotVBO()
	if not (vertexVBO and numIndices) then
		return false
	end
	local spotInstanceVBOLayout = {
		{ id = 1, name = "worldpos_radius", size = 4 },
		{ id = 2, name = "visibility", size = 4 },
		{ id = 3, name = "uvcoords", size = 4 },
	}
	local instanceTable = InstanceVBOTable.makeInstanceVBOTable(spotInstanceVBOLayout, 8, "spotInstanceVBO")
	if not instanceTable then
		goodbye("Failed to create spotInstanceVBO")
		return false
	end
	instanceTable.numVertices = numIndices -- drawn with DrawElements, so this is the index count
	instanceTable.vertexVBO = vertexVBO
	instanceTable.indexVBO = indexVBO
	instanceTable.VAO = InstanceVBOTable.makeVAOandAttach(vertexVBO, instanceTable.instanceVBO, indexVBO)
	instanceTable.primitiveType = GL.TRIANGLES
	spotInstanceVBO = instanceTable
	return true
end

local function spotKey(posx, posz)
	return posx * 65536 + posz
end

local function updateSpotBounds()
	spotMinY, spotMaxY = math.huge, -math.huge
	for i = 1, numSpots do
		local y = mySpots[i].y
		if y < spotMinY then
			spotMinY = y
		end
		if y > spotMaxY then
			spotMaxY = y
		end
	end
	spotBoundsDirty = false
end

local function refreshSpotHeight(spot)
	local y = spGetGroundHeight(spot.x, spot.z)
	if y ~= spot.y then
		if spot.y == spotMinY or spot.y == spotMaxY then
			spotBoundsDirty = true
		end
		spot.y = y
		spotMinY = mathMin(spotMinY, y)
		spotMaxY = mathMax(spotMaxY, y)
	end
end

-- Returns whether a visible extractor is on the spot (spot.y is kept current by UnsyncedHeightMapUpdate)
local function IsSpotOccupied(spot)
	local units = spGetUnitsInSphere(spot.x, spot.y, spot.z, spot.radius)
	for j = 1, #units do
		if extractorDefs[spGetUnitDefID(units[j])] then
			return true
		end
	end
	return false
end

local function updateSpot(spot, gf)
	local occupied = IsSpotOccupied(spot)
	if occupied == spot.occupied then
		return
	end
	spot.occupied = occupied
	local instanceTable = spotInstanceVBO
	---@cast instanceTable -?
	local index = instanceTable.instanceIDtoIndex[spot.instanceID] ---@type integer?
	if index then
		local offset = (index - 1) * instanceTable.instanceStep
		local instanceData = instanceTable.instanceData
		instanceData[offset + 5] = (occupied and 0) or 1
		instanceData[offset + 6] = gf
		uploadElementRange(instanceTable, index - 1, index)
	end
end

local function checkMetalspots()
	local gf = spGetGameFrame()
	for i = 1, numSpots do
		updateSpot(mySpots[i], gf)
	end
end

local function addSpotToGrid(spot)
	local cx = mathMin(mathMax(mathFloor(spot.x / spotGridSize), 0), spotGridWidth - 1)
	local cz = mathMin(mathMax(mathFloor(spot.z / spotGridSize), 0), spotGridHeight - 1)
	local key = cz * spotGridWidth + cx
	local cell = spotGrid[key]
	if not cell then
		cell = {}
		spotGrid[key] = cell
	end
	cell[#cell + 1] = spot
	maxSpotRadius = mathMax(maxSpotRadius, spot.radius)
end

-- Queues a check at frame `due` of every spot whose occupancy query can contain an extractor at x, z
local function queueSpotsNear(x, z, due)
	local cx1 = mathMax(mathFloor((x - maxSpotRadius) / spotGridSize), 0)
	local cx2 = mathMin(mathFloor((x + maxSpotRadius) / spotGridSize), spotGridWidth - 1)
	local cz1 = mathMax(mathFloor((z - maxSpotRadius) / spotGridSize), 0)
	local cz2 = mathMin(mathFloor((z + maxSpotRadius) / spotGridSize), spotGridHeight - 1)
	for cz = cz1, cz2 do
		for cx = cx1, cx2 do
			local cell = spotGrid[cz * spotGridWidth + cx]
			if cell then
				for i = 1, #cell do
					local spot = cell[i]
					local dx, dz = spot.x - x, spot.z - z
					local r = spot.radius + 16
					if dx * dx + dz * dz <= r * r then
						pendingCount = pendingCount + 1
						pendingSpots[pendingCount] = spot
						pendingFrames[pendingCount] = due
					end
				end
			end
		end
	end
end

local function queueSpotsNearUnit(unitID, due)
	local _, _, _, x, _, z = spGetUnitPosition(unitID, true)
	if x then
		queueSpotsNear(x, z, due)
	end
end

local function runPendingChecks(gf)
	local kept = 0
	for i = 1, pendingCount do
		local spot, due = pendingSpots[i], pendingFrames[i]
		if due <= gf then
			updateSpot(spot, gf)
		else
			kept = kept + 1
			pendingSpots[kept], pendingFrames[kept] = spot, due
		end
	end
	for i = kept + 1, pendingCount do
		pendingSpots[i], pendingFrames[i] = nil, nil
	end
	pendingCount = kept
end

local function valueToText(value)
	return stringFormat("%0.1f", mathRound(value / 1000, 1))
end

local function CalcSpotScale(spot)
	return 0.77
		+ (
				(mathMax(spot.maxX, spot.minX) - (mathMin(spot.maxX, spot.minX)))
				* (mathMax(spot.maxZ, spot.minZ) - (mathMin(spot.maxZ, spot.minZ)))
			)
			/ 10000
end

local function InitializeAtlas(mSpots)
	local multipliers = { [1] = true } -- all unique multipliers
	for i, teamID in ipairs(Spring.GetTeamList()) do
		local incomeMultiplier = select(7, Spring.GetTeamInfo(teamID, false))
		if multipliers[incomeMultiplier] == nil then
			multipliers[incomeMultiplier] = teamID
		end
		--spEcho("incomeMultiplier", teamID, incomeMultiplier)
		teamIncomeMultipliers[teamID] = incomeMultiplier
	end
	local uniquevalues = {}
	local numvalues = 0
	local numMultipliers = 0
	for multiplier, _ in pairs(multipliers) do
		numMultipliers = numMultipliers + 1
		for i = 1, #mSpots do
			local spot = mSpots[i]
			local value = valueToText(spot.worth * multiplier)
			if tonumber(value) > 0.001 and tonumber(value) < maxValue then
				local scale = CalcSpotScale(spot)
				if scale < maxScale then
					if uniquevalues[value] == nil then
						uniquevalues[value] = value
						numvalues = numvalues + 1
					end
				end
			end
		end
	end

	-- What's the size of one of these? I would say width 128, height 64
	local textheight = 96
	textheight = mathCeil(fontfileSize * fontfileScale + fontfileOutlineSize * fontfileScale * 0.5)
	--spEcho(textheight)
	local textwidth = 2 * textheight
	-- attempt to make a square-ish, power of two-ish atlas:
	local cellcount = mathMax(1, mathCeil(math.sqrt(numvalues)))
	MetalSpotTextAtlas = MakeAtlasOnDemand({
		sizex = textwidth * cellcount,
		sizey = textheight * cellcount,
		xresolution = textwidth,
		yresolution = textheight,
		name = "MetalSpotAtlas",
		defaultfont = { font = font, options = "o" },
	})
	AtlasTextureID = MetalSpotTextAtlas.textureID

	for uniqueValue, value in pairs(uniquevalues) do
		local uvcoords = MetalSpotTextAtlas:AddText(value)
		valueToUVs[uniqueValue] = uvcoords
	end
end

local function InitializeSpots(mSpots)
	local spotsCount = 0
	for i = 1, #mSpots do
		local spot = mSpots[i]
		local value = valueToText(spot.worth * incomeMultiplier)

		if tonumber(value) > 0.001 and tonumber(value) < maxValue then
			local scale = CalcSpotScale(spot)
			if scale < maxScale then
				-- Create a New myspot!
				local instanceID = spotKey(spot.x, spot.z)

				local mySpot = {
					x = spot.x,
					y = spGetGroundHeight(spot.x, spot.z),
					z = spot.z,
					value = value,
					scale = scale,
					radius = extractorRadius * scale,
					occupied = false,
					instanceID = instanceID,
					worth = spot.worth,
				}

				spotsCount = spotsCount + 1
				mySpots[spotsCount] = mySpot
				addSpotToGrid(mySpot)

				local occupied = IsSpotOccupied(mySpot)
				mySpot.occupied = occupied

				local uvcoords = valueToUVs[value]
				if uvcoords then
					pushElementInstance(
						spotInstanceVBO, -- vbo
						{
							spot.x,
							mySpot.y,
							spot.z,
							scale,
							(occupied and 0) or 1,
							-1000,
							uvcoords.w,
							uvcoords.h,
							uvcoords.x,
							uvcoords.X,
							uvcoords.y,
							uvcoords.Y,
						}, -- instanceData
						instanceID, -- instanceID
						true, -- updateExisting
						true -- noUpload
					)
				end
			end
		end
	end
	numSpots = spotsCount
	updateSpotBounds()
	InstanceVBOTable.uploadAllElements(spotInstanceVBO)
end

local function UpdateSpotValues() -- This will only get called on playerchanged
	for i = 1, numSpots do
		local spot = mySpots[i]
		--local spot = mSpots[i]
		local valueNumber = spot.worth * incomeMultiplier / 1000
		local value = valueToText(spot.worth * incomeMultiplier)
		spot.value = value

		if spot.scale < maxScale and valueNumber > 0.001 and valueNumber < maxValue then
			local occupied = IsSpotOccupied(spot)
			spot.occupied = occupied
			local uvcoords = valueToUVs[spot.value]
			if uvcoords then
				pushElementInstance(
					spotInstanceVBO, -- vbo
					{
						spot.x,
						spot.y,
						spot.z,
						spot.scale,
						(occupied and 0) or 1,
						-1000,
						uvcoords.w,
						uvcoords.h,
						uvcoords.x,
						uvcoords.X,
						uvcoords.y,
						uvcoords.Y,
					}, -- instanceData
					spot.instanceID, -- instanceID
					true, -- updateExisting
					true -- noUpload
				)
			end
		end
	end
	InstanceVBOTable.uploadAllElements(spotInstanceVBO)
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if not WG.resource_spot_finder.metalSpotsList then
		spEcho("<metalspots> This widget requires the 'Metalspot Finder' widget to run.")
		widgetHandler:RemoveWidget()
	end
	if WG.resource_spot_finder.isMetalMap then
		-- no need for this widget on metal maps
		widgetHandler:RemoveWidget()
	end

	WG.metalspots = {}
	WG.metalspots.setShowValue = function(value)
		showValue = value
	end
	WG.metalspots.getShowValue = function()
		return showValue
	end
	WG.metalspots.setOpacity = function(value)
		opacity = value
	end
	WG.metalspots.getOpacity = function()
		return opacity
	end
	WG.metalspots.setMetalViewOnly = function(value)
		metalViewOnly = value
	end
	WG.metalspots.getMetalViewOnly = function()
		return metalViewOnly
	end

	if not initGL4() then
		return
	end

	local mSpots = WG.resource_spot_finder.metalSpotsList
	if not mSpots then
		return
	end
	InitializeAtlas(mSpots)
	InitializeSpots(mSpots)

	if #mSpots <= 1 then
		goodbye("not enough spots detected")
	end
end

function widget:DrawGenesis()
	MetalSpotTextAtlas:RenderTasks()
	-- cause the atlas is done once per initialize only
	widget.widgetHandler.RemoveCallIn(widget.widget, "DrawGenesis")
end
--[[
function widget:DrawScreen()
	MetalSpotTextAtlas:DrawToScreen()
end
]]
--

function widget:Shutdown()
	if MetalSpotTextAtlas then
		MetalSpotTextAtlas:Delete()
	end
	if spotShader then
		spotShader:Finalize()
		spotShader = nil
	end
	if spotInstanceVBO then
		if spotInstanceVBO.VAO then
			spotInstanceVBO.VAO:Delete()
		end
		if spotInstanceVBO.instanceVBO then
			spotInstanceVBO.instanceVBO:Delete()
		end
		spotInstanceVBO = nil
	end
	if spotVBO then
		spotVBO:Delete()
		spotVBO = nil
	end
	if spotIndexVBO then
		spotIndexVBO:Delete()
		spotIndexVBO = nil
	end
	WG.metalspots = nil
	mySpots = {}
	numSpots = 0
	gl.DeleteFont(font)
end

function widget:RecvLuaMsg(msg, playerID)
	if stringFind(msg, "LobbyOverlayActive", 1, true) == 1 then
		chobbyInterface = (stringFind(msg, "LobbyOverlayActive1", 1, true) == 1)
	end
end

function widget:PlayerChanged(playerID)
	local prevFullview = fullview
	local prevMyAllyTeamID = myAllyTeamID
	isSpec, fullview = spGetSpectatingState()
	myAllyTeamID = Spring.GetLocalAllyTeamID()
	local oldIncomeMultiplier = incomeMultiplier
	incomeMultiplier = select(7, Spring.GetTeamInfo(spGetMyTeamID(), false))
	if incomeMultiplier ~= oldIncomeMultiplier then
		UpdateSpotValues()
	end
	if fullview ~= prevFullview or myAllyTeamID ~= prevMyAllyTeamID then
		checkMetalspots()
	end
end

-- only the spots around a created or destroyed extractor can change; enemy ones are found by polling
function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if extractorDefs[unitDefID] then
		queueSpotsNearUnit(unitID, spGetGameFrame() + 1)
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if extractorDefs[unitDefID] then
		-- sphere queries keep finding the unit until its death script has finished, so look again later too
		local gf = spGetGameFrame()
		queueSpotsNearUnit(unitID, gf + 3)
		queueSpotsNearUnit(unitID, gf + 30)
	end
end

-- terrain changes move spots across the water level, which decides the draw passes
function widget:UnsyncedHeightMapUpdate(x1, z1, x2, z2)
	-- heightmap squares to elmos, one square wider for the interpolated ground height
	x1, z1, x2, z2 = x1 * 8 - 8, z1 * 8 - 8, x2 * 8 + 8, z2 * 8 + 8
	local cx1 = mathMax(mathFloor(x1 / spotGridSize), 0)
	local cx2 = mathMin(mathFloor(x2 / spotGridSize), spotGridWidth - 1)
	local cz1 = mathMax(mathFloor(z1 / spotGridSize), 0)
	local cz2 = mathMin(mathFloor(z2 / spotGridSize), spotGridHeight - 1)
	for cz = cz1, cz2 do
		for cx = cx1, cx2 do
			local cell = spotGrid[cz * spotGridWidth + cx]
			if cell then
				for i = 1, #cell do
					local spot = cell[i]
					if spot.x >= x1 and spot.x <= x2 and spot.z >= z1 and spot.z <= z2 then
						refreshSpotHeight(spot)
					end
				end
			end
		end
	end
end

function widget:GameFrame(gf)
	if pendingCount > 0 then
		runPendingChecks(gf)
	end
	-- round robin in small batches, so a full pass is spread over pollFrames instead of one burst
	if numSpots > 0 then
		pollBudget = pollBudget + numSpots / pollFrames
		if pollBudget < mathMin(pollBatch, numSpots) then
			return
		end
		while pollBudget >= 1 do
			pollBudget = pollBudget - 1
			pollIndex = (pollIndex % numSpots) + 1
			updateSpot(mySpots[pollIndex], gf)
		end
	end
end

local function getWaterLevel()
	if lavaWaterLevel then
		return lavaWaterLevel
	end
	local level = Spring.GetGameRulesParam("lavaLevel")
	if level and level ~= -99999 then
		return level
	end
	return 0
end

function widget:LavaRenderState(tideLevel)
	lavaWaterLevel = tideLevel
end

local function spotsHidden()
	return chobbyInterface or (metalViewOnly and spGetMapDrawMode() ~= "metal") or spIsGUIHidden()
end

-- Draw above-water metalspots before units (old method, no ghost occlusion)
function widget:DrawWorldPreUnit()
	if spotsHidden() then
		return
	end
	local wl = getWaterLevel()
	if spotBoundsDirty then
		updateSpotBounds()
	end
	if spotMaxY < wl - waterMargin then -- every spot is under water
		return
	end

	gl.Culling(true)
	gl.Texture(0, "$heightmap")
	gl.Texture(1, AtlasTextureID)
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(false)

	spotShader:Activate()
	spotShader:SetUniformFloat("drawPass", 0)
	spotShader:SetUniformFloat("waterLevel", wl)
	drawInstanceVBO(spotInstanceVBO)
	spotShader:Deactivate()

	gl.Culling(false)
	gl.Texture(0, false)
	gl.Texture(1, false)
end

-- Draw underwater metalspots after water (not distorted by water shader)
function widget:DrawWorld()
	if spotsHidden() then
		return
	end
	local wl = getWaterLevel()
	if spotBoundsDirty then
		updateSpotBounds()
	end
	if spotMinY >= wl + waterMargin then -- every spot is above water
		return
	end

	gl.Culling(true)
	gl.Texture(0, "$heightmap")
	gl.Texture(1, AtlasTextureID)
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(false)
	gl.PolygonOffset(-40, -40)

	spotShader:Activate()
	spotShader:SetUniformFloat("drawPass", 1)
	spotShader:SetUniformFloat("waterLevel", wl)
	drawInstanceVBO(spotInstanceVBO)
	spotShader:Deactivate()

	gl.PolygonOffset(false)
	gl.DepthTest(false)
	gl.Culling(false)
	gl.Texture(0, false)
	gl.Texture(1, false)
end

function widget:GetConfigData(data)
	return {
		showValue = showValue,
		opacity = opacity,
		metalViewOnly = metalViewOnly,
	}
end

function widget:SetConfigData(data)
	if data.showValue ~= nil then
		showValue = data.showValue
	end
	if data.opacity ~= nil then
		opacity = data.opacity
	end
	if data.metalViewOnly ~= nil then
		metalViewOnly = data.metalViewOnly
	end
end

-----------------------------------------------------------------------------------------------
-- The following is a test script.txt for multiple different resource bonuses:
--[[
[Game]
{
	[allyTeam0]
	{
		startrectright = 0.2;
		startrectbottom = 1;
		startrectleft = 0;
		numallies = 0;
		startrecttop = 0;
	}

	[ai1]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = NullAI-50;
		ShortName = NullAI;
		Team = 2;
		Version = 0.1;
	}

	[team1]
	{
		Side = Cortex;
		Handicap = 0;
		RgbColor = 0.99609375 0.546875 0;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[allyTeam1]
	{
		startrectright = 1;
		startrectbottom = 1;
		startrectleft = 0.80000001;
		numallies = 0;
		startrecttop = 0;
	}

	[team3]
	{
		Side = Cortex;
		Handicap = 100;
		RgbColor = 0.99609375 0.546875 0;
		AllyTeam = 0;
		TeamLeader = 0;
	}

	[team0]
	{
		Side = Armada;
		Handicap = 0;
		RgbColor = 0.99609375 0.546875 0;
		AllyTeam = 0;
		TeamLeader = 0;
	}

	[team2]
	{
		Side = Armada;
		Handicap = -50;
		RgbColor = 0.99609375 0.546875 0;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[modoptions]
	{
	}

	[ai2]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = NullAI+100;
		ShortName = NullAI;
		Team = 3;
		Version = 0.1;
	}

	[ai0]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = NullAI+0;
		ShortName = NullAI;
		Team = 1;
		Version = 0.1;
	}

	[player0]
	{
		IsFromDemo = 0;
		Name = Player;
		Team = 0;
		rank = 0;
	}

	hostip = 127.0.0.1;
	hostport = 0;
	numplayers = 1;
	startpostype = 2;
	mapname = Archsimkats_Valley_V1;
	ishost = 1;
	numusers = 4;
	gametype = Beyond All Reason $VERSION;
	GameStartDelay = 5;
	myplayername = Player;
	nohelperais = 0;
}
]]
--
