-- Objects include units and features (and maybe other things later)

if not Game then
	return -- parser environments such as modrules have no Game
end

local spGetUnitPosition = Spring.GetUnitPosition
local spGetFeaturePosition = Spring.GetFeaturePosition

local UNIT_ID_MAX = Game.maxUnits
local offsetFeatureID = not Engine.FeatureSupport.noOffsetForFeatureID ---@as boolean

local getFeaturePosition = spGetFeaturePosition
if offsetFeatureID then
	getFeaturePosition = function(featureID)
		return spGetFeaturePosition(featureID - UNIT_ID_MAX)
	end
end

---@param objectID integer a unitID, or a featureID with the Game.maxUnits offset when the engine adds one
local function getObjectPosition(objectID)
	if objectID <= UNIT_ID_MAX then
		return spGetUnitPosition(objectID)
	end
	return getFeaturePosition(objectID)
end

---@param objects integer[]
---@param getPosition fun(objectID: integer): number?, number?, number?
---@return number x
---@return number z
local function getCentroid(objects, getPosition)
	local sumX, sumZ = 0.0, 0.0
	local count = #objects
	for i = 1, count do
		local x, _, z = getPosition(objects[i] --[[@as integer]])
		---@cast x number
		---@cast z number
		sumX, sumZ = sumX + x, sumZ + z
	end
	return sumX / count, sumZ / count
end

return {
	GetObjectPosition = getObjectPosition,
	GetObjectCentroid = getCentroid,
}
