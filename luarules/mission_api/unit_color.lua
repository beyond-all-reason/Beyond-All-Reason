local PARAM = "mission_unit_color"
local SYNC_ACTION = "MissionUnitColor"

---@param color table? channels 0 to 1, a list or named r, g, b; nil gives the unit its team's color back
local function set(unitID, color)
	local packed = 0
	if color then
		local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
		-- 0 stands for the team's color, so black packs to 1.
		packed = math.max(1, BAR.Utilities.Color.ToInt(r, g, b))
	end
	-- The rules param outlives a /luarules reload, the message draws the change at once.
	Spring.SetUnitRulesParam(unitID, PARAM, packed, { inlos = true })
	SendToUnsynced(SYNC_ACTION, unitID, packed)
end

return {
	Set = set,
}
