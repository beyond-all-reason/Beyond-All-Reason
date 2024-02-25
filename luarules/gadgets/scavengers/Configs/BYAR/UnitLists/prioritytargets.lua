local priorityTargets = {
	"armada_commander",
	"cortex_commander",
}

local priorityTargetsID = {}
for _, unitName in ipairs(priorityTargets) do
	local unitDefID = UnitDefNames[unitName].id
	priorityTargetsID[unitDefID] = true
end

return {
	PriorityTargets = priorityTargets,
	PriorityTargetsID = priorityTargetsID,
}