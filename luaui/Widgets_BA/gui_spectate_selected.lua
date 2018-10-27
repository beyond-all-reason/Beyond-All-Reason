
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

local spGetSpectatingState = Spring.GetSpectatingState
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitTeam = Spring.GetUnitTeam
local spGetMyTeamID = Spring.GetMyTeamID
local spSendCommands = Spring.SendCommands

function widget:CommandsChanged()
	if spGetSpectatingState() then
        local selUnits = spGetSelectedUnits()
        if #selUnits > 0 then
            local selTeam = spGetUnitTeam(selUnits[1])
            if selTeam and selTeam ~= spGetMyTeamID() then
                spSendCommands('specteam ' .. selTeam)
            end
        end
    end
end
