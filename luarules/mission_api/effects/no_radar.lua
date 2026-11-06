---
--- No Radar: a stub for an effect that removes every unit's radar. It does nothing yet.
---

local function removeRadar() end

local function restoreRadar() end

return {
	type = "NoRadar",
	Create = removeRadar,
	Remove = restoreRadar,
}
