--- @class SelectApi
--- @field getFilter fun(ruleDef: string): table
--- @field unitPassesFilter fun(uid: any, filter: any): boolean
--- @field getCommand fun(cmd: string): any
local SelectApi = {}

-- command definitions from https://github.com/beyond-all-reason/spring/blob/BAR105/rts/Sim/Units/CommandAI/Command.h
local CMD_STOP = 0
local CMD_WAIT = 5
local CMD_PATROL = 15
local CMD_GUARD = 25

local defaultdamagetag = Game.armorTypes['default']
local vtoldamagetag = Game.armorTypes['vtol']

local spGetUnitIsCloaked = Spring.GetUnitIsCloaked
local spGetCommandQueue = Spring.GetCommandQueue
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitGroup = Spring.GetUnitGroup
local spGetUnitHealth = Spring.GetUnitHealth
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spIsUnitSelected = Spring.IsUnitSelected
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitPosition = Spring.GetUnitPosition

local includeNanosAsMobile = true -- TODO
local customFilterLookup = {}
local customCommandLookup = {}

local function isBuilder(udef)
	return (udef.canReclaim and udef.reclaimSpeed > 0) or                         -- reclaim
		(udef.canResurrect and udef.resurrectSpeed > 0) or                        -- resurrect
		(udef.canRepair and udef.repairSpeed > 0) or                              -- repair
		(udef.buildOptions and udef.buildOptions[1]) or                           -- build options
		(udef.canStockpile and udef.modCategories.ship and udef.modCategories.noweapon) -- is carrier ship
end

local nameLookup = {}

for udid, udef in pairs(UnitDefs) do
	nameLookup[udef.name] = udid
end

local function invertCurry(invert, filter, args)
	return function(udef, udefid, uid)
		local result = filter(udef, udefid, uid, args)
		result = (result or false) ~= invert
		return result
	end
end

local function simpleUdefFilter(invert, property)
	return invertCurry(invert, function(udef)
		return udef[property]
	end)
end

local function notEmptyUdefFilter(invert, property)
	return invertCurry(invert, function(udef)
		local table = udef[property]
		if table and next(table) ~= nil then
			return true
		end
		return false
	end)
end

local function checkCmd(uid, cmdId, indexTemp)
	local index = indexTemp or 1
	local cmd = spGetCommandQueue(uid, index)
	if cmd and cmd[index] and cmd[index]["id"] == cmdId then
		return true
	end
	return false
end

local function isIdle(udef, _udefid, uid)
	return spGetCommandQueue(uid, 0) == 0
end

local function stringContains(mainString, searchString)
	return mainString:find(searchString, 1, true) ~= nil
end

-- filter
local function parseFilter(filterDef)
	local tokens = {}
	local tokenIndex = 1

	for token in filterDef:gmatch("[^_]+") do
		table.insert(tokens, token)
	end

	local function getNextToken()
		local token = tokens[tokenIndex]
		tokenIndex = tokenIndex + 1
		return token
	end

	local filters = {}
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

		-- simple filters
		if token == "Aircraft" then
			filters.aircraft = simpleUdefFilter(invert, "canFly")
		elseif token == "Builder" then
			filters.builder = invertCurry(invert, function(udef)
				return isBuilder(udef)
			end)
		elseif token == "Buildoptions" then
			filters.buildOptions = notEmptyUdefFilter(invert, "buildOptions")
		elseif token == "Building" then
			filters.building = simpleUdefFilter(invert, "isBuilding")
		elseif token == "Cloak" then
			filters.cloak = simpleUdefFilter(invert, "canCloak")
		elseif token == "Cloaked" then
			filters.cloaked = invertCurry(invert, function(udef, _, uid)
				return udef.canCloak and spGetUnitIsCloaked(uid)
			end)
		elseif token == "Jammer" then
			filters.jammer = invertCurry(invert, function(udef)
				return udef.jammerRadius > 0
			end)
		elseif token == "ManualFireUnit" then
			filters.manualFire = simpleUdefFilter(invert, "canManualFire")
		elseif token == "Radar" then
			filters.radar = invertCurry(invert, function(udef)
				return udef.radarRadius > 0 or udef.sonarRadius > 0
			end)
		elseif token == "Resurrect" then
			filters.resurrect = simpleUdefFilter(invert, "canResurrect")
		elseif token == "Stealth" then
			filters.stealth = simpleUdefFilter(invert, "stealth")
		elseif token == "Transport" then
			filters.transport = simpleUdefFilter(invert, "isTransport")
		elseif token == "Weapons" then
			filters.weapons = notEmptyUdefFilter(invert, "weapons")

			-- command queue filters
		elseif token == "Idle" then
			filters.idle = invertCurry(invert, isIdle)
		elseif token == "Guarding" then
			filters.guarding = invertCurry(invert, function(_udef, _udefid, uid)
				return checkCmd(uid, CMD_GUARD)
			end)
		elseif token == "Waiting" then
			filters.waiting = invertCurry(invert, function(_udef, _udefid, uid)
				return checkCmd(uid, CMD_WAIT)
			end)
		elseif token == "Patrolling" then
			filters.patrolling = invertCurry(invert, function(_udef, _udefid, uid)
				for i = 1, 4, 1 do
					if checkCmd(uid, CMD_PATROL, i) then
						return true
					end
				end
				return false
			end)

			-- hotkey filters
		elseif token == "InHotkeyGroup" then
			filters.inHotKeyGroup = invertCurry(invert, function(_, _, uid)
				return spGetUnitGroup(uid) ~= nil
			end)
		elseif token == "InGroup" then
			local group = tonumber(getNextToken())
			if not group then
				break
			end

			filters.inGroup = invertCurry(invert, function(_, _, uid, selectGroup)
				local unitGroup = spGetUnitGroup(uid)
				return unitGroup == selectGroup
			end, group)
		elseif token == "InPrevSel" then
			filters.inPrevSel = invertCurry(invert, function(udef, _, uid)
				local isSelected = spIsUnitSelected(uid)
				return isSelected
			end)

			-- number comparison
		elseif token == "AbsoluteHealth" then
			local minHealth = tonumber(getNextToken())
			if not minHealth then
				break
			end

			filters.absoluteHealth = invertCurry(invert, function(_, _, uid, minHealth)
				local health = spGetUnitHealth(uid)
				return health > minHealth
			end, minHealth)
		elseif token == "RelativeHealth" then
			local minHealthPercent = tonumber(getNextToken())
			if not minHealthPercent then
				break
			end
			minHealthPercent = minHealthPercent / 100.0

			filters.relativeHealth = invertCurry(invert, function(udef, _, uid, minHealthPercent)
				local minHealth = minHealthPercent * udef.health
				local health = spGetUnitHealth(uid)
				return health > minHealth
			end, minHealthPercent)
			-- elseif token == "RulesParamEquals" then
			-- 	local param = getNextToken()
			-- 	local value = getNextToken()

			-- 	if not value or not param then
			-- 		break
			-- 	end

			-- 	local filterName = param .. "Rule"
			-- 	filters[filterName] = invertCurry(invert, function(udef, _, uid, args)
			-- 		local param = args.param
			-- 		local value = args.value
			-- 		-- implementation here?
			-- 	end, {param = param, value = value})
		elseif token == "AntiAir" then
			filters.antiAir = invertCurry(invert, function(udef)
				if udef.wDefs == nil or udef.canFly then
					return false
				end

				for _name, weapondef in pairs(udef.wDefs) do
					if (weapondef.damages[vtoldamagetag] > weapondef.damages[defaultdamagetag]) then
						return true
					end
				end
				return false
			end)
		elseif token == "WeaponRange" then
			local minRange = tonumber(getNextToken())
			if not minRange then
				break
			end

			filters.weaponRange = invertCurry(invert, function(udef, _, _, minRange)
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

			category = string.lower(category)

			filters.category = invertCurry(invert, function(udef, _, _, category)
				return udef.modCategories[category]
			end, category)
		elseif token == "IdMatches" then
			local name = getNextToken()
			if not name then
				break
			end

			local udefid = nameLookup[name];

			if udefid then
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
					filters.idMatches = invertCurry(invertIdMatches, function(_, udefid, _, idMatchesSet)
						return idMatchesSet[udefid] or false
					end, idMatchesSet)
				end
			end
		elseif token == "NameContain" then
			local name = getNextToken()
			if not name then
				break
			end

			filters.name = invertCurry(invert, function(udef, _, _, name)
				return stringContains(udef.translatedHumanName, name)
			end, name)
		else
			error(token .. " is not a valid filter")
		end
	end

	return filters
end

--- Parses the filter definition and returns a function that determines if a unit passes the
--- filter.
---
--- The parsing will only occure the first time this function is called, after that it is stored in
--- a lookup table.
--- @param filterDef string The filter definition string.
--- @return function the function to call to execute the filter
function SelectApi.getFilter(filterDef)
	local filters = customFilterLookup[filterDef]

	if filters == nil then
		filters = parseFilter(filterDef)
		customFilterLookup[filterDef] = filters
	end

	return filters
end

--- Applies the filter function to the unit represented by the unit ID to determine if the unit
--- passes the filter.
---
--- @param uid integer The unit ID
--- @param filterFns table List of filter functions
--- @return boolean? passes Whether the unit passes the filter, nil if the unit doesn't exist
function SelectApi.unitPassesFilter(uid, filterFns)
	local udefid = spGetUnitDefID(uid)

	if not udefid then
		return nil
	end

	local udef = UnitDefs[udefid]

	for _filterName, filterFn in pairs(filterFns) do
		if not filterFn(udef, udefid, uid) then
			return false
		end
	end

	return true
end

-- command
local function startsWith(str, prefix)
	return str:match("^" .. prefix) ~= nil
end

local function getMouseWorldPos()
	local mouseX, mouseY = spGetMouseState()
	local desc, args = spTraceScreenRay(mouseX, mouseY, true)

	if nil == desc then return end -- off map
	if nil == args then return end

	local x = args[1]
	local y = args[2]
	local z = args[3]

	return x, y, z
end

local countUnitsIndex = 1
local function getCountUnits(uids, countUntil, appendSelected)
	if #uids == 0 then
		return {}
	end

	local alreadySelectedSet = {}

	if appendSelected then
		alreadySelectedSet = getAlreadySelectedSet()
	end

	-- add countUntil units that aren't in alreadySelectedSet
	local selectedCount = 0
	local units = {}

	if countUnitsIndex > #uids then
		countUnitsIndex = 1
	end

	local countUnitsIndexStart = countUnitsIndex
	while true do
		local uid = uids[countUnitsIndex]

		if not alreadySelectedSet[uid] then
			selectedCount = selectedCount + 1
			table.insert(units, uid)
		end

		-- circular array index
		countUnitsIndex = countUnitsIndex + 1

		if countUnitsIndex > #uids then
			countUnitsIndex = 1
		end

		-- break after full cycle or countUntil reached
		if countUnitsIndex == countUnitsIndexStart or selectedCount >= countUntil then
			break;
		end
	end

	return units
end


function getAlreadySelectedSet()
	local alreadySelectedUnits = Spring.GetSelectedUnits()
	local alreadySelectedSet = {}

	for _, unit in ipairs(alreadySelectedUnits) do
		alreadySelectedSet[unit] = true
	end

	return alreadySelectedSet
end

local function parseNumber(input, fn)
	local numStr = input:match("_([^_]+)")
	local distance = tonumber(numStr)

	if not distance then
		error("Invalid input: expected a number after the underscore.")
	end

	return function(args)
		return fn(distance, args)
	end
end


local function parseConclusion(conclusionDef, commandDef)
	local appendSelected = true
	local prefix = conclusionDef:sub(1, 15)

	if prefix == "ClearSelection_" then
		appendSelected = false
		conclusionDef = conclusionDef:sub(16)
	end

	if conclusionDef == "SelectAll" then
		return function(uids)
			Spring.SelectUnitArray(uids, appendSelected)
		end
	elseif conclusionDef == "SelectOne" then
		return function(uids)
			if #uids == 0 then
				Spring.SelectUnitArray({}, appendSelected)
				return
			end

			uids = getCountUnits(uids, 1, appendSelected)
			local uid = uids[1]

			if not uid then
				Spring.SelectUnitArray({}, appendSelected)
				return
			end

			-- center on unit
			local ux, uy, uz = spGetUnitPosition(uid)
			Spring.SetCameraTarget(ux, uy, uz, 1)
			Spring.SelectUnitArray(uids, appendSelected)
		end
	elseif conclusionDef == "SelectClosestToCursor" then
		return function(uids)
			if #uids == 0 then
				Spring.SelectUnitArray({}, appendSelected)
				return
			end

			local x, y, z = getMouseWorldPos()

			if not x or not y or not z then
				Spring.SelectUnitArray({}, appendSelected)
				return
			end

			local closest_uid = nil
			local closest_distance = nil

			for _, uid in pairs(uids) do
				local ux, uy, uz = spGetUnitPosition(uid)
				local dx = x - ux
				local dy = y - uy
				local dz = z - uz

				local distance = dx * dx + dy * dy + dz * dz

				if not closest_distance or distance < closest_distance then
					closest_uid = uid
					closest_distance = distance
				end
			end

			local oneUid = { closest_uid }
			Spring.SelectUnitArray(oneUid, appendSelected)
		end
	elseif startsWith(conclusionDef, "SelectNum_") then
		return parseNumber(conclusionDef, function(countUntil, uids)
			uids = getCountUnits(uids, countUntil, appendSelected)
			Spring.SelectUnitArray(uids, appendSelected)
		end)
	elseif startsWith(conclusionDef, "SelectPart_50+") then
		return parseNumber(conclusionDef, function(percent, uids)
			local countUntil = math.floor(#uids * percent / 100)
			uids = getCountUnits(uids, countUntil, appendSelected)
			Spring.SelectUnitArray(uids, appendSelected)
		end)
	else
		error(conclusionDef .. " is not a valid conclusion")
	end
end

local function parseSource(sourceDef)
	if sourceDef == "AllMap" then
		return function()
			local myTeamId = Spring.GetMyTeamID()
			return Spring.GetTeamUnits(myTeamId)
		end
	elseif sourceDef == "Visible" then
		return function()
			local myTeamId = Spring.GetMyTeamID()
			return Spring.GetVisibleUnits(myTeamId)
		end
	elseif sourceDef == "PrevSelection" then
		return function()
			return Spring.GetSelectedUnits()
		end
	elseif startsWith(sourceDef, "FromMouse_") then
		return parseNumber(sourceDef, function(distance)
			local x, y, z = getMouseWorldPos()
			if z and y and z then
				return Spring.GetUnitsInSphere(x, y, z, distance)
			else
				return {}
			end
		end)
	elseif startsWith(sourceDef, "FromMouseC_") then
		return parseNumber(sourceDef, function(distance)
			local x, y, z = getMouseWorldPos()
			if x and z then
				return Spring.GetUnitsInCylinder(x, z, distance)
			else
				return {}
			end
		end)
	else
		error(sourceDef .. " is not a valid source")
	end
end

local function commandFormatError(commandDef)
	error("select command string " .. commandDef .. " does not match the expected format")
end

local function parseCommand(commandDef)
	local sourceDef, filterDef, conclusionDef = commandDef:match("(.-)%+_(.-)%+_(.-)%+$")

	if not sourceDef or not filterDef or not conclusionDef then
		commandFormatError(commandDef)
		return
	end

	local source = parseSource(sourceDef)
	local filter = SelectApi.getFilter(filterDef)
	local conclusion = parseConclusion(conclusionDef, commandDef)

	return function()
		local uids = source()

		local tmp = {}
		for _, uid in pairs(uids) do
			if SelectApi.unitPassesFilter(uid, filter) then
				tmp[#tmp + 1] = uid
			end
		end

		conclusion(tmp)
	end
end

--- Parses the command definition and returns a function that will execute the command.
---
--- The parsing will only occur the first time this function is called, after that it is stored in
--- a lookup table.
--- @param commandDef string The command definition string.
--- @return function the function to call to execute the command
function SelectApi.getCommand(commandDef)
	local command = customCommandLookup[commandDef]

	if command == nil then
		command = parseCommand(commandDef)
		customCommandLookup[commandDef] = command
	end

	return command
end

return SelectApi
