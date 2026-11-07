local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Terraform Suite Launcher",
		desc = "Loads the map editor suite on demand (/terraformbrush, /terraformpanel, /terraformsuite)",
		author = "PtaQ",
		date = "July 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
		handler = true,
	}
end

-- The editor widgets ship enabled = false so players who never open the editor
-- pay nothing for the suite: no Lua parse, no RML documents, no callins.
-- This launcher is the only always-on piece. It owns the suite entry commands,
-- enables the suite widgets on first use, then passes every later invocation
-- through to the real handlers (they sort after us in the action list).
-- Backends first, UI panels last: enable order is load order, and the RML
-- panels expect their WG.* backends to exist when they initialize.
local SUITE_WIDGETS = {
	"Terraform Brush",
	"Clone Tool",
	"Decal Capture",
	"Decal Placer",
	"Diffuse Painter",
	"DrawFeatureShape GL4",
	"Feature Placer",
	"Grass Brush",
	"Light Placer",
	"Metal Brush",
	"Splat Painter",
	"Start Positions Tool",
	"Terraform Brush Capture",
	"Weather Brush",
	"Water Type Overlay GL4",
	"Terraform Image Overlay",
	"Terraformer Shared RmlUi Helpers",
	"Terraform Brush UI",
	"Decal Placer UI",
	"Diffuse Library UI",
	"Feature Placer UI",
	"Weather Brush UI",
	"Map Labels UI",
	"Unit Library UI",
	"Unit Placer",
	"Map Project",
	"Map Transform",
	"Terraform Key Gate",
}

-- Widgets the tileset shader sync installs in the write dir (LuaUI/Widgets/),
-- not shipped with the game. They are off by default, and they only show up in
-- knownWidgets when they are installed and user widgets are allowed, so the
-- suite turns them on with itself when it finds them. Without them a project's
-- TILESET and SURFACE sections are skipped on load. Tileset first: the surface
-- painter draws into its variant mask.
local OPTIONAL_WIDGETS = {
	"Tileset Terrain Prototype",
	"Surface Painter (Tileset Variants)",
}
-- The optional widgets this suite turned on, so Shutdown turns off only those:
-- someone who enabled one by hand keeps it. Saved in our config data because
-- EnableWidget saves the order list right away, and a crash must not leave the
-- tileset shader on in normal games.
local optionalEnabled = {}

-- Entry commands that must work before the suite is loaded. Sub-tool actions
-- (/diffusepaint, /grassbrush, ...) become available once the suite is up.
local ENTRY_ACTIONS = {
	"terraformbrush",
	"terraformup",
	"terraformdown",
	"terraformlevel",
	"terraformsmooth",
	"terraformerode",
	"terraformramp",
	"terraformrestore",
	"terraformexport",
	"terraformimport",
	"terraformpanel",
}

local suiteEnabled = false
local pendingCommand, pendingFrames -- entry command to re-dispatch once the suite is in

local function enableOptionalWidgets()
	local known = widgetHandler.knownWidgets
	if not (known and widgetHandler.orderList) then
		return
	end
	for i = 1, #OPTIONAL_WIDGETS do
		local name = OPTIONAL_WIDGETS[i]
		if known[name] and (widgetHandler.orderList[name] or 0) <= 0 then
			optionalEnabled[name] = true
			widgetHandler:EnableWidget(name)
		end
	end
end

local function enableSuite()
	if suiteEnabled then
		return false
	end
	suiteEnabled = true
	enableOptionalWidgets()
	for i = 1, #SUITE_WIDGETS do
		widgetHandler:EnableWidget(SUITE_WIDGETS[i])
	end
	return true
end

function widget:Initialize()
	-- the key gate hands keys to these widgets first
	WG.TerraformSuiteWidgets = SUITE_WIDGETS

	-- EnableWidget persists enablement through SaveConfigData. If a crash
	-- skipped our Shutdown cleanup the suite comes back enabled next game;
	-- adopt it so entry commands pass through and Shutdown disables it again.
	local order = widgetHandler.orderList and widgetHandler.orderList["Terraform Brush"]
	if order and order > 0 then
		suiteEnabled = true
		enableOptionalWidgets()
		-- enableSuite() will not run this session, and a saved order list can predate
		-- widgets added to SUITE_WIDGETS: enable any that are missing.
		for i = 1, #SUITE_WIDGETS do
			if (widgetHandler.orderList[SUITE_WIDGETS[i]] or 0) <= 0 then
				widgetHandler:EnableWidget(SUITE_WIDGETS[i])
			end
		end
	end

	-- handler = true hands us the RAW widgetHandler, which has no AddAction
	-- method (that lives on the per-widget proxy). Register through the
	-- actionHandler directly, like gui_options and dbg_test_runner do.
	widgetHandler.actionHandler:AddAction(widget, "terraformsuite", function()
		if not enableSuite() then
			Spring.Echo("[Terraform Suite] Already loaded")
		end
		return true
	end, nil, "t")

	for i = 1, #ENTRY_ACTIONS do
		local cmd = ENTRY_ACTIONS[i]
		widgetHandler.actionHandler:AddAction(widget, cmd, function(_, optLine)
			if suiteEnabled then
				return false -- suite widgets own this command now
			end
			enableSuite()
			-- Re-dispatch so the real handler receives the original command with its
			-- arguments. Not right away: widgets enabled from inside an action are only
			-- inserted on a later frame, and a command sent now would reach no handler.
			pendingCommand = cmd .. ((optLine and optLine ~= "") and (" " .. optLine) or "")
			pendingFrames = 2
			return true
		end, nil, "t")
	end
end

function widget:Update()
	if not pendingCommand then
		return
	end
	pendingFrames = pendingFrames - 1
	if pendingFrames <= 0 then
		local cmd = pendingCommand
		pendingCommand = nil
		Spring.SendCommands(cmd)
	end
end

function widget:Shutdown()
	-- Leave the widget config the way we found it, otherwise SaveConfigData
	-- keeps the whole suite enabled for all of this player's future games.
	-- Direct orderList write instead of DisableWidgetRaw: removing widgets
	-- while the handler iterates its shutdown list is not safe.
	if not (widgetHandler.orderList and widgetHandler.widgets) then
		return
	end
	-- Only when LuaUI itself goes down. Switching off just this launcher marks
	-- it inactive before its Shutdown runs, and the suite it loaded keeps
	-- running, so its config must keep saying so.
	local own = widget.whInfo and widgetHandler.knownWidgets and widgetHandler.knownWidgets[widget.whInfo.name]
	if own and own.active == false then
		return
	end
	local release = {}
	if suiteEnabled then
		for i = 1, #SUITE_WIDGETS do
			release[SUITE_WIDGETS[i]] = true
		end
	end
	for name in pairs(optionalEnabled) do
		release[name] = true
	end
	optionalEnabled = {}
	if not next(release) then
		return
	end
	-- SaveConfigData writes orderList[name] = position for every widget still in
	-- the handler's list, and at Shutdown all of them are, so a plain save turns
	-- the zeros back into "enabled". Saves also follow this callin (an EnableWidget
	-- queued during the shutdown pass saves again), so every save from here on
	-- leaves the released widgets out. Their config data was already collected
	-- before the shutdown pass; a reload builds a fresh handler without this override.
	local handlerSave = widgetHandler.SaveConfigData
	local function saveReleased(handler)
		for name in pairs(release) do
			if (handler.orderList[name] or 0) > 0 then
				handler.orderList[name] = 0
			end
		end
		local all = handler.widgets
		local kept = {}
		for i = 1, #all do
			if not release[all[i].whInfo.name] then
				kept[#kept + 1] = all[i]
			end
		end
		handler.widgets = kept
		local ok, err = pcall(handlerSave, handler)
		handler.widgets = all
		if not ok then
			Spring.Echo("[Terraform Suite] could not save the widget config: " .. tostring(err))
		end
	end
	widgetHandler.SaveConfigData = saveReleased
	saveReleased(widgetHandler)
end

function widget:GetConfigData()
	local names = {}
	for name in pairs(optionalEnabled) do
		names[#names + 1] = name
	end
	return { optionalEnabled = names }
end

function widget:SetConfigData(data)
	if type(data) == "table" and type(data.optionalEnabled) == "table" then
		for _, name in ipairs(data.optionalEnabled) do
			if type(name) == "string" then
				optionalEnabled[name] = true
			end
		end
	end
end
