-- The bindable actions a widget declares in its manifest.json, in the widget hub's format.

local WidgetManifests = require("modules/widgets/manifests", nil, VFS.ZIP)

local USER_WIDGET_FOLDERS = { "LuaUI/Widgets/", "LuaUI/RmlWidgets/" }

local M = {}

local function isNonEmptyString(value)
	return type(value) == "string" and value ~= ""
end

local function isKeyset(value)
	return isNonEmptyString(value) and not value:find("%s")
end

local function relativeTo(base, value)
	return isNonEmptyString(value) and (base .. value) or nil
end

local function startsWithModifier(keyset, modifier)
	return keyset:lower():find("^" .. modifier .. "%+") ~= nil
end

local function stripModifier(keyset, modifier)
	if startsWithModifier(keyset, modifier) then
		return keyset:sub(#modifier + 2)
	end

	return keyset
end

-- The engine lower-cases the command word when it reads a bind line.
local function lowerCommand(named)
	local command = named:match("^%S+") or named

	return command:lower() .. named:sub(#command + 1)
end

local function shapeKeysets(keysets, alwaysModifier)
	local shaped = {}

	if alwaysModifier == "shift" then
		local bare = stripModifier(keysets[1], "shift")
		shaped[1] = bare
		shaped[2] = "Shift+" .. bare

		return shaped
	end

	for i, keyset in ipairs(keysets) do
		if alwaysModifier == "any" and not startsWithModifier(keyset, "any") and keyset:sub(1, 2) ~= "*+" then
			shaped[i] = "Any+" .. keyset
		else
			shaped[i] = keyset
		end
	end

	return shaped
end

local function readKeysets(declared, alwaysModifier)
	if declared == nil then
		return nil, nil
	end
	if type(declared) ~= "table" then
		return nil, "defaultKeysets is not a list"
	end
	if #declared == 0 then
		return nil, nil
	end

	for _, keyset in ipairs(declared) do
		if not isKeyset(keyset) then
			return nil, "defaultKeysets holds something other than a keyset"
		end
	end
	if alwaysModifier == "shift" and #declared > 1 then
		return nil, "a shift-paired action holds exactly one keyset"
	end
	-- Any+ drops the other modifiers when the engine reads it, so both halves would be one bind.
	if alwaysModifier == "shift" and (startsWithModifier(declared[1], "any") or declared[1]:sub(1, 2) == "*+") then
		return nil, "a shift-paired action cannot hold an Any+ keyset"
	end

	return shapeKeysets(declared, alwaysModifier), nil
end

local function readAction(entry, dir, seen)
	if type(entry) ~= "table" then
		return nil, "is not an object"
	end
	local named = type(entry.action) == "string" and entry.action:match("^%s*(.-)%s*$") or ""
	if named == "" then
		return nil, "names no action"
	end
	local modifier = entry.alwaysModifier
	if modifier ~= nil and modifier ~= "any" and modifier ~= "shift" then
		return nil, 'alwaysModifier must be "any" or "shift"'
	end

	local action = lowerCommand(named)
	if seen[action] then
		return nil, "repeats " .. action
	end
	seen[action] = true

	local keysets, keysetProblem = readKeysets(entry.defaultKeysets, modifier)

	return {
		action = action,
		alwaysModifier = modifier,
		icon = relativeTo(dir, entry.icon),
		keysets = keysets,
	},
		nil,
		keysetProblem
end

function M.parse(widget)
	local actions = {}
	local warnings = {}

	local declared = widget.manifest and widget.manifest.keybindings
	if declared == nil then
		return actions, warnings
	end

	local where = widget.dir .. "manifest.json"
	if type(declared) ~= "table" then
		warnings[1] = where .. ": keybindings is not a list; ignored"

		return actions, warnings
	end

	local seen = {}
	for i, entry in ipairs(declared) do
		local at = string.format("%s: keybindings[%d]", where, i)
		local read, problem, keysetProblem = readAction(entry, widget.dir, seen)

		if read then
			actions[#actions + 1] = read
		else
			warnings[#warnings + 1] = at .. " " .. (problem or "") .. "; skipped"
		end
		if keysetProblem then
			warnings[#warnings + 1] = at .. ": " .. keysetProblem .. "; default dropped"
		end
	end

	return actions, warnings
end

-- Discovered once and shared through WG, since each include of this module is a copy of its own.
function M.manifests()
	if not (WG and widgetHandler) then
		return {}, 0
	end

	local shared = WG.widgetManifests
	if not shared then
		local widgets, warnings = WidgetManifests.Discover(USER_WIDGET_FOLDERS, VFS.RAW)
		for _, warning in ipairs(warnings) do
			Spring.Echo("[keybinds] " .. warning)
		end
		shared = { widgets = widgets, changes = 0 }
		WG.widgetManifests = shared
	end

	local revision = widgetHandler:GetWidgetsRevision()
	if shared.revision ~= revision then
		shared.revision = revision
		if WidgetManifests.MarkLoaded(shared.widgets, widgetHandler:GetActiveWidgetFiles()) then
			shared.changes = shared.changes + 1
		end
	end

	return shared.widgets, shared.changes
end

-- Once per widget per session, so a manifest's problems are reported once.
local function actionsOf(widget)
	if widget.actions == nil then
		local actions, warnings = M.parse(widget)
		for _, warning in ipairs(warnings) do
			Spring.Echo("[keybinds] " .. warning)
		end
		widget.actions = actions
	end

	return widget.actions
end

function M.groups(widgets)
	local groups = {}
	local claimed = {}

	for _, widget in ipairs(widgets or {}) do
		if widget.loaded then
			local items = {}
			for _, a in ipairs(actionsOf(widget)) do
				if not claimed[a.action] then
					claimed[a.action] = true
					items[#items + 1] = { action = a.action, alwaysModifier = a.alwaysModifier, icon = a.icon }
				end
			end

			if #items > 0 then
				groups[#groups + 1] = {
					category = "widgets." .. widget.id,
					title = isNonEmptyString(widget.manifest.display_name) and widget.manifest.display_name
						or widget.id,
					section = "widgets",
					items = items,
				}
			end
		end
	end

	return groups
end

function M.hiddenActions(widgets)
	local shown = {}
	for _, widget in ipairs(widgets or {}) do
		if widget.loaded then
			for _, a in ipairs(actionsOf(widget)) do
				shown[a.action] = true
			end
		end
	end

	local hidden = {}
	for _, widget in ipairs(widgets or {}) do
		if not widget.loaded then
			for _, a in ipairs(actionsOf(widget)) do
				if not shown[a.action] then
					shown[a.action] = true
					hidden[#hidden + 1] = a.action
				end
			end
		end
	end

	return hidden
end

-- An action two widgets declare belongs to the first.
function M.defaults(widgets)
	local defaults = {}
	local claimed = {}

	for _, widget in ipairs(widgets or {}) do
		if widget.loaded then
			for _, a in ipairs(actionsOf(widget)) do
				if not claimed[a.action] then
					claimed[a.action] = true
					if a.keysets then
						defaults[#defaults + 1] = { action = a.action, keysets = a.keysets }
					end
				end
			end
		end
	end

	return defaults
end

return M
