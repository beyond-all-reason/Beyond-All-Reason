local ordinal = VFS.Include("modules/i18n/i18nlib/i18n/ordinal.lua")

local function createOrdinalFunction(locale)
	return function(number)
		if not ordinal then
			-- Fallback if ordinal module fails to load
			local numberString = tostring(number)
			local lastTwoDigits = number % 100
			local lastDigit = number % 10

			if lastTwoDigits == 11 or lastTwoDigits == 12 or lastTwoDigits == 13 then
				return numberString .. "th"
			elseif lastDigit == 1 then
				return numberString .. "st"
			elseif lastDigit == 2 then
				return numberString .. "nd"
			elseif lastDigit == 3 then
				return numberString .. "rd"
			else
				return numberString .. "th"
			end
		end

		local key = ordinal.get(locale, number)
		local suffixes = {
			one = "st",
			two = "nd",
			few = "rd",
			other = "th"
		}
		return tostring(number) .. (suffixes[key] or "th")
	end
end

return {
	en = createOrdinalFunction("en"),
}
