-- unit_attachments.lua --------------------------------------------------------
-- Simple common reference for multiple types of unit attachments. Provides some
-- different approaches, preferring customParams values over piece default-name.

local SECTION = "unit_attachments"
local PIECENAME_ATTACH = "attach"

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPieceMap = Spring.GetUnitPieceMap

---Searches for attachment pieces via simple naming conventions.
---
---Custom attachment points are preferred over default ones.
---@param unitID UnitID
---@return integer? pieceNum index of the default attach piece
local function resolveAttachPiece(unitID)
	local pieceMap = spGetUnitPieceMap(unitID)
	if not pieceMap then
		return
	end

	local unitDefID = spGetUnitDefID(unitID)
	local unitDef = UnitDefs[unitDefID] ---@as table

	local attachedTurret = unitDef.customParams.attached_con_turret_piece
	if attachedTurret and pieceMap[attachedTurret] then
		return pieceMap[attachedTurret]
	end

	local attachPiece = unitDef.customParams.attach_piece
	if attachPiece then
		if pieceMap[attachPiece] then
			return pieceMap[attachPiece]
		end
		local index = attachPiece and tonumber(attachPiece)
		if index and table.contains(pieceMap, index) then
			return index ---@as integer
		end
	end

	local pieceIndex = pieceMap[PIECENAME_ATTACH]
	if pieceIndex then
		return pieceIndex
	end

	local messages = {}
	for key, value in pairs({
		[unitDef.name .. " missing attached_con_turret_piece "] = attachedTurret,
		[unitDef.name .. " missing attach_piece "] = attachPiece,
		[unitDef.name .. " missing piece named "] = pieceIndex,
	}) do
		messages[#messages + 1] = key .. value
	end
	Spring.Log(SECTION, LOG.WARNING, table.concat(messages))
end

return {
	ResolveAttachPiece = resolveAttachPiece,
}
