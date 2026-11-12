local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local USER_LAYOUTS_PATH = "LuaUI/Config/gridmenu_layouts.json"
local ECONOMY = "ui.buildMenu.category_econ"

local unitNames = { "armcom", "armmex", "armsolar", "armwin", "armlab", "armpw", "armck" }
local ARMCOM, ARMLAB, ARMCK = 1, 5, 7
local ECONOMY_OPTIONS = { 2, 3, 4 }

-- Unplaced units fill slots 1, 2, 3 in build order, so the stock layout must differ from that to be observable.
local STOCK_ECONOMY = { [1] = "armwin", [3] = "armmex", [4] = "armsolar" }

local function unitDefs()
	local defs, defNames = {}, {}
	for id, name in ipairs(unitNames) do
		defs[id] = { id = id, name = name, buildOptions = {}, customParams = { unitgroup = "energy" } }
		defNames[name] = defs[id]
	end
	defs[ARMCOM].buildOptions = ECONOMY_OPTIONS
	defs[ARMCK].buildOptions = ECONOMY_OPTIONS
	defs[ARMLAB].buildOptions = { 6 }

	return defs, defNames
end

local function stockLayouts()
	return {
		UnitGrids = {
			armcom = { { { "armwin", "", "armmex", "armsolar" } } },
			armck = { { { "armwin", "", "armmex", "armsolar" } } },
		},
		LabGrids = { armlab = { "", "armpw" } },
	}
end

local function loadConfig(userFile)
	local defs, defNames = unitDefs()
	local echoed = {}
	local env = SpecEnv.new({
		UnitDefs = defs,
		UnitDefNames = defNames,
		BAR = {
			I18N = function(key)
				return key
			end,
		},
		Spring = {
			Echo = function(message)
				echoed[#echoed + 1] = message
			end,
		},
		VFS = {
			LoadFile = function(path, mode)
				if path == USER_LAYOUTS_PATH and mode == VFS.RAW then
					return userFile
				end
			end,
		},
		includes = { ["luaui/configs/gridmenu_layouts.lua"] = stockLayouts() },
	})

	return SpecEnv.include(env, "luaui/configs/gridmenu_config.lua"), echoed
end

local function slotNames(options)
	local names = {}
	for index, option in pairs(options) do
		names[index] = option.name
	end

	return names
end

local function economyNames(config, builderId)
	return slotNames(config.getSortedGridForBuilder(builderId or ARMCOM, ECONOMY_OPTIONS, ECONOMY))
end

local function labNames(config)
	return slotNames(config.getSortedGridForLab(ARMLAB, { { id = -6, name = "armpw", action = "buildunit_armpw" } }))
end

describe("gridmenu_config user layouts", function()
	it("uses the stock layout when there is no user file", function()
		local config, echoed = loadConfig(nil)

		assert.same(STOCK_ECONOMY, economyNames(config))
		assert.same({ [2] = "armpw" }, labNames(config))
		assert.same({}, echoed)
	end)

	it("replaces a builder's layout with the user's", function()
		local config = loadConfig([=[{"unitGrids": {"armcom": [[["", "armwin"], ["armmex", "", "", "armsolar"]]]}}]=])

		assert.same({ [2] = "armwin", [5] = "armmex", [8] = "armsolar" }, economyNames(config))
	end)

	it("replaces a lab's layout with the user's", function()
		local config = loadConfig([=[{"labGrids": {"armlab": ["", "", "armpw"]}}]=])

		assert.same({ [3] = "armpw" }, labNames(config))
	end)

	it("applies each builder's entry on its own", function()
		local config = loadConfig([=[{"unitGrids": {"armcom": [[["armmex"]]], "armck": [[[1]]]}}]=])

		assert.same({ [1] = "armmex", [2] = "armsolar", [3] = "armwin" }, economyNames(config, ARMCOM))
		assert.same(STOCK_ECONOMY, economyNames(config, ARMCK))
		assert.same({ [2] = "armpw" }, labNames(config))
	end)

	it("keeps the stock layout for an entry that is not a grid of unit names", function()
		local malformed = {
			[=[{"unitGrids": {"armcom": [[[1]]]}}]=],
			[=[{"unitGrids": {"armcom": [[["a"], ["b"], ["c"], ["d"]]]}}]=],
			[=[{"unitGrids": {"armcom": {"economy": []}}}]=],
			[=[{"unitGrids": {"armcom": "armmex"}}]=],
		}

		for _, userFile in ipairs(malformed) do
			local config, echoed = loadConfig(userFile)

			assert.same(STOCK_ECONOMY, economyNames(config))
			assert.matches("ignoring malformed layout for armcom", echoed[1], nil, true)
		end
	end)

	it("keeps the stock layout when the user file is not valid JSON", function()
		local config, echoed = loadConfig([[{"unitGrids": ]])

		assert.same(STOCK_ECONOMY, economyNames(config))
		assert.matches("could not decode", echoed[1], nil, true)
	end)
end)
