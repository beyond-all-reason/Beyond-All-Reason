local spGetUnitDefID = Spring.GetUnitDefID
local spGetSelectedUnits = Spring.GetSelectedUnits
local parseFilterRules = VFS.Include("luaui/Widgets/Include/select_api.lua").parseFilterRules

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

local function unitPassesRules(uid, apiRules)
	local udefid = spGetUnitDefID(uid)
	local udef = UnitDefs[udefid]
	local passesAllRules = true

	for _ruleName, rule in pairs(apiRules) do
		if not rule(udef, udefid, uid) then
			passesAllRules = false
			break
		end
	end

	return passesAllRules
end

local function compareUnitLists(springUnitSet, apiUnitSet)
	local missingInApi = {}
	local missingInSpring = {}

	for uid in pairs(springUnitSet) do
		if not apiUnitSet[uid] then
			table.insert(missingInApi, uid)
		end
	end

	for uid in pairs(apiUnitSet) do
		if not springUnitSet[uid] then
			table.insert(missingInSpring, uid)
		end
	end

	return missingInApi, missingInSpring
end

local function createAndAddUnit(uid, name, x, z, uids, group)
	if name == 'dbg_sphere' or name == 'dbg_sphere_fullmetal' or name == 'pbr_cube' then
		return
	end

	unitID = SyncedRun(function(locals)
		local uid = locals.uid
		local x = locals.x
		local z = locals.z
		local group = locals.group

		local y = Spring.GetGroundHeight(x, z)
		local unitID = Spring.CreateUnit(uid, x, y, z, "east", 0)

		if group == 1 then
			-- add to control group
		end
		return unitID
	end)

	table.insert(uids, unitID)
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

	for uid, udef in pairs(UnitDefs) do
		if count >= max_count then
			break
		end
		count = count + 1

		x = x + offset
		createAndAddUnit(uid, udef.name, x, z, uids, group)
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
		"NameContain_com",
		"Not_NameContain_com",
		"Category_NOWEAPON",
		"Not_Category_NOWEAPON",
		"IdMatches_armflea_IdMatches_armpw",
		"Not_IdMatches_armcom_Not_IdMatches_armflea",

	}

	for _, rules in ipairs(simpleRuleDefs) do
		local springUnitSet = {}
		local apiUnitSet = {}
		local springRule = "select AllMap+_" .. rules .. "+_ClearSelection_SelectAll+"
		print(rules)
		print(springRule)

		-- spring
		Spring.SendCommands(springRule)
		local springUnits = Spring.GetSelectedUnits()
		for _, uid in ipairs(springUnits) do
			springUnitSet[uid] = true
		end

		-- api
		local apiRules = parseFilterRules(rules)
		for _, uid in ipairs(uids) do
			if unitPassesRules(uid, apiRules) then
				apiUnitSet[uid] = true
			end
		end

		-- compare
		local missingInApi, missingInSpring = compareUnitLists(springUnitSet, apiUnitSet)
		assert(#missingInApi == 0, "Expected missingInApi to be empty, but it contains elements.")
		assert(#missingInSpring == 0, "Expected missingInSpring to be empty, but it contains elements.")
	end
end
