cvMode = Spring.GetModOptions().scoremode

--Is CV Enabled when you launch spring.exe directly?
if cvMode == nil then
	cvMode = "disabled"
end

-- CV Enabled/Disabled Controls
if cvMode == "disabled" then
	return false
end

-------------------------------------------------------
-- Use a building mask for Control Points?
--If this is set to false, then any unit will be buildable in the control point
useBuildingMask = true
-------------------------------------------------------

captureRadius = tonumber(Spring.GetModOptions().captureradius) -- Radius around a point in which to capture it
if captureRadius == nil then
	captureRadius = 500
end

captureTime = tonumber(Spring.GetModOptions().capturetime) -- Time to capture a point
if captureTime == nil then
	captureTime = 30
end

captureBonus = tonumber(Spring.GetModOptions().capturebonus) -- speedup from adding more units
if captureBonus == nil then
	captureBonus = 0.05
else
	captureBonus = captureBonus * 0.01
end

decapSpeed = tonumber(Spring.GetModOptions().decapspeed) -- speed multiplier for neutralizing an enemy point
if decapSpeed == nil then
	decapSpeed = 3
end

dominationScore = tonumber(Spring.GetModOptions().dominationscore)
if dominationScore == nil then
	dominationScore = 1000
end

dominationScoreTime = tonumber(Spring.GetModOptions().dominationscoretime) -- Time needed holding all points to score in multi domination
if dominationScoreTime == nil then
	dominationScoreTime = 30
end

usemapconfig = Spring.GetModOptions().usemapconfig
if usemapconfig == nil then
	usemapconfig = "disabled"
end

limitScore = tonumber(Spring.GetModOptions().limitscore)
if limitScore == nil then
	limitScore = 3500
end

-- These are together because they cover the same area (resourcing)
metalPerPoint = tonumber(Spring.GetModOptions().metalperpoint)
if metalPerPoint == nil then
	metalPerPoint = 0
end

energyPerPoint = tonumber(Spring.GetModOptions().energyperpoint)
if energyPerPoint == nil then
	energyPerPoint = 0
end

numberOfControlPoints = tonumber(Spring.GetModOptions().numberofcontrolpoints)
if numberOfControlPoints == nil then
	numberOfControlPoints = 7
end

startTime = tonumber(Spring.GetModOptions().starttime) -- The time when capturing can start
if startTime == nil then
	startTime = 180
end

tugofWarModifier = tonumber(Spring.GetModOptions().tugofwarmodifier) -- Radius around a point in which to capture it
if tugofWarModifier == nil then
	tugofWarModifier = 2
end