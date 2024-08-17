-- run test using BAR command (in chat): `/runtests select_api`
local spGetUnitDefID = Spring.GetUnitDefID
local parseFilterRules = VFS.Include("luaui/Widgets/Include/select_api.lua").parseFilterRules
local unitPassesFilterRules = VFS.Include("luaui/Widgets/Include/select_api.lua").unitPassesFilterRules
local nameLookup = {}

function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()
end

function cleanup()
	Test.clearMap()

	Spring.SendCommands("setspeed " .. 1)
end

local function compareUnitSets(springUnitSet, apiUnitSet)
	local missingInApi = {}
	local missingInSpring = {}

	for uid in pairs(springUnitSet) do
		if not apiUnitSet[uid] then
			local name = nameLookup[uid]

			-- sometimes the uid wasn't added in the first place
			-- this is why 'cortl' and 'armtl' cause issues
			if name ~= nil then
				table.insert(missingInApi, uid)
			end
		end
	end

	for uid in pairs(apiUnitSet) do
		if not springUnitSet[uid] then
			table.insert(missingInSpring, uid)
		end
	end

	return missingInApi, missingInSpring
end

local function createAndAddUnit(udefid, name, x, z, uids, group)
	if name == 'dbg_sphere' or name == 'dbg_sphere_fullmetal' or name == 'pbr_cube' then -- weird buggy units
		return
	end

	local unitID = SyncedRun(function(locals)
		local udefid = locals.udefid
		local x = locals.x
		local z = locals.z
		local group = locals.group

		local y = Spring.GetGroundHeight(x, z)
		local unitID = Spring.CreateUnit(udefid, x, y, z, "east", 0)


		if group == 1 then
			Spring.SetUnitGroup(unitID, 1)
		end
		return unitID
	end)

	table.insert(uids, unitID)
	return unitID
end

local function getName(uid)
	local udefid = spGetUnitDefID(uid)

	if not udefid then
		return nil
	end

	local udef = UnitDefs[udefid]
	return udef.name
end

local function generateErrorMessage(missingList, listName)
	local names = {}
	for _, uid in ipairs(missingList) do
		local name = getName(uid)
		if name then
			table.insert(names, name)
		end
	end
	return listName .. " contains " .. #missingList .. " elements: " .. table.concat(names, ", ")
end

local function createUnits()
	-- setup rules and units
	local offset = 200
	local x = offset
	local z = offset
	local uids = {}
	local group = 1

	local count = 0
	local max_count = 1000
	-- local max_count = 10

	for udefid, udef in pairs(UnitDefs) do
		if count >= max_count then
			break
		end
		count = count + 1

		x = x + offset
		local unitId = createAndAddUnit(udefid, udef.name, x, z, uids, group)

		if unitId then
			nameLookup[unitId] = udef.name
		end

		group = -1

		if x > 5000 then
			x = offset
			z = z + offset
			group = 1
		end
	end

	print(count .. " total unit count")

	return uids
end

-- 2024/08/17
-- 543 total units are created
-- for each rule, the sum of {{rule}} and Not_{{rule}} always equals 537.
-- this means 6 units are being created but then not included in the tests
-- could be 'dbg_sphere' 'dbg_sphere_fullmetal' 'pbr_cube'
function test()
	local uids = createUnits()

	local simpleRuleDefs = {
		"AbsoluteHealth_100",
		"Not_AbsoluteHealth_100",
		"Aircraft",
		"Not_Aircraft",
		"Builder",
		"Not_Builder",
		"Buildoptions",
		"Not_Buildoptions",
		"Building",
		"Not_Building",
		"Cloak",
		"Not_Cloak",
		"Cloaked",
		"Not_Cloaked",
		"Guarding",
		"Not_Guarding",
		"Patrolling",
		"Not_Patrolling",
		"IdMatches_armflea_IdMatches_armpw",
		"Not_IdMatches_armcom_Not_IdMatches_armflea",
		"Idle",
		"Not_Idle",
		"InGroup_1",
		"Not_InGroup_1",
		"InHotkeyGroup",
		"Not_InHotkeyGroup",
		"Jammer",
		"Not_Jammer",
		"ManualFireUnit",
		"Not_ManualFireUnit",
		"Radar",
		"Not_Radar",
		"Resurrect",
		"Not_Resurrect",
		"RelativeHealth_50",
		"Not_RelativeHealth_50",
		"Stealth",
		"Not_Stealth",
		"Transport",
		"Not_Transport",
		"Waiting",
		"Not_Waiting",
		"WeaponRange_200",
		"Not_WeaponRange_200",
		"Weapons",
		"Not_Weapons",
	}

	local notImplementedApi = {
		"InPrevSel",
		"NotInPrevSel",
		"RulesParamEquals_<string>_<integer>"
	}

	local notImplementedSpring = {
		"AntiAir",
		"NotAntiAir",
	}

	local notWorkingSpring = {
		"NameContain_com",
		"Not_NameContain_com",
		"Category_noweapon",
		"Not_Category_noweapon",
		"Category_NOWEAPON",
		"Not_Category_NOWEAPON",
	}

	local passed = true

	for _, rules in ipairs(simpleRuleDefs) do
		local springUnitSet = {}
		local apiUnitSet = {}
		local springRule = "select AllMap+_" .. rules .. "+_ClearSelection_SelectAll+"

		-- spring
		Spring.SendCommands(springRule)
		local springUnits = Spring.GetSelectedUnits()
		for _, uid in ipairs(springUnits) do
			springUnitSet[uid] = true
		end

		-- api
		local apiRules = parseFilterRules(rules)
		local passingUnitCount = 0
		for _, uid in ipairs(uids) do
			local passes = unitPassesFilterRules(uid, apiRules)

			local ignoreWeirdOutlier = rules == "Not_Builder" and (
				nameLookup[uid] == "cormlv" or
				nameLookup[uid] == "armmlv"
			)

			if passes == nil or ignoreWeirdOutlier then
				springUnitSet[uid] = nil
			elseif passes then
				apiUnitSet[uid] = true
				passingUnitCount = passingUnitCount + 1
			end
		end

		-- compare
		local missingInApi, missingInSpring = compareUnitSets(springUnitSet, apiUnitSet)

		local hasMissingInApi = #missingInApi > 0
		local hasMissingInSpring = #missingInSpring > 0

		print(rules .. " has " .. passingUnitCount .. " units")

		if hasMissingInApi and hasMissingInSpring then
			local errorMessage = generateErrorMessage(missingInApi, "missingInApi") ..
				" | " .. generateErrorMessage(missingInSpring, "missingInSpring")
			print("Rule " .. rules .. " failed: " .. errorMessage)
			passed = false
		elseif hasMissingInApi then
			local errorMessage = generateErrorMessage(missingInApi, "missingInApi")
			print("Rule " .. rules .. " failed: " .. errorMessage)
			passed = false
		elseif hasMissingInSpring then
			local errorMessage = generateErrorMessage(missingInSpring, "missingInSpring")
			print("Rule " .. rules .. " failed: " .. errorMessage)
			passed = false
		end
	end
	assert(passed, "not all rules match")
end
