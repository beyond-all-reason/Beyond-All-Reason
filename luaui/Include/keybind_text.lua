-- Text measuring shared by the keybind editor's controls and the game info panel's rows,
-- so a label clipped in one control clips the same way in the next. The font is passed in
-- because each control draws with its own.

local utf8 = VFS.Include("common/luaUtilities/utf8.lua")

local M = {}

local mathFloor = math.floor

-- Asked of the font once: it does not change with the size the text is drawn at, and baseline
-- runs for every label on every frame.
local bodyHeight = setmetatable({}, { __mode = "k" })

-- Printing with "v" centres the glyphs the string happens to have, so a string with no
-- descender sits lower than one beside it. Measuring the band instead keeps a row of labels
-- on one line.
function M.baseline(font, y1, y2, size)
	local body = bodyHeight[font]
	if not body then
		-- A lowercase x sits on the baseline and reaches neither above nor below the band.
		body = font:GetTextHeight("x")
		bodyHeight[font] = body
	end

	-- Rounded, not floored: always taking the lower one leaves every label sitting a pixel low.
	return mathFloor((y1 + y2) * 0.5 - size * body * 0.5 + 0.5)
end

-- Shortens text until it draws inside maxWidth, marking the cut with "..".
function M.fit(font, text, maxWidth, size)
	-- Callers derive the width by subtracting, so it can come through negative.
	if maxWidth <= 0 then
		return ""
	end

	local width = font:GetTextWidth(text) * size
	if width <= maxWidth then
		return text
	end

	-- Trimmed by character, not byte: translated labels and the chain arrow are multi-byte.
	local len = utf8.len(text)
	local markW = font:GetTextWidth("..") * size
	local keep = math.max(1, math.min(len - 1, math.floor(len * (maxWidth - markW) / width)))
	local cut = utf8.sub(text, 1, keep)
	while keep > 1 and font:GetTextWidth(cut .. "..") * size > maxWidth do
		keep = keep - 1
		cut = utf8.sub(text, 1, keep)
	end
	while keep < len - 1 do
		local longer = utf8.sub(text, 1, keep + 1)
		if font:GetTextWidth(longer .. "..") * size > maxWidth then
			break
		end
		keep, cut = keep + 1, longer
	end

	return cut .. ".."
end

-- A word too long to fit is left over-long, there being nowhere sensible to break it.
function M.wrap(font, text, maxWidth, size)
	local lines = {}
	local line
	for word in text:gmatch("%S+") do
		local candidate = line and (line .. " " .. word) or word
		if line and font:GetTextWidth(candidate) * size > maxWidth then
			lines[#lines + 1] = line
			line = word
		else
			line = candidate
		end
	end
	if line then
		lines[#lines + 1] = line
	end

	return lines
end

-- A tooltip prints its text a line at a time, each from the tooltip own colour, so a colour
-- set on one line would be lost on the next.
function M.carryColors(str)
	local out, current = {}, nil
	for line in (str .. "\n"):gmatch("([^\n]*)\n") do
		if current and line ~= "" and line:byte(1) ~= 255 then
			line = current .. line
		end
		for code in line:gmatch("\255...") do
			current = code
		end
		out[#out + 1] = line
	end

	return table.concat(out, "\n")
end

return M
