local function en(number)
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

return {
	en = en,
}
