local Capture = {}

Capture.Defaults = {
	-- The full bar is never reached: converting at 99% and handing the new
	-- owner a 95% bar is what stops a unit oscillating on the boundary.
	convertAt = 0.99,
	convertedLevel = 0.95,
	maxProgressPerTick = 0.05,
	baseRate = 0.016667,
	period = 7,
	phase = 2,
	passes = 4,
}

---A policy with every dial filled in.
---@class WaveCaptureRules
---@field convertAt number
---@field convertedLevel number
---@field maxProgressPerTick number
---@field baseRate number
---@field period integer
---@field phase integer
---@field passes integer

---@param capture WaveCapturePolicy|nil
---@return WaveCaptureRules
function Capture.Policy(capture)
	local policy = {}
	for key, value in pairs(Capture.Defaults) do
		policy[key] = value
	end
	for key, value in pairs(capture or {}) do
		policy[key] = value
	end
	return policy
end

---Tougher units resist: the fourth root of def health flattens the range
---between a solar and a fusion into something playable. Damaged units go
---much faster — the cube of the health fraction means a building at half
---health is taken eight times as quickly, so a raid that cannot finish a
---structure still costs you it.
---@param policy WaveCaptureRules
---@param health number
---@param maxHealth number
---@param defHealth number
---@param techAnger number
---@return number progress per tick
function Capture.Rate(policy, health, maxHealth, defHealth, techAnger)
	local toughness = math.ceil(math.sqrt(math.sqrt(defHealth)))
	local rate = policy.baseRate * (3 / toughness) * math.max(0.1, techAnger / 100)
	if health < maxHealth then
		rate = rate / math.max(0.000001, (health / maxHealth) ^ 3)
	end
	return math.min(policy.maxProgressPerTick, rate)
end

---@param policy WaveCaptureRules
---@param captureLevel number
---@param progress number
---@return boolean converts
---@return number level the bar after this tick (the converted level on conversion)
function Capture.Step(policy, captureLevel, progress)
	if captureLevel + progress >= policy.convertAt then
		return true, policy.convertedLevel
	end
	return false, math.min(captureLevel + progress, 1)
end

---Which units a pass visits: a fixed share of the roster, selected by id,
---so the cost spreads evenly however many units exist.
---@param policy WaveCaptureRules
---@param frame integer
---@return integer|nil pass nil when this frame is not a capture beat
function Capture.PassOf(policy, frame)
	if frame % policy.period ~= policy.phase then
		return nil
	end
	return math.floor(frame / policy.period) % policy.passes
end

return Capture
