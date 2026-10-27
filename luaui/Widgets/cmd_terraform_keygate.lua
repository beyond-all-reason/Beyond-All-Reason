local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Terraform Key Gate",
		desc = "While an editor tool is in use, game hotkeys stay out of the way of the editor's own",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false,
		handler = true,
	}
end

-- Bound game actions (build grid keys, unit orders) run before any widget's KeyPress, so the
-- editor cannot outvote them from its own layer. Owning text puts this widget in front of them:
-- each key goes to the suite widgets first, the keys below still reach the game, and the rest
-- stop here. The pause button on the panel (or closing it) hands every key back.

local KEY_ESCAPE = 27
local KEY_ENTER = 13
local KEY_KP_ENTER = 0x40000058
local KEY_F1 = 0x4000003A
local KEY_F12 = 0x40000045

-- Actions that stay with the game while editing: camera, chat and views.
local PASS_PREFIXES = { "chat", "move", "view", "camera", "zoom" }
---@type table<string, boolean>
local PASS_ACTIONS = {
	toggleoverview = true,
	screenshot = true,
	pause = true,
	quitmenu = true,
	console = true,
	buildspacing = true, -- the unit placer's spacing keys
	showmetalmap = true,
	showelevation = true,
	showpathtraversability = true,
	showstandard = true,
	togglelos = true,
	lastmsgpos = true,
	mousestate = true,
}

local suiteNames = {} -- name -> true, from the launcher's list (filled on first use: this can load first)
-- Editor widgets outside the suite that take their own keys: the SURFACE painter ships with the tileset
-- shader (a user widget, so not in the suite's enable list) and owns Ctrl+Z / Ctrl+Shift+Z for its strokes.
local EXTRA_KEY_WIDGETS = { "Surface Painter (Tileset Variants)" }
local passedOnPress = {} -- scanCode -> true: its release goes the same way

local function gateWanted()
	---@type table?
	local ui = WG.TerraformBrushUI
	if not (ui and ui.isEngaged and ui.isEngaged()) then
		return false
	end
	return not (ui.isPaused and ui.isPaused())
end

local function passesThrough(key, actions)
	if key == KEY_ESCAPE or key == KEY_ENTER or key == KEY_KP_ENTER or (key >= KEY_F1 and key <= KEY_F12) then
		return true
	end
	for _, bound in ipairs(actions or {}) do
		local cmd = bound.command
		if PASS_ACTIONS[cmd] then
			return true
		end
		for i = 1, #PASS_PREFIXES do
			if cmd:sub(1, #PASS_PREFIXES[i]) == PASS_PREFIXES[i] then
				return true
			end
		end
	end
	return false
end

-- The suite's own key handlers, in the handler's usual order.
local function offerToSuite(callin, ...)
	if next(suiteNames) == nil then
		for _, name in ipairs(WG.TerraformSuiteWidgets or {}) do
			suiteNames[name] = true
		end
		for _, name in ipairs(EXTRA_KEY_WIDGETS) do
			suiteNames[name] = true
		end
	end
	---@type table[]
	local list = widgetHandler[callin .. "List"] or {}
	for _, w in ipairs(list) do
		if w ~= widget and w[callin] and suiteNames[w.whInfo.name] then
			if w[callin](w, ...) then
				return true
			end
		end
	end
	return false
end

function widget:Update()
	local owner = widgetHandler.textOwner
	if gateWanted() then
		if owner == nil then
			widgetHandler.textOwner = widget
		end
	elseif owner == widget then
		widgetHandler.textOwner = nil
	end
end

function widget:KeyPress(key, mods, isRepeat, label, unicode, scanCode, actions)
	if widgetHandler.textOwner ~= widget then
		-- pressed before the gate (re)took the text: its release must reach the game too
		passedOnPress[scanCode] = true
		return false
	end
	if offerToSuite("KeyPress", key, mods, isRepeat, label, unicode, scanCode, actions) then
		return true
	end
	if passesThrough(key, actions) then
		-- Let a chat box or menu that this key opens take the text over.
		widgetHandler.textOwner = nil
		passedOnPress[scanCode] = true
		return false
	end
	return true
end

function widget:KeyRelease(key, mods, label, unicode, scanCode, actions)
	if scanCode and passedOnPress[scanCode] then
		passedOnPress[scanCode] = nil
		-- The handler offers a release to the text owner and again in its list: without this the
		-- second offer swallowed it and held camera actions (Alt moverotate) stuck on.
		if widgetHandler.textOwner == widget then
			widgetHandler.textOwner = nil
		end
		return false
	end
	if widgetHandler.textOwner ~= widget then
		return false
	end
	offerToSuite("KeyRelease", key, mods, label, unicode, scanCode, actions)
	return true
end

function widget:Shutdown()
	if widgetHandler.textOwner == widget then
		widgetHandler.textOwner = nil
	end
end
