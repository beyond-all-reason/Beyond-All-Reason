local aestheticCustomCostRound = {}

function aestheticCustomCostRound.customRound(value)
	if value < 15 then
		return math.floor(value)
	elseif value < 100 then
		return math.floor(value / 5 + 0.5) * 5
	else
		return math.floor(value / 10 + 0.5) * 10
	end
end

return aestheticCustomCostRound
