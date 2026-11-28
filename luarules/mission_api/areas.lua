---
--- Named areas, which mission actions add, reshape over time, and remove.
---
--- Anything that reads an area by its name sees its current shape, and finds no area
--- while the name is removed or not yet added. A name can be added again after removal.
---

local areaNames = GG["MissionAPI"].areaNames
local areaReshapes = GG["MissionAPI"].areaReshapes

local function secondsToFrames(seconds)
	return math.floor(seconds * Game.gameSpeed + 0.5)
end

local function isRectangle(area)
	return area.x1 ~= nil
end

local function interpolateExtent(fromExtent, toExtent, progress, easing)
	local edgePaced = fromExtent + (toExtent - fromExtent) * progress
	local areaPaced = math.sqrt(fromExtent * fromExtent + (toExtent * toExtent - fromExtent * fromExtent) * progress)
	return edgePaced + (areaPaced - edgePaced) * easing
end

local function writeReshapedArea(area, fromArea, toArea, progress, easing)
	if isRectangle(toArea) then
		local fromCenterX, toCenterX = (fromArea.x1 + fromArea.x2) * 0.5, (toArea.x1 + toArea.x2) * 0.5
		local fromCenterZ, toCenterZ = (fromArea.z1 + fromArea.z2) * 0.5, (toArea.z1 + toArea.z2) * 0.5
		local centerX = fromCenterX + (toCenterX - fromCenterX) * progress
		local centerZ = fromCenterZ + (toCenterZ - fromCenterZ) * progress
		local halfWidth =
			interpolateExtent((fromArea.x2 - fromArea.x1) * 0.5, (toArea.x2 - toArea.x1) * 0.5, progress, easing)
		local halfDepth =
			interpolateExtent((fromArea.z2 - fromArea.z1) * 0.5, (toArea.z2 - toArea.z1) * 0.5, progress, easing)
		area.x1, area.x2 = centerX - halfWidth, centerX + halfWidth
		area.z1, area.z2 = centerZ - halfDepth, centerZ + halfDepth
	else
		area.x = fromArea.x + (toArea.x - fromArea.x) * progress
		area.z = fromArea.z + (toArea.z - fromArea.z) * progress
		area.radius = interpolateExtent(fromArea.radius, toArea.radius, progress, easing)
	end
end

--- An area table is its own shape. An area name gives that area's current shape, or nil when the name has no area.
---@param area table|string a rectangle { x1, z1, x2, z2 } or circle { x, z, radius }, or an area name
---@return table?
local function resolveArea(area)
	if type(area) == "string" then
		return areaNames[area]
	end
	return area
end

--- An area name as the shape copies that area's current shape, and adds nothing when the name has no area.
---@param areaName string
---@param area table|string a rectangle { x1, z1, x2, z2 } or circle { x, z, radius }, or an area name
local function addArea(areaName, area)
	local shape = resolveArea(area)
	if shape == nil then
		return
	end
	areaReshapes[areaName] = nil
	areaNames[areaName] = table.copy(shape)
end

--- A reshape starts from the area's current shape and replaces any reshape already under way.
--- With no duration, or between a rectangle and a circle, the area takes its new shape at once.
---@param areaName string
---@param area table|string a rectangle { x1, z1, x2, z2 } or circle { x, z, radius }, or an area name
---@param duration number? seconds
---@param easing number? 0.0 moves the edges at a constant speed, 1.0 changes the covered area at a constant rate
local function reshapeArea(areaName, area, duration, easing)
	local currentArea = areaNames[areaName]
	local shape = resolveArea(area)
	if currentArea == nil or shape == nil then
		return
	end

	local frames = duration and secondsToFrames(duration) or 0
	if frames <= 0 or isRectangle(currentArea) ~= isRectangle(shape) then
		addArea(areaName, shape)
		return
	end

	local frameNumber = Spring.GetGameFrame()
	areaReshapes[areaName] = {
		fromArea = table.copy(currentArea),
		toArea = table.copy(shape),
		startFrame = frameNumber,
		endFrame = frameNumber + frames,
		easing = easing or 0.0,
	}
end

---@param areaName string
local function removeArea(areaName)
	areaReshapes[areaName] = nil
	areaNames[areaName] = nil
end

local function updateReshapes(frameNumber)
	for areaName, reshape in pairs(areaReshapes) do
		if frameNumber >= reshape.endFrame then
			areaReshapes[areaName] = nil
			areaNames[areaName] = reshape.toArea
		else
			local progress = (frameNumber - reshape.startFrame) / (reshape.endFrame - reshape.startFrame)
			writeReshapedArea(areaNames[areaName], reshape.fromArea, reshape.toArea, progress, reshape.easing)
		end
	end
end

return {
	ResolveArea = resolveArea,
	AddArea = addArea,
	ReshapeArea = reshapeArea,
	RemoveArea = removeArea,
	UpdateReshapes = updateReshapes,
}
