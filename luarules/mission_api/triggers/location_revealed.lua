local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Fires when an area comes into the vision of an allyTeam, such as a wreck field or a cache.
-- The engine has no call-in for a position entering line of sight, so the area is polled.
-- Repeating triggers fire again each time the area comes back into sight after leaving it.

-- Half a second is soon enough for a line of dialogue, at a few LOS reads per trigger.
local CHECK_INTERVAL_FRAMES = math.floor(0.5 * Game.gameSpeed)

-- Four LOS squares at losMipLevel 3, so sight cannot reach far into an area between samples.
local SAMPLE_SPACING = 256

-- An even step count keeps the centre of the area a sample.
local function stepsAcross(length)
	return 2 * math.ceil(length / (2 * SAMPLE_SPACING))
end

local function getSamplePoints(area)
	local x1, z1, x2, z2 = area.x1, area.z1, area.x2, area.z2
	if not x1 then
		x1, z1 = area.x - area.radius, area.z - area.radius
		x2, z2 = area.x + area.radius, area.z + area.radius
	end
	local stepsX, stepsZ = stepsAcross(x2 - x1), stepsAcross(z2 - z1)
	local points = {}
	for i = 0, stepsX do
		for j = 0, stepsZ do
			local x = x1 + (x2 - x1) * i / math.max(stepsX, 1)
			local z = z1 + (z2 - z1) * j / math.max(stepsZ, 1)
			if math.isPointInArea(x, z, area) then
				points[#points + 1] = { x = x, z = z, y = Spring.GetGroundHeight(x, z) }
			end
		end
	end
	return points
end

local function isAreaInLos(points, allyTeamID)
	for _, point in ipairs(points) do
		if Spring.IsPosInLos(point.x, point.y, point.z, allyTeamID) then
			return true
		end
	end
	return false
end

return {
	type = 'LocationRevealed',
	parameters = {
		-- Rectangle: { x1 = 0, z1 = 0, x2 = 123, z2 = 123 } with x1 < x2 and z1 < z2
		-- Circle: { x = 0, z = 0, radius = 123 }, where a radius of 0 is a single point
		{ name = 'area',           required = true, type = ParameterTypes.Area },
		{ name = 'sensorAllyTeam', required = true, type = ParameterTypes.AllyTeamID },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context, frameNumber)
			if frameNumber % CHECK_INTERVAL_FRAMES ~= 0 then
				return
			end
			if trigger.triggered and not trigger.settings.repeating then
				return
			end

			local parameters = trigger.parameters
			local location = context.RevealedLocations[triggerID]
			if not location then
				location = { points = getSamplePoints(parameters.area), revealed = false }
				context.RevealedLocations[triggerID] = location
			end

			if not isAreaInLos(location.points, parameters.sensorAllyTeam) then
				location.revealed = false
			elseif not location.revealed and context.ActivateTrigger(trigger) then
				location.revealed = true
			end
		end,
	},
}
