local function eraseLine(starts)
	for i = 1, #starts do
		local pos = starts[i]
		Spring.MarkerErasePosition(pos.x, pos.y, pos.z, nil, false, nil, true)
	end
end

local function removeAllLines()
	local api = GG['MissionAPI']
	for _, starts in pairs(api.lineNames) do
		eraseLine(starts)
	end
	api.lineNames = {}
end

return {
	{
		type = 'RemoveAllLines',
		parameters = {},
		actionFunction = removeAllLines,
	}
}
