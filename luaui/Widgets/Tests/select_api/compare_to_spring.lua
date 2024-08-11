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

	unitID = SyncedRun(function(locals)
		local udefid = locals.udefid
		local x = locals.x
		local z = locals.z
		local group = locals.group

		local y = Spring.GetGroundHeight(x, z)
		local unitID = Spring.CreateUnit(udefid, x, y, z, "east", 0)


		if group == 1 then
			-- add to control group
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

function test()
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

	local simpleRuleDefs = {
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
		"Idle",
		"Not_Idle",
		"Waiting",
		"Not_Waiting",
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
		"Stealth",
		"Not_Stealth",
		"Transport",
		"Not_Transport",
		"Weapons",
		"Not_Weapons",
		"AbsoluteHealth_100",
		"Not_AbsoluteHealth_100",
		"RelativeHealth_50",
		"Not_RelativeHealth_50",
		"WeaponRange_200",
		"Not_WeaponRange_200",
		"IdMatches_armflea_IdMatches_armpw",
		"Not_IdMatches_armcom_Not_IdMatches_armflea",
	}

	local notImplementedApi = {
		"Category_NOWEAPON",
		"Not_Category_NOWEAPON",
	}

	local notWorkingSpring = {
		"NameContain_com",
		"Not_NameContain_com",
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
		for _, uid in ipairs(uids) do
			local passes = unitPassesFilterRules(uid, apiRules)

			if passes == nil then
				springUnitSet[uid] = nil
			elseif passes then
				apiUnitSet[uid] = true
			end
		end

		-- compare
		local missingInApi, missingInSpring = compareUnitSets(springUnitSet, apiUnitSet)

		local hasMissingInApi = #missingInApi > 0
		local hasMissingInSpring = #missingInSpring > 0

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
