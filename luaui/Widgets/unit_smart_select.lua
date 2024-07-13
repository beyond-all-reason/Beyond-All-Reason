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

-- command definitions from https://github.com/beyond-all-reason/spring/blob/BAR105/rts/Sim/Units/CommandAI/Command.h
local CMD_STOP = 0
local CMD_WAIT = 5
local CMD_PATROL = 15
local CMD_GUARD = 25

local minimapToWorld = VFS.Include("luaui/Widgets/Include/minimap_utils.lua").minimapToWorld
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
 all      = false, -- whether to select all units
 mobile   = false, -- whether to select only mobile units
}
local customFilterDef = ""
local lastMods = mods
local lastCustomFilterDef = customFilterDef
local lastMouseSelection = {}
local lastMouseSelectionCount = 0

local spGetMouseState = Spring.GetMouseState
local spGetModKeyState = Spring.GetModKeyState
local spGetSelectionBox = Spring.GetSelectionBox

local spIsGodModeEnabled = Spring.IsGodModeEnabled

local spGetUnitsInScreenRectangle = Spring.GetUnitsInScreenRectangle
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spSelectUnitArray = Spring.SelectUnitArray
local spGetActiveCommand = Spring.GetActiveCommand
local spGetUnitTeam = Spring.GetUnitTeam

local spIsAboveMiniMap = Spring.IsAboveMiniMap

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsCloaked = Spring.GetUnitIsCloaked
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
local customFilter = {}

local nameLookup = {}

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

	-- simple filters
	nameLookup[udef.name] = udid
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

	return spGetUnitsInRectangle(left, bottom, right, top)
end

local function handleSetModifier(_, _, _, data)
	mods[data[1]] = data[2]
end

local function invertCurry(invert, rule, args)
	return function(udef, udefid, uid)
		local result = rule(udef, udefid, uid, args)
		result = (result or false) ~= invert
		return result
	end
end

local function simpleUdefRule(invert, property)
	return invertCurry(invert, function(udef)
		return udef[property]
	end)
end

local function notEmptyUdefRule(invert, property)
	return invertCurry(invert, function(udef)
		local table = udef[property]
		if table and next(table) ~= nil then
			return true
		end
		return false
	end)
end

local function isIdle(_udef, udefid, uid)
	local canBeIdle = mobileFilter[udefid] or builderFilter[udefid]
	return canBeIdle and spGetCommandQueue(uid, 0) == 0
end

local function stringContains(mainString, searchString)
	return mainString:find(searchString, 1, true) ~= nil
end

local function handleSetCustomFilter(_, args)
	local tokens = {}
	local tokenIndex = 1

	for token in args:gmatch("[^_]+") do
		table.insert(tokens, token)
	end

	local function getNextToken()
		local token = tokens[tokenIndex]
		tokenIndex = tokenIndex + 1
		return token
	end

	local rules = {}
	local invertIdMatches = nil
	local idMatchesSet = {}

	while true do
		local token = getNextToken()
		local invert = false

		if token == "Not" then
			invert = true;
			token = getNextToken()
		end

		if not token then
			break
		end

		-- simple rules
		if token == "Aircraft" then
			rules.aircraftRule = simpleUdefRule(invert, "canFly")
		elseif token == "Builder" then
			rules.builderRule = invertCurry(invert, function(udef, udefid)
				return builderFilter[udefid] and not udef.canResurrect
			end)
		elseif token == "Buildoptions" then
			rules.buildOptionsRule = notEmptyUdefRule(invert, "buildOptions")
		elseif token == "Building" then
			rules.buildingRule = simpleUdefRule(invert, "isBuilding")
		elseif token == "Cloak" then
			rules.cloakRule = simpleUdefRule(invert, "canCloak")
		elseif token == "Cloaked" then
			rules.cloakedRule = invertCurry(invert, function(udef, _, uid)
				return udef.canCloak and spGetUnitIsCloaked(uid)
			end)
		elseif token == "Jammer" then
			rules.jammerRule = invertCurry(invert, function(udef)
				return udef.jammerRadius > 0
			end)
		elseif token == "ManualFireUnit" then
			rules.manualFireRule = simpleUdefRule(invert, "canManualFire")
		elseif token == "Radar" then
			rules.radarRule = invertCurry(invert, function(udef)
				return udef.radarRadius > 0 or udef.sonarRadius > 0
			end)
		elseif token == "Resurrect" then
			rules.resurrectRule = simpleUdefRule(invert, "canResurrect")
		elseif token == "Stealth" then
			rules.stealthRule = simpleUdefRule(invert, "stealth")
		elseif token == "Transport" then
			rules.transportRule = simpleUdefRule(invert, "isTransport")
		elseif token == "Weapons" then
			rules.weaponsRule = notEmptyUdefRule(invert, "weapons")

			-- command queue rules
		elseif token == "Idle" then
			rules.idleRule = invertCurry(invert, isIdle)
		elseif token == "Guarding" then
			rules.guardingRule = invertCurry(invert, function(udef, udefid, uid)
				return spGetCommandQueue(uid, 0) == CMD_GUARD;
			end)
		elseif token == "Waiting" then
			rules.waitingRule = invertCurry(invert, function(udef, udefid, uid)
				return spGetCommandQueue(uid, 0) == CMD_WAIT;
			end)
		elseif token == "Patrolling" then
			rules.patrollingRule = invertCurry(invert, function(udef, udefid, uid)
				for i = 0, 3, 1 do
					local cmd = spGetCommandQueue(uid, i)
					print("cmd: " .. cmd)
					if cmd == CMD_PATROL then
						return true
					end
				end
				return false
			end)

		-- hotkey rules
		elseif token == "InHotkeyGroup" then
			rules.inHotKeyGroup = invertCurry(invert, function(_, _, uid)
				return Spring.GetUnitGroup(uid) ~= nil
			end)
		elseif token == "InGroup" then
			local group = tonumber(getNextToken())
			if not group then
				break
			end

			rules.inGroup = invertCurry(invert, function(_, _, uid, selectGroup)
				local unitGroup = Spring.GetUnitGroup(uid)
				return unitGroup == selectGroup
			end, group)

			-- number comparison
		elseif token == "AbsoluteHealth" then
			local minHealth = tonumber(getNextToken())
			if not minHealth then
				break
			end
			print(minHealth)

			rules.absoluteHealthRule = invertCurry(invert, function(_, _, uid, minHealth)
				local health = Spring.GetUnitHealth(uid)
				return health > minHealth
			end, minHealth)
		elseif token == "RelativeHealth" then
			local minHealthPercent = tonumber(getNextToken())
			if not minHealthPercent then
				break
			end
			minHealthPercent = minHealthPercent / 100.0
			print(minHealthPercent)

			rules.relativeHealthRule = invertCurry(invert, function(udef, _, uid, minHealthPercent)
				local minHealth = minHealthPercent * udef.health
				local health = Spring.GetUnitHealth(uid)
				return health > minHealth
			end, minHealthPercent)
			-- elseif token == "RulesParamEquals" then
			-- 	local param = getNextToken()
			-- 	local value = getNextToken()

			-- 	if not value or not param then
			-- 		break
			-- 	end

			-- 	local ruleName = param .. "Rule"
			-- 	rules[ruleName] = invertCurry(invert, function(udef, _, uid, args)
			-- 		local param = args.param
			-- 		local value = args.value
			-- 		-- implementation here?
			-- 	end, {param = param, value = value})
		elseif token == "WeaponRange" then
			local minRange = tonumber(getNextToken())
			if not minRange then
				break
			end
			print(minRange)

			rules.weaponRangeRule = invertCurry(invert, function(udef, _, _, minRange)
				if udef.wDefs == nil then
					return false
				end

				for _name, weapondef in pairs(udef.wDefs) do
					if weapondef.range > minRange then
						return true
					end
				end
				return false
			end, minRange)

			-- string comparision
		elseif token == "Category" then
			local category = getNextToken()
			if not category then
				break
			end
			print(category)

			rules.categoryRule = invertCurry(invert, function(udef, _, _, category)
				if udef.category == nil then
					print(udef)
					return false
				end

				return stringContains(udef.category, category)
			end, category)
		elseif token == "IdMatches" then
			local name = getNextToken()
			if not name then
				break
			end
			print(name)

			local udefid = nameLookup[name];
			idMatchesSet[udefid] = true

			-- requires special invert logic
			-- treats `invert = false` as priority
			-- we don't want to handle pointless edge cases like IdMatches_armcom_Not_IdMatches_armcom
			-- on the other hand IdMatches_armcom_Not_IdMatches_armflea is basically the same as IdMatches_armcom
			local skip = false
			if invertIdMatches == nil or invertIdMatches == invert then
				invertIdMatches = invert
			elseif invertIdMatches == true then
				idMatchesSet = {}
				invertIdMatches = false
			elseif invertIdMatches == false then
				skip = true
			end

			if not skip then
				rules.idMatches = invertCurry(invertIdMatches, function(_, udefid, _, idMatchesSet)
					return idMatchesSet[udefid] or false
				end, idMatchesSet)
			end
		elseif token == "NameContain" then
			local name = getNextToken()
			if not name then
				break
			end
			print(name)

			rules.nameRule = invertCurry(invert, function(udef, _, _, name)
				return stringContains(udef.name, name)
			end, name)
		end
	end
	customFilterDef = args
	customFilter = rules
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
			-- we must clear selection to disambiguate from our own deselect modifier
			selectedUnits = {}
			spSelectUnitArray({})
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

function widget:Update()
	if skipSel or spGetActiveCommand() ~= 0 then
		return
	end

	local x, y, lmb = Spring.GetMouseState()
	if lmb == false then inMiniMapSel = false end

	-- get all units within selection rectangle
	local x1, y1, x2, y2 = spGetSelectionBox()

	inSelection = inMiniMapSel or (x1 ~= nil)
	if not inSelection then return end -- not in valid selection box (mouserelease/minimum threshold/chorded/etc)

	if #referenceSelection == 0 then  -- no point in inverting an empty selection
		mods.deselect = false
	end

	local mouseSelection
	if inMiniMapSel then
		mouseSelection = GetUnitsInMinimapRectangle(x, y)
	else
		mouseSelection = spGetUnitsInScreenRectangle(x1, y1, x2, y2, nil) or {}
	end

	local newSelection = {}
	local uid, udid, tmp

	tmp = {}
	local n = 0
	local equalsMouseSelection = #mouseSelection == lastMouseSelectionCount
	local isGodMode = spIsGodModeEnabled()

	for i = 1, #mouseSelection do
		uid = mouseSelection[i]
		if not spGetUnitNoSelect(uid) and -- filter unselectable units
			(isGodMode or (spGetUnitTeam(uid) ~= GaiaTeamID and not ignoreUnits[spGetUnitDefID(uid)] and (spec or spGetUnitTeam(uid) == myTeamID))) then -- filter gaia units + ignored units (objects) + only own units when not spectating
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
		and customFilterDef == lastCustomFilterDef
	then
		return
	end

	lastMods = { mods.idle, mods.same, mods.deselect, mods.all, mods.mobile }
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

			local udefid = spGetUnitDefID(uid)
			local udef = UnitDefs[udefid]
			local passesAllRules = true
			-- checkUdef(udef, "canManualFire")

			for _ruleName, rule in pairs(customFilter) do
				if not rule(udef, udefid, uid) then
					passesAllRules = false
					break
				end
			end

			if passesAllRules then
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
			if isIdle(nil, udid, uid) then
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

	elseif mods.all then  -- append units inside selection rectangle to current selection
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
