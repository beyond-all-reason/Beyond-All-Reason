
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Show Orders",
		desc      = "Hold shift+meta to show allied units orders",
		author    = "Niobium",
		date      = "date",
		version   = 1.2,
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

-----------------------------------------------------
-- Performance Optimizations:
-- 1. Table reuse pools (cellsPool, cellPool, textDrawQueue)
-- 2. Factory unit caching (only iterate factories, not all units)
-- 3. Separated data updates from rendering (eliminates flicker)
-- 4. Batched text rendering (single font:Begin/End per frame)
-- 5. Allied teams caching
-- 6. String pre-allocation (percentStrings, numberStrings)
-- 7. Off-screen culling
-- 8. Cached render data (expensive queries throttled every 10 frames)
-- 9. Distance-based scaling (calculated per frame for smooth zoom response)
-- 10. Minimized GL state changes (batch backgrounds, then textures)
-- 11. Two-pass rendering (all backgrounds first, then all textures)
-- 12. Allied units tracking via callins (eliminates per-frame spGetTeamUnits calls)
-----------------------------------------------------


-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry

local vsx,vsy = spGetViewGeometry()
local widgetScale = vsy / 2000

-----------------------------------------------------
-- Config
-----------------------------------------------------
local borderWidth = 2
local iconSize = 190
local maxColumns = 4
local maxRows = 2
local fontSize = 66

-- Performance tuning: Update expensive data (factory commands) every N frames
-- Rendering (positions, drawing) happens every frame for smooth display
-- Set to 1 for most responsive updates, 3-5 for good balance, 7-15 for maximum performance
local updateInterval = 10

-- Distance-based scaling configuration
local enableDistanceScaling = true -- Set to false to disable distance scaling for better performance
local minScaleDistance = 500    -- Distance at which icons start scaling down
local maxScaleDistance = 3000   -- Distance at which icons are at minimum scale
local minScale = 0.3            -- Minimum scale factor (0.3 = 30% of original size)
local maxScale = 1.0            -- Maximum scale factor (1.0 = 100% of original size)
-- Note: Distance scaling is calculated every frame for responsive zoom, but it's relatively cheap

-----------------------------------------------------
-- Globals
-----------------------------------------------------
local isFactory = {}
local GaiaTeamID  = Spring.GetGaiaTeamID() 		-- set to -1 to include Gaia units

local font, chobbyInterface

-- Table reuse pools for performance
local cellsPool = {}
local cellPool = {}
local cellPoolIndex = 0
local maxCellPoolSize = 100

-- Cached values
local alliedTeamsCache = {}
local alliedTeamsCacheValid = false
local cachedScaledValues = {}

-- Factory caching for performance
local factoryUnits = {}
local factoryUnitsDirty = true

-- Allied units tracking (replaces spGetTeamUnits calls in DrawWorld)
local alliedUnits = {}

-- Frame throttling for expensive updates
local frameCounter = 0

-- Text batching
local textDrawQueue = {}
local textDrawQueueSize = 0

-- Cached render data to avoid recalculating every frame
local cachedRenderData = {}
local renderDataDirty = true

-- String caching to avoid concatenation
local percentStrings = {}
for i = 0, 100 do
	percentStrings[i] = i .. "%"
end
local idleString = "IDLE"

-- Number string cache to avoid tostring allocations
local numberStrings = {}
for i = 1, 999 do
	numberStrings[i] = tostring(i)
end

-- Helper function to get a reused cell table
local function getCell()
	cellPoolIndex = cellPoolIndex + 1
	if not cellPool[cellPoolIndex] then
		cellPool[cellPoolIndex] = {}
	end
	return cellPool[cellPoolIndex]
end

-- Helper function to get a reused cells array
local function getCellsArray()
	local cells = table.remove(cellsPool)
	if not cells then
		cells = {}
	end
	return cells
end

-- Helper function to return a cells array to the pool
local function recycleCellsArray(cells)
	for i = 1, #cells do
		cells[i] = nil
	end
	if #cellsPool < maxCellPoolSize then
		cellsPool[#cellsPool + 1] = cells
	end
end

-----------------------------------------------------
-- Speedup
-----------------------------------------------------
local floor = math.floor

local spGetModKeyState = Spring.GetModKeyState
local spDrawUnitCommands = Spring.DrawUnitCommands
local spGetFactoryCommands = Spring.GetFactoryCommands
local spGetSpecState = Spring.GetSpectatingState
local spGetTeamList = Spring.GetTeamList
local spGetTeamUnits = Spring.GetTeamUnits
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spWorldToScreenCoords	= Spring.WorldToScreenCoords
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitStates = Spring.GetUnitStates
local spGetCameraPosition = Spring.GetCameraPosition
local spGetTeamInfo = Spring.GetTeamInfo

local glColor			= gl.Color
local glTexture			= gl.Texture
local glTexRect			= gl.TexRect
local glRect			= gl.Rect

local max = math.max
local min = math.min
local sqrt = math.sqrt

-----------------------------------------------------
-- Code
-----------------------------------------------------

-- Calculate distance-based scale factor for icons
local function GetDistanceScale(unitX, unitY, unitZ)
	local camX, camY, camZ = spGetCameraPosition()
	if not camX then return maxScale end

	-- Calculate 3D distance from camera to unit
	local dx = unitX - camX
	local dy = unitY - camY
	local dz = unitZ - camZ
	local distance = sqrt(dx*dx + dy*dy + dz*dz)

	-- Scale linearly between min and max distances
	if distance <= minScaleDistance then
		return maxScale
	elseif distance >= maxScaleDistance then
		return minScale
	else
		-- Linear interpolation
		local t = (distance - minScaleDistance) / (maxScaleDistance - minScaleDistance)
		return maxScale - (t * (maxScale - minScale))
	end
end

function widget:ViewResize()
	vsx,vsy = spGetViewGeometry()
	widgetScale = vsy / 2000
	font = WG['fonts'].getFont(2)

	-- Pre-calculate scaled values
	cachedScaledValues.iconSize = iconSize * widgetScale
	cachedScaledValues.borderWidth = borderWidth * widgetScale
	cachedScaledValues.fontSize = fontSize * widgetScale
	cachedScaledValues.iconPlusBorder = (iconSize + borderWidth) * widgetScale
	cachedScaledValues.border2x = 2 * borderWidth * widgetScale
end

local function GetAlliedTeams()
	if alliedTeamsCacheValid then
		return alliedTeamsCache
	end

	local _, fullView, _ = spGetSpecState()
	local teams = fullView and spGetTeamList() or spGetTeamList(spGetMyAllyTeamID())

	-- Reuse the cache table
	for i = 1, #alliedTeamsCache do
		alliedTeamsCache[i] = nil
	end
	for i = 1, #teams do
		alliedTeamsCache[i] = teams[i]
	end

	alliedTeamsCacheValid = true
	return alliedTeamsCache
end

local function InvalidateTeamCache()
	alliedTeamsCacheValid = false
end

local function InvalidateFactoryCache()
	factoryUnitsDirty = true
	renderDataDirty = true
end

local function UpdateFactoryCache()
	if not factoryUnitsDirty then return end

	-- Clear old cache
	for i = 1, #factoryUnits do
		factoryUnits[i] = nil
	end

	local alliedTeams = GetAlliedTeams()
	for t = 1, #alliedTeams do
		local teamID = alliedTeams[t]
		if teamID ~= GaiaTeamID then
			local teamUnits = spGetTeamUnits(teamID)
			for u = 1, #teamUnits do
				local uID = teamUnits[u]
				local uDefID = spGetUnitDefID(uID)
				if uDefID and isFactory[uDefID] then
					factoryUnits[#factoryUnits + 1] = uID
				end
			end
		end
	end

	factoryUnitsDirty = false
end

function widget:Initialize()
	widget:ViewResize()
	for uDefID, uDef in pairs(UnitDefs) do
		if uDef.isFactory then
			isFactory[uDefID] = true
		end
	end

	-- Initialize allied units tracking
	local alliedTeams = GetAlliedTeams()
	for t = 1, #alliedTeams do
		local teamID = alliedTeams[t]
		if teamID ~= GaiaTeamID then
			local teamUnits = spGetTeamUnits(teamID)
			for u = 1, #teamUnits do
				alliedUnits[#alliedUnits + 1] = teamUnits[u]
			end
		end
	end
end

-- Track allied units using callins instead of querying every frame
function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	-- Only track allied units (not Gaia)
	if unitTeam ~= GaiaTeamID then
		local _, fullView, _ = spGetSpecState()
		local myAllyTeam = spGetMyAllyTeamID()
		local unitAllyTeam = select(6, spGetTeamInfo(unitTeam))

		-- Add if it's our ally or we're in spec fullview
		if fullView or unitAllyTeam == myAllyTeam then
			alliedUnits[#alliedUnits + 1] = unitID
		end
	end
end

function widget:VisibleUnitRemoved(unitID)
	-- Remove from allied units list
	for i = 1, #alliedUnits do
		if alliedUnits[i] == unitID then
			table.remove(alliedUnits, i)
			break
		end
	end
end

function widget:PlayerChanged(playerID)
	InvalidateTeamCache()
	InvalidateFactoryCache()

	-- Rebuild allied units list when teams change
	for i = 1, #alliedUnits do
		alliedUnits[i] = nil
	end
	local alliedTeams = GetAlliedTeams()
	for t = 1, #alliedTeams do
		local teamID = alliedTeams[t]
		if teamID ~= GaiaTeamID then
			local teamUnits = spGetTeamUnits(teamID)
			for u = 1, #teamUnits do
				alliedUnits[#alliedUnits + 1] = teamUnits[u]
			end
		end
	end
end

function widget:TeamDied(teamID)
	InvalidateTeamCache()
	InvalidateFactoryCache()
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if isFactory[unitDefID] then
		InvalidateFactoryCache()
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if isFactory[unitDefID] then
		InvalidateFactoryCache()
	end
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if isFactory[unitDefID] then
		InvalidateFactoryCache()
	end
end

function widget:DrawWorld()
	if chobbyInterface then return end

	local _, _, meta, shift = spGetModKeyState()
	if not (shift and meta) then return end

	-- Draw commands for all tracked allied units
	spDrawUnitCommands(alliedUnits)
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

-- Update expensive data (factory commands, build status) on throttled schedule
local function UpdateRenderData()
	-- Update factory cache if needed
	UpdateFactoryCache()

	-- Reset cell pool index for reuse
	cellPoolIndex = 0

	-- Clear old render data
	for i = 1, #cachedRenderData do
		cachedRenderData[i] = nil
	end

	-- Build render data for all factories
	for f = 1, #factoryUnits do
		local uID = factoryUnits[f]

		-- Validate unit still exists
		local uDefID = spGetUnitDefID(uID)
		if uDefID then
			local isBuilding, progress = spGetUnitIsBeingBuilt(uID)
			local uCmds = spGetFactoryCommands(uID,-1)

			local cells = getCellsArray()

			if (isBuilding) then
				local cell = getCell()
				cell.texture = "#" .. uDefID
				cell.text = percentStrings[floor(progress * 100)] or (floor(progress * 100) .. "%")
				cells[1] = cell
			else
				if (#uCmds == 0) then
					local cell = getCell()
					cell.texture = "#" .. uDefID
					cell.text = idleString
					cells[1] = cell
				end
			end

			if (#uCmds > 0) then
				local uCount = 0
				local prevID = -1000

				for c = 1, #uCmds do
					local cDefID = -uCmds[c].id

					if (cDefID == prevID) then
						uCount = uCount + 1
					else
						if (prevID > 0) then
							local cell = getCell()
							cell.texture = "#" .. prevID
							local count = uCount + 1
							cell.text = numberStrings[count] or count
							cells[#cells + 1] = cell
						end
						uCount = 0
					end

					prevID = cDefID
				end

				if (prevID > 0) then
					local cell = getCell()
					cell.texture = "#" .. prevID
					local count = uCount + 1
					cell.text = numberStrings[count] or count
					cells[#cells + 1] = cell
				end
			end

			-- Cache repeat state
			local isRepeat = select(4,spGetUnitStates(uID,false,true))

			-- Store render data (scale will be calculated per-frame for smooth zoom response)
			local renderData = {
				unitID = uID,
				cells = cells,
				isRepeat = isRepeat
			}
			cachedRenderData[#cachedRenderData + 1] = renderData
		end
	end

	renderDataDirty = false
end

function widget:DrawScreen()
	if chobbyInterface then return end

	local _, _, meta, shift = spGetModKeyState()
	if not (shift and meta) then return end

	-- Frame throttling - only update data every N frames, but always render
	frameCounter = frameCounter + 1
	if frameCounter >= updateInterval or renderDataDirty then
		frameCounter = 0
		UpdateRenderData()
	end

	-- Reset text queue
	textDrawQueueSize = 0

	-- Cache base scaled values
	local baseIconSize = cachedScaledValues.iconSize
	local baseBorderWidth = cachedScaledValues.borderWidth
	local baseFontSize = cachedScaledValues.fontSize
	local baseIconPlusBorder = cachedScaledValues.iconPlusBorder
	local baseBorder2x = cachedScaledValues.border2x

	-- Render from cached data (this runs every frame for smooth display)
	for i = 1, #cachedRenderData do
		local renderData = cachedRenderData[i]
		local uID = renderData.unitID
		local cells = renderData.cells
		local isRepeat = renderData.isRepeat

		-- Get current position (this is cheap and needs to be current for smooth movement)
		local ux, uy, uz = spGetUnitPosition(uID)
		if ux then
			local sx, sy = spWorldToScreenCoords(ux, uy, uz)

			-- Early exit if off-screen
			if sx >= 0 and sx <= vsx and sy >= 0 and sy <= vsy then
				-- Calculate distance scale every frame for responsive zoom
				local distScale = maxScale
				if enableDistanceScaling then
					distScale = GetDistanceScale(ux, uy, uz)
				end

				-- Apply distance scale
				local scaledIconSize = baseIconSize * distScale
				local scaledBorderWidth = baseBorderWidth * distScale
				local scaledFontSize = baseFontSize * distScale
				local scaledIconPlusBorder = baseIconPlusBorder * distScale
				local scaledBorder2x = baseBorder2x * distScale
				-- Set background color once for all cells of this factory
				if isRepeat then
					glColor(0.0, 0.0, 0.5, 1.0)
				else
					glColor(0.0, 0.0, 0.0, 1.0)
				end

				-- First pass: Draw all backgrounds
				for r = 0, maxRows - 1 do
					for c = 1, maxColumns do
						local cell = cells[maxColumns * r + c]
						if not cell then break end

						local cx = sx + (c - 1) * scaledIconPlusBorder
						local cy = sy - r * scaledIconPlusBorder

						glRect(cx, cy, cx + scaledIconSize + scaledBorder2x,
							cy - scaledIconSize - scaledBorder2x)
					end
				end

				-- Set white color once for all textures
				glColor(1.0, 1.0, 1.0, 1.0)

				-- Second pass: Draw all textures and queue text
				for r = 0, maxRows - 1 do
					for c = 1, maxColumns do
						local cell = cells[maxColumns * r + c]
						if not cell then break end

						local cx = sx + (c - 1) * scaledIconPlusBorder
						local cy = sy - r * scaledIconPlusBorder

						glTexture(cell.texture)
						glTexRect(cx + scaledBorderWidth, cy - scaledIconSize - scaledBorderWidth,
							cx + scaledIconSize + scaledBorderWidth, cy - scaledBorderWidth)

						if (cell.text) then
							-- Queue text for batched rendering
							textDrawQueueSize = textDrawQueueSize + 1
							local textEntry = textDrawQueue[textDrawQueueSize]
							if not textEntry then
								textEntry = {}
								textDrawQueue[textDrawQueueSize] = textEntry
							end
							textEntry.text = cell.text
							textEntry.x = cx + scaledBorderWidth + (scaledIconSize * 0.1)
							textEntry.y = cy - scaledIconSize + (scaledIconSize * 0.1)
							textEntry.size = scaledFontSize
						end
					end -- columns
				end -- rows

				glTexture(false)
			end -- off-screen check
		end -- position check
	end -- cachedRenderData

	-- Batch render all text at once
	if textDrawQueueSize > 0 then
		font:Begin()
		font:SetOutlineColor(0, 0, 0, 1)
		font:SetTextColor(0.9,0.9,0.9, 1)
		for i = 1, textDrawQueueSize do
			local entry = textDrawQueue[i]
			font:Print(entry.text, entry.x, entry.y, entry.size, 'ob')
		end
		font:End()
	end
end -- DrawScreen
