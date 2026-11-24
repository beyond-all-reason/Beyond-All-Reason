-- The lower value is the stricter choice, matching the personal settings menu.
local vision = { allied = 1, optIn = 2, full = 3 }

function vision.lobbyMode(option)
	if option == "allied" or option == true or tonumber(option) == 1 then
		return vision.allied
	end
	return option == "optin" and vision.optIn or vision.full
end

-- Install before LuaUI copies Spring into the bundled and user widget environments.
-- Only LuaRules grants access to other teams, including their communications.
function vision.installWidgetControls(spring)
	local hasFullAccess = spring.GetSpectatorFullCommunications
	local setView, setSelect, setTeam =
		spring.SetSpectatorFullView, spring.SetSpectatorFullSelect, spring.SetSpectatorTeam
	local getPlayer, getTeam = spring.GetPlayerInfo, spring.GetTeamInfo
	local myPlayer = spring.GetMyPlayerID()
	spring.SetSpectatorFullCommunications = nil

	function spring.SetSpectatorFullView(enabled)
		if not enabled or hasFullAccess() then
			setView(enabled)
		end
	end

	function spring.SetSpectatorFullSelect(enabled)
		if not enabled or hasFullAccess() then
			setSelect(enabled)
		end
	end

	function spring.SetSpectatorTeam(teamID)
		if not hasFullAccess() then
			local _, _, spectating, _, originalAllyTeam = getPlayer(myPlayer, false)
			local _, _, _, _, _, targetAllyTeam = getTeam(teamID, false)
			if not spectating or not originalAllyTeam or originalAllyTeam ~= targetAllyTeam then
				return false
			end
		end
		return setTeam(teamID)
	end
end

return vision
