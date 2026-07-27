
if not gadgetHandler:IsSyncedCode() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Wade Effects",
		desc      = "Spawn wakes when non-ship ground units move while partially, but not completely submerged",
		author    = "Anarchid",
		date      = "March 2016",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

---@class WadeUnitData
---@field id integer
---@field unitID integer
---@field h number
---@field ceg string

---@type table<integer, WadeUnitData>
local unit = {}
local unitsCount = 0
---@type WadeUnitData[]
local unitsData = {}

local fold_frames = 4 -- every X-th frame
local n_folds = 3 -- check every X-th unit
local current_fold = 1

local spGetUnitIsCloaked = Spring.GetUnitIsCloaked
local spGetUnitPosition  = Spring.GetUnitPosition
local spGetUnitVelocity  = Spring.GetUnitVelocity
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitDefDimensions = Spring.GetUnitDefDimensions
local spSpawnCEG = Spring.SpawnCEG

local wadeDepth = {}
---@type table<integer, string|false>
local wadeCeg = {}

local smc = Game.speedModClasses		-- Accepted values are 0 = Tank, 1 = KBot, 2 = Hover, 3 = Ship.
local wadingSMC = {
	[smc.Tank] = true,
	[smc.KBot] = true,
}
local cegSizes = {"waterwake-tiny", "waterwake-small", "waterwake-medium", "waterwake-large", "waterwake-huge"}

local function checkCanWade(unitDef)
	local moveDef = unitDef.moveDef
	if not moveDef then
		return false
	end
	local smClass = moveDef.smClass
	if not smClass or not wadingSMC[smClass] then
		return false
	end
	return true
end

for unitDefID = 1, #UnitDefs do
	local unitDef = UnitDefs[unitDefID]
	if checkCanWade(unitDef) then
		wadeDepth[unitDefID] = -spGetUnitDefDimensions(unitDefID).height
		local footprint = math.max(unitDef.xsize, unitDef.zsize)
		wadeCeg[unitDefID] = cegSizes[math.clamp(footprint - 2, 1, #cegSizes)]
	else
		-- there are ~400 wadables but the highest one's ID is >512, so we also assign `false`
		-- instead of keeping them `nil` to keep the internal representation an array (faster)
		wadeDepth[unitDefID] = false
		wadeCeg[unitDefID] = false
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	local maxDepth = wadeDepth[unitDefID]
	local ceg = wadeCeg[unitDefID]
	if maxDepth and ceg then
		unitsCount = unitsCount + 1
		local data = {id = unitsCount, unitID = unitID, h = maxDepth, ceg = ceg}
		unitsData[unitsCount] = data
		unit[unitID] = data
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local data = unit[unitID]
	if data then
		local unitIndex = data.id
		if unitIndex ~= unitsCount then
			local lastUnitData = unitsData[unitsCount]
			if lastUnitData then
				unitsData[unitIndex] = lastUnitData
				lastUnitData.id = unitIndex
			end
		end
		unit[unitID] = nil
		unitsData[unitsCount] = nil
		unitsCount = unitsCount - 1
	end
end

function gadget:GameFrame(n)
	if n % fold_frames ~= 0 then
		return
	end

	local listData = unitsData
	for i = current_fold, unitsCount, n_folds do
		local data = listData[i]
		if data then
			local unitID = data.unitID
			local x, y, z = spGetUnitPosition(unitID)
			if y and y > data.h and y <= 0 then
				local _, _, _, speed = spGetUnitVelocity(unitID)
				if speed and speed > 0 and not spGetUnitIsCloaked(unitID) then
					spSpawnCEG(data.ceg, x, 0, z, 0, 0, 0)
				end
			end
		end
	end

	current_fold = current_fold + 1
	if current_fold > n_folds then
		current_fold = 1
	end
end

function gadget:Initialize()
	local minHeight = Spring.GetGroundExtremes()
	if minHeight > 20 then
		gadgetHandler:RemoveGadget(self)
		return
	end

	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
	end
end
