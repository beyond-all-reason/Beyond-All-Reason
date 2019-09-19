function gadget:GetInfo()
  return {
	name      = "Unit glass pieces",
	desc      = "Draws semitransparent unit pieces",
	author    = "ivand",
	date      = "2019",
	license   = "PD",
	layer     = 0,
	enabled   = true,
  }
end


if (gadgetHandler:IsSyncedCode()) then
  return
end


-----------------------------------------------------------------
-- Unsynced
-----------------------------------------------------------------

local udIDs = {}

local solidUnitDefs = {}
local glassUnitDefs = {}

local glassUnits = {}

local pieceList

local function UpdateGlassUnits(unitID)
	if not udIDs[unitID] then
		udIDs[unitID] = Spring.GetUnitDefID(unitID)
	end
	local unitDefID = udIDs[unitID]

	if not unitDefID then --unidentified object ?
		return
	end

	if solidUnitDefs[unitDefID] then --a known solid unitDef
		return
	end

	if not glassUnitDefs[unitDefID] then -- unknown unitdef
		pieceList = Spring.GetUnitPieceList(unitID)
		for pieceID, pieceName in ipairs(pieceList) do
			if pieceName:find("_glass") then

				if not glassUnitDefs[unitDefID] then
					glassUnitDefs[unitDefID] = {}
				end
				Spring.Echo(unitID, unitDefID, pieceID, pieceName)
				table.insert(glassUnitDefs[unitDefID], pieceID)
			end
		end

		if not glassUnitDefs[unitDefID] then --no glass pieces found
			solidUnitDefs[unitDefID] = true
		end
	end

	if glassUnitDefs[unitDefID] then --unitdef with glass pieces
		glassUnits[unitID] = true
	end

end

local function RenderGlassUnits()
	--Spring.Echo("RenderGlassUnits")
	gl.Color(0.2, 0.2, 0.2, 0.6)
	gl.AlphaTest(false)
	gl.DepthTest(false)
	gl.DepthMask(false)
	gl.Culling(false)
	gl.Blending(true)

	gl.PushMatrix()

	for unitID, _ in pairs(glassUnits) do
		local unitDefID = udIDs[unitID]
		for _, pieceID in ipairs(glassUnitDefs[unitDefID]) do --go over pieces list
			gl.UnitPieceMultMatrix(unitID, pieceID)
			gl.UnitMultMatrix(unitID)
			--gl.Rect(-10, -10, 10, 10)
			gl.UnitPiece(unitID, pieceID)
		end
	end

	gl.PopMatrix()
end

function gadget:DrawWorld()
	RenderGlassUnits()
end

function gadget:Initialize()
	local allUnits = Spring.GetVisibleUnits(-1, 30, false)
	for _, uID in ipairs(allUnits) do
		UpdateGlassUnits(uID)
	end
end