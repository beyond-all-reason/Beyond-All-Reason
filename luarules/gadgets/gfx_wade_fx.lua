--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Wade Effects",
		desc      = "Spawn wakes when non-ship ground units move while partially, but not completely submerged",
		author    = "Anarchid",
		date      = "March 2016",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

local unit = {}
local unitsCount = 0
local unitsData = {}

local fold_frames = 7 -- every seventh frame
local n_folds = 4 -- check every fourth unit
local current_fold = 1

local spGetUnitIsCloaked = Spring.GetUnitIsCloaked
local spGetUnitPosition  = Spring.GetUnitPosition
local spGetUnitVelocity  = Spring.GetUnitVelocity

local spusCallAsUnit = Spring.UnitScript.CallAsUnit
local spusEmitSfx    = Spring.UnitScript.EmitSfx

local wadeDepth = {}
local wadeSfxID = {}
do
	local smc = Game.speedModClasses
	local wadingSMC = {
		[smc.Tank] = true,
		[smc.KBot] = true,
	}
	local SFXTYPE_WAKE1 = 2
	local SFXTYPE_WAKE2 = 3

	local UD = UnitDefs
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

	local spGetUnitDefDimensions = Spring.GetUnitDefDimensions
	for unitDefID = 1, #UD do
		local unitDef = UD[unitDefID]
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
end

function gadget:UnitCreated(unitID, unitDefID)
	local maxDepth = wadeDepth[unitDefID]
	if maxDepth then
		unitsCount = unitsCount + 1
		unitsData[unitsCount] = unitID
		unit[unitID] = {id = unitsCount, h = maxDepth, fx = wadeSfxID[unitDefID]}
	end
end

function gadget:UnitDestroyed(unitID)
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
		local listData = unitsData
		for i = current_fold, unitsCount, n_folds do
			local unitID = listData[i]
			local data = unit[unitID]
			local x,y,z = spGetUnitPosition(unitID)
			local h = data.h

			local _, _, _, speed = spGetUnitVelocity(unitID)
			if speed and y > h and y <= 0 and speed > 0 and not spGetUnitIsCloaked(unitID) then
				-- 1 is the pieceID, most likely it's usually the base piece
				-- but even if it isn't, it doesn't really matter
				spusCallAsUnit(unitID, spusEmitSfx, 1, data.fx)
			end
		end
		current_fold = (current_fold % n_folds) + 1
	end
end

function gadget:Initialize()
	local spGetUnitDefID = Spring.GetUnitDefID
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
	end
end
