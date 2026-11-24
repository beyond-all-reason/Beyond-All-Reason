function widget:GetInfo()
	return {
		name = "Spectator Commands",
		desc = "Select spectator sight, selection and the followed team",
		layer = 0,
		enabled = true,
	}
end

if not Spring.SetSpectatorTeam then
	return false
end

local function specTeam(_, _, words)
	local teamID = tonumber(words[1])
	return teamID ~= nil and Spring.SetSpectatorTeam(teamID)
end

local function specFullView(_, _, words)
	local spectating, fullView = Spring.GetSpectatingState()
	if not spectating then
		return false
	end
	local view, fullSelect = not fullView, not fullView
	if words[1] then
		local mode = tonumber(words[1])
		if mode ~= 0 and mode ~= 1 and mode ~= 2 and mode ~= 3 then
			return false
		end
		view, fullSelect = mode % 2 == 1, mode >= 2
	end
	Spring.SetSpectatorFullView(view)
	Spring.SetSpectatorFullSelect(fullSelect)
	return true
end

function widget:Initialize()
	widgetHandler:AddAction("specteam", specTeam, nil, "tp")
	widgetHandler:AddAction("specfullview", specFullView, nil, "tp")
end

function widget:Shutdown()
	widgetHandler:RemoveAction("specteam")
	widgetHandler:RemoveAction("specfullview")
end
