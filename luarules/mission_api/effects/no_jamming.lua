---
--- No Jamming: a stub for an effect that removes every unit's radar jamming. It does nothing yet.
---

local function removeJamming() end

local function restoreJamming() end

return {
	type = "NoJamming",
	Create = removeJamming,
	Remove = restoreJamming,
}
