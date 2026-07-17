--- Unit validation helpers for advplayerslist.lua
--- partition depends only on the sender's modes, so memoise once per selection, not per player
local UnitShared = VFS.Include("common/luaUtilities/sharing/unit_transfer_shared.lua")

local UnitValidationHelpers = {}

-- The selection these memos describe (nil when nothing is selected).
local currentSelection = nil
-- Memoised ValidateUnits result for a shareable (canShare) receiver under currentSelection.
local sharedPartition = nil
-- Memoised trivial result for a non-shareable receiver (ValidateUnits short-circuits).
local deniedResult = nil
-- separate backing tables so ValidateUnits fills in place and both can be live in one draw pass
local sharedScratch = {}
local deniedScratch = {}

---Record the active selection and drop the per-selection memos; partition computed lazily later.
---@param selectedUnits number[]?
function UnitValidationHelpers.SetSelection(selectedUnits)
	currentSelection = (selectedUnits and #selectedUnits > 0) and selectedUnits or nil
	sharedPartition = nil
	deniedResult = nil
end

---Drop the memos without touching the selection; used when our own sharing policy changes.
function UnitValidationHelpers.InvalidateValidations()
	sharedPartition = nil
	deniedResult = nil
end

---Validate the current selection for a single receiver, memoised; nil when nothing selected.
---@param myTeamID number
---@param receiverTeamID number
---@return UnitValidationResult | nil
function UnitValidationHelpers.GetPlayerUnitValidation(myTeamID, receiverTeamID)
	if not currentSelection then
		return nil
	end

	local policyResult = UnitShared.GetCachedPolicyResult(myTeamID, receiverTeamID, Spring)
	if not policyResult.canShare then
		-- denied receivers all short-circuit to the same empty partition, so compute once
		if not deniedResult then
			deniedResult = UnitShared.ValidateUnits(policyResult, currentSelection, Spring, nil, deniedScratch)
		end
		return deniedResult
	end

	-- Identical for every shareable receiver (modes are the sender's), so compute once.
	if not sharedPartition then
		sharedPartition = UnitShared.ValidateUnits(policyResult, currentSelection, Spring, nil, sharedScratch)
	end
	return sharedPartition
end

return UnitValidationHelpers
