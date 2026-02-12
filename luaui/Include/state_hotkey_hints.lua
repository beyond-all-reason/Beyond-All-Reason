local M = {}

local function getTapCount(rawHotkey)
	if type(rawHotkey) ~= "string" or rawHotkey == "" then
		return 0
	end

	local taps = 1
	for _ in string.gmatch(rawHotkey, ",") do
		taps = taps + 1
	end
	return taps
end

function M.buildStateHotkeyHints(actionHotkeys, actionName, stateCount, sanitizeHotkeyFn, getStateLabelFn)
	if type(actionHotkeys) ~= "table" or type(actionName) ~= "string" or type(stateCount) ~= "number" then
		return {}
	end

	local hints = {}
	local dedupe = {}

	for stateValue = 0, stateCount - 1 do
		local rawHotkey = actionHotkeys[actionName .. "_" .. stateValue]
		if rawHotkey ~= nil and rawHotkey ~= "" then
			local hotkey = rawHotkey
			if sanitizeHotkeyFn then
				hotkey = sanitizeHotkeyFn(rawHotkey)
			end
			if hotkey ~= nil and hotkey ~= "" then
				local stateLabel = tostring(stateValue)
				if getStateLabelFn then
					stateLabel = getStateLabelFn(stateValue) or stateLabel
				end

				local dedupeKey = hotkey .. "\31" .. stateLabel
				if not dedupe[dedupeKey] then
					dedupe[dedupeKey] = true
					hints[#hints + 1] = {
						hotkey = hotkey,
						stateLabel = stateLabel,
						taps = getTapCount(rawHotkey),
					}
				end
			end
		end
	end

	table.sort(hints, function(a, b)
		if a.taps ~= b.taps then
			return a.taps < b.taps
		end
		if #a.hotkey ~= #b.hotkey then
			return #a.hotkey < #b.hotkey
		end
		return a.hotkey < b.hotkey
	end)

	return hints
end

function M.formatStateHotkeyHints(hints, highlightColor, textColor)
	if type(hints) ~= "table" or #hints == 0 then
		return ""
	end

	local lines = {}
	for i = 1, #hints do
		local hint = hints[i]
		lines[#lines + 1] = string.format(
			"%s%s%s = %s",
			highlightColor or "",
			string.upper(hint.hotkey),
			textColor or "",
			hint.stateLabel
		)
	end

	return table.concat(lines, "\n")
end

return M
