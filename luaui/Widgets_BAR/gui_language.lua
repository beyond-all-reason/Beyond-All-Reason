function widget:GetInfo()
	return {
		name      = "Language",
		desc      = "api to handle translations",
		author    = "Floris",
		date      = "December 2020",
		license   = "",
		layer     = -math.huge,
		enabled   = true,
	}
end

local noTranslationText = '---'

local myPlayerID = Spring.GetMyPlayerID()
local myCountry = select(8, Spring.GetPlayerInfo(myPlayerID, false))
local language = 'en'
local languages = {}
local languageContent = {}

local function loadLanguage()
	local file = "language/"..language..".lua"
	local s = assert(VFS.LoadFile(file, VFS.RAW_FIRST))
	local func = loadstring(s, file)
	languageContent = func()
end

function widget:Initialize()
	loadLanguage()

	WG['lang'] = {}
	WG['lang'].getLanguage = function()
		return language
	end
	WG['lang'].setLanguage = function(value)
		if value ~= language and languages[value] then
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
