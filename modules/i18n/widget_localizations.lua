-- A hub widget's optional localizations.json, { "<languageCode>": { <nested keys> } }, under widgets.<id>.

local WidgetManifests = VFS.Include("modules/widgets/manifests.lua", nil, VFS.ZIP)

local LOCALIZATIONS_FILE = "localizations.json"
local DISPLAY_NAME_KEY = "displayName"
local FALLBACK_LANGUAGE = "en"

local WidgetLocalizations = {}

local function isNonEmptyString(value)
	return type(value) == "string" and value ~= ""
end

local function sanitizeStrings(node, keyPath, file, warnings)
	local clean = {}

	for key, value in pairs(node) do
		local composedKey = keyPath .. "." .. tostring(key)

		if not isNonEmptyString(key) then
			warnings[#warnings + 1] = string.format("%s: %s is not a non-empty string key; skipped", file, composedKey)
		elseif key:find(".", 1, true) then
			-- i18n splits a key on dots, so a dotted one would reach into its siblings.
			warnings[#warnings + 1] = string.format("%s: %s has a dot in a key; skipped", file, composedKey)
		elseif type(value) == "table" then
			local cleanChild = sanitizeStrings(value, composedKey, file, warnings)
			if next(cleanChild) ~= nil then
				clean[key] = cleanChild
			end
		elseif isNonEmptyString(value) then
			clean[key] = value
		else
			warnings[#warnings + 1] = string.format("%s: %s is not a non-empty string; skipped", file, composedKey)
		end
	end

	return clean
end

local function sanitizeLanguages(localizations, file, warnings)
	local byLanguage = {}

	for languageCode, strings in pairs(localizations) do
		if isNonEmptyString(languageCode) and type(strings) == "table" then
			byLanguage[languageCode] = sanitizeStrings(strings, languageCode, file, warnings)
		else
			warnings[#warnings + 1] =
				string.format("%s: %s is not a language table; skipped", file, tostring(languageCode))
		end
	end

	return byLanguage
end

function WidgetLocalizations.Read(widgets, vfsMode)
	local byId = {}
	local warnings = {}

	for _, widget in ipairs(widgets) do
		local byLanguage = {}

		local displayName = widget.manifest.display_name
		if isNonEmptyString(displayName) then
			byLanguage[FALLBACK_LANGUAGE] = { [DISPLAY_NAME_KEY] = displayName }
		end

		local file = widget.dir .. LOCALIZATIONS_FILE
		local localizations, problem = WidgetManifests.ReadJson(file, vfsMode)
		if problem then
			warnings[#warnings + 1] = string.format("%s %s; skipped", file, problem)
		elseif localizations then
			for languageCode, strings in pairs(sanitizeLanguages(localizations, file, warnings)) do
				byLanguage[languageCode] = byLanguage[languageCode] or {}
				for key, value in pairs(strings) do
					byLanguage[languageCode][key] = value
				end
			end
		end

		if next(byLanguage) ~= nil then
			byId[widget.id] = byLanguage
		end
	end

	return byId, warnings
end

return WidgetLocalizations
