function widget:GetInfo()
	return {
		name      = "Language",
		desc      = "API to handle translations",
		author    = "Floris",
		date      = "December 2020",
		license   = "",
		layer     = -math.huge,
		enabled   = true,
	}
end

local function refreshDefs()
	for unitDefName, unitDef in pairs(UnitDefNames) do
		local isScavenger = unitDef.customParams and unitDef.customParams.isscavenger

		if not isScavenger then
			unitDef.translatedHumanName = Spring.I18N('units.names.' .. unitDefName)
			unitDef.translatedTooltip = Spring.I18N('units.descriptions.' .. unitDefName)
		else
			Spring.Echo("blah")
			Spring.Echo(unitDefName, unitDef.customParams.fromunit)
			local fromUnitName = Spring.I18N('units.names.' .. unitDef.customParams.fromunit)
			unitDef.translatedHumanName = Spring.I18N('units.scavenger', { name = fromUnitName })

			local unitTooltip = Spring.I18N('units.descriptions.' .. unitDefName)
			-- Not all Scavenger units have unique descriptions, so need to use the regular unit's description as fallback
			-- I18N returns lookup key if can't find a translation, which is why that is use for the comparison
			if unitTooltip == 'units.descriptions.' .. unitDefName then
				unitTooltip = Spring.I18N('units.descriptions.' .. unitDef.customParams.fromunit)
			end

			unitDef.translatedTooltip = unitTooltip
		end
	end
end

local function languageChanged(language)
	Spring.I18N.setLanguage(language)
	refreshDefs()
end

local noTranslationText = '---'

local languageContent = {}
local defaultLanguage = 'en'
local language = Spring.GetConfigString('language', defaultLanguage)


local languages = {}
local files = VFS.DirList('language', '*')
for k, file in ipairs(files) do
	local name = string.sub(file, 10)
	local ext = string.sub(name, string.len(name) - 2)
	if ext == 'lua' then
		name = string.sub(name, 1, string.len(name) - 4)
		languages[name] = true
	end
end

local function loadLanguage()
	-- load base language file (english)
	local file = "language/"..defaultLanguage..".lua"
	local s = assert(VFS.LoadFile(file, VFS.RAW_FIRST))
	local func = loadstring(s, file)
	local defaultLanguageContent = func()

	if language == defaultLanguage then
		languageContent = defaultLanguageContent
	else
		file = "language/"..language..".lua"
		s = assert(VFS.LoadFile(file, VFS.RAW_FIRST))
		func = loadstring(s, file)
		-- merge default base file with custom language
		languageContent = table.merge(defaultLanguageContent, func())
	end
end

function widget:Initialize()
	refreshDefs()
	Spring.Echo("foo")
	for _, ud in pairs(UnitDefs) do
		if ud.customParams.iscommander ~= nil then
			Spring.Echo(ud.name, ud.customParams.iscommander, type(ud.customParams.iscommander))
			-- Spring.Echo(ud.translatedHumanName, ud.translatedTooltip)
		end
	end
	loadLanguage()

	WG['lang'] = {}
	WG['lang'].getLanguage = function()
		return language
	end
	WG['lang'].setLanguage = function(value)
		if value ~= language and languages[value] then
			Spring.SetConfigString('language', language)
			language = value
			loadLanguage()
		end
	end
	WG['lang'].getLanguages = function()
		return languages
	end
	WG['lang'].getText = function(id, subId)
		if subId then
			if languageContent[id] and languageContent[subId] then
				return languageContent[id][subId]
			else
				return noTranslationText
			end
		else
			if languageContent[id] then
				return languageContent[id]
			else
				return noTranslationText
			end
		end
	end
end

function widget:Shutdown()
	WG['lang'] = nil
end


function widget:GetConfigData(data)
	return {

	}
end

function widget:SetConfigData(data)

end
