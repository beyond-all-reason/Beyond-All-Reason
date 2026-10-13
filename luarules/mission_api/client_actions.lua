---
--- Actions that take effect on the players' clients: the camera actions.
--- They have to reach LuaUI, unlike the unit markers an unsynced gadget draws itself: the camera is
--- widget territory (WG.cinematicCamera).
--- Synced code resolves unit names to units and sends one command table to every client,
--- where luarules/gadgets/api_mission_client_actions.lua hands it to LuaUI
--- (luaui/Widgets/api_mission_client_actions.lua). Defaults live in the widgets, so an
--- optional parameter a mission leaves out travels as nil.
---

local SYNC_ACTION = "MissionClientAction"

---The living units behind one name or a list of names, each once.
---@param unitName string?
---@param unitNames string[]?
---@return UnitID[]
local function unitIDsOf(unitName, unitNames)
	local matchingUnits = GG["MissionAPI"].Modules.UnitQuery.MatchingUnits
	local unitIDs = {}
	local seen = {}
	local function add(name)
		for _, unitID in ipairs(matchingUnits(name)) do
			if not seen[unitID] then
				seen[unitID] = true
				unitIDs[#unitIDs + 1] = unitID
			end
		end
	end
	if unitName then
		add(unitName)
	end
	for _, name in ipairs(unitNames or {}) do
		add(name)
	end
	return unitIDs
end

---Where the units are now, as the widget's first "last seen" point: the client only sees
---units in its line of sight, so a hidden target would otherwise start out at the map origin.
---@param unitIDs UnitID[]
local function centroid(unitIDs)
	local n = 0
	local sx, sy, sz = 0.0, 0.0, 0.0
	for _, unitID in ipairs(unitIDs) do
		local x, y, z = Spring.GetUnitPosition(unitID)
		if x then
			n, sx, sy, sz = n + 1, sx + x, sy + y, sz + z
		end
	end
	if n > 0 then
		return sx / n, sy / n, sz / n
	end
end

---A camera target as the widget wants it: a point, or the units to follow, moved by an offset.
---A position wins when units are named as well; unitName and unitNames add up.
---@param unitName string?
---@param unitNames string[]?
---@param position { x: number, y: number, z: number }?
---@param offset { x: number, y: number, z: number }?
---@param relativeToHeading boolean? the offset turns with the first unit's heading
local function buildTarget(unitName, unitNames, position, offset, relativeToHeading)
	if position then
		return {
			x = position.x,
			y = position.y,
			z = position.z,
			offset = offset,
			relativeToHeading = relativeToHeading,
		}
	end
	local unitIDs = unitIDsOf(unitName, unitNames)
	local x, y, z = centroid(unitIDs)
	return {
		unitIDs = unitIDs,
		lastX = x,
		lastY = y,
		lastZ = z,
		offset = offset,
		relativeToHeading = relativeToHeading,
	}
end

---Keyframes as authored (see camera_keyframe_schema.lua) to keyframes as the widget wants them.
local function buildKeyframes(keyframes)
	local built = {}
	for i, keyframe in ipairs(keyframes) do
		local offset
		if keyframe.offsetX or keyframe.offsetY or keyframe.offsetZ then
			offset = { x = keyframe.offsetX or 0, y = keyframe.offsetY or 0, z = keyframe.offsetZ or 0 }
		end
		local position =
			buildTarget(keyframe.unitName, nil, keyframe.position, offset, offset and keyframe.relativeToHeading)

		local lookAt
		if keyframe.lookAtPosition or keyframe.lookAtUnitName or keyframe.lookAtUnitNames then
			lookAt = buildTarget(keyframe.lookAtUnitName, keyframe.lookAtUnitNames, keyframe.lookAtPosition)
		end

		built[i] = {
			position = position,
			lookAt = lookAt,
			pitch = keyframe.pitch,
			yaw = keyframe.yaw,
			roll = keyframe.roll,
			fov = keyframe.fov,
			duration = keyframe.duration,
			hold = keyframe.hold,
			easing = keyframe.easing,
			path = keyframe.path,
		}
	end
	return built
end

---@param kind string what the client should do, see the widget's handlers
---@param params table
---@param teamID TeamID? only this team's players act on it; every client otherwise
local function send(kind, params, teamID)
	SendToUnsynced(SYNC_ACTION, { kind = kind, teamID = teamID, params = params })
end

return {
	BuildTarget = buildTarget,
	BuildKeyframes = buildKeyframes,
	Send = send,
}
