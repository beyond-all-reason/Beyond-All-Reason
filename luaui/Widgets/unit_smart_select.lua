local widget = widget ---@type Widget

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

local minimapToWorld = VFS.Include("luaui/Include/minimap_utils.lua").minimapToWorld
local selectApi = VFS.Include("luaui/Include/select_api.lua")

local skipSel
local inSelection = false
local inMiniMapSel = false

local referenceX, referenceY

local selectBuildingsWithMobile = false		-- whether to select buildings when mobile units are inside selection rectangle
local includeNanosAsMobile = true
local includeBuilders = false

-- selection modifiers
local mods = {
 idle     = false, -- whether to select only idle units
 same     = false, -- whether to select only units that share type with current selection
 deselect = false, -- whether to select units not present in current selection
 all      = false, -- whether to select without filters and append (backwards compatibility, it's like append+any)
 mobile   = false, -- whether to select only mobile units
 append   = false, -- whether to append units to current selection
 any      = false, -- whether to select without filters
}
local customFilterDef = ""
local lastMods = mods
local lastCustomFilterDef = customFilterDef
local lastMouseSelection = {}
local lastMouseSelectionCount = 0

local spGetMouseState = Spring.GetMouseState
local spGetModKeyState = Spring.GetModKeyState
local spGetSelectionBox = Spring.GetSelectionBox

local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spIsGodModeEnabled = Spring.IsGodModeEnabled

local spGetUnitsInScreenRectangle = Spring.GetUnitsInScreenRectangle
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spSelectUnitArray = Spring.SelectUnitArray
local spGetActiveCommand = Spring.GetActiveCommand
local spGetUnitTeam = Spring.GetUnitTeam

local spIsAboveMiniMap = Spring.IsAboveMiniMap

local spGetUnitDefID = Spring.GetUnitDefID
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
local customFilter = {}

for udid, udef in pairs(UnitDefs) do
	if udef.modCategories['object'] or udef.customParams.objectify then
		ignoreUnits[udid] = true
	end

	local isMobile = not udef.isImmobile  or  (includeNanosAsMobile and (udef.isStaticBuilder and not udef.isFactory))
	local builder = (udef.canReclaim and udef.reclaimSpeed > 0)  or  (udef.canResurrect and udef.resurrectSpeed > 0)  or  (udef.canRepair and udef.repairSpeed > 0) or (udef.buildOptions and udef.buildOptions[1])
	local building = (isMobile == false)
	local combat = (not builder) and isMobile and (#udef.weapons > 0)

	if string.find(udef.name, 'armspid') or string.find(udef.name, 'leginfestor') then
		builder = false
	end
	combatFilter[udid] = combat
	builderFilter[udid] = builder
	buildingFilter[udid] = building
	mobileFilter[udid] = isMobile
end

local dualScreen
local vpy = select(Spring.GetViewGeometry(), 4)
local referenceSelection = {}
local referenceSelectionTypes = {}

local function sort(v1, v2)
	if v1 > v2 then
		return v2, v1
	else
		return v1, v2
	end
end

local function GetUnitsInMinimapRectangle(x, y)
	local left = referenceX
	local top = referenceY
	local right, _, bottom = minimapToWorld(x, y, vpy, dualScreen)

	left, right = sort(left, right)
	bottom, top = sort(bottom, top)

	return spGetUnitsInRectangle(left, bottom, right, top, not spec and -2)		-- -2 = own units
end

local function handleSetModifier(_, _, _, data)
	mods[data[1]] = data[2]
end



local function handleSetCustomFilter(_, ruleDef)
	customFilter = selectApi.getFilter(ruleDef)
	customFilterDef = ruleDef
end

local function handleClearCustomFilter(_, _, _)
	customFilter = {}
	customFilterDef = ""
end


function widget:ViewResize()
	dualScreen = Spring.GetMiniMapDualScreen()
	_, _, _, vpy = Spring.GetViewGeometry()
end

function widget:SelectionChanged(sel)
	-- Check if engine has just deselected via mouserelease on selectbox.
	-- We want to ignore engine passed selection and make sure we retain smartselect state
	if inSelection and not select(3, spGetMouseState()) then -- left mouse button
		inSelection = false

		if #sel == 0 and not select(2, spGetModKeyState()) then -- ctrl
			-- if empty selection box and engine hardcoded deselect modifier is not
			-- pressed, user is selected empty space
			-- let engine deselect everything by itself since we didn't modify its provided value
			selectedUnits = {}
			return false
		else
			-- we also want to override back from engine selection to our selection
			spSelectUnitArray(selectedUnits)
		end
		return selectedUnits
	end

	selectedUnits = sel
end

-- this widget gets called early due to its layer
-- this function will get called after all widgets have had their chance with widget:MousePress
local function mousePress(x, y, button, hasMouseOwner)  --function widget:MousePress(x, y, button)
	if hasMouseOwner or button ~= 1 then
		skipSel = true
		return
	end

	skipSel = false

	referenceSelection = selectedUnits
	referenceSelectionTypes = {}
	for i = 1, #referenceSelection do
		local udid = spGetUnitDefID(referenceSelection[i])
		if udid then
			referenceSelectionTypes[udid] = 1
		end
	end

	inMiniMapSel = spIsAboveMiniMap(x, y)
	if inMiniMapSel then
		referenceX, _, referenceY = minimapToWorld(x, y, vpy, dualScreen)
	end
end

function widget:PlayerChanged()
	spec = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
end

local sec = 0
local prevSelRect = {}
function widget:Update(dt)
	sec = sec + dt

	if skipSel or spGetActiveCommand() ~= 0 then
		return
	end

	local x, y, lmb = spGetMouseState()
	if lmb == false then inMiniMapSel = false end

	local x1, y1, x2, y2 = spGetSelectionBox()
	local selRectChanged = false
	if (prevSelRect[1] and prevSelRect[1] ~= x1) or (not prevSelRect[1] and x1) or
		(prevSelRect[2] and prevSelRect[2] ~= y1) or (not prevSelRect[2] and y1) or
		(prevSelRect[3] and prevSelRect[3] ~= x2) or (not prevSelRect[3] and x2) or
		(prevSelRect[4] and prevSelRect[4] ~= y2) or (not prevSelRect[4] and y2)
	then
		selRectChanged = true
	end
	prevSelRect = {x1, y1, x2, y2}

	inSelection = inMiniMapSel or (x1 ~= nil)
	if not inSelection then return end -- not in valid selection box (mouserelease/minimum threshold/chorded/etc)

	if #referenceSelection == 0 then  -- no point in inverting an empty selection
		mods.deselect = false
	end

	-- limit updaterate  (cause Spring.GetUnitsIn.... expensive mem alloc wise)
	if (not selRectChanged and sec < 1/30) -- limit to 30 updates per sec when selection rectangle didnt change
		or selRectChanged and  sec < 1/60	-- limit to 60 updates per sec
	then
		return
	end
	sec = 0

	-- get units under selection rectangle
	local isGodMode = spIsGodModeEnabled()
	local mouseSelection
	if inMiniMapSel then
		mouseSelection = GetUnitsInMinimapRectangle(x, y)
	else
		mouseSelection = spGetUnitsInScreenRectangle(x1, y1, x2, y2, not spec and not isGodMode and -2) or {}		-- -2 = own units
	end

	local newSelection = {}
	local uid, udid

	local tmp = {}
	local n = 0
	local equalsMouseSelection = #mouseSelection == lastMouseSelectionCount
	if equalsMouseSelection and lastMouseSelectionCount == 0 and not mods.deselect and not mods.append then
		-- if its an empty selection but reference selection isn't empty consider
		-- it non equal so deselect by selecting empty space always works.
		-- skip if deselect or append since it won't deselect on empty selection.
		equalsMouseSelection = #referenceSelection == 0
	end

	for i = 1, #mouseSelection do
		uid = mouseSelection[i]
		if not spGetUnitNoSelect(uid) and -- filter unselectable units
			 -- filter gaia units + ignored units (objects)
			(isGodMode or ((not spec or spGetUnitTeam(uid) ~= GaiaTeamID) and not ignoreUnits[spGetUnitDefID(uid)])) then
			n = n + 1
			tmp[n] = uid
			if equalsMouseSelection and not lastMouseSelection[uid] then
				equalsMouseSelection = false
			end
		end
	end
	if equalsMouseSelection
		and mods.idle == lastMods[1]
		and mods.same == lastMods[2]
		and mods.deselect == lastMods[3]
		and mods.all == lastMods[4]
		and mods.mobile == lastMods[5]
		and mods.append == lastMods[6]
		and mods.any == lastMods[7]
		and customFilterDef == lastCustomFilterDef
	then
		return
	end

	lastMods = { mods.idle, mods.same, mods.deselect, mods.all, mods.mobile, mods.append, mods.any }
	lastCustomFilterDef = customFilterDef

	-- Fill dictionary for set comparison
	-- We increase slightly the perf cost of cache misses but at the same
	-- we hit caches way more often. At thousands of units, this improvement
	-- is massive
	lastMouseSelection = {}
	lastMouseSelectionCount = #mouseSelection
	for i = 1, #mouseSelection do
		lastMouseSelection[mouseSelection[i]] = true
	end

	mouseSelection = tmp

	if next(customFilter) ~= nil then -- use custom filter if it's not empty
		tmp = {}
		for i = 1, #mouseSelection do
			uid = mouseSelection[i]

			if selectApi.unitPassesFilter(uid, customFilter) then
				tmp[#tmp + 1] = uid
			end
		end

		if #tmp ~= 0 then -- treat the filter as a preference
			mouseSelection = tmp -- if no units match, just keep everything
		end
	end

	if mods.idle then
		tmp = {}
		for i = 1, #mouseSelection do
			uid = mouseSelection[i]
			udid = spGetUnitDefID(uid)
			if spGetUnitCommandCount(uid) == 0 then
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

	elseif selectBuildingsWithMobile == false and (mods.any == false and mods.all == false) and mods.deselect == false then
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

	if mods.deselect then -- deselect units inside the selection rectangle, if we already had units selected
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
		selectedUnits = newSelection
		spSelectUnitArray(selectedUnits)

	elseif (mods.append or mods.all) then  -- append units inside selection rectangle to current selection
		spSelectUnitArray(newSelection)
		spSelectUnitArray(mouseSelection, true)
		selectedUnits = Spring.GetSelectedUnits()

	elseif #mouseSelection > 0 then  -- select units inside selection rectangle
		selectedUnits = mouseSelection
		spSelectUnitArray(selectedUnits)

	elseif #mouseSelection == 0 then
		selectedUnits = {}
		spSelectUnitArray(selectedUnits)

	else  -- keep current selection while dragging until more things are selected
		selectedUnits = referenceSelection
		spSelectUnitArray(selectedUnits)
	end
end

--- Profiling Update, remember to change widget:Update to local function update above
--
--local spGetTimer = Spring.GetTimer
--local highres = nil
--if Spring.GetTimerMicros and  Spring.GetConfigInt("UseHighResTimer", 0) == 1 then
--	spGetTimer = Spring.GetTimerMicros
--	highres = true
--end
--
--function widget:Update()
--	local sTimer = spGetTimer()
--
--	update()
--
--	Spring.Echo('Update time:', Spring.DiffTimers(spGetTimer(), sTimer, nil, highres))
--end
--
function widget:Shutdown()
	WG['smartselect'] = nil

	WG.SmartSelect_MousePress2 = nil
end

function widget:Initialize()
	WG.SmartSelect_MousePress2 = mousePress

	for modifierName, _ in pairs(mods) do
		widgetHandler:AddAction("selectbox_" .. modifierName, handleSetModifier, { modifierName, true }, "p")
		widgetHandler:AddAction("selectbox_" .. modifierName, handleSetModifier, { modifierName, false }, "r")
	end

	widgetHandler:AddAction("selectbox", handleSetCustomFilter, nil, "p")
	widgetHandler:AddAction("selectbox", handleClearCustomFilter, nil, "r")

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

	widget:ViewResize()
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
