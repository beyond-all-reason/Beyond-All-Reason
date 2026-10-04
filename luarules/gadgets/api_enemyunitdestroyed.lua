
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "EnemyUnitDestroyed",
		desc	= 'Calls Script.LuaUI.EnemyUnitDestroyed for enemy units dying in allied LOS',
		author	= 'Beherith',
		date	= '20211029',
		license	= 'GNU GPL, v2 or later',
		layer	= -999999,
		enabled	= false -- api_widget_events.lua exists
	}
end

if not gadgetHandler:IsSyncedCode() then
	local spGetUnitAllyTeam =  Spring.GetUnitAllyTeam
	local myAllyTeamID = Spring.GetMyAllyTeamID()
	local spec, fullView = Spring.GetSpectatingState()

	function gadget:Initialize()
		myAllyTeamID = Spring.GetMyAllyTeamID()
		spec, fullView = Spring.GetSpectatingState()
	end

	function gadget:PlayerChanged(playerID)
		gadget:Initialize()
	end

	function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID, weaponDefID)
		local allyTeam = spGetUnitAllyTeam(unitID)
		if (spec and fullview) or (allyTeam and allyTeam ~= myAllyTeamID) then
			local losstate = Spring.GetUnitLosState(unitID, myAllyTeamID)
			if losstate and losstate["los"] and Script.LuaUI("EnemyUnitDestroyed") then
				Script.LuaUI.EnemyUnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID, weaponDefID)
			end
		end
	end
end
