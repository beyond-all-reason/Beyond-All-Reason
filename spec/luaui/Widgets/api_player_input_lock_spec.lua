local SpringUnsyncedBuilder = VFS.Include("spec/builders/spring_unsynced_builder.lua")

local WIDGET_PATH = "luaui/Widgets/api_player_input_lock.lua"

describe("luaui.Widgets.api_player_input_lock", function()
	local config ---@type table<string, integer>
	local configWrites ---@type table<integer, { key: string, value: integer, overlay: boolean }>
	local handlerCalls ---@type table<integer, any[]>
	local activeCommandSets ---@type integer[]
	local rulesParams ---@type table<string, number>
	local windowOpen = false
	local gameOver = false

	local function loadWidget()
		local loaded = SpringUnsyncedBuilder.new()
			:WithSpringFn("GetConfigInt", function(key, default)
				return config[key] or default
			end)
			:WithSpringFn("SetConfigInt", function(key, value, overlay)
				config[key] = value
				configWrites[#configWrites + 1] = { key = key, value = value, overlay = overlay }
			end)
			:WithSpringFn("SetActiveCommand", function(index)
				activeCommandSets[#activeCommandSets + 1] = index
			end)
			:WithSpringFn("GetGameRulesParam", function(name)
				return rulesParams[name]
			end)
			:WithSpringFn("IsGameOver", function()
				return gameOver
			end)
			:LoadWidget(WIDGET_PATH)
		local handler = loaded.env.widgetHandler
		for _, name in ipairs({ "HideInterface", "ShowInterface", "LockKeyboard", "UnlockKeyboard" }) do
			handler[name] = function(_, ...)
				handlerCalls[#handlerCalls + 1] = { name, ... }
				return true
			end
		end
		handler.IsAnyWindowOpen = function()
			return windowOpen
		end
		return loaded
	end

	local function setParam(loaded, value)
		rulesParams.playerInputLock = value
		loaded.env.widget:GameFrame()
	end

	before_each(function()
		config = { WindowedEdgeMove = 1, FullscreenEdgeMove = 0 }
		configWrites = {}
		handlerCalls = {}
		activeCommandSets = {}
		rulesParams = {}
		windowOpen = false
		gameOver = false
	end)

	it("locks on the rules param: hides all but the menu buttons, locks keys, stops edge scrolling", function()
		local loaded = loadWidget()

		setParam(loaded, 1)

		assert.are.same({
			{ "HideInterface", "playerInputLock", { "Top Bar Buttons", "Player Input Lock" } },
			{ "LockKeyboard", "playerInputLock" },
		}, handlerCalls)
		assert.are.same({ 0 }, activeCommandSets)
		assert.are.same({
			{ key = "WindowedEdgeMove", value = 0, overlay = true },
			{ key = "FullscreenEdgeMove", value = 0, overlay = true },
		}, configWrites)
	end)

	it("does nothing while the rules param is unset, and locks only once while it stays set", function()
		local loaded = loadWidget()
		loaded.env.widget:GameFrame()
		assert.are.same({}, handlerCalls)

		setParam(loaded, 1)
		loaded.env.widget:GameFrame()
		assert.are.equal(2, #handlerCalls)
		assert.are.equal(2, #configWrites) -- the edge-move settings were saved once, not overwritten with zeros
	end)

	it("puts everything back when the rules param is cleared", function()
		local loaded = loadWidget()
		setParam(loaded, 1)
		handlerCalls = {}
		configWrites = {}

		setParam(loaded, 0)

		assert.are.same(
			{ { "ShowInterface", "playerInputLock" }, { "UnlockKeyboard", "playerInputLock" } },
			handlerCalls
		)
		assert.are.equal(1, config.WindowedEdgeMove)
		assert.are.equal(0, config.FullscreenEdgeMove)
		for _, write in ipairs(configWrites) do
			assert.is_true(write.overlay)
		end
	end)

	it("eats the mouse wheel only while locked", function()
		local loaded = loadWidget()
		local function wheelConsumed()
			local consumed = loaded.env.widget:MouseWheel(true, 1)
			return consumed == true
		end
		assert.is_false(wheelConsumed())
		setParam(loaded, 1)
		assert.is_true(wheelConsumed())
		windowOpen = true -- a showing window gets the wheel, as it gets the keys
		assert.is_false(wheelConsumed())
	end)

	it("picks a lock that is already set up on Initialize, as after a /luaui reload", function()
		local loaded = loadWidget()
		rulesParams.playerInputLock = 1

		loaded.env.widget:Initialize()

		assert.are.same(
			{ "HideInterface", "playerInputLock", { "Top Bar Buttons", "Player Input Lock" } },
			handlerCalls[1]
		)
	end)

	it("lets go at game over and ignores the rules param from then on", function()
		local loaded = loadWidget()
		setParam(loaded, 1)
		handlerCalls = {}

		loaded.env.widget:GameOver()
		loaded.env.widget:GameFrame()

		assert.are.same(
			{ { "ShowInterface", "playerInputLock" }, { "UnlockKeyboard", "playerInputLock" } },
			handlerCalls
		)
		assert.are.equal(1, config.WindowedEdgeMove)
	end)

	it("does not lock on Initialize after game over", function()
		local loaded = loadWidget()
		rulesParams.playerInputLock = 1
		gameOver = true

		loaded.env.widget:Initialize()

		assert.are.same({}, handlerCalls)
	end)

	it("unlocks on shutdown, and touches nothing when it was not locked", function()
		local loaded = loadWidget()
		loaded.env.widget:Shutdown()
		assert.are.same({}, handlerCalls)
		assert.are.same({}, configWrites)

		setParam(loaded, 1)
		loaded.env.widget:Shutdown()

		assert.are.equal(1, config.WindowedEdgeMove)
		assert.are.same({ "ShowInterface", "playerInputLock" }, handlerCalls[3])
		assert.are.same({ "UnlockKeyboard", "playerInputLock" }, handlerCalls[4])
	end)

	it("saves the settings afresh when locked again after an unlock", function()
		local loaded = loadWidget()
		setParam(loaded, 1)
		setParam(loaded, 0)
		config.WindowedEdgeMove = 0 -- the player turned it off in between

		setParam(loaded, 1)
		setParam(loaded, 0)

		assert.are.equal(0, config.WindowedEdgeMove)
		assert.are.equal(0, config.FullscreenEdgeMove)
	end)
end)
