local ChatEmoji = {}

local IMAGE_DIR = ":n:LuaUI/Images/emojis/twemoji/"

local aliases = {
	angry = "angry.png",
	clap = "clap.png",
	confused = "confused.png",
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
	rofl = "rofl.png",
	sad = "sad.png",
	salute = "salute.png",
	shrug = "shrug.png",
	slight_smile = "slight_smile.png",
	smile = "smile.png",
	smiley = "smiley.png",
	sob = "sob.png",
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
	rofl = "\240\159\164\163",
	sad = "\240\159\152\162",
	salute = "\240\159\171\161",
	shrug = "\240\159\164\183",
	slight_smile = "\240\159\153\130",
	smile = "\240\159\152\132",
	smiley = "\240\159\152\131",
	sob = "\240\159\152\173",
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

local glColor = gl.Color
local glTexture = gl.Texture
local glTexRect = gl.TexRect

local function emojiSize(fontSize)
	return max(12, floor(fontSize * 1.05))
end

local function findNextEmoji(text, pos)
	local foundStart, foundEnd, foundAlias
	for alias in pairs(aliases) do
		local aliasToken = ":" .. alias .. ":"
		local aliasStart, aliasEnd = sfind(text, aliasToken, pos, true)
		if aliasStart and (not foundStart or aliasStart < foundStart) then
			foundStart, foundEnd, foundAlias = aliasStart, aliasEnd, alias
		end

		local unicodeToken = unicode[alias]
		if unicodeToken then
			local unicodeStart, unicodeEnd = sfind(text, unicodeToken, pos, true)
			if unicodeStart and (not foundStart or unicodeStart < foundStart) then
				foundStart, foundEnd, foundAlias = unicodeStart, unicodeEnd, alias
			end
		end
	end
	return foundStart, foundEnd, foundAlias
end

local function emojiTextWidth(text, fontSize, usedFont)
	if not text or text == '' then
		return 0
	end

	local width = 0
	local pos = 1
	while pos <= #text do
		local colorStart = sfind(text, "\255", pos, true)
		local emojiStart, emojiEnd, emojiAlias = findNextEmoji(text, pos)
		local nextSpecial = emojiStart
		if colorStart and (not nextSpecial or colorStart < nextSpecial) then
			nextSpecial = colorStart
		end
		if not nextSpecial then
			width = width + (usedFont:GetTextWidth(ssub(text, pos)) * fontSize)
			break
		end
		if nextSpecial > pos then
			width = width + (usedFont:GetTextWidth(ssub(text, pos, nextSpecial - 1)) * fontSize)
		end
		if colorStart == nextSpecial then
			pos = math.min(#text + 1, colorStart + 4)
		elseif emojiAlias then
			width = width + emojiSize(fontSize) + 2
			pos = emojiEnd + 1
		end
	end
	return width
end

function ChatEmoji.GetAutocompleteAliases()
	return autocompleteAliases
end

function ChatEmoji.GetLeadingColorPrefix(text)
	return text and string.byte(text, 1) == 255 and #text >= 4 and ssub(text, 1, 4) or ''
end

function ChatEmoji.WordWrapRichText(text, maxWidth, fontSize, usedFont)
	local lines = {}
	local lineCount = 0
	for _, line in ipairs(text) do
		local words = {}
		local wordsCount = 0
		local linebuffer = ''
		for w in line:gmatch("%S+") do
			wordsCount = wordsCount + 1
			words[wordsCount] = w
		end
		for _, word in ipairs(words) do
			local candidate = linebuffer ~= '' and (linebuffer .. ' ' .. word) or word
			if linebuffer ~= '' and emojiTextWidth(candidate, fontSize, usedFont) > maxWidth then
				lineCount = lineCount + 1
				lines[lineCount] = linebuffer
				linebuffer = word
			else
				linebuffer = candidate
			end
		end
		if linebuffer ~= '' then
			lineCount = lineCount + 1
			lines[lineCount] = linebuffer
		end
	end
	return lines
end

function ChatEmoji.DrawRichText(usedFont, text, x, y, fontSize, options, outlineColor)
	if not text or text == '' then
		return
	end
	if not sfind(text, ":", nil, true) and not findNextEmoji(text, 1) then
		usedFont:Begin(true)
		usedFont:SetOutlineColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4])
		usedFont:Print(text, x, y, fontSize, options)
		usedFont:End()
		return
	end

	local pos = 1
	local drawX = x
	local activeColor = ''
	local textActive = false
	local size = emojiSize(fontSize)
	local emojiYOffset = max(0, floor((fontSize - size) * 0.35))

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
		if chunk and chunk ~= '' then
			beginText()
			usedFont:Print(activeColor .. chunk, drawX, y, fontSize, options)
			drawX = drawX + (usedFont:GetTextWidth(chunk) * fontSize)
		end
	end

	while pos <= #text do
		local colorStart = sfind(text, "\255", pos, true)
		local emojiStart, emojiEnd, emojiAlias = findNextEmoji(text, pos)
		local nextSpecial = emojiStart
		if colorStart and (not nextSpecial or colorStart < nextSpecial) then
			nextSpecial = colorStart
		end
		if not nextSpecial then
			drawTextChunk(ssub(text, pos))
			break
		end
		drawTextChunk(ssub(text, pos, nextSpecial - 1))
		if colorStart == nextSpecial and colorStart + 3 <= #text then
			activeColor = ssub(text, colorStart, colorStart + 3)
			pos = colorStart + 4
		elseif emojiAlias then
			endText()
			glColor(1, 1, 1, 1)
			glTexture(IMAGE_DIR .. aliases[emojiAlias])
			glTexRect(drawX, y + emojiYOffset, drawX + size, y + emojiYOffset + size)
			glTexture(false)
			drawX = drawX + size + 2
			pos = emojiEnd + 1
		else
			break
		end
	end
	endText()
end

return ChatEmoji
