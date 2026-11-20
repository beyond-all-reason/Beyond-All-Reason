local PARAM = "mission_unit_color"
local SYNC_ACTION = "MissionUnitColor"

local function channel(value)
	return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
end

--- Never 0, which stands for the team's color.
---@param color table channels 0 to 1: a list from an action, named in the mission's own loadout
---@return number packed R * 65536 + G * 256 + B, channels 0 to 255
local function pack(color)
	local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
	return math.max(1, channel(r) * 65536 + channel(g) * 256 + channel(b))
end

---@param color table? nil gives the unit its team's color back
local function set(unitID, color)
	local packed = color and pack(color) or 0
	-- The rules param outlives a /luarules reload, the message draws the change at once.
	Spring.SetUnitRulesParam(unitID, PARAM, packed, { inlos = true })
	SendToUnsynced(SYNC_ACTION, unitID, packed)
end

return {
	Set = set,
}
