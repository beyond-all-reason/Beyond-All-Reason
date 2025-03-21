--- @class SelectApi
--- @field getFilter fun(ruleDef: string): table
--- @field unitPassesFilter fun(uid: any, filter: any): boolean
--- @field getCommand fun(cmd: string): any
local SelectApi = {}

local defaultdamagetag = Game.armorTypes['default']
local vtoldamagetag = Game.armorTypes['vtol']

local spGetUnitIsCloaked = Spring.GetUnitIsCloaked
local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitGroup = Spring.GetUnitGroup
local spGetUnitHealth = Spring.GetUnitHealth
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spIsUnitSelected = Spring.IsUnitSelected
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitPosition = Spring.GetUnitPosition

local customFilterLookup = {}
local customCommandLookup = {}

local filterCache = {}

local function handleCaching(invert, tokenLower, filterFunction, optionalArg)
	if optionalArg == nil then
		optionalArg = false
	end

	if not filterCache[tokenLower] then
		filterCache[tokenLower] = {}
	end

	if not filterCache[tokenLower][optionalArg] then
		filterCache[tokenLower][optionalArg] = {}
	end

	local cache = filterCache[tokenLower][optionalArg]

	return function(udef)
		if cache[udef] == nil then
			local result = filterFunction(udef, optionalArg)
			-- handle invert explicitly here for caching
			result = (result or false) ~= invert
			cache[udef] = result
		end
		return cache[udef]
	end
end

local function logError(message)
	Spring.Log("Select API", LOG.ERROR, message)
end

local function isBuilder(udef)
	return (udef.canReclaim and udef.reclaimSpeed > 0) or
		(udef.canResurrect and udef.resurrectSpeed > 0) or
		(udef.canRepair and udef.repairSpeed > 0) or
		(udef.buildOptions and udef.buildOptions[1]) or
		(udef.canStockpile and udef.modCategories.ship and udef.modCategories.noweapon) -- carrier ships
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
	local cmd = spGetUnitCommands(uid, index)
	if cmd and cmd[index] and cmd[index]["id"] == cmdId then
		return true
	end
	return false
end

local function isIdle(udef, _udefid, uid)
	return spGetUnitCommandCount(uid) == 0
end

local function stringContains(mainString, searchString)
	return mainString:find(searchString, 1, true) ~= nil
end

-- filter
local function parseFilter(filterDef)
	local tokens = {}
	local tokenIndex = 1

	tokens = filterDef:split("_")

	local function getNextToken()
		local token = tokens[tokenIndex]
		tokenIndex = tokenIndex + 1
		return token
	end

	local filters = {}
	local invertIdMatches = nil
	local idMatchesSet = {}

	while true do
		local invert = false
		local token = getNextToken()

		if not token then
			break
		end

		local tokenLower = string.lower(token)

		if tokenLower == "not" then
			invert = true;
			token = getNextToken()
			tokenLower = string.lower(token)
		end

		if not token then
			break
		end

		-- simple filters
		if tokenLower == "aircraft" then
			filters.aircraft = simpleUdefFilter(invert, "canFly")
		elseif tokenLower == "builder" then
			filters.builder = handleCaching(invert, tokenLower, function(udef)
				return isBuilder(udef)
			end)
		elseif tokenLower == "buildoptions" then
			filters.buildOptions = notEmptyUdefFilter(invert, "buildOptions")
		elseif tokenLower == "building" then
			filters.building = simpleUdefFilter(invert, "isBuilding")
		elseif tokenLower == "cloak" then
			filters.cloak = simpleUdefFilter(invert, "canCloak")
		elseif tokenLower == "cloaked" then
			filters.cloaked = invertCurry(invert, function(udef, _, uid)
				return udef.canCloak and spGetUnitIsCloaked(uid)
			end)
		elseif tokenLower == "jammer" then
			filters.jammer = handleCaching(invert, tokenLower, function(udef)
				return udef.jammerRadius > 0
			end)
		elseif tokenLower == "manualfireunit" then
			filters.manualFire = simpleUdefFilter(invert, "canManualFire")
		elseif tokenLower == "radar" then
			filters.radar = handleCaching(invert, tokenLower, function(udef)
				return udef.radarRadius > 0 or udef.sonarRadius > 0
			end)
		elseif tokenLower == "resurrect" then
			filters.resurrect = simpleUdefFilter(invert, "canResurrect")
		elseif tokenLower == "stealth" then
			filters.stealth = simpleUdefFilter(invert, "stealth")
		elseif tokenLower == "transport" then
			filters.transport = simpleUdefFilter(invert, "isTransport")
		elseif tokenLower == "weapons" then
			filters.weapons = notEmptyUdefFilter(invert, "weapons")

			-- command queue filters
		elseif tokenLower == "idle" then
			filters.idle = invertCurry(invert, isIdle)
		elseif tokenLower == "guarding" then
			filters.guarding = invertCurry(invert, function(_udef, _udefid, uid)
				return checkCmd(uid, CMD.GUARD)
			end)
		elseif tokenLower == "waiting" then
			filters.waiting = invertCurry(invert, function(_udef, _udefid, uid)
				return checkCmd(uid, CMD.WAIT)
			end)
		elseif tokenLower == "patrolling" then
			filters.patrolling = invertCurry(invert, function(_udef, _udefid, uid)
				-- patrol is implemented using the command queue
				-- so need to check the first four positions
				for i = 1, 4, 1 do
					if checkCmd(uid, CMD.PATROL, i) then
						return true
					end
				end
				return false
			end)

			-- hotkey filters
		elseif tokenLower == "inhotkeygroup" then
			filters.inHotKeyGroup = invertCurry(invert, function(_, _, uid)
				return spGetUnitGroup(uid) ~= nil
			end)
		elseif tokenLower == "ingroup" then
			local group = tonumber(getNextToken())
			if not group then
				break
			end

			filters.inGroup = invertCurry(invert, function(_, _, uid, selectGroup)
				local unitGroup = spGetUnitGroup(uid)
				return unitGroup == selectGroup
			end, group)
		elseif tokenLower == "inprevsel" or tokenLower == "inpreviousselection" then
			filters.inPreviousSelection = invertCurry(invert, function(udef, _, uid)
				local isSelected = spIsUnitSelected(uid)
				return isSelected
			end)

			-- number comparison
		elseif tokenLower == "absolutehealth" then
			local minHealth = tonumber(getNextToken())
			if not minHealth then
				break
			end

			filters.absoluteHealth = invertCurry(invert, function(_, _, uid, minHealth)
				local health = spGetUnitHealth(uid)
				return health > minHealth
			end, minHealth)
		elseif tokenLower == "relativehealth" then
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
		elseif tokenLower == "antiair" then
			filters.antiAir = handleCaching(invert, tokenLower, function(udef)
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
		elseif tokenLower == "weaponrange" then
			local minRange = tonumber(getNextToken())
			if minRange == nil then
				break
			end

			filters.weaponRange = handleCaching(invert, tokenLower, function(udef, minRange)
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

			-- string comparison
		elseif tokenLower == "category" then
			local category = getNextToken()
			if not category then
				break
			end

			category = string.lower(category)

			filters.category = handleCaching(invert, tokenLower, function(udef, category)
				return udef.modCategories[category]
			end, category)
		elseif tokenLower == "idmatches" then
			local name = getNextToken()
			if not name then
				break
			end

			local udefid = UnitDefNames[name];

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
		elseif tokenLower == "namecontain" then
			local name = getNextToken()
			if not name then
				break
			end

			filters.name = handleCaching(invert, tokenLower, function(udef, name)
				return stringContains(udef.name, name)
			end, name)
		else
			logError(token .. " is not a valid filter")
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
--- @param filterFunctions table List of filter functions
--- @return boolean? passes Whether the unit passes the filter, nil if the unit doesn't exist
function SelectApi.unitPassesFilter(uid, filterFunctions)
	local udefid = spGetUnitDefID(uid)

	if not udefid then
		return nil
	end

	local udef = UnitDefs[udefid]

	for _filterName, filterFunction in pairs(filterFunctions) do
		if not filterFunction(udef, udefid, uid) then
			return false
		end
	end

	return true
end

-- command
local function startsWith(str, prefix)
	return str:match("^" .. prefix) ~= nil
end

local function getAlreadySelectedSet()
	local alreadySelectedUnits = spGetSelectedUnits()
	local alreadySelectedSet = {}

	for _, unit in ipairs(alreadySelectedUnits) do
		alreadySelectedSet[unit] = true
	end

	return alreadySelectedSet
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

local function parseNumber(input, fn)
	if input == nil then
		logError("Invalid input, unexpected nil")
		return function(args)
			return fn(0, args)
		end
	end

	local numStr = input:match("_([^_]+)")
	local distance = tonumber(numStr)

	if distance == nil then
		logError("Invalid input, expected a number after the underscore: " .. input)
	end

	return function(args)
		return fn(distance or 0, args)
	end
end


local function parseConclusion(conclusionDef)
	local appendSelected = true
	local prefix = conclusionDef:sub(1, 15)
	local prefixLower = string.lower(prefix)

	if prefixLower == "clearselection_" then
		appendSelected = false
		conclusionDef = conclusionDef:sub(16)
	end

	local conclusionDefLower = string.lower(conclusionDef)

	if conclusionDefLower == "selectall" then
		return function(uids)
			Spring.SelectUnitArray(uids, appendSelected)
		end
	elseif conclusionDefLower == "selectone" then
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
	elseif conclusionDefLower == "selectclosesttocursor" then
		return function(uids)
			if not uids or #uids == 0 then
				Spring.SelectUnitArray({}, appendSelected)
				return
			end

			local x, y, z = getMouseWorldPos()
			if x == nil or y == nil or z == nil then
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

				if closest_distance == nil or distance < closest_distance then
					closest_uid = uid
					closest_distance = distance
				end
			end

			local oneUid = { closest_uid }
			Spring.SelectUnitArray(oneUid, appendSelected)
		end
	elseif startsWith(conclusionDefLower, "selectnum_") or startsWith(conclusionDefLower, "selectnumber_") then
		return parseNumber(conclusionDef, function(countUntil, uids)
			uids = getCountUnits(uids, countUntil, appendSelected)
			Spring.SelectUnitArray(uids, appendSelected)
		end)
	elseif startsWith(conclusionDefLower, "selectpart_") then
		return parseNumber(conclusionDef, function(percent, uids)
			local countUntil = math.floor(#uids * percent / 100)
			uids = getCountUnits(uids, countUntil, appendSelected)
			Spring.SelectUnitArray(uids, appendSelected)
		end)
	else
		logError(conclusionDef .. " is not a valid conclusion")
	end
end

local function parseSource(sourceDef)
	local sourceDefLower = string.lower(sourceDef)

	if sourceDefLower == "allmap" then
		return function()
			local myTeamId = Spring.GetMyTeamID()
			return Spring.GetTeamUnits(myTeamId)
		end
	elseif sourceDefLower == "visible" then
		return function()
			local myTeamId = Spring.GetMyTeamID()
			return Spring.GetVisibleUnits(myTeamId)
		end
	elseif sourceDefLower == "prevselection" or sourceDefLower == "previousselection" then
		return function()
			return spGetSelectedUnits()
		end
	elseif startsWith(sourceDefLower, "frommouse_") then
		return parseNumber(sourceDef, function(distance)
			local x, y, z = getMouseWorldPos()
			if x and y and z then
				return Spring.GetUnitsInSphere(x, y, z, distance)
			else
				return {}
			end
		end)
	elseif startsWith(sourceDefLower, "frommousec_") or startsWith(sourceDefLower, "frommousecylinder_") then
		return parseNumber(sourceDef, function(distance)
			local x, y, z = getMouseWorldPos()
			if x and z then
				return Spring.GetUnitsInCylinder(x, z, distance)
			else
				return {}
			end
		end)
	else
		logError(sourceDef .. " is not a valid source")
	end
end

local function commandFormatError(commandDef)
	logError("Select command string does not match the expected format: " .. commandDef)
end

local function parseCommand(commandDef)
	local sourceDef, filterDef, conclusionDef = commandDef:match("(.-)%+_(.-)%+_(.-)%+$")

	if not sourceDef or not filterDef or not conclusionDef then
		commandFormatError(commandDef)
		return
	end

	local source = parseSource(sourceDef)
	local filter = SelectApi.getFilter(filterDef)
	local conclusion = parseConclusion(conclusionDef)

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
