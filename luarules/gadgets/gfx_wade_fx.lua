
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

local unit = {}
local unitsCount = 0
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
local wadeSfxID = {}

local smc = Game.speedModClasses		-- Accepted values are 0 = Tank, 1 = KBot, 2 = Hover, 3 = Ship.
local wadingSMC = {
	[smc.Tank] = true,
	[smc.KBot] = true,
}
local SFXTYPE_WAKE1 = 2
local SFXTYPE_WAKE2 = 3

local cegSizes = {"waterwake-tiny", "waterwake-small", "waterwake-medium", "waterwake-large", "waterwake-huge"}

local unitWadeCeg = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if not unitDef.isBuilding then
		local footprint = math.max(unitDef.xsize, unitDef.zsize)
		unitWadeCeg[unitDefID] = cegSizes[math.clamp(footprint - 2, 1, #cegSizes)]
	end
end

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

		local cpR = unitDef.customParams.modelradius
		local r = cpR and tonumber(cpR) or unitDef.radius
		wadeSfxID[unitDefID] = (((r > 50) or unitDef.customParams.floattoggle) and SFXTYPE_WAKE2) or SFXTYPE_WAKE1
	else
		-- there are ~400 wadables but the highest one's ID is >512, so we also assign `false`
		-- instead of keeping them `nil` to keep the internal representation an array (faster)
		wadeDepth[unitDefID] = false
		wadeSfxID[unitDefID] = false
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	local maxDepth = wadeDepth[unitDefID]
	if maxDepth then
		unitsCount = unitsCount + 1
		unitsData[unitsCount] = unitID
		unit[unitID] = {id = unitsCount, h = maxDepth, fx = wadeSfxID[unitDefID], defid = unitDefID}
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	local data = unit[unitID]
	if data then
		local unitIndex = data.id
		local lastUnitID = unitsData[unitsCount]
		unitsData[unitIndex] = lastUnitID
		unit[lastUnitID].id = unitIndex --shift last entry into empty space
		unitsData[unitsCount] = nil
		unitsCount = unitsCount - 1
		unit[unitID] = nil
	end
end

function gadget:GameFrame(n)
	if n%fold_frames == 0 then
		if (n <= fold_frames) then
			local minheight = Spring.GetGroundExtremes()
			if minheight > 20 then
				gadgetHandler:RemoveGadget(self)
				return
			end
		end

		local listData = unitsData
		if current_fold and unitsCount then
			for i = current_fold, unitsCount, n_folds do	-- this line errors sometimes: "attempt to compare number with nil" therefore the nil check above
				local unitID = listData[i]
				local data = unit[unitID]
				local unitDefID = data.defid
				if data and data.h and unitWadeCeg[unitDefID] then
					local x,y,z = spGetUnitPosition(unitID)
					local h = data.h

					if y and y > h and y <= 0 then
						local _, _, _, speed = spGetUnitVelocity(unitID)
						if speed and speed > 0 and not spGetUnitIsCloaked(unitID) then
							-- 1 is the pieceID, most likely it's usually the base piece
							-- but even if it isn't, it doesn't really matter
							--spusCallAsUnit(unitID, spusEmitSfx, 1, data.fx)
							spSpawnCEG(unitWadeCeg[unitDefID], x, 0, z, 0, 0, 0)
						end
					end
				end
			end
		end
		current_fold = (current_fold % n_folds) + 1
	end
end

function gadget:Initialize()
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
	end
end
