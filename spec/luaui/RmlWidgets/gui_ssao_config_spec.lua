local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local RENDERER_PATH = "luaui/Widgets/gfx_ssao.lua"
local PANEL_PATH = "luaui/RmlWidgets/gui_ssao_config/gui_ssao_config.lua"

local function replaceUpvalue(fn, name, replacement)
	for i = 1, 60 do
		local key = debug.getupvalue(fn, i)
		if key == name then
			debug.setupvalue(fn, i, replacement)
			return
		end
		if not key then
			break
		end
	end
	error("Missing renderer boundary: " .. name)
end

local function loadRenderer(saved)
	local rebuilds = 0
	local messages = {}
	local env = SpecEnv.new({
		widget = {},
		WG = {},
		GL = {},
		gl = {},
		Platform = { gpuVendor = "NVIDIA", gpuMemorySize = 8000000 },
		Spring = {
			Echo = function(message)
				messages[#messages + 1] = message
			end,
			GetConfigFloat = function(_, default)
				return default
			end,
			GetConfigInt = function(_, default)
				return default
			end,
		},
	})
	SpecEnv.include(env, RENDERER_PATH)
	-- Keep real configuration logic; replace only GPU resource allocation/teardown.
	replaceUpvalue(env.widget.Initialize, "InitGL", function()
		rebuilds = rebuilds + 1
	end)
	replaceUpvalue(env.widget.Initialize, "CleanGL", function() end)
	if saved then
		env.widget:SetConfigData(saved)
	end
	env.widget:Initialize()
	return env, function()
		return rebuilds
	end, messages
end

local function loadPanel(wg, failDocument)
	local model
	local leftDown = false
	local actions = {}
	local lifecycle = {}
	local document = {
		Show = function()
			lifecycle[#lifecycle + 1] = "show"
		end,
		Hide = function()
			lifecycle[#lifecycle + 1] = "hide"
		end,
		ReloadStyleSheet = function()
			lifecycle[#lifecycle + 1] = "reload"
		end,
		Close = function()
			lifecycle[#lifecycle + 1] = "close"
		end,
	}
	local context = {
		OpenDataModel = function(_, _, initial)
			model = initial
			return model
		end,
		LoadDocument = function()
			if not failDocument then
				return document
			end
		end,
		RemoveDataModel = function()
			lifecycle[#lifecycle + 1] = "remove-model"
		end,
	}
	local env = SpecEnv.new({
		widget = {},
		WG = wg,
		RmlUi = {
			GetContext = function()
				return context
			end,
		},
		widgetHandler = {
			AddAction = function(_, name, callback)
				actions[name] = callback
			end,
			RemoveAction = function(_, name)
				actions[name] = nil
			end,
			RemoveWidget = function() end,
		},
		Spring = {
			Echo = function() end,
			GetMouseState = function()
				return 0, 0, leftDown
			end,
		},
	})
	SpecEnv.include(env, PANEL_PATH)
	env.widget:Initialize()
	return env.widget, model, actions, lifecycle, function(value)
		leftDown = value
	end
end

describe("SSAO configurator", function()
	it("exposes every slider and represents all preset values without clamping", function()
		local renderer = loadRenderer()
		local api = renderer.WG.ssao
		assert.are.equal(27, #api.getParameters())
		for presetID = 1, #api.getPresets() do
			api.setPreset(presetID)
			local panel, model = loadPanel(renderer.WG)
			assert.are.equal(27, #model.rows)
			assert.are.equal(3, #model.presets)
			assert.is_true(model.presets[presetID].selected)
			for _, row in ipairs(model.rows) do
				assert.is_true(row.value >= row.min and row.value <= row.max, row.name)
				assert.are.equal(10 ^ -row.digits, row.step)
				assert.are.equal(tostring(row.min), row.minimum)
				assert.are.equal(tostring(row.max), row.maximum)
			end
			panel:Shutdown()
		end
	end)

	it("normalizes changes and coalesces shader rebuilds at the update boundary", function()
		local renderer, rebuilds = loadRenderer()
		local api = renderer.WG.ssao
		assert.are.equal(0.13, api.setParameter("SSAO_KERNEL_MINZ", "0.126"))
		assert.are.equal(64, api.setParameter("SSAO_KERNEL_SIZE", 100))
		assert.are.equal(1, rebuilds())
		assert.are.equal(0.13, api.getConfiguration().SSAO_KERNEL_MINZ)
		renderer.widget:Update(0)
		assert.are.equal(2, rebuilds())
		local revision = api.getConfigurationRevision()
		api.setParameter("SSAO_KERNEL_SIZE", 64)
		renderer.widget:Update(0)
		assert.are.equal(revision, api.getConfigurationRevision())
		assert.are.equal(2, rebuilds())
	end)

	it("reports invalid parameters and presets without changing configuration", function()
		local renderer, _, messages = loadRenderer()
		local api = renderer.WG.ssao
		local original = api.getConfiguration()
		assert.is_nil(api.setParameter("SSAO_RADIUS", "not a number"))
		assert.is_nil(api.setParameter("SSAO_RADIUS", math.huge))
		assert.is_nil(api.setParameter("SSAO_RADIUS", 0 / 0))
		assert.is_nil(api.setParameter("unknown", 1))
		assert.is_false(api.setPreset(0))
		assert.is_false(api.setPreset(1.5))
		assert.are.same(original, api.getConfiguration())
		assert.are.equal(6, #messages)
	end)

	it("returns independent schema and configuration snapshots", function()
		local renderer = loadRenderer()
		local api = renderer.WG.ssao
		api.getParameters()[1].max = 999
		api.getConfiguration().SSAO_RADIUS = 999
		assert.are.equal(1, api.getParameters()[1].max)
		assert.are.equal(7, api.getRadius())
	end)

	it("persists custom values while preserving graphics settings keys", function()
		local renderer = loadRenderer()
		local api = renderer.WG.ssao
		api.setParameter("SSAO_RADIUS", 11.2)
		api.setParameter("DEBUG_BLUR", 1)
		api.setStrength(13)
		local saved = renderer.widget:GetConfigData()
		local restored = loadRenderer(saved)
		assert.are.same(api.getConfiguration(), restored.WG.ssao.getConfiguration())
		saved.strength = 9
		saved.radius = 6
		restored = loadRenderer(saved)
		assert.are.equal(9, restored.WG.ssao.getStrength())
		assert.are.equal(6, restored.WG.ssao.getRadius())
		assert.are.equal(1, restored.WG.ssao.getConfiguration().DEBUG_BLUR)
	end)

	it("keeps preset overlays and resets all tuning on request", function()
		local renderer = loadRenderer()
		local api = renderer.WG.ssao
		api.setParameter("SSAO_RADIUS", 11)
		api.setParameter("DEBUG_BLUR", 1)
		api.setPreset(1)
		assert.are.equal(9, api.getRadius())
		assert.are.equal(1, api.getConfiguration().DEBUG_BLUR)
		api.resetConfiguration()
		assert.are.equal(0, api.getConfiguration().DEBUG_BLUR)
		assert.are.equal(3, api.getConfiguration().DOWNSAMPLE)
		assert.are.same({}, renderer.widget:GetConfigData().parameters)
	end)

	it("ignores unchanged values and updates readouts without restamping the dragged slider", function()
		local renderer = loadRenderer()
		local panel, model, _, _, setLeftDown = loadPanel(renderer.WG)
		model.onParameter({ parameters = { value = 7 } }, "SSAO_RADIUS")
		model.onPreset({ parameters = { value = "1" } })
		panel:Update()
		assert.are.equal(7, renderer.WG.ssao.getRadius())
		assert.are.equal(3, renderer.WG.ssao.getPreset())
		setLeftDown(true)
		model.onSliderPress({ parameters = { button = 0 } }, "SSAO_RADIUS")
		local before = model.rows
		model.onParameter({ parameters = { value = 12 } }, "SSAO_RADIUS")
		panel:Update()
		assert.are.equal(12, renderer.WG.ssao.getRadius())
		assert.are_not.equal(before, model.rows)
		assert.are.equal("SSAO_RADIUS: 12.0", model.editing)
		for _, row in ipairs(model.rows) do
			if row.name == "SSAO_RADIUS" then
				assert.are.equal(12, row.value)
				assert.are.equal("12.0", row.formatted)
				assert.are.equal(7, row.sliderValue)
			end
		end
		setLeftDown(false)
		panel:Update()
		assert.are_not.equal(before, model.rows)
		for _, row in ipairs(model.rows) do
			if row.name == "SSAO_RADIUS" then
				assert.are.equal(12, row.value)
				assert.are.equal(12, row.sliderValue)
			end
		end
	end)

	it("accepts native change events even when no separate press/key event was delivered", function()
		local renderer, rebuilds = loadRenderer()
		local panel, model = loadPanel(renderer.WG)
		model.onParameter({ parameters = { value = 12 } }, "SSAO_RADIUS")
		assert.are.equal(12, renderer.WG.ssao.getRadius())
		for _, row in ipairs(model.rows) do
			if row.name == "SSAO_RADIUS" then
				assert.are.equal("12.0", row.formatted)
			end
		end
		renderer.widget:Update(0)
		assert.are.equal(2, rebuilds())
		model.onParameter({ parameters = { value = 12 } }, "SSAO_RADIUS")
		renderer.widget:Update(0)
		assert.are.equal(2, rebuilds())
		panel:Shutdown()
	end)

	it("supports keyboard edits and queues preset/reset commands outside event dispatch", function()
		local renderer = loadRenderer()
		local panel, model = loadPanel(renderer.WG)
		model.onSliderKey(nil, "DEBUG_BLUR")
		model.onParameter({ parameters = { value = 1 } }, "DEBUG_BLUR")
		model.onSliderBlur()
		assert.are.equal(1, renderer.WG.ssao.getConfiguration().DEBUG_BLUR)
		model.onPresetActivate()
		model.onPreset({ parameters = { value = "1" } })
		assert.are.equal(3, renderer.WG.ssao.getPreset())
		panel:Update()
		assert.are.equal(1, renderer.WG.ssao.getPreset())
		model.onReset()
		assert.are.equal(1, renderer.WG.ssao.getConfiguration().DEBUG_BLUR)
		panel:Update()
		assert.are.equal(0, renderer.WG.ssao.getConfiguration().DEBUG_BLUR)
	end)

	it("handles renderer removal, reload, visibility and teardown", function()
		local renderer = loadRenderer()
		local panel, model, actions, lifecycle = loadPanel(renderer.WG)
		assert.is_true(model.available)
		assert.are.same({ "reload", "show" }, lifecycle)
		renderer.widget:Shutdown()
		panel:Update()
		assert.is_false(model.available)
		assert.are.equal(27, #model.rows)
		renderer.widget:Initialize()
		panel:Update()
		assert.is_true(model.available)
		model.onClose()
		actions.ssaoconfig()
		assert.is_true(panel:KeyPress(27))
		panel:Shutdown()
		assert.is_nil(actions.ssaoconfig)
		assert.are.equal("remove-model", lifecycle[#lifecycle - 1])
		assert.are.equal("close", lifecycle[#lifecycle])
	end)

	it("removes a partially initialized model when document loading fails", function()
		local _, _, actions, lifecycle = loadPanel({}, true)
		assert.are.same({ "remove-model" }, lifecycle)
		assert.is_nil(actions.ssaoconfig)
	end)
end)
