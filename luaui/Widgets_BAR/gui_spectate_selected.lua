
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
local spGetUnitTeam = Spring.GetUnitTeam
local spGetMyTeamID = Spring.GetMyTeamID
local spSendCommands = Spring.SendCommands

function widget:SelectionChanged(sel)
	if WG['smartselect'] and not WG['smartselect'].updateSelection then return end
	if spGetSpectatingState() then
        if #sel > 0 then
            local selTeam = spGetUnitTeam(sel[1])
            if selTeam and selTeam ~= spGetMyTeamID() then
                spSendCommands('specteam ' .. selTeam)
            end
        end
    end
end
