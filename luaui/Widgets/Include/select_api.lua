-- command definitions from https://github.com/beyond-all-reason/spring/blob/BAR105/rts/Sim/Units/CommandAI/Command.h
local CMD_STOP = 0
local CMD_WAIT = 5
local CMD_PATROL = 15
local CMD_GUARD = 25

local defaultdamagetag = Game.armorTypes['default']
local vtoldamagetag = Game.armorTypes['vtol']

local spGetUnitIsCloaked = Spring.GetUnitIsCloaked
local spGetCommandQueue = Spring.GetCommandQueue

local includeNanosAsMobile = true -- TODO
local customRulesLookup = {}


local function isMobile(udef)
	return (udef.canMove and udef.speed > 0.000001) or
		(includeNanosAsMobile and (udef.name == "armnanotc" or udef.name == "cornanotc"))
end
local function isBuilder(udef)
	return (udef.canReclaim and udef.reclaimSpeed > 0) or (udef.canResurrect and udef.resurrectSpeed > 0) or
		(udef.canRepair and udef.repairSpeed > 0) or (udef.buildOptions and udef.buildOptions[1])
end

local nameLookup = {}

for udid, udef in pairs(UnitDefs) do
	nameLookup[udef.name] = udid
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

local function checkCmd(uid, cmdId, indexTemp)
	local index = indexTemp or 1
	local cmd = spGetCommandQueue(uid, index)
	if cmd and cmd[index] and cmd[index]["id"] == cmdId then
		return true
	end
	return false
end

local function isIdle(udef, _udefid, uid)
	local canBeIdle = isMobile(udef) or isBuilder(udef)
	return canBeIdle and spGetCommandQueue(uid, 0) == 0
end

local function stringContains(mainString, searchString)
	return mainString:find(searchString, 1, true) ~= nil
end

local function parseFilterRules(ruleDef)
	local tokens = {}
	local tokenIndex = 1

	for token in ruleDef:gmatch("[^_]+") do
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
			rules.builderRule = invertCurry(invert, function(udef)
				return isBuilder(udef) and not udef.canResurrect
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
			rules.guardingRule = invertCurry(invert, function(_udef, _udefid, uid)
				return checkCmd(uid, CMD_GUARD)
			end)
		elseif token == "Waiting" then
			rules.waitingRule = invertCurry(invert, function(_udef, _udefid, uid)
				return checkCmd(uid, CMD_WAIT)
			end)
		elseif token == "Patrolling" then
			rules.patrollingRule = invertCurry(invert, function(_udef, _udefid, uid)
				for i = 1, 4, 1 do
					if checkCmd(uid, CMD_PATROL, i) then
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
		elseif token == "AntiAir" then
			rules.antiAirRule = invertCurry(invert, function(udef)
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
			-- elseif token == "Category" then
			-- 	local category = getNextToken()
			-- 	if not category then
			-- 		break
			-- 	end

			-- 	rules.categoryRule = invertCurry(invert, function(udef, _, _, category)
			-- 		if udef.category == nil then
			-- 			return false
			-- 		end

			-- 		return stringContains(udef.category, category)
			-- 	end, category)
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
				rules.idMatches = invertCurry(invertIdMatches, function(_, udefid, _, idMatchesSet)
					return idMatchesSet[udefid] or false
				end, idMatchesSet)
			end
		elseif token == "NameContain" then
			local name = getNextToken()
			if not name then
				break
			end

			rules.nameRule = invertCurry(invert, function(udef, _, _, name)
				return stringContains(udef.name, name)
			end, name)
		end
	end

	return rules
end

local function getFilterRules(ruleDef)
	local rules = customRulesLookup[ruleDef]

	if rules == nil then
		rules = parseFilterRules(ruleDef)
		customRulesLookup[ruleDef] = rules
	end

	return rules
end

return { parseFilterRules = parseFilterRules, getFilterRules = getFilterRules }
