local widget = widget ---@type Widget

function widget:GetInfo()
  return {
	name      = "Game Speed",
	desc      = "Overrides increasing/decreasing game speed behaviour",
	author    = "Beherith",
	date      = "2020",
	license   = "GNU GPL, v2 or later",
	layer     = -999999,
	enabled   = true,
  }
end

-- The number of speed gradations should be minimized,
-- while maintaining suitable fine control around normal (1×) speed
local speedLevels = {
	0.1, -- this speed cannot be set, as engine enforces speed > 0.2
	0.25,
	0.5,
	0.8,
	1,
	1.1,
	1.25,
	1.5,
	1.75,
	2,
	5,
	10,
	20,
}

local function setGameSpeed(speed)
	if Spring.Utilities.Gametype.IsSinglePlayer() or Spring.IsCheatingEnabled() or Spring.IsReplay() then
		Spring.SendCommands("setspeed " .. speed)
	end
end

local function increaseSpeed()
	local currentSpeed = Spring.GetGameSpeed()

	if currentSpeed >= speedLevels[#speedLevels] then
		return
	end

	local i = 1
	while speedLevels[i] <= currentSpeed do
		i = i + 1
	end

	setGameSpeed(speedLevels[i])
end

local function decreaseSpeed()
	local currentSpeed = Spring.GetGameSpeed()

	if currentSpeed <= speedLevels[1] then
		return
	end

	local i = #speedLevels
	while speedLevels[i] >= currentSpeed do
		i = i - 1
	end

	setGameSpeed(speedLevels[i])
end

function widget:Initialize()
	widgetHandler:AddAction("increasespeed", increaseSpeed, nil, 'pR')
	widgetHandler:AddAction("decreasespeed", decreaseSpeed, nil, 'pR')
end
