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

local includeNanosAsMobile = true -- TODO
local customFilterLookup = {}


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
				return Spring.GetUnitGroup(uid) ~= nil
			end)
		elseif token == "InGroup" then
			local group = tonumber(getNextToken())
			if not group then
				break
			end

			filters.inGroup = invertCurry(invert, function(_, _, uid, selectGroup)
				local unitGroup = Spring.GetUnitGroup(uid)
				return unitGroup == selectGroup
			end, group)
		elseif token == "InPrevSel" then
			filters.inPrevSel = invertCurry(invert, function(udef, _, uid)
				local isSelected = Spring.IsUnitSelected(uid)
				return isSelected
			end)

			-- number comparison
		elseif token == "AbsoluteHealth" then
			local minHealth = tonumber(getNextToken())
			if not minHealth then
				break
			end

			filters.absoluteHealth = invertCurry(invert, function(_, _, uid, minHealth)
				local health = Spring.GetUnitHealth(uid)
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
				local health = Spring.GetUnitHealth(uid)
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
		elseif token == "NameContain" then
			local name = getNextToken()
			if not name then
				break
			end

			filters.name = invertCurry(invert, function(udef, _, _, name)
				return stringContains(udef.name, name)
			end, name)
		end
	end

	return filters
end

local function getFilter(filterDef)
	local filters = customFilterLookup[filterDef]

	if filters == nil then
		filters = parseFilter(filterDef)
		customFilterLookup[filterDef] = filters
	end

	return filters
end

local function unitPassesFilter(uid, filterFns)
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

return {
	parseFilter = parseFilter,
	getFilter = getFilter,
	unitPassesFilter = unitPassesFilter
}
