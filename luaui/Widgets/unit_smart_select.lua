
function widget:GetInfo()
	return {
		name = "SmartSelect",
		desc = "Selects units as you drag over them.",
		author = "aegis (Ryan Hileman)",
		date = "Jan 2, 2011",
		license = "Public Domain",
		layer = -999999,
		enabled = true
	}
end

local getMiniMapFlipped = VFS.Include("luaui/Widgets/Include/minimap_utils.lua").getMiniMapFlipped

local selectBuildingsWithMobile = false		-- whether to select buildings when mobile units are inside selection rectangle
local includeNanosAsMobile = true
local includeBuilders = false

-- CONFIG(int, MouseDragSelectionThreshold).defaultValue(4).description("Distance in pixels which the mouse must be dragged to trigger a selection box.");
local dragSelectionThreshold

-- selection modifiers
local mods = {
 idle     = false, -- whether to select only idle units
 same     = false, -- whether to select only units that share type with current selection
 deselect = false, -- whether to select units not present in current selection
 all      = false, -- whether to select all units
 mobile   = false, -- whether to select only mobile units
}

local spGetMouseState = Spring.GetMouseState

local spTraceScreenRay = Spring.TraceScreenRay

local spGetUnitsInScreenRectangle = Spring.GetUnitsInScreenRectangle
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spSelectUnitArray = Spring.SelectUnitArray
local spGetActiveCommand = Spring.GetActiveCommand
local spGetUnitTeam = Spring.GetUnitTeam

local spGetGroundHeight = Spring.GetGroundHeight
local spGetMiniMapGeometry = Spring.GetMiniMapGeometry
local spIsAboveMiniMap = Spring.IsAboveMiniMap

local spGetUnitDefID = Spring.GetUnitDefID
local spGetCommandQueue = Spring.GetCommandQueue
local spGetUnitNoSelect = Spring.GetUnitNoSelect

local GaiaTeamID = Spring.GetGaiaTeamID()
local selectedUnits = Spring.GetSelectedUnits()

local spec = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()

local ignoreUnits = {}
local combatFilter = {}
local builderFilter = {}
local buildingFilter = {}
local mobileFilter = {}
for udid, udef in pairs(UnitDefs) do
	if udef.modCategories['object'] or udef.customParams.objectify then
		ignoreUnits[udid] = true
	end

	local isMobile = (udef.canMove and udef.speed > 0.000001)  or  (includeNanosAsMobile and (udef.name == "armnanotc" or udef.name == "cornanotc"))
	local builder = (udef.canReclaim and udef.reclaimSpeed > 0)  or  (udef.canResurrect and udef.resurrectSpeed > 0)  or  (udef.canRepair and udef.repairSpeed > 0) or (udef.buildOptions and udef.buildOptions[1])
	local building = (isMobile == false)
	local combat = (not builder) and isMobile and (#udef.weapons > 0)

	if string.find(udef.name, 'armspid') then
		builder = false
	end
	combatFilter[udid] = combat
	builderFilter[udid] = builder
	buildingFilter[udid] = building
	mobileFilter[udid] = isMobile
end

local dualScreen
local vpy
local mapWidth, mapHeight = Game.mapSizeX, Game.mapSizeZ

local lastCoords, lastMeta, lastSelection
local referenceCoords, referenceScreenCoords, referenceSelection, referenceSelectionTypes

local function sort(v1, v2)
	if v1 > v2 then
		return v2, v1
	else
		return v1, v2
	end
end

local function getDist(coords1, coords2)
  local dx = coords1[1] - coords2[1]
  local dy = coords1[2] - coords2[2]
  return math.sqrt (dx * dx + dy * dy)
end

local function MinimapToWorldCoords(x, y)
	local px, py, sx, sy = spGetMiniMapGeometry()
	if dualScreen == "left" then
		x = x + sx + px
	end
	x = ((x - px) / sx) * mapWidth
	local z = (1 - (y - py + vpy)/sy) * mapHeight
	y = spGetGroundHeight(x, z)

	if getMiniMapFlipped() then
		x = mapWidth - x
		z = mapHeight - z
	end

	return x, y, z
end

local function GetUnitsInMinimapRectangle(x1, y1, x2, y2, team)
	local left, _, top = MinimapToWorldCoords(x1, y1)
	local right, _, bottom = MinimapToWorldCoords(x2, y2)

	left, right = sort(left, right)
	bottom, top = sort(bottom, top)

	return spGetUnitsInRectangle(left, bottom, right, top, team)
end

local function setModifier(_, _, _, data)
	mods[data[1]] = data[2]
end


function widget:ViewResize()
	dualScreen = Spring.GetMiniMapDualScreen()
	_, _, _, vpy = Spring.GetViewGeometry()
end

function widget:SelectionChanged(sel)
	local equalSelection = #selectedUnits == #sel

	if equalSelection then
		for i = 1, #sel do
			if selectedUnits[i] ~= sel[i] then
				equalSelection = false
				break
			end
		end
	end

	selectedUnits = sel
	if referenceCoords ~= nil and spGetActiveCommand() == 0 then
		if not select(3, spGetMouseState()) and referenceSelection ~= nil and lastSelection ~= nil and equalSelection then
			WG['smartselect'].updateSelection = false    -- widgethandler uses this to ignore the engine mouserelease selection
		end
	end
end

-- this widget gets called early due to its layer
-- this function will get called after all widgets have had their chance with widget:MousePress
local function mousePress(x, y, button)  --function widget:MousePress(x, y, button)
	if button ~= 1 then return end

	referenceSelection = selectedUnits
	referenceSelectionTypes = {}
	for i = 1, #referenceSelection do
		local udid = spGetUnitDefID(referenceSelection[i])
		if udid then
			referenceSelectionTypes[udid] = 1
		end
	end
	referenceScreenCoords = { x, y }
	lastMeta = nil
	lastSelection = nil

	if spIsAboveMiniMap(x, y) then
		referenceCoords = { 0, 0, 0 }
		lastCoords = { 0, 0, 0 }
	else
		local _, c = spTraceScreenRay(x, y, true, false, true)
		referenceCoords = c
		lastCoords = c
	end
end

function widget:PlayerChanged()
	spec = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
end

function widget:Update()
	WG['smartselect'].updateSelection = true

	if referenceCoords == nil or spGetActiveCommand() ~= 0 then
		return
	end

	local x, y, pressed = spGetMouseState()

	if not ((pressed or lastSelection) and referenceSelection ~= nil) then
		referenceSelection = nil
		referenceSelectionTypes = nil
		referenceCoords = nil

		return
	end

	if #referenceSelection == 0 then  -- no point in inverting an empty selection
		mods.deselect = false
	end

	if referenceScreenCoords ~= nil and x == referenceScreenCoords[1] and y == referenceScreenCoords[2] then -- sameLast
		if lastCoords == referenceCoords then
			return
		elseif lastMeta ~= nil and mods.mobile == lastMeta[1] and mods.deselect == lastMeta[2] and mods.idle == lastMeta[3] and mods.all == lastMeta[4] then
			return
		end
	end

	lastCoords = { x, y }
	lastMeta = { mods.mobile, mods.deselect, mods.idle, mods.all }

	-- get all units within selection rectangle
	local mouseSelection, originalMouseSelection
	local r = referenceScreenCoords
	if r ~= nil and spIsAboveMiniMap(r[1], r[2]) then
		mouseSelection = GetUnitsInMinimapRectangle(r[1], r[2], x, y, nil)
	else
		local x1, y1, x2, y2 = Spring.GetSelectionBox()

		if x1 then
			mouseSelection = spGetUnitsInScreenRectangle(x1, y1, x2, y2, nil) or {}
		elseif getDist(referenceScreenCoords, lastCoords) <= dragSelectionThreshold then -- empty selection if didnt make drag threshold
			mouseSelection = {}
		else -- if not x1 selection box is not valid anymore (mouserelease/minimum threshold/chorded/etc)
			mouseSelection = selectedUnits
		end
	end

	originalMouseSelection = mouseSelection

	local newSelection = {}
	local uid, udid, tmp

	-- filter unselectable units
	tmp = {}
	for i = 1, #mouseSelection do
		uid = mouseSelection[i]
		if not spGetUnitNoSelect(uid) then
			tmp[#tmp + 1] = uid
		end
	end
	mouseSelection = tmp

	-- filter gaia units + ignored units (objects) + only own units when not spectating
	if not Spring.IsGodModeEnabled() then
		tmp = {}
		for i = 1, #mouseSelection do
			uid = mouseSelection[i]
			if spGetUnitTeam(uid) ~= GaiaTeamID and not ignoreUnits[spGetUnitDefID(uid)] and (spec or spGetUnitTeam(uid) == myTeamID) then
				tmp[#tmp + 1] = uid
			end
		end
		mouseSelection = tmp
	end

	if mods.idle then
		tmp = {}
		for i = 1, #mouseSelection do
			uid = mouseSelection[i]
			udid = spGetUnitDefID(uid)
			if (mobileFilter[udid] or builderFilter[udid]) and spGetCommandQueue(uid, 0) == 0 then
				tmp[#tmp + 1] = uid
			end
		end
		mouseSelection = tmp
	end

	-- only select new units identical to those already selected
	if mods.same and #referenceSelection > 0 then
		tmp = {}
		for i = 1, #mouseSelection do
			uid = mouseSelection[i]
			if referenceSelectionTypes[ spGetUnitDefID(uid) ] ~= nil then
				tmp[#tmp + 1] = uid
			end
		end
		mouseSelection = tmp
	end

	if mods.mobile then  -- only select mobile combat units
		if not mods.deselect then
			tmp = {}
			for i = 1, #referenceSelection do
				uid = referenceSelection[i]
				if combatFilter[ spGetUnitDefID(uid) ] then  -- is a combat unit
					tmp[#tmp + 1] = uid
				end
			end
			newSelection = tmp
		end

		tmp = {}
		for i = 1, #mouseSelection do
			uid = mouseSelection[i]
			if combatFilter[ spGetUnitDefID(uid) ] then  -- is a combat unit
				tmp[#tmp + 1] = uid
			end
		end
		mouseSelection = tmp

	elseif selectBuildingsWithMobile == false and mods.all == false and mods.deselect == false then
		-- only select mobile units, not buildings
		local mobiles = false
		for i = 1, #mouseSelection do
			uid = mouseSelection[i]
			if mobileFilter[ spGetUnitDefID(uid) ] then
				mobiles = true
				break
			end
		end

		if mobiles then
			tmp = {}
			local tmp2 = {}
			for i = 1, #mouseSelection do
				uid = mouseSelection[i]
				udid = spGetUnitDefID(uid)
				if buildingFilter[udid] == false then
					if includeBuilders or not builderFilter[udid] then
						tmp[#tmp + 1] = uid
					else
						tmp2[#tmp2 + 1] = uid
					end
				end
			end
			if #tmp == 0 then
				tmp = tmp2
			end
			mouseSelection = tmp
		end
	end

	if #newSelection < 1 then
		newSelection = referenceSelection
	end

	if mods.deselect then  -- deselect units inside the selection rectangle, if we already had units selected
		local negative = {}
		for i = 1, #mouseSelection do
			uid = mouseSelection[i]
			negative[uid] = true
		end

		tmp = {}
		for i = 1, #newSelection do
			uid = newSelection[i]
			if not negative[uid]  then
				tmp[#tmp + 1] = uid
			end
		end
		newSelection = tmp
		spSelectUnitArray(newSelection)

	elseif mods.all then  -- append units inside selection rectangle to current selection
		spSelectUnitArray(newSelection)
		spSelectUnitArray(mouseSelection, true)

	elseif #mouseSelection > 0 then  -- select units inside selection rectangle
		spSelectUnitArray(mouseSelection)

	elseif #originalMouseSelection > 0 and #mouseSelection == 0 then
		spSelectUnitArray({})

	else  -- keep current selection while dragging until more things are selected
		spSelectUnitArray(referenceSelection)
		lastSelection = nil
		return
	end

	if pressed then
		lastSelection = true
	else
		lastSelection = nil
		referenceSelection = nil
		referenceSelectionTypes = nil
		referenceCoords = nil
	end
end

function widget:Shutdown()
	WG['smartselect'] = nil

	WG.SmartSelect_MousePress2 = nil
end

function widget:Initialize()
	dragSelectionThreshold = Spring.GetConfigInt("MouseDragSelectionThreshold")

	WG.SmartSelect_MousePress2 = mousePress

	for modifierName, _ in pairs(mods) do
		widgetHandler:AddAction("selectbox_" .. modifierName, setModifier, { modifierName,  true }, "p")
		widgetHandler:AddAction("selectbox_" .. modifierName, setModifier, { modifierName, false }, "r")
	end

	WG['smartselect'] = {}
	WG['smartselect'].getIncludeBuildings = function()
		return selectBuildingsWithMobile
	end
	WG['smartselect'].setIncludeBuildings = function(value)
		selectBuildingsWithMobile = value
	end
	WG['smartselect'].getIncludeBuilders = function()
		return includeBuilders
	end
	WG['smartselect'].setIncludeBuilders = function(value)
		includeBuilders = value
	end
	WG['smartselect'].updateSelection = false

	widget:ViewResize();
end

function widget:GetConfigData()
	return {
		selectBuildingsWithMobile = selectBuildingsWithMobile,
		includeNanosAsMobile = includeNanosAsMobile,
		includeBuilders = includeBuilders
	}
end

function widget:SetConfigData(data)
	if data.selectBuildingsWithMobile ~= nil then
		selectBuildingsWithMobile = data.selectBuildingsWithMobile
	end
	if data.includeNanosAsMobile ~= nil then
		includeNanosAsMobile = data.includeNanosAsMobile
	end
	if data.includeBuilders ~= nil then
		includeBuilders = data.includeBuilders
	end
end
