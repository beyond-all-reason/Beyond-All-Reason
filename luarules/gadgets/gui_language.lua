function gadget:GetInfo()
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

if gadgetHandler:IsSyncedCode() then
	return
end

local noTranslationText = '---'

local languageContent = {}

local function loadLanguage()
	-- load base language file (english)
	local language = 'en'
	local file = "language/"..language..".lua"
	local s = assert(VFS.LoadFile(file, VFS.RAW_FIRST))
	local func = loadstring(s, file)
	languageContent = func()
end

function gadget:Initialize()
	loadLanguage()

	GG.lang = {}
	GG.lang.getText = function(id, subId)
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

function gadget:Shutdown()
	GG.lang = nil
end
