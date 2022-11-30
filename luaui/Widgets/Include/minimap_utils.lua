local function getMiniMapFlipped()
	if not Spring.GetMiniMapRotation then
		return false
	end

	local rot = Spring.GetMiniMapRotation()

	return rot > math.pi/2 and rot <= 3 * math.pi/2;
end

return { getMiniMapFlipped = getMiniMapFlipped }
