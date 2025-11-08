local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = 'Spectate Selected',
		desc      = 'Automatically spectates owner of selected unit',
		author    = 'Niobium',
        version   = '1.0',
		date      = 'April 2011',
		license   = 'GNU GPL v2',
		layer     = 0,
		enabled   = true
	}
end


-- Localized Spring API for performance
local spGetMyTeamID = Spring.GetMyTeamID
local spGetSpectatingState = Spring.GetSpectatingState

local spGetUnitTeam = Spring.GetUnitTeam
local spec, fullview = spGetSpectatingState()
local myTeamID = spGetMyTeamID()

local switchToTeam

function widget:PlayerChanged()
	spec, fullview = spGetSpectatingState()
	if myTeamID ~= spGetMyTeamID() then
		myTeamID = spGetMyTeamID()
		switchToTeam = myTeamID
	end
end

function widget:SelectionChanged(sel)
	if spec and #sel > 0 then
		local selTeam = spGetUnitTeam(sel[1])
		if selTeam and selTeam ~= myTeamID then
			switchToTeam = selTeam
		end
	end
end

local sec = 0
function widget:Update(dt)
	if spec then
		sec = sec + dt
		if sec > 1.5 and switchToTeam ~= nil then	-- added a delay cause doing too quick changes is perf costly, happens when you area drag lots of mixed team units

			local oldMapDrawMode = Spring.GetMapDrawMode()
			Spring.SendCommands('specteam ' .. switchToTeam)
			local newMapDrawMode = Spring.GetMapDrawMode()
			if oldMapDrawMode == 'los' and oldMapDrawMode ~= newMapDrawMode then
				Spring.SendCommands("togglelos")
			end

			myTeamID = switchToTeam
			sec = 0
			switchToTeam = nil
		end
	end
end
