-- common/vectors.lua
--
-- Vector operations on number components.

local math_sqrt = math.sqrt
local math_acos = math.acos
local math_sin = math.sin

local ARC_EPSILON = 1e-6
local ARC_NORMAL_EPSILON = 1 - 1e-6

---@param vx number
---@param vy number
---@param vz number
---@param speed number the length of `v`
---@param tx number
---@param ty number
---@param tz number `t` is a unit vector
---@param angleMax number radians
---@return number vx
---@return number vy
---@return number vz
local function slerp(vx, vy, vz, speed, tx, ty, tz, angleMax)
	local cosAngle = (vx * tx + vy * ty + vz * tz) / speed
	if cosAngle > 1 then
		cosAngle = 1
	elseif cosAngle < -1 then
		cosAngle = -1
	end

	-- Near-zero sine is parallel or antiparallel and gets skipped.
	local sinAngle = math_sqrt(1 - cosAngle * cosAngle)
	if sinAngle > ARC_EPSILON then
		local angle = math_acos(cosAngle)
		local factor = angleMax / angle
		if factor < ARC_NORMAL_EPSILON then
			local weight1 = math_sin((1 - factor) * angle) / speed
			local weight2 = math_sin(factor * angle)
			local scale = speed / sinAngle
			vx = (vx * weight1 + tx * weight2) * scale
			vy = (vy * weight1 + ty * weight2) * scale
			vz = (vz * weight1 + tz * weight2) * scale
		else
			vx, vy, vz = tx * speed, ty * speed, tz * speed
		end
	end

	return vx, vy, vz
end

return {
	slerp = slerp,
}
