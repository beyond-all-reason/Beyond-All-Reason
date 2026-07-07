local ChatEmoji = {}

local IMAGE_DIR = ":n:LuaUI/Images/emojis/twemoji/"
local CUSTOM_IMAGE_DIR = ":n:LuaUI/Images/emojis/custom/"

local aliases = {
	angry = "angry.png",
	clap = "clap.png",
	confused = "confused.png",
	cookie = { image = "cookie.png", custom = true },
	cool = "cool.png",
	cry = "cry.png",
	fire = "fire.png",
	gg = "gg.png",
	grin = "grin.png",
	heart = "heart.png",
	joy = "joy.png",
	laughing = "laughing.png",
	lol = "lol.png",
	ok_hand = "ok_hand.png",
	party = "party.png",
	pleading = "pleading.png",
	pray = "praying.png",
	rofl = "rofl.png",
	sad = "sad.png",
	salute = "salute.png",
	shrug = "shrug.png",
	slight_smile = "slight_smile.png",
	smile = "smile.png",
	smiley = "smiley.png",
	sob = "sob.png",
	skull = "skull.png",
	tada = "tada.png",
	thinking = "thinking.png",
	thumbsdown = "thumbsdown.png",
	thumbsup = "thumbsup.png",
	wave = "wave.png",
	wink = "wink.png",
}

local unicode = {
	angry = "\240\159\152\160",
	clap = "\240\159\145\143",
	confused = "\240\159\152\149",
	cookie = "\240\159\141\170",
	cool = "\240\159\152\142",
	cry = "\240\159\152\162",
	fire = "\240\159\148\165",
	gg = "\240\159\164\157",
	grin = "\240\159\152\129",
	heart = "\226\157\164\239\184\143",
	joy = "\240\159\152\130",
	laughing = "\240\159\152\134",
	lol = "\240\159\152\130",
	ok_hand = "\240\159\145\140",
	party = "\240\159\165\179",
	pleading = "\240\159\165\186",
	pray = "\240\159\153\143",
	rofl = "\240\159\164\163",
	sad = "\240\159\152\162",
	salute = "\240\159\171\161",
	shrug = "\240\159\164\183",
	slight_smile = "\240\159\153\130",
	smile = "\240\159\152\138",
	smiley = "\240\159\152\131",
	sob = "\240\159\152\173",
	skull = "\240\159\146\128",
	tada = "\240\159\142\137",
	thinking = "\240\159\164\148",
	thumbsdown = "\240\159\145\142",
	thumbsup = "\240\159\145\141",
	wave = "\240\159\145\139",
	wink = "\240\159\152\137",
}

local autocompleteAliases = {}
for alias in pairs(aliases) do
	autocompleteAliases[#autocompleteAliases + 1] = ":" .. alias .. ":"
end
table.sort(autocompleteAliases)

local floor = math.floor
local max = math.max
local sfind = string.find
local ssub = string.sub
local sbyte = string.byte
local sort = table.sort

local glColor = gl.Color
local glTexture = gl.Texture
local glTexRect = gl.TexRect

local SEGMENT_TEXT = 1
local SEGMENT_COLOR = 2
local SEGMENT_EMOJI = 3

local MAX_PARSE_CACHE_SIZE = 2048
local parseCache = {}
local parseCacheCount = 0
local MAX_ELIGIBILITY_CACHE_SIZE = 4096
local eligibilityCache = {}
local eligibilityCacheCount = 0
local EMPTY_TABLE = {}

local aliasTokens = {}
local maxAliasTokenLength = 0
local unicodeStartByteLookup = {}
local unicodeStartChars = {}
local aliasImagePaths = {}

local function getImagePath(alias)
	local data = aliases[alias]
	if not data then
		return
	end
	if type(data) == "table" then
		return (data.custom and CUSTOM_IMAGE_DIR or IMAGE_DIR) .. data.image
	end
	return IMAGE_DIR .. data
end

for alias in pairs(aliases) do
	local aliasToken = ":" .. alias .. ":"
	aliasTokens[aliasToken] = alias
	if #aliasToken > maxAliasTokenLength then
		maxAliasTokenLength = #aliasToken
	end
	aliasImagePaths[alias] = getImagePath(alias)
end

for alias, token in pairs(unicode) do
	local startByte = sbyte(token, 1)
	if not unicodeStartByteLookup[startByte] then
		unicodeStartByteLookup[startByte] = {}
		unicodeStartChars[#unicodeStartChars + 1] = string.char(startByte)
	end
	unicodeStartByteLookup[startByte][#unicodeStartByteLookup[startByte] + 1] = {
		token = token,
		alias = alias,
		len = #token,
	}
end

for _, candidates in pairs(unicodeStartByteLookup) do
	sort(candidates, function(a, b)
		return a.len > b.len
	end)
end

local function emojiSize(fontSize)
	return max(12, floor(fontSize * 1.05))
end

local function emojiInlinePadding(fontSize)
	return max(2, floor(fontSize * 0.16))
end

local function emojiVerticalOffset(fontSize, size)
	return -max(3, floor(fontSize * 0.18))
end

function ChatEmoji.HasEmojiCandidate(text)
	if not text then
		return false
	end
	local firstColon = sfind(text, ":", 1, true)
	if firstColon and sfind(text, ":", firstColon + 1, true) then
		return true
	end
	for i = 1, #unicodeStartChars do
		if sfind(text, unicodeStartChars[i], nil, true) then
			return true
		end
	end
	return false
end

local function likelyContainsEmoji(text)
	local cached = eligibilityCache[text]
	if cached ~= nil then
		return cached
	end

	local hasEmoji = ChatEmoji.HasEmojiCandidate(text)

	if eligibilityCache[text] == nil then
		eligibilityCacheCount = eligibilityCacheCount + 1
		if eligibilityCacheCount > MAX_ELIGIBILITY_CACHE_SIZE then
			eligibilityCache = {}
			eligibilityCacheCount = 1
		end
	end
	eligibilityCache[text] = hasEmoji

	return hasEmoji
end

function ChatEmoji.HasEmojiAliasCandidate(text)
	if not text then
		return false
	end
	local firstColon = sfind(text, ":", 1, true)
	if not firstColon then
		return false
	end
	return sfind(text, ":", firstColon + 1, true) ~= nil
end

function ChatEmoji.WordWrapPlain(textLines, maxWidth, usedFont, fontSize)
	local lines = {}
	local lineCount = 0
	for _, line in ipairs(textLines) do
		local linebuffer = ""
		for word in line:gmatch("%S+") do
			if linebuffer ~= "" and (usedFont:GetTextWidth(linebuffer .. " " .. word) * fontSize) > maxWidth then
				lineCount = lineCount + 1
				lines[lineCount] = linebuffer
				linebuffer = ""
			end
			linebuffer = (linebuffer ~= "" and (linebuffer .. " " .. word) or word)
		end
		if linebuffer ~= "" then
			lineCount = lineCount + 1
			lines[lineCount] = linebuffer
		end
	end
	return lines
end

local function parseRichText(text)
	local cached = parseCache[text]
	if cached ~= nil then
		return cached
	end

	local textLen = #text
	local segments = {}
	local segmentCount = 0
	local hasEmoji = false
	local pos = 1
	local chunkStart = 1

	while pos <= textLen do
		local c = sbyte(text, pos)
		local matchedLen = 0
		local matchedAlias
		local consumedColor = false

		if c == 255 and pos + 3 <= textLen then
			if chunkStart < pos then
				segmentCount = segmentCount + 2
				segments[segmentCount - 1] = SEGMENT_TEXT
				segments[segmentCount] = ssub(text, chunkStart, pos - 1)
			end
			segmentCount = segmentCount + 2
			segments[segmentCount - 1] = SEGMENT_COLOR
			segments[segmentCount] = ssub(text, pos, pos + 3)
			pos = pos + 4
			chunkStart = pos
			consumedColor = true
		elseif c == 58 then
			local aliasEnd = sfind(text, ":", pos + 1, true)
			if aliasEnd and aliasEnd <= pos + maxAliasTokenLength - 1 then
				local aliasToken = ssub(text, pos, aliasEnd)
				local aliasMatch = aliasTokens[aliasToken]
				if aliasMatch ~= nil then
					matchedAlias = aliasMatch
					matchedLen = aliasEnd - pos + 1
				end
			end
		end

		if not consumedColor and matchedAlias == nil then
			local unicodeCandidates = unicodeStartByteLookup[c] or EMPTY_TABLE
			for i = 1, #unicodeCandidates do
				local candidate = unicodeCandidates[i]
				if pos + candidate.len - 1 <= textLen and ssub(text, pos, pos + candidate.len - 1) == candidate.token then
					matchedAlias = candidate.alias
					matchedLen = candidate.len
					break
				end
			end
		end

		if consumedColor then
			-- color code already consumed and cursor advanced
		elseif matchedAlias ~= nil and matchedLen > 0 then
			if chunkStart < pos then
				segmentCount = segmentCount + 2
				segments[segmentCount - 1] = SEGMENT_TEXT
				segments[segmentCount] = ssub(text, chunkStart, pos - 1)
			end
			segmentCount = segmentCount + 2
			segments[segmentCount - 1] = SEGMENT_EMOJI
			segments[segmentCount] = matchedAlias
			hasEmoji = true
			pos = pos + matchedLen
			chunkStart = pos
		else
			pos = pos + 1
		end
	end

	if chunkStart <= textLen then
		segmentCount = segmentCount + 2
		segments[segmentCount - 1] = SEGMENT_TEXT
		segments[segmentCount] = ssub(text, chunkStart, textLen)
	end

	local parsed = {
		segments = segments,
		hasEmoji = hasEmoji,
		widthCache = {},
	}

	if not parseCache[text] then
		parseCacheCount = parseCacheCount + 1
		if parseCacheCount > MAX_PARSE_CACHE_SIZE then
			parseCache = {}
			parseCacheCount = 1
		end
	end
	parseCache[text] = parsed

	return parsed
end

local function emojiTextWidth(text, fontSize, usedFont)
	if not text or text == "" then
		return 0
	end
	if not likelyContainsEmoji(text) then
		return usedFont:GetTextWidth(text) * fontSize
	end

	local parsed = parseRichText(text)
	local fontWidths = parsed.widthCache[usedFont]
	if not fontWidths then
		fontWidths = {}
		parsed.widthCache[usedFont] = fontWidths
	end
	local cachedWidth = fontWidths[fontSize]
	if cachedWidth then
		return cachedWidth
	end

	local width = 0.0
	local size = emojiSize(fontSize)
	local padding = emojiInlinePadding(fontSize)
	local segments = parsed.segments
	for i = 1, #segments, 2 do
		local kind = segments[i]
		local value = segments[i + 1]
		if kind == SEGMENT_TEXT then
			width = width + (usedFont:GetTextWidth(value) * fontSize)
		elseif kind == SEGMENT_EMOJI then
			width = width + size + (padding * 2)
		end
	end

	fontWidths[fontSize] = width
	return width
end

function ChatEmoji.GetAutocompleteAliases()
	return autocompleteAliases
end

function ChatEmoji.GetAliases()
	return autocompleteAliases
end

function ChatEmoji.GetImagePath(aliasTokenOrAlias)
	if not aliasTokenOrAlias then
		return nil
	end
	local alias = aliasTokenOrAlias
	if ssub(aliasTokenOrAlias, 1, 1) == ":" and ssub(aliasTokenOrAlias, -1) == ":" then
		alias = ssub(aliasTokenOrAlias, 2, -2)
	end
	return aliasImagePaths[alias]
end

function ChatEmoji.GetRichTextWidth(text, fontSize, usedFont)
	return emojiTextWidth(text, fontSize, usedFont)
end

function ChatEmoji.GetLeadingColorPrefix(text)
	return text and string.byte(text, 1) == 255 and #text >= 4 and ssub(text, 1, 4) or ""
end

function ChatEmoji.WordWrapRichText(text, maxWidth, fontSize, usedFont)
	local lines = {}
	local lineCount = 0
	local spaceWidth = usedFont:GetTextWidth(" ") * fontSize
	for _, line in ipairs(text) do
		local linebuffer = ""
		local linebufferWidth = 0.0
		local lineHasEmoji = likelyContainsEmoji(line)

		if not lineHasEmoji then
			for word in line:gmatch("%S+") do
				if linebuffer ~= "" and (usedFont:GetTextWidth(linebuffer .. " " .. word) * fontSize) > maxWidth then
					lineCount = lineCount + 1
					lines[lineCount] = linebuffer
					linebuffer = ""
				end
				linebuffer = (linebuffer ~= "" and (linebuffer .. " " .. word) or word)
			end
			if linebuffer ~= "" then
				lineCount = lineCount + 1
				lines[lineCount] = linebuffer
			end
		else
			for word in line:gmatch("%S+") do
				local wordWidth = emojiTextWidth(word, fontSize, usedFont)
				if linebuffer ~= "" and (linebufferWidth + spaceWidth + wordWidth) > maxWidth then
					lineCount = lineCount + 1
					lines[lineCount] = linebuffer
					linebuffer = word
					linebufferWidth = wordWidth
				else
					if linebuffer == "" then
						linebuffer = word
						linebufferWidth = wordWidth
					else
						linebuffer = linebuffer .. " " .. word
						linebufferWidth = linebufferWidth + spaceWidth + wordWidth
					end
				end
			end
			if linebuffer ~= "" then
				lineCount = lineCount + 1
				lines[lineCount] = linebuffer
			end
		end
	end
	return lines
end

function ChatEmoji.DrawRichText(usedFont, text, x, y, fontSize, options, outlineColor)
	if not text or text == "" then
		return
	end
	if not likelyContainsEmoji(text) then
		usedFont:Begin(true)
		usedFont:SetOutlineColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4])
		usedFont:Print(text, x, y, fontSize, options)
		usedFont:End()
		return
	end
	local parsed = parseRichText(text)
	if not parsed.hasEmoji then
		usedFont:Begin(true)
		usedFont:SetOutlineColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4])
		usedFont:Print(text, x, y, fontSize, options)
		usedFont:End()
		return
	end

	local drawX = x
	local activeColor = ""
	local textActive = false
	local textureBound = false
	local lastTexturePath = nil
	local size = emojiSize(fontSize)
	local emojiPadding = emojiInlinePadding(fontSize)
	local emojiYOffset = emojiVerticalOffset(fontSize, size)

	local function beginText()
		if not textActive then
			usedFont:Begin(true)
			usedFont:SetOutlineColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4])
			textActive = true
		end
	end

	local function endText()
		if textActive then
			usedFont:End()
			textActive = false
		end
	end

	local function drawTextChunk(chunk)
		if chunk and chunk ~= "" then
			beginText()
			usedFont:Print(activeColor .. chunk, drawX, y, fontSize, options)
			drawX = drawX + (usedFont:GetTextWidth(chunk) * fontSize)
			-- Font rendering may bind its own atlas texture, so force emoji texture rebind next time.
			lastTexturePath = nil
		end
	end

	local segments = parsed.segments
	for i = 1, #segments, 2 do
		local kind = segments[i]
		local value = segments[i + 1]
		if kind == SEGMENT_TEXT then
			drawTextChunk(value)
		elseif kind == SEGMENT_COLOR then
			activeColor = value
		elseif kind == SEGMENT_EMOJI then
			endText()
			glColor(1, 1, 1, 1)
			local texturePath = aliasImagePaths[value]
			if lastTexturePath ~= texturePath then
				glTexture(texturePath)
				lastTexturePath = texturePath
				textureBound = true
			end
			glTexRect(drawX + emojiPadding, y + emojiYOffset, drawX + emojiPadding + size, y + emojiYOffset + size)
			drawX = drawX + size + (emojiPadding * 2)
		end
	end
	if textureBound then
		glTexture(false)
	end
	endText()
end

return ChatEmoji
