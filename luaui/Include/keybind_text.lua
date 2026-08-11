-- Text measuring shared by the keybind editor's controls, so a label clipped in one
-- control clips the same way in the next. The font is passed in because each control
-- draws with its own.

local utf8 = VFS.Include('common/luaUtilities/utf8.lua')

local M = {}

-- Shortens text until it draws inside maxWidth, marking the cut with "..".
function M.fit(font, text, maxWidth, size)
	-- Callers derive the width by subtracting, so it can come through negative. Returning
	-- the text whole there draws it straight out of whatever it was meant to fit inside.
	if maxWidth <= 0 then
		return ""
	end

	if font:GetTextWidth(text) * size <= maxWidth then
		return text
	end

	-- Trimmed by character, not byte: translated labels and the chain arrow are multi-byte.
	local len = utf8.len(text)
	while len > 1 and font:GetTextWidth(text .. "..") * size > maxWidth do
		len = len - 1
		text = utf8.sub(text, 1, len)
	end

	return text .. ".."
end

-- Splits text into lines that each draw inside maxWidth. A word too long to fit is left
-- over-long for the caller to shorten, there being nowhere sensible to break it.
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

return M
