-- run test using BAR command (in chat): `/runtests select_api`
local spGetUnitDefID = Spring.GetUnitDefID
local selectApi = VFS.Include("luaui/Include/select_api.lua")
local nameLookup = {}
local passed = true


function skip()
	return Spring.GetGameFrame() <= 0 or not Platform.gl
end

function setup()
	Test.clearMap()
end

function cleanup()
	Spring.SendCommands("setspeed " .. 1)
end

local function printTable(tbl, indent)
	if type(tbl) ~= "table" then
		print(tbl, type(tbl))
		return
	end

	indent = indent or 0
	for key, value in pairs(tbl) do
		local formatting = string.rep("  ", indent) .. key .. ": "
		if type(value) == "table" then
			print(formatting)
			printTable(value, indent + 1)
		else
			print(formatting .. tostring(value))
		end
	end
end

local function getName(uid)
	local udefid = spGetUnitDefID(uid)

	if not udefid then
		return nil
	end

	local udef = UnitDefs[udefid]
	return udef.name, udefid
end

local function compareUnitSets(springUnitSet, apiUnitSet, filter)
	local missingInApi = {}
	local missingInSpring = {}

	for uid in pairs(springUnitSet) do
		if not apiUnitSet[uid] then
			local name = getName(uid)

			-- sometimes the uid wasn't added in the first place
			-- this is why 'cortl' and 'armtl' cause issues
			if name ~= nil and name ~= "armtl" then
				print(name)
				table.insert(missingInApi, uid)
			end
		end
	end

	for uid in pairs(apiUnitSet) do
		if not springUnitSet[uid] then
			local name = getName(uid)

			-- these have weird behaviour for the "Not_Builder" filter
			-- they behave as expected for the "Builder" filter
			local isWeirdOutlier = (filter == "Not_Builder" and (
					name == "cormlv" or
					name == "armmlv"
				))
				-- api command selects these, but spring select doesn't
				-- I think they spawn? don't seem to exist during build script
				or name == "armdrone" or name == "corvacct"
				or name == "armtl"

			if not isWeirdOutlier then
				table.insert(missingInSpring, uid)
			end
		end
	end

	return missingInApi, missingInSpring
end

local function createAndAddUnit(udefid, name, x, z, uids, group)
	if name == 'dbg_sphere' or name == 'dbg_sphere_fullmetal' or name == 'pbr_cube'
		or name == 'lootboxplatinum'
	then -- weird buggy units
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

local function generateErrorMessage(missingList, listName)
	local names = {}
	for _, uid in pairs(missingList) do
		local name, udefid = getName(uid)
		if name then
			table.insert(names, name .. "|" .. udefid)
		end
	end
	return listName .. " contains " .. #missingList .. " elements: " .. table.concat(names, ", ")
end

local function createUnits()
	-- setup filters and units
	local offset = 200
	local x = offset
	local z = offset
	local uids = {}
	local group = 1

	local count = 0
	local max_count = 1000
	-- local max_count = 100
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

local comparableConclusions = {
	["ClearSelection_SelectAll+"] = true,
	["SelectAll+"] = true,
	["ClearSelection_SelectClosestToCursor+"] = true,
	["SelectClosestToCursor+"] = true
}

local function test_command(preSelectedUnitIDs, filter, command, conclusion)
	local springCommand = "select " .. command

	-- api command
	local apiCommand = selectApi.getCommand(command)
	local apiCommandUnitSet = {}
	Spring.SelectUnitArray(preSelectedUnitIDs)
	apiCommand()
	local apiUnits = Spring.GetSelectedUnits()
	for _, uid in pairs(apiUnits) do
		apiCommandUnitSet[uid] = true
	end

	-- spring
	local springUnitSet = {}
	Spring.SelectUnitArray(preSelectedUnitIDs)
	Spring.SendCommands(springCommand)
	local springUnits = Spring.GetSelectedUnits()
	for _, uid in pairs(springUnits) do
		springUnitSet[uid] = true
	end

	-- compare
	local function compare(apiUnitSet, type)
		local missingInApi, missingInSpring = compareUnitSets(springUnitSet, apiUnitSet, filter)
		local hasMissingInApi = #missingInApi > 0
		local hasMissingInSpring = #missingInSpring > 0
		local prefix = "\n" .. type .. " " .. command .. " failed: "

		if hasMissingInApi and hasMissingInSpring then
			local errorMessage = generateErrorMessage(missingInApi, "missingInApi") ..
				" | " .. generateErrorMessage(missingInSpring, "missingInSpring")
			print(prefix .. errorMessage)
			passed = false
		elseif hasMissingInApi then
			local errorMessage = generateErrorMessage(missingInApi, "missingInApi")
			print(prefix .. errorMessage)
			passed = false
		elseif hasMissingInSpring then
			local errorMessage = generateErrorMessage(missingInSpring, "missingInSpring")
			print(prefix .. errorMessage)
			passed = false
		end
	end

	if comparableConclusions[conclusion] then
		compare(apiCommandUnitSet, "Command")
	elseif #springUnits ~= #apiUnits then
		-- Spring and API handle rounding 0.5 differently
		-- other things seem to cause off-by-one errors as well.
		if math.abs(#springUnits - #apiUnits) > 2 then
			print("Count doesn't match for " .. command .. " Spring: " .. #springUnits .. " API: " .. #apiUnits)
			passed = false
		end
	end
end

-- 2024/08/17
-- 543 total units are created
-- for each filter, the sum of {{filter}} and Not_{{filter}} always equals 537.
-- this means 6 units are being created but then not included in the tests
-- could be 'dbg_sphere' 'dbg_sphere_fullmetal' 'pbr_cube'
function test()
	passed = true
	local uids = createUnits()
	local halfSize = math.floor(#uids / 2)
	local preSelectedUnitIDs = {}

	for i = 1, halfSize do
		local unitID = uids[i]
		table.insert(preSelectedUnitIDs, unitID)
	end

	local simpleFilterDefs = {
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
		"InPrevSel",
		"Not_InPrevSel",
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

	local sources = {
		"AllMap",
		"Visible",
		"PrevSelection",
		"FromMouse_500",
		"FromMouseC_500"
	}

	local conclusions = {
		"ClearSelection_SelectAll+",
		"SelectAll+",
		"ClearSelection_SelectClosestToCursor+",
		"SelectClosestToCursor+",

		-- these give different results, need to compare the count
		"ClearSelection_SelectOne+",
		"ClearSelection_SelectNum_5+",
		"ClearSelection_SelectPart_50+",

		-- these have odd behavior in Spring, don't test.
		-- "SelectOne+",
		-- "SelectNum_5+",
		-- "SelectPart_50+"
	}

	for _, filter in pairs(simpleFilterDefs) do
		for _, source in pairs(sources) do
			for _, conclusion in pairs(conclusions) do
				local command = source .. "+_" .. filter .. "+_" .. conclusion
				test_command(preSelectedUnitIDs, filter, command, conclusion)
			end
		end
	end
	assert(passed, "read errors above")
end
