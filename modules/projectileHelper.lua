local mathSqrt = math.sqrt

--- Calculate flightTime using the linear accelerated movement formula
---
--- It can work either in elmos/frame -> frames, or elmos/second -> seconds.
--- Make sure all input parameters are in consistent units.
---
--- @param initialVelocity number Start velocity in either elmos/frame or elmos/s
--- @param maximumVelocity number Maximum velocity in either elmos/frame or elmos/s
--- @param accelerationRate number Acceleration in either elmos/frame^2 or elmos/s^2
--- @param totalDistance number Distance in elmos
local function calculateFlightFrames(initialVelocity, maximumVelocity, accelerationRate, totalDistance)
	local totalFrames = 0

	-- Frames to reach maximum velocity
	local framesToMaxVelocity = (maximumVelocity - initialVelocity) / accelerationRate

	-- Distance traveled while accelerating
	local distanceAccelerating = initialVelocity * framesToMaxVelocity + 0.5 * accelerationRate * framesToMaxVelocity^2

	if distanceAccelerating > totalDistance then
		-- We already traveled too much, so just calculate time with accelerated movement + quadratic equation formula
		totalFrames = (mathSqrt(initialVelocity^2 + 2 * totalDistance * accelerationRate) - initialVelocity) / accelerationRate
	else
		-- Linear movement after accelerating
		totalFrames = framesToMaxVelocity + (totalDistance - distanceAccelerating) / maximumVelocity
	end

	-- Return the floored value of total frames
	return totalFrames
end

return {
	calculateFlightFrames = calculateFlightFrames,
}
