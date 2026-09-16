local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Submersion",
		desc = "Sets the water depth at which units pass below the surface.",
		author = "efrec",
		version = "1.0",
		date = "2026-09",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

--------------------------------------------------------------------------------
--
--    customparams = {
--        water_submersion_depth := <number>
--    }
--
-- The engine submerges a unit once its midpoint plus its radius drops below the
-- water surface, and both of those come from the model rather than from the
-- collision volume. The depth at which a unit stops being a target is therefore
-- unrelated to the depth at which it stops being hittable.
--
-- The submersion depth, in elmos, replaces the radius that the unit carries in
-- water, and its midpoint as well when the radius alone cannot reach that deep.
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local radiusMin = 1.0 -- The engine clamps the radius above this value.

--------------------------------------------------------------------------------
-- Locals ----------------------------------------------------------------------

local spGetAllUnits = Spring.GetAllUnits
local spGetUnitDefDimensions = Spring.GetUnitDefDimensions
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetWaterLevel = Spring.GetWaterLevel
local spSetUnitMidAndAimPos = Spring.SetUnitMidAndAimPos
local spSetUnitRadiusAndHeight = Spring.SetUnitRadiusAndHeight

--------------------------------------------------------------------------------
-- Setup -----------------------------------------------------------------------

---@class SubmersionParams
---@field midX number
---@field midZ number
---@field modelMidY number
---@field modelRadius number
---@field waterMidY number?
---@field waterRadius number

local submersionParams = {} ---@type table<integer, SubmersionParams>

for unitDefID, unitDef in pairs(UnitDefs) do
	local param = unitDef.customParams.water_submersion_depth
	if param then
		local depth = tonumber(param)
		local dims = depth and spGetUnitDefDimensions(unitDefID)
		if not depth or depth < radiusMin then
			Spring.Log(
				gadget:GetInfo().name,
				LOG.WARNING,
				"Skipped " .. unitDef.name .. ". The submersion depth must be a number >= " .. radiusMin .. "."
			)
		elseif not dims then
			-- Unit has no model?
		else
			local params = {
				midX = dims.midx,
				midZ = dims.midz,
				modelMidY = dims.midy,
				modelRadius = dims.radius,
				waterRadius = depth - dims.midy,
			}

			if params.waterRadius < radiusMin then
				params.waterRadius = radiusMin
				params.waterMidY = depth - radiusMin
			end

			submersionParams[unitDefID] = params
		end
	end
end

--------------------------------------------------------------------------------
-- Engine callins --------------------------------------------------------------

function gadget:UnitEnteredWater(unitID, unitDefID)
	local params = submersionParams[unitDefID]
	if not params then
		return
	end

	-- Awkward: Dipping a toe in water can disjoint the radius instantly.
	spSetUnitRadiusAndHeight(unitID, params.waterRadius)

	if params.waterMidY then
		local midX, midZ = params.midX, params.midZ
		spSetUnitMidAndAimPos(unitID, midX, params.waterMidY, midZ, midX, params.modelMidY, midZ, true)
	end
end

function gadget:UnitLeftWater(unitID, unitDefID)
	local params = submersionParams[unitDefID]
	if not params then
		return
	end

	-- Awkward: Leaving the water likewise can disjoint the model instantly,
	-- e.g. going from in-range to out-of-range in an unexpected way.
	spSetUnitRadiusAndHeight(unitID, params.modelRadius)

	if params.waterMidY then
		local midX, midY, midZ = params.midX, params.modelMidY, params.midZ
		spSetUnitMidAndAimPos(unitID, midX, midY, midZ, midX, midY, midZ, true)
	end
end

function gadget:Initialize()
	if not next(submersionParams) then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "Removing gadget. No units found.")
		gadgetHandler:RemoveGadget(self)
		return
	end

	local units = spGetAllUnits()
	for ii = 1, #units do
		local unitID = units[ii]
		local unitDefID = spGetUnitDefID(unitID)
		if submersionParams[unitDefID] then
			local x, y, z = spGetUnitPosition(unitID)
			if y <= spGetWaterLevel(x, z) then
				gadget:UnitEnteredWater(unitID, unitDefID)
			else
				gadget:UnitLeftWater(unitID, unitDefID)
			end
		end
	end
end
