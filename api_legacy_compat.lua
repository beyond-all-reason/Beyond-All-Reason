function widget:GetInfo()
	return {
		name        = "Legacy Compatibility Layer",
		desc        = "Bridges detached BAR.* modules back to Spring.* for older community widgets",
		author      = "CrossGamer",
		date        = "2026",
		license     = "GNU GPL, v2 or later",
		layer       = -math.huge,
		enabled     = true,
		alwaysStart = true,
	}
end

local ALIASES = {
	GetMyTeamID              = "GetLocalTeamID",
	GetMyPlayerID            = "GetLocalPlayerID",
	GetMyAllyTeamID          = "GetLocalAllyTeamID",
	GiveOrderToUnitArray     = "GiveOrderArrayToUnitArray",
}

local function installBridge()
	if not Spring then return end

	if BAR then
		Spring.I18N              = Spring.I18N or BAR.I18N
		Spring.Utilities         = Spring.Utilities or BAR.Utilities
		Spring.Debug             = Spring.Debug or BAR.Debug
		Spring.Lava              = Spring.Lava or BAR.Lava
		Spring.GetModOptionsCopy = Spring.GetModOptionsCopy or BAR.GetModOptionsCopy
	end

	for oldName, newName in pairs(ALIASES) do
		if not Spring[oldName] and Spring[newName] then
			Spring[oldName] = Spring[newName]
		end
	end

	local mt = getmetatable(Spring) or {}
	if mt.__compat_installed then return end
	mt.__compat_installed = true

	local orig_index = mt.__index
	mt.__index = function(t, key)
		if orig_index then
			local val = (type(orig_index) == "function") and orig_index(t, key) or orig_index[key]
			if val ~= nil then return val end
		end

		if BAR and BAR[key] ~= nil then
			rawset(t, key, BAR[key])
			return BAR[key]
		end

		if ALIASES[key] and Spring[ALIASES[key]] then
			rawset(t, key, Spring[ALIASES[key]])
			return Spring[ALIASES[key]]
		end

		return nil
	end

	setmetatable(Spring, mt)
end

installBridge()

function widget:Initialize()
	installBridge()
end

function widget:CommandsChanged()
	installBridge()
end
