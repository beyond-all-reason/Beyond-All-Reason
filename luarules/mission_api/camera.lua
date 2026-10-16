---
--- Turns camera action parameters into the targets and keyframes WG.cinematicCamera takes.
--- The actions send them through api_mission_camera.lua, unsynced, to LuaUI.
---

---@param unitName string?
---@param position { x: number, y: number, z: number }?
---@param offset { x: number, y: number, z: number }?
---@param relativeToHeading boolean?
local function buildTarget(unitName, position, offset, relativeToHeading)
	if position then
		return {
			x = position.x,
			y = position.y,
			z = position.z,
			offset = offset,
			relativeToHeading = relativeToHeading,
		}
	end

	-- LuaUI only knows where units in LOS are, so it starts from where synced sees them.
	local unitIDs = GG["MissionAPI"].Modules.UnitQuery.MatchingUnits(unitName)
	local x, y, z = Spring.GetUnitArrayCentroid(unitIDs)
	return {
		unitIDs = unitIDs,
		lastX = x,
		lastY = y,
		lastZ = z,
		offset = offset,
		relativeToHeading = relativeToHeading,
	}
end

local function buildKeyframes(keyframes)
	local built = {}
	for i, keyframe in ipairs(keyframes) do
		local offset
		if keyframe.offsetX or keyframe.offsetY or keyframe.offsetZ then
			offset = { x = keyframe.offsetX or 0, y = keyframe.offsetY or 0, z = keyframe.offsetZ or 0 }
		end

		local lookAt
		if keyframe.lookAtPosition or keyframe.lookAtUnitName then
			lookAt = buildTarget(keyframe.lookAtUnitName, keyframe.lookAtPosition)
		end

		built[i] = {
			position = buildTarget(keyframe.unitName, keyframe.position, offset, keyframe.relativeToHeading),
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

return {
	BuildTarget = buildTarget,
	BuildKeyframes = buildKeyframes,
}
