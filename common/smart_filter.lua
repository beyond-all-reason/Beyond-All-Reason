-- common/smart_filter.lua
--
-- The smart filter test the brush tools share: may a stamp land at (x, z)?
-- Feature scatter (common/feature_scatter.lua), the feature and unit placers,
-- the grass brush and the LAYERS painter all ask the same five questions:
--   avoidWater    refuses ground below 0
--   avoidCliffs   refuses slopes steeper than slopeMax degrees (default 45)
--   preferSlopes  refuses slopes flatter than slopeMin degrees (default 10)
--   altMinEnable  refuses ground below altMin
--   altMaxEnable  refuses ground above altMax
-- Whether the filter is on at all stays with the caller.
--
-- Pure Lua, safe in synced code (feature scatter runs in the gadget too).

local cos = math.cos
local pi = math.pi
local GetGroundHeight = Spring.GetGroundHeight
local GetGroundNormal = Spring.GetGroundNormal

---@class SmartFilterSettings
---@field avoidWater boolean?
---@field avoidCliffs boolean?
---@field preferSlopes boolean?
---@field slopeMax number? degrees
---@field slopeMin number? degrees
---@field altMinEnable boolean?
---@field altMin number?
---@field altMaxEnable boolean?
---@field altMax number?

---True when the filter lets a stamp land at (x, z).
---@param x number
---@param z number
---@param sf table SmartFilterSettings fields; the tools pass their own state tables
---@param h number? the ground height there, when the caller has it already
---@return boolean
local function passes(x, z, sf, h)
	h = h or GetGroundHeight(x, z)
	if sf.avoidWater and h < 0 then
		return false
	end
	if sf.avoidCliffs or sf.preferSlopes then
		local _, ny = GetGroundNormal(x, z)
		ny = ny or 1.0
		if sf.avoidCliffs and ny < cos((sf.slopeMax or 45) * pi / 180) then
			return false
		end
		if sf.preferSlopes and ny > cos((sf.slopeMin or 10) * pi / 180) then
			return false
		end
	end
	if sf.altMinEnable and sf.altMin and h < sf.altMin then
		return false
	end
	if sf.altMaxEnable and sf.altMax and h > sf.altMax then
		return false
	end
	return true
end

return {
	passes = passes,
}
