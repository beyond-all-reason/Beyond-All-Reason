function widget:GetInfo()
	return {
		name      = "Language",
		desc      = "api to handle translations",
		author    = "Floris",
		date      = "December 2020",
		layer     = -math.huge,
		enabled   = true,
	}
end

local noTranslationText = '---'

-- todo: echo where language of choice is missing entries
--local debug = false		-- true = echo the missing entries of the additional languages

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

local function tableMerge(t1, t2)
	for k, v in pairs(t2) do
		if type(v) == "table" then
			if type(t1[k] or false) == "table" then
				tableMerge(t1[k] or {}, t2[k] or {})
			else
				t1[k] = v
			end
		else
			t1[k] = v
		end
	end
	return t1
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
		languageContent = tableMerge(defaultLanguageContent, func())
	end
end

function widget:Initialize()
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
