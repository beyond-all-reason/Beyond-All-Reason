local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Dynamic collision volume & Hitsphere Scaledown",
		desc = "Adjusts collision volume for pop-up style units & Reduces the diameter of default sphere collision volume for 3DO models",
		author = "Deadnight Warrior",
		date = "Nov 26, 2011",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetUnitArmored = Spring.GetUnitArmored
local spGetUnitCollisionData = Spring.GetUnitCollisionVolumeData
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitHeight = Spring.GetUnitHeight
local spGetUnitPieceList = Spring.GetUnitPieceList
local spSetPieceCollisionData = Spring.SetUnitPieceCollisionVolumeData
local spSetUnitCollisionData = Spring.SetUnitCollisionVolumeData
local spSetUnitMidAndAimPos = Spring.SetUnitMidAndAimPos
local spSetUnitRadiusAndHeight = Spring.SetUnitRadiusAndHeight

local CollisionVolumes = include("LuaRules/Configs/CollisionVolumes.lua") ---@type CollisionVolumes

local COLVOL_CONFIG = CollisionVolumes.COLVOL.CONFIG
local unitDefColVolType = CollisionVolumes.UnitDefColVolType
local unitDefColVolData = CollisionVolumes.UnitDefColVolData
local unitDefModelColVol = CollisionVolumes.UnitDefModelColVol
local pieceColVolDisabled = CollisionVolumes.PieceColVolDisabled
local rescaleFeature3DO = CollisionVolumes.ModelVolumes.FEATURE["3do"].rescale

local featureModelType = {} ---@type {[FeatureDefID?]:("3do"|"s3o")?}
for featureDefID, featureDef in pairs(FeatureDefs) do
	featureModelType[featureDefID] = featureDef.modeltype
end

---@class PopupUnit
---@field colvol ColVolUnitOnOff|ColVolPieceMapOnOff
---@field setVolume fun(unitID: integer, colvol: UnitCollisionVolumeData|ColVolPieceMap)
---@field armored boolean? Unset until the first update.

local popupUnits = {} ---@type table<integer, PopupUnit>

-- Setters ---------------------------------------------------------------------

local function setUnitVolume(unitID, colvol)
	spSetUnitCollisionData(
		unitID,
		colvol[1],
		colvol[2],
		colvol[3],
		colvol[4],
		colvol[5],
		colvol[6],
		colvol[7],
		colvol[8],
		colvol[9]
	)
end

local function setPieceVolume(unitID, piece, colvol)
	spSetPieceCollisionData(
		unitID,
		piece,
		colvol[9] ~= false,
		colvol[1],
		colvol[2],
		colvol[3],
		colvol[4],
		colvol[5],
		colvol[6],
		colvol[7],
		colvol[8]
	)
end

local function setAllPieceVolumes(unitID, pieceMap)
	for piece = 1, #spGetUnitPieceList(unitID) do
		-- Disable all pieces not included in the config piece map for safe init:
		setPieceVolume(unitID, piece, pieceMap[piece] or pieceColVolDisabled)
	end
end

local function setNamedPieceVolumes(unitID, pieceMap)
	for piece, colvol in pairs(pieceMap) do
		if type(piece) == "number" then
			setPieceVolume(unitID, piece, colvol)
		end
	end
end

local function setAimOffsets(unitID, unitHeight, offsets)
	spSetUnitMidAndAimPos(unitID, 0, unitHeight / 2, 0, offsets[1], offsets[2], offsets[3], true)
end

local setConfigVolume = {
	[COLVOL_CONFIG.UNIT_STATIC] = function(unitID, colvol)
		setUnitVolume(unitID, colvol)
		if colvol.offsets then
			setAimOffsets(unitID, spGetUnitHeight(unitID), colvol.offsets)
		end
	end,
	[COLVOL_CONFIG.UNIT_DYNAMIC] = function(unitID, colvol)
		popupUnits[unitID] = { colvol = colvol, setVolume = setUnitVolume }
	end,
	[COLVOL_CONFIG.PIECE_STATIC] = function(unitID, colvol)
		setAllPieceVolumes(unitID, colvol)
		if colvol.offsets then
			setAimOffsets(unitID, spGetUnitHeight(unitID), colvol.offsets)
		end
	end,
	[COLVOL_CONFIG.PIECE_DYNAMIC] = function(unitID, colvol)
		setAllPieceVolumes(unitID, colvol.on)
		popupUnits[unitID] = { colvol = colvol, setVolume = setNamedPieceVolumes }
	end,
}

-- Engine callins --------------------------------------------------------------

function gadget:Initialize()
	for _, featureID in ipairs(Spring.GetAllFeatures()) do
		local modelType = featureModelType[spGetFeatureDefID(featureID)]
		local modelData = modelType and CollisionVolumes.ModelVolumes.FEATURE[modelType]
		if modelData and modelData.rescale then
			modelData.rescale(featureID)
		end
	end

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	local modelColVol = unitDefModelColVol[unitDefID]
	if modelColVol then
		if modelColVol[9] == nil then
			-- The def does not give the primary axis, so the first unit of the def does.
			modelColVol[9] = select(9, spGetUnitCollisionData(unitID))
		end
		setUnitVolume(unitID, modelColVol)
		if modelColVol.radius then
			spSetUnitRadiusAndHeight(unitID, modelColVol.radius, modelColVol.height)
		end
	end

	local configType = unitDefColVolType[unitDefID]
	if configType then
		setConfigVolume[configType](unitID, unitDefColVolData[unitDefID])
	end
end

function gadget:UnitDestroyed(unitID)
	popupUnits[unitID] = nil
end

function gadget:FeatureCreated(featureID)
	if featureModelType[spGetFeatureDefID(featureID)] == "3do" then
		rescaleFeature3DO(featureID)
	end
end

function gadget:GameFrame(frame)
	-- Pop-up units switch volumes with their armored state, checked twice per second.
	if frame % 15 ~= 0 then
		return
	end
	for unitID, popup in pairs(popupUnits) do
		local armored = spGetUnitArmored(unitID) == true
		if popup.armored ~= armored then
			local unitHeight = spGetUnitHeight(unitID)
			if unitHeight then
				popup.armored = armored
				local colvol = armored and popup.colvol.off or popup.colvol.on
				popup.setVolume(unitID, colvol)
				if colvol.offsets then
					setAimOffsets(unitID, unitHeight, colvol.offsets)
				end
			else
				popupUnits[unitID] = nil
			end
		end
	end
end
