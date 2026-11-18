-- Preserve the Area Command Filter assignment for both area-Attack widgets.
local tableInsert = table.insert

return function(selectedUnits, filteredTargets)
	local unitTargetsMap = {}
	for unitIdx, selectedUnitId in ipairs(selectedUnits) do
		unitTargetsMap[selectedUnitId] = {}
		for targetIdx, targetUnitId in ipairs(filteredTargets) do
			if
				targetIdx % #filteredTargets == unitIdx % #filteredTargets
				or unitIdx % #selectedUnits == targetIdx % #selectedUnits
			then
				tableInsert(unitTargetsMap[selectedUnitId], targetUnitId)
			end
		end
	end
	return unitTargetsMap
end
