function gadget:GetInfo()
  return {
    name      = "No Share Self-D",
    desc      = "Prevents self-destruction when a unit changes hands or a player leaves",
    author    = "quantum, Bluestone",
    date      = "July 13, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end


if (not gadgetHandler:IsSyncedCode()) then
 
function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
  -- remove self d commands on shared units
  if (Spring.GetUnitSelfDTime(unitID) > 0) then
    Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, {})
  end
end

function gadget:PlayerChanged(playerID) --necessary wtfness, probably can remove in 97.0+
end

else

-- remove self d orders from empty teams
function gadget:PlayerChanged(playerID)
	local _,active,spec,teamID = Spring.GetPlayerInfo(playerID)
	if active and not spec then return end
	local team = Spring.GetPlayerList(teamID)
	
	if team then
		-- check team is empty
		for _,pID in pairs(team) do
			_,active,spec = Spring.GetPlayerInfo(pID)
			if active and not spec then
				return
			end
		end
	
		-- cancel any self d orders
		local units = Spring.GetTeamUnits(teamID)
		for _,unitID in pairs(units) do
			if (Spring.GetUnitSelfDTime(unitID) > 0) then
				Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, {})
			end
		end
	end
end


end