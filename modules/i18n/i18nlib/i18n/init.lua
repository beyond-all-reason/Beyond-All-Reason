local i18n = {}

local store
local locale
local pluralizeFunction
local defaultLocale = "en"
local fallbackLocale = defaultLocale

-- I18N_PATH is set globally
local plural = VFS.Include(I18N_PATH .. "plural.lua")
local interpolate = VFS.Include(I18N_PATH .. "interpolate.lua")
local variants = VFS.Include(I18N_PATH .. "variants.lua")
local version = VFS.Include(I18N_PATH .. "version.lua")

i18n.plural, i18n.interpolate, i18n.variants, i18n.version, i18n._VERSION =
	plural, interpolate, variants, version, version

-- private stuff

local function dotSplit(str)
	local fields, length = {}, 0
	str:gsub("[^%.]+", function(c)
		length = length + 1
		fields[length] = c
	end)
	return fields, length
end

local function isPluralTable(t)
	return type(t) == "table" and type(t.other) == "string"
end

local function isPresent(str)
	return type(str) == "string" and #str > 0
end

local function assertPresent(functionName, paramName, value)
	if isPresent(value) then
		return
	end

	local msg = "i18n.%s requires a non-empty string on its %s. Got %s (a %s value)."
	error(msg:format(functionName, paramName, tostring(value), type(value)))
end

local function assertPresentOrPlural(functionName, paramName, value)
	if isPresent(value) or isPluralTable(value) then
		return
	end

	local msg = "i18n.%s requires a non-empty string or plural-form table on its %s. Got %s (a %s value)."
	error(msg:format(functionName, paramName, tostring(value), type(value)))
end

local function assertPresentOrTable(functionName, paramName, value)
	if isPresent(value) or type(value) == "table" then
		return
	end

	local msg = "i18n.%s requires a non-empty string or table on its %s. Got %s (a %s value)."
	error(msg:format(functionName, paramName, tostring(value), type(value)))
end

local function assertFunctionOrNil(functionName, paramName, value)
	if value == nil or type(value) == "function" then
		return
	end

	local msg = "i18n.%s requires a function (or nil) on param %s. Got %s (a %s value)."
	error(msg:format(functionName, paramName, tostring(value), type(value)))
end

local function defaultPluralizeFunction(count)
	return plural.get(variants.root(i18n.getLocale()), count)
end

local function pluralize(t, data)
	assertPresentOrPlural("interpolatePluralTable", "t", t)
	data = data or {}
	local count = data.count or 1
	local plural_form = pluralizeFunction(count)
	return t[plural_form]
end

local function treatNode(node, data)
	if type(node) == "string" then
		return interpolate(node, data)
	elseif isPluralTable(node) then
		return interpolate(pluralize(node, data), data)
	end
	return node
end

local function recursiveLoad(currentContext, data)
	local composedKey
	for k, v in pairs(data) do
		composedKey = (currentContext and (currentContext .. ".") or "") .. tostring(k)
		assertPresent("load", composedKey, k)
		assertPresentOrTable("load", composedKey, v)
		if type(v) == "string" then
			i18n.set(composedKey, v)
		else
			recursiveLoad(composedKey, v)
		end
	end
end

-- Keys and locales are split once; the cap only matters if a caller builds keys from unbounded input
local splitCache, splitCacheSize = {}, 0
local SPLIT_CACHE_MAX = 20000

local function cachedDotSplit(str)
	local fields = splitCache[str]
	if not fields then
		if splitCacheSize >= SPLIT_CACHE_MAX then
			splitCache, splitCacheSize = {}, 0
		end
		fields = dotSplit(str)
		splitCache[str] = fields
		splitCacheSize = splitCacheSize + 1
	end
	return fields
end

-- variants.fallbacks lists, by fallback locale then locale; read only
local fallbacksCache = {}

local function getFallbacks(usedLocale)
	local byLocale = fallbacksCache[fallbackLocale]
	if not byLocale then
		byLocale = {}
		fallbacksCache[fallbackLocale] = byLocale
	end
	local fallbacks = byLocale[usedLocale]
	if not fallbacks then
		fallbacks = variants.fallbacks(usedLocale, fallbackLocale)
		byLocale[usedLocale] = fallbacks
	end
	return fallbacks
end

-- walks the same path as dotSplit(locale .. "." .. key)
local function localizedTranslate(key, locale, data)
	local node = store
	local path = cachedDotSplit(locale)
	for i = 1, #path do
		node = node[path[i]]
		if not node then
			return nil
		end
	end

	path = cachedDotSplit(key)
	for i = 1, #path do
		node = node[path[i]]
		if not node then
			return nil
		end
	end

	return treatNode(node, data)
end

-- public interface

function i18n.set(key, value)
	assertPresent("set", "key", key)
	assertPresentOrPlural("set", "value", value)

	local path, length = dotSplit(key)
	local node = store

	for i = 1, length - 1 do
		key = path[i]
		node[key] = node[key] or {}
		node = node[key]
	end

	local lastKey = path[length]
	node[lastKey] = value
end

local missingTranslations = {}
local emptyData = {} -- never written to
local UNIT_NAMES_PREFIX = "units.names."
local UNIT_NAMES_PREFIX_LENGTH = #UNIT_NAMES_PREFIX

function i18n.translate(key, data)
	if type(key) ~= "string" or #key == 0 then
		assertPresent("translate", "key", key)
	end

	data = data or emptyData
	local usedLocale = data.locale or locale

	-- if user elected to use English unit names, force `en` locale when translating a unit name
	if
		key:sub(1, UNIT_NAMES_PREFIX_LENGTH) == UNIT_NAMES_PREFIX
		and Spring.GetConfigInt("language_english_unit_names", 1) == 1
	then
		usedLocale = "en"
	end

	local fallbacks = getFallbacks(usedLocale)
	for i = 1, #fallbacks do
		local fallback = fallbacks[i]
		local value = localizedTranslate(key, fallback, data)
		if value then
			return value
		else
			if missingTranslations[key] == nil then
				missingTranslations[key] = {}
			end
			local missingTranslation = missingTranslations[key]
			if not missingTranslation[fallback] and not (fallback == "en" and data.default) then
				Spring.Log("i18n", "notice", '"' .. key .. '" is not translated in ' .. fallback)
				missingTranslation[fallback] = true
			end
		end
	end
	if missingTranslations[key] == nil then
		missingTranslations[key] = {}
	end
	local missingTranslation = missingTranslations[key]
	if not missingTranslation._all and data.default == nil then
		Spring.Log("i18n", "notice", 'No translation found for "' .. key .. '"')
		missingTranslation._all = true
	end
	return data.default or key
end

function i18n.setLocale(newLocale, newPluralizeFunction)
	assertPresent("setLocale", "newLocale", newLocale)
	assertFunctionOrNil("setLocale", "newPluralizeFunction", newPluralizeFunction)
	locale = newLocale
	pluralizeFunction = newPluralizeFunction or defaultPluralizeFunction
end

function i18n.setFallbackLocale(newFallbackLocale)
	assertPresent("setFallbackLocale", "newFallbackLocale", newFallbackLocale)
	fallbackLocale = newFallbackLocale
end

function i18n.getFallbackLocale()
	return fallbackLocale
end

function i18n.getLocale()
	return locale
end

function i18n.reset()
	store = {}
	plural.reset()
	i18n.setLocale(defaultLocale)
	i18n.setFallbackLocale(defaultLocale)
end

function i18n.load(data)
	recursiveLoad(nil, data)
end

function i18n.loadFile(path)
	local success, data = pcall(function()
		local chunk = VFS.LoadFile(path, VFS.ZIP_FIRST)
		x = assert(loadstring(chunk))
		return x()
	end)
	if not success then
		Spring.Log("i18n", LOG.ERROR, "Failed to parse file " .. path .. ": ")
		Spring.Log("i18n", LOG.ERROR, data)
		return nil
	end
	i18n.load(data)
end

setmetatable(i18n, {
	__call = function(_, ...)
		return i18n.translate(...)
	end,
})

i18n.reset()

return i18n
