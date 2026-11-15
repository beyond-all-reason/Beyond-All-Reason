-- The bindable actions a widget declares in its manifest.json, in the widget hub's format.

local WidgetManifests = require("modules/widgets/manifests", nil, VFS.ZIP)

local WIDGET_FOLDERS = { "LuaUI/Widgets/", "LuaUI/RmlWidgets/" }
-- Game first, so a player's widget can't claim a shipped id.
local VFS_MODES = { VFS.ZIP, VFS.RAW }

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

local function readKeysets(declared, alwaysModifier, field)
	if declared == nil then
		return nil, nil
	end
	if type(declared) ~= "table" then
		return nil, field .. " is not a list"
	end
	if #declared == 0 then
		return nil, nil
	end

	for _, keyset in ipairs(declared) do
		if not isKeyset(keyset) then
			return nil, field .. " holds something other than a keyset"
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

local function readProfileKeysets(declared, alwaysModifier, dropped)
	if declared == nil then
		return nil
	end
	if type(declared) ~= "table" then
		dropped[#dropped + 1] = "profileKeysets is not an object; every profile's default dropped"

		return nil
	end

	local profiles = {}
	for profile in pairs(declared) do
		if not isNonEmptyString(profile) then
			dropped[#dropped + 1] = "profileKeysets is not an object; every profile's default dropped"

			return nil
		end
		profiles[#profiles + 1] = profile
	end
	table.sort(profiles)

	local byProfile = {}
	for _, profile in ipairs(profiles) do
		local shaped, problem = readKeysets(declared[profile], alwaysModifier, "profileKeysets." .. profile)
		local id = profile:lower()
		if problem then
			dropped[#dropped + 1] = problem .. "; that profile's default dropped"
		elseif shaped then
			byProfile[id] = byProfile[id] or {}
			for _, keyset in ipairs(shaped) do
				table.insert(byProfile[id], keyset)
			end
		end
	end

	return next(byProfile) and byProfile or nil
end

local function readMembers(declared)
	if declared == nil then
		return nil, nil
	end
	if type(declared) ~= "table" or #declared == 0 then
		return nil, "members is not a list"
	end

	for _, member in ipairs(declared) do
		if not isKeyset(member) then
			return nil, "members holds something other than a single word"
		end
	end

	return declared, nil
end

local function commandsOf(a)
	if not a.members then
		return { { action = a.action } }
	end

	local commands = {}
	for i, member in ipairs(a.members) do
		commands[i] = { action = a.action .. " " .. member, member = member }
	end

	return commands
end

local function keysetsFor(a, layout, member)
	local keysets = {}
	for _, keyset in ipairs(a.keysets or {}) do
		keysets[#keysets + 1] = keyset
	end
	local own = layout and a.profileKeysets and a.profileKeysets[layout:lower()]
	for _, keyset in ipairs(own or {}) do
		keysets[#keysets + 1] = keyset
	end
	if member then
		for i, keyset in ipairs(keysets) do
			keysets[i] = keyset:gsub("%%{n}", (member:gsub("%%", "%%%%")))
		end
	end

	return #keysets > 0 and keysets or nil
end

local function readAction(entry, keyPrefix, dir, seen)
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

	local members, membersProblem = readMembers(entry.members)
	if membersProblem then
		return nil, membersProblem
	end

	local action = lowerCommand(named)
	local own = {}
	for _, command in ipairs(commandsOf({ action = action, members = members })) do
		if seen[command.action] or own[command.action] then
			return nil, "repeats " .. command.action
		end
		own[command.action] = true
	end
	for command in pairs(own) do
		seen[command] = true
	end

	local dropped = {}
	local keysets, keysetProblem = readKeysets(entry.defaultKeysets, modifier, "defaultKeysets")
	if keysetProblem then
		dropped[#dropped + 1] = keysetProblem .. "; default dropped"
	end
	local profileKeysets = readProfileKeysets(entry.profileKeysets, modifier, dropped)

	return {
		action = action,
		label = relativeTo(keyPrefix, entry.label),
		description = relativeTo(keyPrefix, entry.description),
		alwaysModifier = modifier,
		icon = relativeTo(dir, entry.icon),
		members = members,
		keysets = keysets,
		profileKeysets = profileKeysets,
	},
		nil,
		dropped
end

-- Transifex only picks up language/, so a shipped widget names its keys there in full.
local function keyPrefixOf(widget)
	return widget.vfsMode == VFS.ZIP and "" or ("widgets." .. widget.id .. ".")
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

	local keyPrefix = keyPrefixOf(widget)
	local seen = {}
	for i, entry in ipairs(declared) do
		local at = string.format("%s: keybindings[%d]", where, i)
		local read, problem, dropped = readAction(entry, keyPrefix, widget.dir, seen)

		if read then
			actions[#actions + 1] = read
		else
			warnings[#warnings + 1] = at .. " " .. (problem or "") .. "; skipped"
		end
		for _, drop in ipairs(dropped or {}) do
			warnings[#warnings + 1] = at .. ": " .. drop
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
		local widgets, warnings = WidgetManifests.Discover(WIDGET_FOLDERS, VFS_MODES)
		for _, warning in ipairs(warnings) do
			Spring.Echo("[keybinds] " .. warning)
		end
		BAR.I18N.loadWidgetLocalizations(widgets, VFS.RAW)
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
				local members = {}
				for _, command in ipairs(commandsOf(a)) do
					if not claimed[command.action] then
						claimed[command.action] = true
						members[#members + 1] = command.member or command.action
					end
				end

				if #members > 0 then
					local item = {
						label = a.label,
						description = a.description,
						alwaysModifier = a.alwaysModifier,
						icon = a.icon,
					}
					if a.members then
						item.prefix = a.action .. " "
						item.members = members
					else
						item.action = a.action
					end
					items[#items + 1] = item
				end
			end

			if #items > 0 then
				groups[#groups + 1] = {
					category = "widgets." .. widget.id .. ".displayName",
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
				for _, command in ipairs(commandsOf(a)) do
					shown[command.action] = true
				end
			end
		end
	end

	local hidden = {}
	for _, widget in ipairs(widgets or {}) do
		if not widget.loaded then
			for _, a in ipairs(actionsOf(widget)) do
				for _, command in ipairs(commandsOf(a)) do
					if not shown[command.action] then
						shown[command.action] = true
						hidden[#hidden + 1] = command.action
					end
				end
			end
		end
	end

	return hidden
end

-- An action two widgets declare belongs to the first. `layout` is a shipped profile's id.
function M.defaults(widgets, layout)
	local defaults = {}
	local claimed = {}

	for _, widget in ipairs(widgets or {}) do
		if widget.loaded then
			for _, a in ipairs(actionsOf(widget)) do
				for _, command in ipairs(commandsOf(a)) do
					if not claimed[command.action] then
						claimed[command.action] = true
						local keysets = keysetsFor(a, layout, command.member)
						if keysets then
							defaults[#defaults + 1] = { action = command.action, keysets = keysets }
						end
					end
				end
			end
		end
	end

	return defaults
end

return M
