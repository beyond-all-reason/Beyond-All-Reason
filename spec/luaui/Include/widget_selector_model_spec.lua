local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local function known(name, basename, active, fields)
	local info = {
		basename = basename,
		filename = "LuaUI/Widgets/" .. basename,
		desc = name .. " desc",
		fromZip = true,
		active = active,
	}
	for k, v in pairs(fields or {}) do
		info[k] = v
	end
	return info
end

-- A fresh model over a handler that knows a few widgets, as a window would set it up.
local function newModel()
	local handler = {
		knownWidgets = {
			["Widget Selector"] = known("Widget Selector", "widget_selector.lua", true),
			["Stand In"] = known("Stand In", "widget_selector_other.lua", false),
			["Top Thing"] = known("Top Thing", "gui_top.lua", true, { enabled = true }),
			["Off Thing"] = known("Off Thing", "gui_off.lua", false),
			["Cam Thing"] = known("Cam Thing", "camera_cam.lua", true),
			["Mine"] = known("Mine", "my_own.lua", true, { fromZip = false }),
		},
		orderList = { ["Top Thing"] = 1, ["Cam Thing"] = 2, ["Mine"] = 3 },
		configData = {},
		widgets = {},
		errorLog = {},
		errorCount = 0,
		enabled = {},
		disabled = {},
		EnableWidget = function(self, name)
			self.enabled[#self.enabled + 1] = name
		end,
		DisableWidget = function(self, name)
			self.disabled[#self.disabled + 1] = name
		end,
		SaveConfigData = function() end,
	}
	local widget = {
		GetInfo = function()
			return { name = "Widget Selector" }
		end,
		widgetHandler = handler,
	}
	local env = SpecEnv.new({
		gl = {},
		WG = {
			-- (measuring is the profiling include's, and wraps every callin of a real handler)
			widgetProfiling = {
				stats = {},
				subscribe = function() end,
				unsubscribe = function() end,
			},
		},
		widget = widget,
		widgetHandler = handler,
		BAR = {
			I18N = function(_, params)
				return params and params.default or ""
			end,
		},
	})
	local model = SpecEnv.include(env, "luaui/Include/widget_selector/model.lua")
	model.searchText = function()
		return ""
	end
	model.onSetsChanged = function() end
	model.onCategoriesBuilt = function() end
	model.onContentChanged = function() end
	model.loadLabels()
	model.refreshContent()
	return model, handler
end

local function rowNames(model)
	local names = {}
	for i, row in ipairs(model.rows) do
		names[i] = row.name
	end
	return names
end

local function categoryKeys(model)
	local keys = {}
	for i, category in ipairs(model.categories) do
		keys[i] = category.key or "all"
	end
	return keys
end

describe("widget selector model", function()
	it("lists every widget but its own window, and what the window keeps off", function()
		local model = newModel()
		assert.is_nil(model.entryByName["Widget Selector"])
		assert.is_table(model.entryByName["Stand In"])

		model.hidden["Stand In"] = true
		model.refreshContent()
		assert.is_nil(model.entryByName["Stand In"])
	end)

	it("groups by filename prefix, what no prefix claims under other, and adds the views", function()
		local model = newModel()
		assert.equals("interface", model.entryByName["Top Thing"].group)
		assert.equals("camera", model.entryByName["Cam Thing"].group)
		assert.equals("other", model.entryByName["Mine"].group)
		assert.same({ "all", "changed", "local", "interface", "camera", "other" }, categoryKeys(model))
	end)

	it("narrows the rows by category and by what is switched on", function()
		local model = newModel()
		model.selectedCategory = "interface"
		model.rebuildRows()
		assert.same({ "Off Thing", "Top Thing" }, rowNames(model))

		model.filters.enabledOnly = true
		model.buildCategories()
		model.rebuildRows()
		assert.same({ "Top Thing" }, rowNames(model))
	end)

	it("forgets a selected category that is gone", function()
		local model = newModel()
		model.selectedCategory = "sound"
		model.refreshContent()
		assert.is_nil(model.selectedCategory)
	end)

	it("takes the ordering switches as either or", function()
		local model = newModel()
		model.filters.profiler = true
		model.toggleFilter("byOrder")
		model.toggleFilter("byLoad")
		assert.is_true(model.filters.byLoad)
		assert.is_false(model.filters.byOrder)
	end)

	it("saves what is on as a set, and a set puts both halves back", function()
		local model, handler = newModel()
		model.saveSet("  mine  ")
		assert.equals("mine", model.pickedSet)
		assert.same({ ["Top Thing"] = true, ["Cam Thing"] = true, ["Mine"] = true }, model.sets[1].widgets)

		model.sets[1].widgets = { ["Off Thing"] = true, ["Mine"] = true }
		model.applySet("mine")
		assert.same({ "Off Thing" }, handler.enabled)
		table.sort(handler.disabled)
		assert.same({ "Cam Thing", "Top Thing" }, handler.disabled)
	end)

	it("keeps favourites and settings across its saved config", function()
		local model = newModel()
		model.fav.toggle("Top Thing")
		model.filters.enabledOnly = true
		model.saveSet("a")
		local saved = model.getConfigData()

		local fresh = newModel()
		fresh.setConfigData(saved)
		assert.is_true(fresh.fav.names["Top Thing"])
		assert.is_true(fresh.filters.enabledOnly)
		assert.equals("a", fresh.pickedSet)
		assert.equals("a", fresh.sets[1].name)
	end)

	it("takes nothing malformed from a saved config", function()
		local model = newModel()
		model.setConfigData({
			sets = { "no", { name = 1, widgets = {} }, { name = "ok", widgets = { [1] = true, a = true } } },
		})
		assert.equals(1, #model.sets)
		assert.same({ a = true }, model.sets[1].widgets)
	end)

	it("writes what a widget saved as a listing that loads back the same", function()
		local model, handler = newModel()
		handler.configData["Top Thing"] = { a = 1, list = { "x\ny", true }, ["odd key"] = {} }
		local lines = {}
		for _, line in ipairs(model.dataView.listing("Top Thing")) do
			local parts = {}
			for i, part in ipairs(line.parts) do
				parts[i] = part.s
			end
			lines[#lines + 1] = table.concat(parts)
		end
		local chunk = assert(loadstring(table.concat(lines, "\n")))
		assert.same(handler.configData["Top Thing"], chunk())
	end)
end)
